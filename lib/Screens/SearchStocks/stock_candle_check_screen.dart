import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/history_model.dart';
import 'package:stock_demo/model/stock_model.dart';

class StockCandleCheckScreen extends StatefulWidget {
  final StockModel stock;

  const StockCandleCheckScreen({super.key, required this.stock});

  @override
  State<StockCandleCheckScreen> createState() => _StockCandleCheckScreenState();
}

class _StockCandleCheckScreenState extends State<StockCandleCheckScreen> {
  List<HistoryModel> historyList = [];
  bool isDayBreakOut = false;
  bool isLoading = false;

  @override
  void initState() {
    _initialize();
    super.initState();
  }

  Future<void> _initialize() async {
    setState(() {
      isLoading = true;
      historyList.clear();
    });
    var result = await Utilities.buildTodayHistory(
      widget.stock.historyFiveMin ?? [],
      widget.stock,
      isDayBreakOut: isDayBreakOut,
    );
    if (result.isNotEmpty) {
      historyList = result;
      for (var i = 0; i < historyList.length; i++) {
        await checkDailyTimeframeAPI(historyList[i]);
        if (mounted) setState(() {});
      }
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> checkDailyTimeframeAPI(HistoryModel item) async {
    try {
      final url =
          Uri.parse('http://200.97.163.130:8080/api/checkDailyTimeframe');

      final body = jsonEncode({
        "symbol": widget.stock.symbol
                ?.replaceAll("NSE:", "")
                .replaceAll("BSE:", "") ??
            "",
        "stockPrice": item.price ?? 0.0,
        "targetPrice": (item.price ?? 0.0) * 1.02,
        "date": item.dateTime?.toIso8601String().split('T')[0] ??
            DateTime.now().toIso8601String().split('T')[0]
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print(decoded);
        if (decoded['success'] == true && decoded['data'] != null) {
          item.apiPassed = decoded['data']['passed'];
          List reasons = decoded['data']['reasons'] ?? [];
          item.apiReason = reasons.join("\n");
        } else {
          item.apiPassed = false;
          item.apiReason = decoded['message'] ?? "Unknown error";
        }
      } else {
        item.apiPassed = false;
        item.apiReason = "API Failed: ${response.statusCode}";
      }
    } catch (e) {
      item.apiPassed = false;
      item.apiReason = "Error: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stock.symbol ?? ''}'),
        actions: [
          Row(
            children: [
              const Text('DayBreakOut', style: TextStyle(fontSize: 12)),
              Switch(
                value: isDayBreakOut,
                onChanged: (val) {
                  setState(() {
                    isDayBreakOut = val;
                  });
                  _initialize();
                },
              ),
            ],
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : historyList.isEmpty
              ? const Center(child: Text('No candle data matches filters'))
              : ListView.separated(
                  itemCount: historyList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final obj = historyList[index];
                    return ListTile(
                      leading: Icon(
                        (obj.isPassed == true)
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color:
                            (obj.isPassed == true) ? Colors.green : Colors.red,
                      ),
                      title: Text(obj.price.toString()),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${obj.dateTime}" +
                                (obj.volumeX != null && obj.volumeX! > 0
                                    ? " | Vol: ${obj.volumeX!.toStringAsFixed(2)}x"
                                    : ""),
                          ),
                          if (obj.apiPassed != null)
                            Text(
                              obj.apiPassed! ? "API: Passed" : "API: Rejected",
                              style: TextStyle(
                                color:
                                    obj.apiPassed! ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (obj.apiPassed == false &&
                              obj.apiReason != null &&
                              obj.apiReason!.isNotEmpty)
                            Text(
                              obj.apiReason!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: (obj.isBuyAlert == true)
                          ? const Icon(Icons.notifications_active,
                              color: Colors.blue)
                          : null,
                      dense: true,
                    );
                  },
                ),
    );
  }
}
