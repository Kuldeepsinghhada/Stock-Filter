import 'dart:async';
import 'dart:developer';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/IndCheck/stock_check_screen.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'dashboard_services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';

@pragma('vm:entry-point')
Future<void> repeatTask() async {
  await DashboardService.instance.fetchQuotes();
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isLoading = true;
  List<String> messages = [];

  String searchQuery = '';

  static const int alarmId = 1;
  var isTaskRunning = false;
  Timer? timer;
  List<StockModel> quoteList = [];

  @override
  void initState() {
    super.initState();
    fetchQuotesFromService();
  }

  Future<bool> fetchQuotesFromService() async {
    if (isTaskRunning) {
      Fluttertoast.showToast(
        msg: "Please wait, task is already running",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return false;
    }

    setState(() {
      isLoading = true;
    });
    final result = await DashboardService.instance.fetchQuotes();
    setState(() {
      quoteList = result;
      //log("Filtered Quotes Count: ${quoteList.length}");
      log(quoteList.map((e) => e.symbol).join(", "));
      isLoading = false;
    });
    return true;
  }

  /// Start repeating task every 5 minutes
  Future<void> startApiTask() async {
    // timer = Timer.periodic(const Duration(minutes: 5), (timer) {
    //   if (isLoading!) {
    //     fetchQuotesFromService();
    //   }
    // });
    // setState(() => isTaskRunning = true);
    // return;
    AndroidAlarmManager.periodic(
          const Duration(minutes: 1),
          alarmId,
          repeatTask,
          wakeup: true,
          rescheduleOnReboot: true,
        )
        .then((_) {
          setState(() => isTaskRunning = true);
        })
        .catchError((error) {
          log("Failed to start AlarmManager: $error");
        });
  }

  /// Stop the repeating task
  Future<void> stopApiTask() async {
    // timer?.cancel();
    // timer = null;
    // setState(() => isTaskRunning = false);
    // return;
    await AndroidAlarmManager.cancel(alarmId);
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
                    title: Text(stock.symbol?.replaceAll("NSE:", "") ?? ''),
                    subtitle: Text(
                      'Token: ${stock.token}, Price: ${stock.lastPrice}',
                    ),
                    trailing: Builder(
                      builder: (context) {
                        double? percentChange;
                        if (stock.ohlc != null &&
                            stock.ohlc!.open != null &&
                            stock.ohlc!.open != 0 &&
                            stock.lastPrice != null) {
                          percentChange =
                              ((stock.lastPrice! - stock.ohlc!.open!) /
                                  stock.ohlc!.open!) *
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StockCheckScreen(stock: stock),
                        ),
                      );
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
