import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_demo/Utils/candle_utils.dart';
import 'package:stock_demo/Screens/history/history_screen.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/Utils/math_utils.dart';
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
  double accuracy = 0.0;
  Map<String, String> stockTradeResult = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    quoteList.clear();
    stockTradeResult.clear();
    Future.delayed(const Duration(milliseconds: 200), () async {
      setState(() {
        isLoading = true;
        totalSignals = 0;
        profitableSignals = 0;
        slSignals = 0;
        neutralSignals = 0;
        accuracy = 0.0;
      });
      int tSignals = 0;
      int targetHits = 0;
      int slHits = 0;
      int neutralHits = 0;
      for (var item in DataManager.instance.preFilteredStocksList) {
        var result = await Utilities.buildTodayHistory(
          item.historyFiveMin ?? [],
          item,
        );
        if (result.isNotEmpty) {
          quoteList.add(item);
          historyList.add(result);

          final accResult =
              FilterUtils.calculateBuyAlertAccuracy(item.historyFiveMin ?? []);

          if (accResult != null) {
            tSignals++;
            String status = accResult['status'];
            if (status == "Win") {
              targetHits++;
              stockTradeResult[item.symbol ?? ''] = "Target Hit";
            } else if (status == "Loss") {
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
      print(historyList.length);
      setState(() {
        isLoading = false;
        totalSignals = tSignals;
        profitableSignals = targetHits;
        slSignals = slHits;
        neutralSignals = neutralHits;
        accuracy = tSignals > 0 ? (targetHits / tSignals) * 100 : 0.0;
      });
    });
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
                'Acc: ${accuracy.toStringAsFixed(1)}% | TGT: $profitableSignals | SL: $slSignals | NEU: $neutralSignals',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
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
          : RefreshIndicator(
              onRefresh: _initialize,
              child: Column(
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
                          onTap: () {
                            if (stockHistory.isEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HistoryScreen(
                                    stockName: stock.symbol ?? '',
                                    historyModel: stockHistory,
                                  ),
                                ),
                              );
                              return;
                            }

                            final accResult =
                                FilterUtils.calculateBuyAlertAccuracy(
                                    stock.historyFiveMin ?? []);

                            double signalPrice = accResult != null
                                ? accResult['entryPrice']
                                : 0.0;
                            double targetPrice =
                                accResult != null ? accResult['target'] : 0.0;
                            double stoplossPrice =
                                accResult != null ? accResult['stoploss'] : 0.0;

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
                                    const SizedBox(height: 8),
                                    Text('Score: $score'),
                                    Text(
                                        'Volume Mult: ${volMult.toStringAsFixed(2)}x'),
                                    const SizedBox(height: 8),
                                    Text(
                                        'Target (2%): ${targetPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Colors.green)),
                                    Text(
                                        'Stoploss: ${stoplossPrice.toStringAsFixed(2)}',
                                        style:
                                            const TextStyle(color: Colors.red)),
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
            ),
    );
  }
}
