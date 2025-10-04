import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/history/history_screen.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/model/historical_data_model.dart';
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
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    quoteList.clear();
    Future.delayed(const Duration(milliseconds: 200), () async {
      setState(() {
        isLoading = true;
      });
      for (var item in DataManager.instance.preFilteredStocksList) {
        var result = await buildTodayHistory(item.historyFiveMin ?? [], item);
        if (result.isNotEmpty) {
          quoteList.add(item);
          historyList.add(result);
        }
      }
      setState(() {
        isLoading = false;
      });
    });
  }

  String timeKey(DateTime ts) {
    return "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";
  }

  // main scanner
  Future<List<HistoryModel>> buildTodayHistory(
    List<HistoricalDataModel> candles,
    StockModel model,
  ) async {
    // sort
    candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // identify today's date
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // filter only today's candles
    final todayCandles =
        candles
            .where(
              (c) =>
                  c.timestamp.year == todayDate.year &&
                  c.timestamp.month == todayDate.month &&
                  c.timestamp.day == todayDate.day,
            )
            .toList();
    List<HistoryModel> historyThisList = [];
    for (var current in todayCandles) {
      // collect all candles of 20 days till this time-of-day
      var historySoFar =
          candles.where((c) {
            return (c.timestamp.hour < current.timestamp.hour) ||
                (c.timestamp.hour == current.timestamp.hour &&
                    c.timestamp.minute <= current.timestamp.minute);
          }).toList();

      // run your filter
      try {
        bool passed = await FilterUtils.isPassAllTimeFrame(historySoFar, model);

        if (passed) {
          historyThisList.add(
            HistoryModel(
              dateTime: current.timestamp,
              price: current.close,
              isPassed: passed,
            ),
          );
        }
      } catch (e) {
        print(e.toString());
      }
    }
    return historyThisList;
  }

  bool passesFilter(
    HistoricalDataModel candle,
    List<HistoricalDataModel> historySoFar,
  ) {
    if (historySoFar.isEmpty) return false;

    double lastHigh = historySoFar
        .map((c) => c.high)
        .fold<double>(-double.infinity, (a, b) => a > b ? a : b);

    return candle.close > lastHigh; // breakout
  }

  // // Helper: compare only intraday time (hh:mm)
  // bool isBeforeOrEqualTime(DateTime a, DateTime b) {
  //   if (a.hour < b.hour) return true;
  //   if (a.hour == b.hour && a.minute <= b.minute) return true;
  //   return false;
  // }

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
      appBar: AppBar(title: const Text('Pre Filtered Stocks')),
      body:
          isLoading
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
                        onChanged:
                            (value) =>
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
                          return ListTile(
                            leading: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            title: Text(symbol),
                            subtitle: Text(
                              'Token: ${stock.token}, Price: ${stock.lastPrice}',
                            ),
                            trailing: Text(
                              historyList[index].length.toString(),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => HistoryScreen(
                                        stockName: stock.symbol ?? '',
                                        historyModel: historyList[index],
                                      ),
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
