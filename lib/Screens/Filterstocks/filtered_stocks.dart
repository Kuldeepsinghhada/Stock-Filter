import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_services.dart';
import 'package:stock_demo/Screens/PreFilteredStocks/pre_stocks_screen.dart';
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
  bool isLoading = true;
  bool isTaskRunning = false;
  bool _isBullish = true;
  bool _isBearish = true;
  String searchQuery = '';
  List<FinalStockModel> quoteList = [];

  List<NotificationModel> notificationsList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSettings();
    await NotificationService.requestPermissions();
    await _loadCachedStocks();
    await fetchQuotesFromService(); // always fetch fresh data once
  }

  Future<void> _loadSettings() async {
    _isBullish = await SharedPreferenceHelper.instance.getBullish();
    _isBearish = await SharedPreferenceHelper.instance.getBearish();
    setState(() {});
  }

  Future<void> _setBullish(bool value) async {
    await SharedPreferenceHelper.instance.setBullish(value);
    setState(() {
      _isBullish = value;
    });
  }

  Future<void> _setBearish(bool value) async {
    await SharedPreferenceHelper.instance.setBearish(value);
    setState(() {
      _isBearish = value;
    });
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
      final result = await DashboardService.instance.fetchQuotes();
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<FinalStockModel> get _filteredQuotes {
    if (searchQuery.isEmpty) return quoteList;
    return quoteList
        .where(
          (s) => (s.stockSymbol ?? "").toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
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
    final filtered = _filteredQuotes;
    return Scaffold(
      // drawer: Drawer(
      //   child: ListView(
      //     padding: EdgeInsets.zero,
      //     children: [
      //       const DrawerHeader(
      //         decoration: BoxDecoration(color: Colors.blue),
      //         child: Text(
      //           'Settings',
      //           style: TextStyle(color: Colors.white, fontSize: 18),
      //         ),
      //       ),
      //       SwitchListTile(
      //         title: const Text('Bullish'),
      //         value: _isBullish,
      //         onChanged: (v) => _setBullish(v),
      //         secondary: const Icon(Icons.trending_up),
      //       ),
      //       SwitchListTile(
      //         title: const Text('Bearish'),
      //         value: _isBearish,
      //         onChanged: (v) => _setBearish(v),
      //         secondary: const Icon(Icons.trending_down),
      //       ),
      //       ListTile(
      //         title: const Text('Clear Saved Token'),
      //         onTap: () {
      //           clearTokens();
      //           Navigator.pop(context);
      //         },
      //         leading: const Icon(Icons.clear),
      //       ),
      //     ],
      //   ),
      // ),
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
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PreFilteredStock()),
                ),
            icon: const Icon(Icons.filter_center_focus),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by symbol',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value.trim()),
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
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: const Text(
                                  'Are you sure you want to delete this stock?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
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
          // if (Platform.isAndroid) {
          //   if (!await checkAndRequestExactAlarmPermission()) return;
          //   isTaskRunning ? stopApiTask() : startApiTask();
          // } else {

          DateTime now = DateTime.now();

          // Today 9:30 AM
          DateTime targetTime = DateTime(now.year, now.month, now.day, 9, 30);

          if (!now.isAfter(targetTime)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task can only be started after 9:30 AM'),
              ),
            );
            return;
          }
          await WakelockPlus.enable();
          if (!isTaskRunning) {
            isTaskRunning = true;
            await fetchQuotesFromService();
            //setState(() {});
            // _timer = Timer.periodic(Duration(seconds: 45), (timer) async {
            //   await fetchQuotesFromService();
            // });
          } else {
            isTaskRunning = false;
            await WakelockPlus.disable();
            //_timer?.cancel();
          }
          setState(() {});
          // }
        },
      ),
    );
  }
}
