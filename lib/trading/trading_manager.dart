import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'models.dart';
import 'trade_executor.dart';
import 'kite_api_client.dart';
import 'order_service.dart';
import 'order_monitor.dart';

class TradingManager {
  static final TradingManager instance = TradingManager._internal();

  late TradeExecutor tradeExecutor;
  bool _isAutoTradingEnabled = false;
  static const String _prefKey = 'is_auto_trading_enabled';

  // Default configuration for trades triggered by signals
  TradeConfig defaultTradeConfig = TradeConfig(
    symbol: '',
    exchange: 'NSE',
    quantity: 10,
    slPoints: 1.0, // default 1%, or update as per config
    targetPoints: 2.0, // default 2%
    isPercentageBased: true,
  );

  TradingManager._internal() {
    // Initialize services
    final apiClient = KiteApiClient();
    final orderService = OrderService(apiClient: apiClient);
    final orderMonitor = OrderMonitor(orderService: orderService);
    tradeExecutor =
        TradeExecutor(orderService: orderService, orderMonitor: orderMonitor);
  }

  /// Initialize the manager and load the saved trading preference.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoTradingEnabled = prefs.getBool(_prefKey) ?? false;
    developer.log(
        'TradingManager initialized. Auto Trading Enabled: $_isAutoTradingEnabled',
        name: 'TradingManager');
  }

  /// Get the current status of auto trading
  bool get isAutoTradingEnabled => _isAutoTradingEnabled;

  /// Enable or disable auto trading
  Future<void> setAutoTradingStatus(bool isEnabled) async {
    _isAutoTradingEnabled = isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isEnabled);
    developer.log('Auto Trading status changed to: $isEnabled',
        name: 'TradingManager');
  }

  /// Triggered whenever a stock comes into radar (meets scanner conditions)
  Future<void> onStockRadarTrigger(
      String symbol, double entryPrice, double target, double stoploss) async {
    developer.log(
        'Signal received for $symbol. Entry: $entryPrice, Target: $target, SL: $stoploss',
        name: 'TradingManager');

    if (!_isAutoTradingEnabled) {
      developer.log('Auto Trading is disabled. Ignoring signal for $symbol.',
          name: 'TradingManager');
      return;
    }

    // Get max trade amount from preferences
    final prefs = await SharedPreferences.getInstance();
    final maxTradeAmount = prefs.getDouble('maxTradeAmount') ?? 5000.0;

    // Calculate quantity based on max trade amount and entry price
    int calculatedQuantity = 0;
    if (entryPrice > 0) {
      calculatedQuantity = (maxTradeAmount / entryPrice).floor();
    }

    if (calculatedQuantity <= 0) {
      developer.log(
          'Calculated quantity is 0 or less (Price: $entryPrice, MaxAmount: $maxTradeAmount). Aborting trade.',
          name: 'TradingManager');
      return;
    }

    // Calculate actual points based on the entry price and provided target/stoploss
    double slPoints = entryPrice - stoploss;
    double targetPoints = target - entryPrice;

    // Create a specific config for this symbol using the calculated points
    final config = TradeConfig(
      symbol: symbol,
      exchange: defaultTradeConfig.exchange,
      quantity: calculatedQuantity,
      slPoints: slPoints > 0 ? slPoints : defaultTradeConfig.slPoints,
      targetPoints:
          targetPoints > 0 ? targetPoints : defaultTradeConfig.targetPoints,
      isPercentageBased: false, // Since we calculated exact points
      pollingInterval: defaultTradeConfig.pollingInterval,
      timeout: defaultTradeConfig.timeout,
      slOrderType: defaultTradeConfig.slOrderType,
    );

    // Execute the trade (fire and forget)
    tradeExecutor.executeTrade(config).catchError((e) {
      developer.log('Trade execution failed for $symbol: $e',
          name: 'TradingManager', error: e);
    });
  }

  /// Test function to forcefully execute a trade with 1 quantity
  /// Ignores Auto Trading enabled status and Max Trade Amount.
  Future<void> testTradeExecution(String symbol, double entryPrice) async {
    developer.log('Executing TEST trade for $symbol at price $entryPrice',
        name: 'TradingManager');

    // Create a specific config for 1 quantity with dummy SL/Target
    final config = TradeConfig(
      symbol: symbol,
      exchange: defaultTradeConfig.exchange,
      quantity: 1, // Strictly 1 quantity for testing
      slPoints: 1.0, // 1 point SL for testing
      targetPoints: 2.0, // 2 points Target for testing
      isPercentageBased: false,
      pollingInterval: defaultTradeConfig.pollingInterval,
      timeout: defaultTradeConfig.timeout,
      slOrderType: defaultTradeConfig.slOrderType,
    );

    tradeExecutor.executeTrade(config).catchError((e) {
      developer.log('Test trade execution failed for $symbol: $e',
          name: 'TradingManager', error: e);
    });
  }
}
