import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_services.dart';
import 'package:stock_demo/Screens/PreFilteredStocks/pre_stocks_screen.dart';
import 'package:stock_demo/Screens/SearchStocks/search_stocks_screen.dart';
import 'package:stock_demo/Services/notification_service.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
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

  List<NotificationModel> notificationsList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await NotificationService.requestPermissions();
    await _loadCachedStocks();
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
        symbols =
            input.split(',').map((e) => e.trim().toUpperCase()).toList();
      }

      final result =
          await DashboardService.instance.fetchQuotes(symbolsToFilter: symbols);
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
    notificationsList = notificationsList.reversed.toList();
    setState(() {});
    return true;
  }

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
      body: Column(
        children: [
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: getNotifications,
              child: ListView.builder(
                itemCount: notificationsList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(notificationsList[index].stocksNameList ?? ''),
                    subtitle: Text(notificationsList[index].time ?? ''),
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
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmDelete == true) {
                          notificationsList.remove(notificationsList[index]);
                          await SharedPreferenceHelper.instance
                              .saveNotificationList(notificationsList);
                          setState(() {});
                        }
                      },
                      icon: Icon(Icons.delete),
                    ),
                    onTap: () {},
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Text(isTaskRunning ? "STOP" : "START"),
        onPressed: () async {
          // Only allow starting the task after 9:28 AM local time.
          final now = DateTime.now();
          final startAllowedAt = DateTime(now.year, now.month, now.day, 9, 28);

          // If currently not running (we're trying to START) and time is before allowed time, block it.
          if (!isTaskRunning && now.isBefore(startAllowedAt)) {
            Fluttertoast.showToast(msg: "Start allowed after 9:28 AM");
            return;
          }

          await WakelockPlus.enable();
          if (!isTaskRunning) {
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
}
