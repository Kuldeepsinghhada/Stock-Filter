import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_demo/Screens/history/history_screen.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/Screens/PreFilteredStocks/passed_daily_stocks_screen.dart';
import 'package:stock_demo/model/history_model.dart';
import 'package:stock_demo/model/stock_model.dart';

class PreFilteredStock extends StatefulWidget {
  const PreFilteredStock({super.key});

  @override
  State<PreFilteredStock> createState() => _PreFilteredStockState();
}

class _PreFilteredStockState extends State<PreFilteredStock> {
  String searchQuery = '';
  List<StockModel> quoteList = [];
  List<List<HistoryModel>> historyList = [];
  var isLoading = false;
  int totalSignals = 0;
  int profitableSignals = 0;
  int slSignals = 0;
  int neutralSignals = 0;
  double totalPnL = 0.0;
  bool isRadarMode = true;
  Map<String, String> stockTradeResult = {};
  Map<String, Map<String, dynamic>> stockAccuracyResults = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    quoteList.clear();
    stockTradeResult.clear();
    stockAccuracyResults.clear();
    Future.delayed(const Duration(milliseconds: 200), () async {
      setState(() {
        isLoading = true;
        totalSignals = 0;
        profitableSignals = 0;
        slSignals = 0;
        neutralSignals = 0;
        totalPnL = 0.0;
      });
      int tSignals = 0;
      int targetHits = 0;
      int slHits = 0;
      int neutralHits = 0;
      double tPnL = 0.0;
      for (var item in DataManager.instance.preFilteredStocksList) {
        var result = await Utilities.buildTodayHistory(
          item.historyFiveMin ?? [],
          item,
        );
        if (result.isNotEmpty) {
          for (var i = 0; i < result.length; i++) {
            checkDailyTimeframeAPI(result[i], item).then((_) {
              if (mounted) setState(() {});
            });
          }
          quoteList.add(item);
          historyList.add(result);

          final accResult = await FilterUtils.calculateBuyAlertAccuracy(
              item.historyFiveMin ?? [], item.token.toString(),
              useRadarAlert: isRadarMode);

          if (accResult != null) {
            stockAccuracyResults[item.symbol ?? ''] = accResult;
            tSignals++;
            double pnl = accResult['percentPnL'] ?? 0.0;
            tPnL += pnl;
            String status = accResult['status'];
            if (status == "Win") {
              targetHits++;
              stockTradeResult[item.symbol ?? ''] = "Target Hit";
            } else if (status == "Loss" || status == "SL Hit" || status == "Trailing SL Hit") {
              slHits++;
              stockTradeResult[item.symbol ?? ''] = "SL Hit";
            } else {
              neutralHits++;
              stockTradeResult[item.symbol ?? ''] = "Neutral";
            }
          } else {
            stockTradeResult[item.symbol ?? ''] = "Neutral";
          }
        }
      }

      // Sort the lists by the time they came into the radar (ascending - earliest first)
      List<Map<String, dynamic>> combined = [];
      for (int i = 0; i < quoteList.length; i++) {
        final hl = historyList[i];
        final radarTime = hl.isNotEmpty ? hl.first.dateTime : DateTime.now();
        combined.add({
          'quote': quoteList[i],
          'history': hl,
          'time': radarTime,
        });
      }

      // a.compareTo(b) sorts ascending (oldest time first)
      combined.sort(
          (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

      quoteList = combined.map((e) => e['quote'] as StockModel).toList();
      historyList =
          combined.map((e) => e['history'] as List<HistoryModel>).toList();

      setState(() {
        isLoading = false;
        totalSignals = tSignals;
        profitableSignals = targetHits;
        slSignals = slHits;
        neutralSignals = neutralHits;
        totalPnL = tPnL;
      });
    });
  }

  Future<void> checkDailyTimeframeAPI(HistoryModel item, StockModel stock) async {
    try {
      final url = Uri.parse('http://200.97.163.130:8080/api/checkDailyTimeframe');
      
      final body = jsonEncode({
        "symbol": stock.symbol?.replaceAll("NSE:", "").replaceAll("BSE:", "") ?? "",
        "stockPrice": item.price ?? 0.0,
        "targetPrice": (item.price ?? 0.0) * 1.02,
        "date": item.dateTime?.toIso8601String().split('T')[0] ?? DateTime.now().toIso8601String().split('T')[0]
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
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
  void dispose() {
    super.dispose();
  }

  List<StockModel> get _filteredQuotes {
    if (searchQuery.isEmpty) return quoteList;
    return quoteList
        .where(
          (s) => (s.symbol ?? "").toLowerCase().contains(
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pre Filtered Stocks', style: TextStyle(fontSize: 18)),
            if (!isLoading && totalSignals > 0)
              Text(
                'Total PnL: ${totalPnL > 0 ? '+' : ''}${totalPnL.toStringAsFixed(2)}% | TGT: $profitableSignals | SL: $slSignals | NEU: $neutralSignals',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color:
                        totalPnL >= 0 ? Colors.greenAccent : Colors.redAccent),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Passed Daily Stocks',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PassedDailyStocksScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final symbols = _filteredQuotes
                  .map((s) => s.symbol?.replaceAll("NSE:", "") ?? "")
                  .where((s) => s.isNotEmpty)
                  .join(",");
              if (symbols.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: symbols));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by symbol',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setState(() => searchQuery = value.trim()),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final stock = filtered[index];
                    final symbol =
                        stock.symbol?.replaceAll("NSE:", "") ?? '';
                    String tradeState =
                        stockTradeResult[stock.symbol ?? ''] ?? "Neutral";
                    int originalIndex = quoteList.indexOf(stock);
                    List<HistoryModel> stockHistory = originalIndex != -1
                        ? historyList[originalIndex]
                        : [];

                    Color? tileColor;
                    Color? textColor;
                    if (tradeState == "Target Hit") {
                      tileColor = Colors.green.withOpacity(0.1);
                      textColor = Colors.green;
                    } else if (tradeState == "SL Hit") {
                      tileColor = Colors.red.withOpacity(0.1);
                      textColor = Colors.red;
                    } else {
                      tileColor = Colors.grey.withOpacity(0.1);
                      textColor = Colors.orange;
                    }

                    return ListTile(
                      tileColor: tileColor,
                      leading: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      title: Text(
                        symbol,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: tradeState == "Neutral"
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Token: ${stock.token}, Price: ${stock.lastPrice}',
                      ),
                      trailing: Text(
                        stockHistory.length.toString(),
                      ),
                      onTap: () async {
                        // Use cached result if available, otherwise fetch on the fly
                        Map<String, dynamic>? accResult = stockAccuracyResults[stock.symbol ?? ''];
                        if (accResult == null) {
                          accResult = await FilterUtils.calculateBuyAlertAccuracy(
                              stock.historyFiveMin ?? [],
                              stock.token.toString(),
                              useRadarAlert: isRadarMode);
                        }

                        double signalPrice = accResult != null
                            ? accResult['entryPrice']
                            : 0.0;
                        double targetPrice =
                            accResult != null ? accResult['target'] : 0.0;
                        double stoplossPrice =
                            accResult != null ? accResult['stoploss'] : 0.0;
                        double percentPnL = accResult != null
                            ? accResult['percentPnL'] ?? 0.0
                            : 0.0;

                        double risk = accResult != null ? (accResult['risk'] ?? 0.0) : 0.0;
                        double reward = accResult != null ? (accResult['reward'] ?? 0.0) : 0.0;
                        double rrRatio = accResult != null ? (accResult['rrRatio'] ?? 0.0) : 0.0;
                        double atrVal = accResult != null ? (accResult['atrValue'] ?? 0.0) : 0.0;
                        double stVal = accResult != null ? (accResult['supertrendValue'] ?? 0.0) : 0.0;

                        final historySoFar = stock.historyFiveMin
                                ?.where((c) => !c.timestamp.isAfter(
                                    accResult != null
                                        ? accResult['alertTime']
                                        : DateTime.now()))
                                .toList() ??
                            [];
                        int score = FilterUtils.getIntradayMomentumScore(
                            historySoFar);
                        double volMult =
                            FilterUtils.getVolumeMultiplication(
                                historySoFar);

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(symbol),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Signal Price: ${signalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Trade Result: $tradeState',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                Text(
                                    'Total PnL %: ${percentPnL > 0 ? '+' : ''}${percentPnL.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: percentPnL >= 0
                                            ? Colors.green
                                            : Colors.red)),
                                const SizedBox(height: 8),
                                Text('Score: $score'),
                                Text(
                                    'Volume Mult: ${volMult.toStringAsFixed(2)}x'),
                                const Divider(color: Colors.white24, height: 16),
                                Text(
                                    'Target Price: ${targetPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.green)),
                                Text(
                                    'Stoploss Price: ${stoplossPrice.toStringAsFixed(2)} '
                                    '(${signalPrice > 0 ? (((signalPrice - stoplossPrice) / signalPrice) * 100).toStringAsFixed(2) : "0.00"}%)',
                                    style:
                                        const TextStyle(color: Colors.red)),
                                const SizedBox(height: 8),
                                Text('Risk: ${risk.toStringAsFixed(2)}'),
                                Text('Reward: ${reward.toStringAsFixed(2)}'),
                                Text('Risk Reward Ratio: 1:${rrRatio.toStringAsFixed(1)}'),
                                Text('ATR (5m): ${atrVal.toStringAsFixed(2)}'),
                                Text('Supertrend (5m): ${stVal.toStringAsFixed(2)}'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  final radarHits = stockHistory
                                      .where((h) => h.isPassed == true)
                                      .toList();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HistoryScreen(
                                        stockName: stock.symbol ?? '',
                                        historyModel: radarHits,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Radar Hits'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  final buyAlerts = stockHistory
                                      .where((h) => h.isBuyAlert == true)
                                      .toList();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HistoryScreen(
                                        stockName: (stock.symbol ?? '') +
                                            ' (Buy Alerts)',
                                        historyModel: buyAlerts,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Buy Alerts'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}
