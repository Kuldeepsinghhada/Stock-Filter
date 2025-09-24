import 'dart:async';
import 'dart:developer';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'dashboard_services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';

@pragma('vm:entry-point')
Future<void> repeatTask() async {
  var result = await DashboardService.instance.fetchQuotes();
  await SharedPreferenceHelper.instance.saveStocks(result);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool isLoading = true;
  List<String> messages = [];

  String searchQuery = '';

  static const int alarmId = 1;
  var isTaskRunning = false;
  Timer? timer;
  List<FinalStockModel> quoteList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadCachedStocks();
    getAlarmStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadCachedStocks(); // reload latest cached data when app is foreground
    }
  }

  Future<void> loadCachedStocks() async {
    final cached = await SharedPreferenceHelper.instance.getStocks();
    if (cached.isNotEmpty) {
      setState(() {
        quoteList = cached;
        isLoading = false;
      });
    } else {
      fetchQuotesFromService();
    }
  }

  Future<void> getAlarmStatus() async {
    isTaskRunning = await SharedPreferenceHelper.instance.getAlarmRunning();
    setState(() {});
    if (isTaskRunning) {
      // ensure alarm is still scheduled
      startApiTask();
    }
  }

  Future<bool> fetchQuotesFromService() async {
    setState(() => isLoading = true);

    final result = await DashboardService.instance.fetchQuotes();
    await SharedPreferenceHelper.instance.saveStocks(result);

    setState(() {
      quoteList = result;
      isLoading = false;
    });
    return true;
  }

  /// Start repeating task every 5 minutes
  Future<void> startApiTask() async {
    AndroidAlarmManager.periodic(
          const Duration(minutes: 1),
          alarmId,
          repeatTask,
          wakeup: true,
          rescheduleOnReboot: true,
        )
        .then((_) {
          SharedPreferenceHelper.instance.setAlarmRunning(true);
          setState(() => isTaskRunning = true);
        })
        .catchError((error) {
          log("Failed to start AlarmManager: $error");
        });
  }

  /// Stop the repeating task
  Future<void> stopApiTask() async {
    await AndroidAlarmManager.cancel(alarmId);
    await SharedPreferenceHelper.instance.setAlarmRunning(false);
    setState(() => isTaskRunning = false);
  }

  static Future<bool> checkAndRequestExactAlarmPermission() async {
    // Android 12+ → check permission
    var status = await Permission.scheduleExactAlarm.status;

    if (status.isGranted) {
      return true;
    } else {
      // Request permission
      status = await Permission.scheduleExactAlarm.request();

      if (status.isGranted) {
        return true;
      } else {
        // Permission denied
        print("Exact alarm permission denied");
        return false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          (isLoading && quoteList.isEmpty)
              ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : SizedBox(),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
            icon: Icon(Icons.notifications),
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
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchQuotesFromService,

              child: ListView.builder(
                itemCount: quoteList.length,
                itemBuilder: (context, index) {
                  final stock = quoteList[index];
                  return ListTile(
                    leading: Text(
                      (index + 1).toString(),
                      style: TextStyle(fontSize: 16),
                    ),
                    title: Text(
                      stock.stockSymbol?.replaceAll("NSE:", "") ?? '',
                    ),
                    subtitle: Text(
                      'Token: ${stock.token}, Price: ${stock.lastPrice}',
                    ),
                    trailing: Builder(
                      builder: (context) {
                        double? percentChange;
                        if (stock.open != null &&
                            stock.open != 0 &&
                            stock.lastPrice != null) {
                          percentChange =
                              ((stock.lastPrice! - stock.open!) / stock.open!) *
                              100;
                        }
                        return percentChange != null
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
                            : const SizedBox();
                      },
                    ),
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => StockCheckScreen(stock: stock),
                      //   ),
                      // );
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
          var status = await checkAndRequestExactAlarmPermission();
          if (!status) return;
          if (isTaskRunning) {
            stopApiTask();
          } else {
            startApiTask();
          }
        },
      ),
    );
  }
}
