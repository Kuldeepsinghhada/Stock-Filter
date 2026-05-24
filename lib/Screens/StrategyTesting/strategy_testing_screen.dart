import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/Screens/DataScreen/history_services.dart';
import 'package:stock_demo/Utils/candle_utils.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/history_model.dart';
import 'package:stock_demo/model/stock_model.dart';

class BacktestResult {
  final DateTime date;
  final String symbol;
  final HistoryModel? signal;
  final bool isProfitable;
  final double maxHigh;

  BacktestResult({
    required this.date,
    required this.symbol,
    required this.signal,
    required this.isProfitable,
    required this.maxHigh,
  });
}

class StrategyTestingScreen extends StatefulWidget {
  const StrategyTestingScreen({super.key});

  @override
  State<StrategyTestingScreen> createState() => _StrategyTestingScreenState();
}

class _StrategyTestingScreenState extends State<StrategyTestingScreen> {
  final TextEditingController _stocksController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<BacktestResult> _results = [];
  double _accuracy = 0.0;
  int _totalSignals = 0;
  int _profitableSignals = 0;
  bool _isDayBreakOut = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _runBacktest() async {
    if (_stocksController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results.clear();
      _totalSignals = 0;
      _profitableSignals = 0;
      _accuracy = 0.0;
    });

    List<String> symbols = _stocksController.text
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    await Utilities.loadStocksList();

    int totalSignals = 0;
    int profitableSignals = 0;
    List<BacktestResult> localResults = [];

    for (String symbol in symbols) {
      var stockModel = DataManager.instance.stocksList.firstWhere(
        (e) => e.symbol == symbol,
        orElse: () => StockModel(symbol: symbol),
      );

      if (stockModel.token == null) continue;

      // fetch 5min data
      var candles = await HistoryServices.instance.fetchIntervalData(
        stockModel,
        "5m",
        forceRefresh: true,
      );

      if (candles.isEmpty) continue;

      // filter candles up to selectedDate 23:59
      var endOfDay = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, 23, 59, 59);
      var filtered =
          candles.where((c) => c.timestamp.isBefore(endOfDay)).toList();

      if (filtered.isEmpty) continue;

      // group by date
      var groupedByDate = CandleUtils.groupByDate(filtered);
      var tradingDates = groupedByDate.keys.toList()..sort();

      // get last 5 dates
      var last5Dates = tradingDates.reversed.take(5).toList().reversed.toList();

      for (var date in last5Dates) {
        var dateEndOfDay =
            DateTime(date.year, date.month, date.day, 23, 59, 59);
        var candlesUpToDate =
            filtered.where((c) => c.timestamp.isBefore(dateEndOfDay)).toList();

        var signals =
            await Utilities.buildTodayHistory(candlesUpToDate, stockModel, isDayBreakOut: _isDayBreakOut);

        if (signals.isNotEmpty) {
          for (var signal in signals) {
            bool profitable = false;
            var signalDateTime = signal.dateTime ?? date;
            var subsequentCandles = groupedByDate[date]!
                .where((c) => c.timestamp.isAfter(signalDateTime))
                .toList();

            double signalPrice = signal.price?.toDouble() ?? 0.0;

            double maxHigh = subsequentCandles.isNotEmpty
                ? subsequentCandles.map((c) => c.high).reduce(max).toDouble()
                : signalPrice;

            if (maxHigh > signalPrice) {
              profitable = true;
            }

            if (profitable) profitableSignals++;
            totalSignals++;

            localResults.add(BacktestResult(
              date: date,
              symbol: symbol,
              signal: signal,
              isProfitable: profitable,
              maxHigh: maxHigh,
            ));
          }
        } else {
          localResults.add(BacktestResult(
            date: date,
            symbol: symbol,
            signal: null,
            isProfitable: false,
            maxHigh: 0.0,
          ));
        }
      }
    }

    // Sort by date descending
    localResults.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _results = localResults;
      _totalSignals = totalSignals;
      _profitableSignals = profitableSignals;
      _accuracy =
          totalSignals > 0 ? (profitableSignals / totalSignals) * 100 : 0.0;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy Testing'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _stocksController,
              decoration: const InputDecoration(
                labelText: 'Enter Stock Names (comma separated)',
                border: OutlineInputBorder(),
                hintText: 'e.g. RELIANCE, TCS, INFY',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Selected Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: const Text('Select Date'),
                ),
                const SizedBox(width: 16),
                const Text('DayBreakOut', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _isDayBreakOut,
                  onChanged: (val) {
                    setState(() {
                      _isDayBreakOut = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _runBacktest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Run Backtest',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (_results.isNotEmpty)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text("Total Signals"),
                          Text("$_totalSignals",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text("Profitable"),
                          Text("$_profitableSignals",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text("Accuracy"),
                          Text("${_accuracy.toStringAsFixed(2)}%",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.blue)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: Text("Fetching Data..."))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        final String dateStr =
                            DateFormat('dd MMM yyyy').format(result.date);

                        if (result.signal == null) {
                          return ListTile(
                            title: Text("${result.symbol} - $dateStr"),
                            subtitle: const Text("No Signal"),
                            leading: const Icon(Icons.remove_circle,
                                color: Colors.grey),
                          );
                        }

                        final signal = result.signal!;
                        final String signalTime = signal.dateTime != null 
                            ? DateFormat('HH:mm').format(signal.dateTime!) 
                            : 'N/A';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              result.isProfitable
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: result.isProfitable
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(
                              "${result.symbol} - $dateStr",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Signal at $signalTime | Price: ${signal.price}\nMax High after signal: ${result.maxHigh}",
                            ),
                            isThreeLine: true,
                          ),
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
