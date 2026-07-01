import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_services.dart';
import 'package:stock_demo/Screens/PreFilteredStocks/pre_stocks_screen.dart';
import 'package:stock_demo/Screens/SearchStocks/search_stocks_screen.dart';
import 'package:stock_demo/Screens/Settings/trade_setting_screen.dart';
import 'package:stock_demo/Services/notification_service.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/model/notification_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class FilteredStockScreen extends StatefulWidget {
  const FilteredStockScreen({super.key});

  @override
  State<FilteredStockScreen> createState() => _FilteredStockScreenState();
}

class _FilteredStockScreenState extends State<FilteredStockScreen>
    with WidgetsBindingObserver {
  bool isLoading = false;
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
    getNotifications();
    setState(() => isLoading = true);
    try {
      final input = _symbolsController.text.trim();
      List<String>? symbols;
      if (input.isNotEmpty) {
        symbols = input.split(',').map((e) => e.trim().toUpperCase()).toList();
      }

      final result = await DashboardService.instance
          .fetchQuotes(symbolsToFilter: symbols, selectedDate: selectedDate);
      await SharedPreferenceHelper.instance.saveStocks(result);
      setState(() => quoteList = result);
      var savedTokenList =
          await SharedPreferenceHelper.instance.getStockTokenList();
      List<String> tokenList =
          quoteList.map((e) => e.token.toString()).toList();
      // merge without duplicates
      savedTokenList = {...savedTokenList, ...tokenList}.toList();
      await SharedPreferenceHelper.instance.setStockTokenLists(savedTokenList);
      getNotifications();
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

  @override
  Widget build(BuildContext context) {
    double totalPnlPercent = 0.0;
    int validStocksCount = 0;

    for (var stock in notificationsListByRecent) {
      if (stock.price != null && stock.price! > 0) {
        final symbolUpper = stock.stocksNameList?.toUpperCase() ?? '';
        final quote = quoteList.firstWhere(
          (q) => q.stockSymbol != null && symbolUpper.contains(q.stockSymbol!.toUpperCase()),
          orElse: () => FinalStockModel(),
        );

        if (quote.lastPrice != null && quote.lastPrice! > 0) {
          double pnl = ((quote.lastPrice! - stock.price!) / stock.price!) * 100;
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  color: Colors.blue.shade50,
                  elevation: 2,
                  child: ListTile(
                    title: const Text("Today's Profit & Loss", style: TextStyle(fontWeight: FontWeight.bold)),
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
        floatingActionButton: FloatingActionButton(
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
            (q) => q.stockSymbol != null && symbolUpper.contains(q.stockSymbol!.toUpperCase()),
            orElse: () => FinalStockModel(),
          );

          Color? tileColor;
          if (quote.lastPrice != null && quote.lastPrice! > 0 && stock.target != null && stock.stoploss != null && stock.price != null) {
            if (quote.lastPrice! >= stock.target!) {
              tileColor = Colors.green.withOpacity(0.3);
            } else if (quote.lastPrice! <= stock.stoploss!) {
              tileColor = Colors.red.withOpacity(0.3);
            } else {
              tileColor = Colors.yellow.withOpacity(0.3);
            }
          }

          return Container(
            color: tileColor,
            child: ListTile(
              title: Text(stock.stocksNameList ?? ''),
              subtitle: Text(
                  "${stock.time ?? ''}${stock.volumeX != null && stock.volumeX! > 0 ? " | Vol: ${stock.volumeX!.toStringAsFixed(2)}x" : ""}${stock.target != null ? "\nTarget: ₹${stock.target?.toStringAsFixed(2)} | SL: ₹${stock.stoploss?.toStringAsFixed(2)}${stock.price != null && stock.price! > 0 && stock.stoploss != null ? " (${(((stock.price! - stock.stoploss!) / stock.price!) * 100).toStringAsFixed(2)}%)" : ""}" : ""}"),
              leading: const Icon(Icons.notifications),
            trailing: IconButton(
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
            onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
