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
  double accuracy = 0.0;
  Map<String, bool> stockProfitability = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    quoteList.clear();
    stockProfitability.clear();
    Future.delayed(const Duration(milliseconds: 200), () async {
      setState(() {
        isLoading = true;
        totalSignals = 0;
        profitableSignals = 0;
        accuracy = 0.0;
      });
      int tSignals = 0;
      int pSignals = 0;
      for (var item in DataManager.instance.preFilteredStocksList) {
        var result = await Utilities.buildTodayHistory(
          item.historyFiveMin ?? [],
          item,
        );
        if (result.isNotEmpty) {
          quoteList.add(item);
          historyList.add(result);

          var candles = item.historyFiveMin ?? [];
          if (candles.isNotEmpty) {
            var groupedByDate = CandleUtils.groupByDate(candles);
            var sortedDates = groupedByDate.keys.toList()..sort();
            if (sortedDates.isNotEmpty) {
              var todayDate = sortedDates.last;
              var todayCandles = groupedByDate[todayDate]!;

              var signal = result.first;
              tSignals++;
              bool profitable = false;
              var signalDateTime = signal.dateTime ?? todayDate;
              var subsequentCandles = todayCandles
                  .where((c) => c.timestamp.isAfter(signalDateTime))
                  .toList();

              double signalPrice = signal.price?.toDouble() ?? 0.0;

              if (signalPrice > 0) {
                for (var candle in subsequentCandles) {
                  double highChange =
                      ((candle.high - signalPrice) / signalPrice) * 100;

                  if (highChange >= 2.0) {
                    profitable = true;
                    break;
                  }
                }
              }

              if (profitable) pSignals++;
              stockProfitability[item.symbol ?? ''] = profitable;
            }
          }
        }
      }
      print(historyList.length);
      setState(() {
        isLoading = false;
        totalSignals = tSignals;
        profitableSignals = pSignals;
        accuracy = tSignals > 0 ? (pSignals / tSignals) * 100 : 0.0;
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
                'Accuracy: ${accuracy.toStringAsFixed(2)}% ($profitableSignals/$totalSignals)',
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
                        bool isProfitable =
                            stockProfitability[stock.symbol ?? ''] ?? false;
                        int originalIndex = quoteList.indexOf(stock);
                        List<HistoryModel> stockHistory = originalIndex != -1
                            ? historyList[originalIndex]
                            : [];

                        return ListTile(
                          tileColor:
                              isProfitable ? null : Colors.red.withOpacity(0.1),
                          leading: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          title: Text(
                            symbol,
                            style: TextStyle(
                              color: isProfitable ? null : Colors.red,
                              fontWeight: isProfitable
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

                            final signal = stockHistory.first;
                            final signalTime = signal.dateTime;
                            final signalPrice = signal.price ?? 0.0;

                            final historySoFar = stock.historyFiveMin
                                    ?.where((c) =>
                                        !c.timestamp.isAfter(signalTime!))
                                    .toList() ??
                                [];
                            int score = FilterUtils.getSmartPriceActionScore(
                                historySoFar);
                            double volMult =
                                FilterUtils.getVolumeMultiplication(
                                    historySoFar);

                            final todayCandles = stock.historyFiveMin
                                    ?.where((c) =>
                                        c.timestamp.year == signalTime!.year &&
                                        c.timestamp.month == signalTime.month &&
                                        c.timestamp.day == signalTime.day)
                                    .toList() ??
                                [];
                            final subsequentCandles = todayCandles
                                .where((c) => c.timestamp.isAfter(signalTime!))
                                .toList();

                            double maxHigh = subsequentCandles.isNotEmpty
                                ? subsequentCandles
                                    .map((c) => c.high)
                                    .reduce((a, b) => max(a, b))
                                : signalPrice;
                            double closePrice = todayCandles.isNotEmpty
                                ? todayCandles.last.close
                                : signalPrice;

                            double highPercent = signalPrice > 0
                                ? ((maxHigh - signalPrice) / signalPrice) * 100
                                : 0.0;
                            double closePercent = signalPrice > 0
                                ? ((closePrice - signalPrice) / signalPrice) *
                                    100
                                : 0.0;

                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(symbol),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Signal Price: $signalPrice',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('Score: $score'),
                                    Text(
                                        'Volume Mult: ${volMult.toStringAsFixed(2)}x'),
                                    const SizedBox(height: 8),
                                    Text(
                                        'High: $maxHigh (${highPercent > 0 ? '+' : ''}${highPercent.toStringAsFixed(2)}%)',
                                        style: TextStyle(
                                            color: highPercent >= 0
                                                ? Colors.green
                                                : Colors.red)),
                                    Text(
                                        'Close: $closePrice (${closePercent > 0 ? '+' : ''}${closePercent.toStringAsFixed(2)}%)',
                                        style: TextStyle(
                                            color: closePercent >= 0
                                                ? Colors.green
                                                : Colors.red)),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HistoryScreen(
                                            stockName: stock.symbol ?? '',
                                            historyModel: stockHistory,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('View Chart'),
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
