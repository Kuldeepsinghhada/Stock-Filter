import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'models.dart';
import 'order_service.dart';
import 'order_monitor.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_services.dart';
import 'package:stock_demo/Utils/INdicators/indicator_engine.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';

class TradeExecutor {
  final OrderService orderService;
  final OrderMonitor orderMonitor;

  // Track active trades by symbol to prevent duplicate executions
  final Set<String> _activeTrades = {};

  TradeExecutor({
    required this.orderService,
    required this.orderMonitor,
  });

  /// Executes the full trade flow for a given configuration.
  Future<void> executeTrade(TradeConfig config) async {
    if (_activeTrades.contains(config.symbol)) {
      developer.log(
          'Trade for ${config.symbol} is already active. Ignoring new request.',
          name: 'TradeExecutor');
      return;
    }

    _activeTrades.add(config.symbol);
    developer.log('Starting trade execution for ${config.symbol}',
        name: 'TradeExecutor');

    try {
      await _runTradeFlow(config);
    } catch (e) {
      developer.log('Trade flow for ${config.symbol} failed with error: $e',
          name: 'TradeExecutor', error: e);
    } finally {
      _activeTrades.remove(config.symbol);
      developer.log(
          'Finished trade execution for ${config.symbol}. Lock released.',
          name: 'TradeExecutor');
    }
  }

  Future<void> _runTradeFlow(TradeConfig config) async {
    // 1. Place an intraday BUY MARKET order (MIS)
    String buyOrderId;
    try {
      buyOrderId = await orderService.placeOrder(
        variety: 'regular',
        exchange: config.exchange,
        tradingsymbol: config.symbol,
        transactionType: 'BUY',
        quantity: config.quantity,
        product: 'MIS',
        orderType: 'MARKET',
      );
      developer.log('BUY order placed successfully. Order ID: $buyOrderId',
          name: 'TradeExecutor');
    } catch (e) {
      developer.log('Failed to place BUY order.',
          name: 'TradeExecutor', error: e);
      return;
    }

    // 2. & 3. Poll the order status every X seconds for a max of Y seconds
    OrderDetails? buyOrderDetails = await orderMonitor.pollOrderStatus(
      orderId: buyOrderId,
      pollingInterval: config.pollingInterval,
      timeout: config.timeout,
    );

    // 6. If the BUY order is still not COMPLETE after timeout
    if (buyOrderDetails == null) {
      developer.log(
          'BUY order $buyOrderId timed out after ${config.timeout.inSeconds}s.',
          name: 'TradeExecutor');
      // Fetch latest state to check if it's still open
      try {
        final latestDetails = await orderService.getOrderHistory(buyOrderId);
        if (latestDetails.isOpen) {
          developer.log('Cancelling open BUY order $buyOrderId',
              name: 'TradeExecutor');
          await orderService.cancelOrder(buyOrderId);
        }
      } catch (e) {
        developer.log('Failed to fetch or cancel timed-out BUY order.',
            name: 'TradeExecutor', error: e);
      }
      return; // Exit flow
    }

    // 5. If the BUY order is REJECTED or CANCELLED, stop the flow.
    if (buyOrderDetails.isRejected || buyOrderDetails.isCancelled) {
      developer.log(
          'BUY order $buyOrderId was ${buyOrderDetails.status}. Stopping flow.',
          name: 'TradeExecutor');
      return;
    }

    // 4. If the order status becomes COMPLETE
    if (buyOrderDetails.isComplete) {
      final averagePrice = buyOrderDetails.averagePrice;
      final filledQuantity = buyOrderDetails.filledQuantity;

      developer.log(
          'BUY order COMPLETE. Avg Price: $averagePrice, Qty: $filledQuantity',
          name: 'TradeExecutor');

      if (filledQuantity == 0 || averagePrice == 0) {
        developer.log(
            'Warning: Filled quantity or average price is 0. Aborting SL/Target placement.',
            name: 'TradeExecutor');
        return;
      }

      // Calculate SL and Target prices
      double slOffset = config.isPercentageBased
          ? averagePrice * (config.slPoints / 100)
          : config.slPoints;
      double targetOffset = config.isPercentageBased
          ? averagePrice * (config.targetPoints / 100)
          : config.targetPoints;

      double slPrice = averagePrice - slOffset;
      double targetPrice = averagePrice + targetOffset;

      // Round to nearest tick size (assuming 0.05 for NSE)
      slPrice = (slPrice * 20).round() / 20;
      targetPrice = (targetPrice * 20).round() / 20;

      developer.log('Calculated SL: $slPrice, Target: $targetPrice',
          name: 'TradeExecutor');

      // Place SELL Stop Loss order
      String? slOrderId;
      try {
        slOrderId = await orderService.placeOrder(
          variety: 'regular',
          exchange: config.exchange,
          tradingsymbol: config.symbol,
          transactionType: 'SELL',
          quantity: filledQuantity,
          product: 'MIS',
          orderType: config.slOrderType,
          triggerPrice: slPrice,
          price: config.slOrderType == 'SL'
              ? slPrice
              : null, // If SL-L, pass price as well
        );
        developer.log('SL Order placed. Order ID: $slOrderId',
            name: 'TradeExecutor');
      } catch (e) {
        developer.log('Failed to place SL order.',
            name: 'TradeExecutor', error: e);
      }

      // Place SELL Target LIMIT order
      String? targetOrderId;
      try {
        targetOrderId = await orderService.placeOrder(
          variety: 'regular',
          exchange: config.exchange,
          tradingsymbol: config.symbol,
          transactionType: 'SELL',
          quantity: filledQuantity,
          product: 'MIS',
          orderType: 'LIMIT',
          price: targetPrice,
        );
        developer.log('Target Order placed. Order ID: $targetOrderId',
            name: 'TradeExecutor');
      } catch (e) {
        developer.log('Failed to place Target order.',
            name: 'TradeExecutor', error: e);
      }

      // 7. Continuously monitor both order statuses (OCO logic)
      if (slOrderId != null && targetOrderId != null) {
        await _monitorOco(
          slOrderId: slOrderId,
          targetOrderId: targetOrderId,
          config: config,
          averagePrice: averagePrice,
          initialSL: slPrice,
          initialTarget: targetPrice,
          risk: slOffset,
        );
      } else {
        developer.log(
            'Could not place both SL and Target. OCO monitoring skipped.',
            name: 'TradeExecutor');
      }
    }
  }

  /// Monitors SL and Target orders. If one completes, cancels the other.
  /// Also implements EOD square-off and dynamic trailing stop loss at +1R profit using 1-minute Supertrend.
  Future<void> _monitorOco({
    required String slOrderId,
    required String targetOrderId,
    required TradeConfig config,
    required double averagePrice,
    required double initialSL,
    required double initialTarget,
    required double risk,
  }) async {
    developer.log(
        'Starting OCO monitoring for SL: $slOrderId, Target: $targetOrderId',
        name: 'TradeExecutor');

    DateTime? lastFetchTime;
    List<HistoricalDataModel> candles1m = [];
    double currentTrailedSL = initialSL;
    bool isTrailingActive = false;

    while (true) {
      try {
        final prefs = SharedPreferenceHelper.instance;

        // 1. Check EOD Square-off
        final sqEnabled = await prefs.getSquareOffEnabled();
        if (sqEnabled) {
          final sqTimeStr = await prefs.getSquareOffTime();
          final sqParts = sqTimeStr.split(":");
          if (sqParts.length == 2) {
            final hour = int.tryParse(sqParts[0]) ?? 15;
            final minute = int.tryParse(sqParts[1]) ?? 15;
            final now = DateTime.now();
            final sqTime = DateTime(now.year, now.month, now.day, hour, minute);
            if (now.isAfter(sqTime)) {
              developer.log(
                  'EOD Square-off time reached. Cancelling open orders and exiting position.',
                  name: 'TradeExecutor');
              await _safeCancel(slOrderId);
              await _safeCancel(targetOrderId);
              try {
                final sellMarketId = await orderService.placeOrder(
                  variety: 'regular',
                  exchange: config.exchange,
                  tradingsymbol: config.symbol,
                  transactionType: 'SELL',
                  quantity: config.quantity,
                  product: 'MIS',
                  orderType: 'MARKET',
                );
                developer.log(
                    'EOD Square-off MARKET SELL order placed: $sellMarketId',
                    name: 'TradeExecutor');
              } catch (e) {
                developer.log('EOD Market Sell order placement failed: $e',
                    name: 'TradeExecutor', error: e);
              }
              break;
            }
          }
        }

        // Fetch both statuses
        final slDetails = await orderService.getOrderHistory(slOrderId);
        final targetDetails = await orderService.getOrderHistory(targetOrderId);

        // If Target order completes, cancel SL
        if (targetDetails.isComplete) {
          developer.log(
              'Target order $targetOrderId COMPLETE. Cancelling SL $slOrderId',
              name: 'TradeExecutor');
          await _safeCancel(slOrderId);
          break;
        }

        // If SL order completes, cancel Target
        if (slDetails.isComplete) {
          developer.log(
              'SL order $slOrderId COMPLETE. Cancelling Target $targetOrderId',
              name: 'TradeExecutor');
          await _safeCancel(targetOrderId);
          break;
        }

        // If both are cancelled or rejected (e.g., by user manually or exchange), stop monitoring
        if ((slDetails.isCancelled || slDetails.isRejected) &&
            (targetDetails.isCancelled || targetDetails.isRejected)) {
          developer.log(
              'Both SL and Target are no longer active. Stopping OCO monitoring.',
              name: 'TradeExecutor');
          break;
        }

        // 2. Fetch LTP to check for +1R Trailing condition
        double ltp = 0.0;
        try {
          final cleanSymbol = config.symbol.replaceAll("NSE:", "").replaceAll("BSE:", "");
          final instrumentKey = '${config.exchange}:$cleanSymbol';
          final ltpResponse = await orderService.apiClient
              .get('/quote/ltp?i=$instrumentKey');
          if (ltpResponse != null && ltpResponse is Map) {
            if (ltpResponse.containsKey(instrumentKey)) {
              ltp =
                  (ltpResponse[instrumentKey]['last_price'] as num).toDouble();
            }
          }
        } catch (e) {
          developer.log('Error fetching LTP: $e',
              name: 'TradeExecutor', error: e);
        }

        if (ltp > 0.0) {
          if (!isTrailingActive && ltp >= averagePrice + risk) {
            isTrailingActive = true;
            developer.log(
                '+1R profit reached (LTP: $ltp >= ${averagePrice + risk}). Trailing stop-loss activated.',
                name: 'TradeExecutor');
          }
        }

        // 3. Trailing Stop Loss logic using 1-minute Supertrend
        if (isTrailingActive) {
          final now = DateTime.now();
          if (lastFetchTime == null ||
              now.difference(lastFetchTime) > const Duration(seconds: 30)) {
            final instrumentToken = config.instrumentToken;
            if (instrumentToken != 0) {
              try {
                final fetched = await DashboardService.instance
                    .fetch1MinHistoricalData(instrumentToken);
                if (fetched != null && fetched.isNotEmpty) {
                  candles1m = fetched;
                  lastFetchTime = now;
                }
              } catch (e) {
                developer.log('Failed to fetch 1m candles for trailing: $e',
                    name: 'TradeExecutor', error: e);
              }
            } else {
              developer.log('Instrument token is 0, cannot fetch 1m data for ${config.symbol}', name: 'TradeExecutor');
            }
          }

          if (candles1m.isNotEmpty) {
            final stPeriod = await prefs.getSupertrendPeriod();
            final stMult = await prefs.getSupertrendMultiplier();
            final engine1m = IndicatorEngine(candles1m);
            final supertrend1mList = IndicatorUtils.supertrendSeries(
              engine1m,
              atrPeriod: stPeriod,
              multiplier: stMult,
            );
            if (supertrend1mList.isNotEmpty) {
              final latestStVal = supertrend1mList.last;
              if (latestStVal != 0.0) {
                final roundedSt =
                    (latestStVal * 20).round() / 20; // NSE 0.05 tick rounding
                if (roundedSt > currentTrailedSL) {
                  developer.log(
                      'Trailing SL moving from $currentTrailedSL to $roundedSt',
                      name: 'TradeExecutor');
                  currentTrailedSL = roundedSt;
                  try {
                    await orderService.modifyOrder(
                      orderId: slOrderId,
                      variety: 'regular',
                      triggerPrice: currentTrailedSL,
                      price:
                          config.slOrderType == 'SL' ? currentTrailedSL : null,
                    );
                    developer.log(
                        'Kite SL order $slOrderId successfully modified to $currentTrailedSL',
                        name: 'TradeExecutor');
                  } catch (e) {
                    developer.log(
                        'Failed to modify Kite SL order $slOrderId to $currentTrailedSL: $e',
                        name: 'TradeExecutor',
                        error: e);
                  }

                  // Also update on the backend
                  try {
                    await BackendOrderService.updateActiveSL(
                      symbol: config.symbol,
                      triggerPrice: currentTrailedSL,
                    );
                  } catch (e) {
                    developer.log(
                        'Failed to update SL on Backend for ${config.symbol}: $e',
                        name: 'TradeExecutor',
                        error: e);
                  }

                  // Update UI notifications list so FilteredStockScreen shows the latest SL
                  try {
                    final prefs = SharedPreferenceHelper.instance;
                    var notifications = await prefs.getNotificationList();
                    bool updated = false;
                    for (var n in notifications) {
                      if (n.stocksNameList == config.symbol &&
                          n.status != "SL Hit" &&
                          n.status != "Target Hit") {
                        n.stoploss = currentTrailedSL;
                        updated = true;
                      }
                    }
                    if (updated) {
                      await prefs.saveNotificationList(notifications);
                    }
                  } catch (e) {
                    developer.log(
                        'Failed to update SL in local storage for ${config.symbol}: $e',
                        name: 'TradeExecutor');
                  }
                }
              }
            }
          }
        }

        await Future.delayed(config.pollingInterval);
      } catch (e) {
        developer.log('Error during OCO monitoring: $e',
            name: 'TradeExecutor', error: e);
        await Future.delayed(config.pollingInterval);
      }
    }

    developer.log('Trade closed.', name: 'TradeExecutor');
  }

  Future<void> _safeCancel(String orderId) async {
    try {
      await orderService.cancelOrder(orderId);
      developer.log('Successfully cancelled order $orderId',
          name: 'TradeExecutor');
    } catch (e) {
      developer.log('Failed to cancel order $orderId',
          name: 'TradeExecutor', error: e);
    }
  }
}
