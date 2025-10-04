import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_services.dart';
import 'package:stock_demo/Screens/PreFilteredStocks/pre_stocks_screen.dart';
import 'package:stock_demo/Services/notification_service.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';

/// Background task entry point
@pragma('vm:entry-point')
Future<void> repeatTask() async {
  final result = await DashboardService.instance.fetchQuotes();
  await SharedPreferenceHelper.instance.saveStocks(result);
}

class FilteredStockScreen extends StatefulWidget {
  const FilteredStockScreen({super.key});

  @override
  State<FilteredStockScreen> createState() => _FilteredStockScreenState();
}

class _FilteredStockScreenState extends State<FilteredStockScreen>
    with WidgetsBindingObserver {
  static const int alarmId = 1;

  bool isLoading = true;
  bool isTaskRunning = false;
  String searchQuery = '';
  List<FinalStockModel> quoteList = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await NotificationService.requestPermissions();
    await _loadCachedStocks();
    await _getAlarmStatus();
    await fetchQuotesFromService(); // always fetch fresh data once
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

  Future<void> _getAlarmStatus() async {
    final status = await SharedPreferenceHelper.instance.getAlarmRunning();
    setState(() => isTaskRunning = status);
    if (status) startApiTask(); // re-ensure scheduled
  }

  Future<void> fetchQuotesFromService() async {
    setState(() => isLoading = true);
    try {
      final result = await DashboardService.instance.fetchQuotes();
      await SharedPreferenceHelper.instance.saveStocks(result);
      setState(() => quoteList = result);
    } catch (e) {
      log("Fetch quotes failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startApiTask() async {
    try {
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 5),
        alarmId,
        repeatTask,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      await SharedPreferenceHelper.instance.setAlarmRunning(true);
      setState(() => isTaskRunning = true);
    } catch (e) {
      log("Failed to start AlarmManager: $e");
    }
  }

  Future<void> stopApiTask() async {
    await AndroidAlarmManager.cancel(alarmId);
    await SharedPreferenceHelper.instance.setAlarmRunning(false);
    setState(() => isTaskRunning = false);
  }

  static Future<bool> checkAndRequestExactAlarmPermission() async {
    var status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return true;

    status = await Permission.scheduleExactAlarm.request();
    if (status.isGranted) return true;

    log("Exact alarm permission denied");
    return false;
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuotes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        // leading: IconButton(
        //   onPressed: () async {
        //     final player = AudioPlayer();
        //     await player.play(AssetSource('not.wav'));
        //   },
        //   icon: Icon(Icons.notification_add),
        // ),
        actions: [
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
              onRefresh: fetchQuotesFromService,
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final stock = filtered[index];
                  final symbol =
                      stock.stockSymbol?.replaceAll("NSE:", "") ?? '';
                  final percentChange =
                      (stock.open != null &&
                              stock.open != 0 &&
                              stock.lastPrice != null)
                          ? ((stock.lastPrice! - stock.open!) / stock.open!) *
                              100
                          : null;

                  return ListTile(
                    leading: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    title: Text(symbol),
                    subtitle: Text(
                      'Token: ${stock.token}, Price: ${stock.lastPrice}',
                    ),
                    trailing:
                        percentChange != null
                            ? Text(
                              '${percentChange.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color:
                                    percentChange >= 0
                                        ? Colors.green
                                        : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : const SizedBox(),
                    onTap: () {
                      print(stock.link);
                    },
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
          if (Platform.isAndroid) {
            if (!await checkAndRequestExactAlarmPermission()) return;
            isTaskRunning ? stopApiTask() : startApiTask();
          } else {
            if (!isTaskRunning) {
              _timer = Timer.periodic(Duration(minutes: 1), (timer) async {
                await fetchQuotesFromService();
                isTaskRunning = true;
              });
            } else {
              isTaskRunning = false;
              _timer?.cancel();
            }
            setState(() {});
          }
        },
      ),
    );
  }
}
