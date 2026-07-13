import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_services.dart';
import 'package:stock_demo/Screens/PreFilteredStocks/pre_stocks_screen.dart';
import 'package:stock_demo/Screens/SearchStocks/search_stocks_screen.dart';
import 'package:stock_demo/Screens/Settings/trade_setting_screen.dart';
import 'package:stock_demo/Services/notification_service.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/model/notification_model.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/INdicators/indicator_engine.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class FilteredStockScreen extends StatefulWidget {
  const FilteredStockScreen({super.key});

  @override
  State<FilteredStockScreen> createState() => _FilteredStockScreenState();
}

class _FilteredStockScreenState extends State<FilteredStockScreen>
    with WidgetsBindingObserver {
  bool isLoading = false;
  bool isBackendConnected = false;
  bool isTaskRunning = false;
  List<FinalStockModel> quoteList = [];
  final TextEditingController _symbolsController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  List<NotificationModel> notificationsList = [];
  List<NotificationModel> notificationsListByVolume = [];
  List<NotificationModel> notificationsListByRecent = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await NotificationService.requestPermissions();
    await FilterUtils.cacheFilterSettings();
    await _loadCachedStocks();
    getNotifications();
    //await fetchQuotesFromService(); // always fetch fresh data once
  }

  Future<void> clearTokens() async {
    await SharedPreferenceHelper.instance.setStockTokenLists([]);
    Fluttertoast.showToast(msg: "All Token Cleared");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCachedStocks(); // reload latest cached data when app resumes
      getNotifications();
    }
  }

  Future<void> _loadCachedStocks() async {
    final cached = await SharedPreferenceHelper.instance.getStocks();
    if (cached.isNotEmpty) {
      setState(() {
        quoteList = cached;
        isLoading = false;
      });
    }
  }

  Future<void> fetchQuotesFromService() async {
    await getNotifications();
    setState(() => isLoading = true);
    try {
      final input = _symbolsController.text.trim();
      List<String>? symbols;
      if (input.isNotEmpty) {
        symbols = input.split(',').map((e) => e.trim().toUpperCase()).toList();
      }

      final result = await DashboardService.instance
          .fetchQuotes(symbolsToFilter: symbols, selectedDate: selectedDate);

      // Fetch LTPs for all active stocks in notificationsList that are not in result (filtered out by scanner)
      final activeSymbols = notificationsList
          .where((n) => n.status == "Active" && n.stocksNameList != null)
          .map((n) => n.stocksNameList!.split(" - ").first.trim())
          .toList();
      if (activeSymbols.isNotEmpty) {
        try {
          final ltpMap =
              await DashboardService.instance.fetchLtpForSymbols(activeSymbols);
          for (var entry in ltpMap.entries) {
            final symbol =
                entry.key.replaceAll("NSE:", "").trim().toUpperCase();
            final ltp = entry.value;

            // Find if we already have it in result
            final idx = result
                .indexWhere((q) => q.stockSymbol?.toUpperCase() == symbol);
            if (idx != -1) {
              result[idx].lastPrice = ltp;
            } else {
              result.add(FinalStockModel(
                stockSymbol: symbol,
                lastPrice: ltp,
              ));
            }
          }
        } catch (e) {
          log("LTP fetch for active symbols failed: $e");
        }
      }

      // Check for stoploss/target hit conditions and lock their status
      bool notificationsChanged = false;
      for (var stock in notificationsList) {
        if (stock.status == "Active") {
          final symbolUpper = stock.stocksNameList?.toUpperCase() ?? '';
          final quote = result.firstWhere(
            (q) =>
                q.stockSymbol != null &&
                symbolUpper.contains(q.stockSymbol!.toUpperCase()),
            orElse: () => FinalStockModel(),
          );

          if (quote.lastPrice != null && quote.lastPrice! > 0) {
            if (stock.target != null && quote.lastPrice! >= stock.target!) {
              stock.status = "Target Hit";
              notificationsChanged = true;
              log("${stock.stocksNameList} hit target: ${stock.target}");
            } else if (stock.stoploss != null &&
                quote.lastPrice! <= stock.stoploss!) {
              stock.status = "SL Hit";
              notificationsChanged = true;
              log("${stock.stocksNameList} hit stoploss: ${stock.stoploss}");
            }
          }
        }
      }

      // ---------------- NEW TRAILING SL LOGIC ----------------
      final prefs = SharedPreferenceHelper.instance;
      final stPeriod = await prefs.getSupertrendPeriod();
      final stMult = await prefs.getSupertrendMultiplier();

      for (var stock in notificationsList) {
        if (stock.status == "Active") {
          final symbolUpper = stock.stocksNameList?.toUpperCase() ?? '';
          final quote = result.firstWhere(
            (q) =>
                q.stockSymbol != null &&
                symbolUpper.contains(q.stockSymbol!.toUpperCase()),
            orElse: () => FinalStockModel(),
          );

          if (quote.lastPrice != null && quote.lastPrice! > 0) {
            double entryPrice = stock.price ?? 0.0;
            double initialSL = stock.initialSL ?? stock.stoploss ?? 0.0;
            if (entryPrice > 0 && initialSL > 0) {
              double risk = entryPrice - initialSL;
              double oneRPrice = entryPrice + risk;

              if (quote.lastPrice! >= oneRPrice) {
                // Fetch token
                final cleanSymbol = symbolUpper.split(" - ").first.trim().replaceAll("NSE:", "").replaceAll("BSE:", "");
                int instrumentToken = 0;
                try {
                  final s = DataManager.instance.stocksList.firstWhere(
                    (s) => s.symbol?.replaceAll("NSE:", "") == cleanSymbol,
                  );
                  instrumentToken = int.tryParse(s.token.toString()) ?? 0;
                } catch (_) {}

                if (instrumentToken != 0) {
                  final candles1m = await DashboardService.instance.fetch1MinHistoricalData(instrumentToken);
                  if (candles1m != null && candles1m.isNotEmpty) {
                    final engine1m = IndicatorEngine(candles1m);
                    final supertrend1mList = IndicatorUtils.supertrendSeries(
                      engine1m,
                      atrPeriod: stPeriod,
                      multiplier: stMult,
                    );
                    if (supertrend1mList.isNotEmpty) {
                      final latestStVal = supertrend1mList.last;
                      if (latestStVal != 0.0) {
                        final roundedSt = (latestStVal * 20).round() / 20; // NSE 0.05 tick rounding
                        if (stock.stoploss == null || roundedSt > stock.stoploss!) {
                          log("Trailing SL for $cleanSymbol moving from ${stock.stoploss} to $roundedSt");
                          stock.stoploss = roundedSt;
                          notificationsChanged = true;
                          
                          // Update on backend
                          try {
                            await BackendOrderService.updateActiveSL(
                              symbol: cleanSymbol,
                              triggerPrice: roundedSt,
                            );
                          } catch (e) {
                            log('Failed to update SL on Backend for $cleanSymbol: $e');
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      // ---------------- END NEW TRAILING SL LOGIC ----------------


      if (notificationsChanged) {
        await SharedPreferenceHelper.instance
            .saveNotificationList(notificationsList);
      }

      await SharedPreferenceHelper.instance.saveStocks(result);
      setState(() => quoteList = result);
      var savedTokenList =
          await SharedPreferenceHelper.instance.getStockTokenList();
      List<String> tokenList =
          quoteList.map((e) => e.token.toString()).toList();
      // merge without duplicates
      savedTokenList = {...savedTokenList, ...tokenList}.toList();
      await SharedPreferenceHelper.instance.setStockTokenLists(savedTokenList);
      await getNotifications();
      if (isTaskRunning == true) {
        fetchQuotesFromService();
      }
    } catch (e) {
      log("Fetch quotes failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _symbolsController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<bool> getNotifications() async {
    notificationsList =
        await SharedPreferenceHelper.instance.getNotificationList();

    notificationsListByVolume = List<NotificationModel>.from(notificationsList);
    // Sort by volumeX descending, placing nulls at the end
    notificationsListByVolume.sort((a, b) {
      double volA = a.volumeX ?? 0.0;
      double volB = b.volumeX ?? 0.0;
      return volB.compareTo(volA);
    });

    notificationsListByRecent =
        List<NotificationModel>.from(notificationsList).reversed.toList();

    setState(() {});
    return true;
  }

  void connectBackend() async {
    {
      try {
        // 1. Health Check
        final isHealthy = await BackendOrderService.healthCheck();
        if (isHealthy) {
          // 2. Save Zerodha Session
          String? accessToken =
              await SharedPreferenceHelper.instance.getToken();
          String? refreshToken =
              await SharedPreferenceHelper.instance.getRefreshToken();

          final isSaved = await BackendOrderService.saveZerodhaSession(
              accessToken ?? "", refreshToken ?? "");

          if (isSaved) {
            setState(() {
              isBackendConnected = true;
            });
            Fluttertoast.showToast(msg: "Connected");
            // 3. Make GET API call to check session and print token
            await BackendOrderService.getSession();
          } else {
            Fluttertoast.showToast(msg: "Failed to save session");
          }
        } else {
          Fluttertoast.showToast(msg: "Health check failed");
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Connection error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalPnlPercent = 0.0;
    int validStocksCount = 0;

    for (var stock in notificationsListByRecent) {
      if (stock.price != null && stock.price! > 0) {
        double pnl = 0.0;
        bool hasPnl = false;

        if (stock.status == "Target Hit") {
          if (stock.target != null) {
            pnl = ((stock.target! - stock.price!) / stock.price!) * 100;
            hasPnl = true;
          }
        } else if (stock.status == "SL Hit") {
          if (stock.stoploss != null) {
            pnl = ((stock.stoploss! - stock.price!) / stock.price!) * 100;
            hasPnl = true;
          }
        } else {
          // Active
          final symbolUpper = stock.stocksNameList?.toUpperCase() ?? '';
          final quote = quoteList.firstWhere(
            (q) =>
                q.stockSymbol != null &&
                symbolUpper.contains(q.stockSymbol!.toUpperCase()),
            orElse: () => FinalStockModel(),
          );

          if (quote.lastPrice != null && quote.lastPrice! > 0) {
            pnl = ((quote.lastPrice! - stock.price!) / stock.price!) * 100;
            hasPnl = true;
          }
        }

        if (hasPnl) {
          totalPnlPercent += pnl;
          validStocksCount++;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Search button
          if (isLoading && quoteList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PreFilteredStock()),
            ),
            icon: const Icon(Icons.filter_center_focus),
          ),

          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchStocksScreen()),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TradeSettingPage()),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Till Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Select Date"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _symbolsController,
              decoration: const InputDecoration(
                labelText: 'Enter symbols (comma separated)',
                hintText: 'e.g. RELIANCE,TCS,INFY',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (validStocksCount > 0)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                color: Colors.blue.shade50,
                elevation: 2,
                child: ListTile(
                  title: const Text("Today's Profit & Loss",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    "${totalPnlPercent >= 0 ? '+' : ''}${totalPnlPercent.toStringAsFixed(2)}%",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: totalPnlPercent >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  subtitle: Text("Based on $validStocksCount active alerts"),
                ),
              ),
            ),
          Expanded(
            child: _buildList(notificationsListByRecent),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'connect_backend_fab',
            label: Text(isBackendConnected ? "Connected" : "Connect"),
            icon: Icon(isBackendConnected ? Icons.cloud_done : Icons.cloud_off),
            backgroundColor: isBackendConnected ? Colors.green : null,
            onPressed: () => connectBackend(),
          ),
          const SizedBox(height: 10),
          // FloatingActionButton(
          //     child: Icon(Icons.network_check),
          //     onPressed: () {
          //       BackendOrderService.testPlaceStockOrder();
          //     }),
          // const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'filtered_stocks_fab',
            child: Text(isTaskRunning ? "STOP" : "START"),
            onPressed: () async {
              // Only allow starting the task after 9:28 AM local time.
              final now = DateTime.now();
              final startAllowedAt =
                  DateTime(now.year, now.month, now.day, 9, 30);
              // If currently not running (we're trying to START) and time is before allowed time, block it.
              if (!isTaskRunning && now.isBefore(startAllowedAt)) {
                Fluttertoast.showToast(msg: "Start allowed after 9:30 AM");
                return;
              }

              await WakelockPlus.enable();
              if (!isTaskRunning) {
                await FilterUtils.cacheFilterSettings();
                isTaskRunning = true;
                await fetchQuotesFromService();
              } else {
                isTaskRunning = false;
                await WakelockPlus.disable();
              }
              setState(() {});
              // }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<NotificationModel> list) {
    return RefreshIndicator(
      onRefresh: getNotifications,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final stock = list[index];
          final symbolUpper = stock.stocksNameList?.toUpperCase() ?? '';
          final quote = quoteList.firstWhere(
            (q) =>
                q.stockSymbol != null &&
                symbolUpper.contains(q.stockSymbol!.toUpperCase()),
            orElse: () => FinalStockModel(),
          );

          Color? tileColor;
          double pnl = 0.0;
          bool hasPnl = false;

          if (stock.status == "Target Hit") {
            tileColor = Colors.green.withOpacity(0.3);
            if (stock.target != null &&
                stock.price != null &&
                stock.price! > 0) {
              pnl = ((stock.target! - stock.price!) / stock.price!) * 100;
              hasPnl = true;
            }
          } else if (stock.status == "SL Hit") {
            tileColor = Colors.red.withOpacity(0.3);
            if (stock.stoploss != null &&
                stock.price != null &&
                stock.price! > 0) {
              pnl = ((stock.stoploss! - stock.price!) / stock.price!) * 100;
              hasPnl = true;
            }
          } else {
            // Active
            if (quote.lastPrice != null &&
                quote.lastPrice! > 0 &&
                stock.price != null &&
                stock.price! > 0) {
              pnl = ((quote.lastPrice! - stock.price!) / stock.price!) * 100;
              hasPnl = true;
              if (stock.target != null && quote.lastPrice! >= stock.target!) {
                tileColor = Colors.green.withOpacity(0.3);
              } else if (stock.stoploss != null &&
                  quote.lastPrice! <= stock.stoploss!) {
                tileColor = Colors.red.withOpacity(0.3);
              } else {
                tileColor = Colors.yellow.withOpacity(0.3);
              }
            } else {
              tileColor = Colors.grey.withOpacity(0.1);
            }
          }

          return Container(
            color: tileColor,
            child: ListTile(
              title: Text(stock.stocksNameList ?? ''),
              subtitle: Text(
                  "${stock.time ?? ''}${stock.target != null ? "\nTG: ₹${stock.target?.toStringAsFixed(2)} | SL: ₹${stock.stoploss?.toStringAsFixed(2)}${stock.price != null && stock.price! > 0 && stock.stoploss != null ? " (${(((stock.price! - stock.stoploss!) / stock.price!) * 100).toStringAsFixed(2)}%)" : ""}" : ""}"),
              leading: Text("$index"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasPnl)
                    Text(
                      "${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: pnl >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      bool? confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Delete'),
                          content: const Text(
                            'Are you sure you want to delete this stock?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmDelete == true) {
                        notificationsList.remove(list[index]);
                        await SharedPreferenceHelper.instance
                            .saveNotificationList(notificationsList);
                        getNotifications();
                      }
                    },
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
