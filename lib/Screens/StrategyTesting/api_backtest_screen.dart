import 'package:flutter/material.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/api_backtest_model.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:intl/intl.dart';

class ApiBacktestScreen extends StatefulWidget {
  const ApiBacktestScreen({super.key});

  @override
  State<ApiBacktestScreen> createState() => _ApiBacktestScreenState();
}

class _ApiBacktestScreenState extends State<ApiBacktestScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 15);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 30);
  final TextEditingController _maxTradesController =
      TextEditingController(text: '5');
  bool _isLoading = false;
  ApiBacktestData? _cachedData;
  ApiBacktestSummary? _summary;
  Map<String, List<ApiBacktestTrade>> _groupedTrades = {};

  // Custom groupBy function
  Map<String, List<ApiBacktestTrade>> _groupBy(
      List<ApiBacktestTrade> list, String Function(ApiBacktestTrade) keyFunc) {
    Map<String, List<ApiBacktestTrade>> map = {};
    for (var item in list) {
      var key = keyFunc(item);
      if (!map.containsKey(key)) {
        map[key] = [];
      }
      map[key]!.add(item);
    }
    return map;
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
      _applyFilters();
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    if (_cachedData == null) return;

    setState(() {
      int? maxTrades = int.tryParse(_maxTradesController.text);

      var filteredTrades = _cachedData!.trades.where((trade) {
        String cleanName =
            trade.stockName.replaceAll("NSE:", "").split("-").first;
        if (Utilities.blockedSymbols.contains(cleanName)) {
          return false;
        }
        if (trade.entryTime != null) {
          try {
            DateTime dt = DateTime.parse(trade.entryTime!).toLocal();
            int tradeMinutes = dt.hour * 60 + dt.minute;
            int startMinutes = _startTime.hour * 60 + _startTime.minute;
            int endMinutes = _endTime.hour * 60 + _endTime.minute;
            if (tradeMinutes < startMinutes || tradeMinutes > endMinutes) {
              return false;
            }
          } catch (e) {
            print("Error parsing time: ${trade.entryTime} - $e");
          }
        }
        return true;
      }).toList();

      var tempGrouped = _groupBy(filteredTrades, (trade) => trade.date);

      int totalTrades = 0;
      int wins = 0;
      int losses = 0;
      double totalPnl = 0.0;

      _groupedTrades = {};

      for (var entry in tempGrouped.entries) {
        var dateTrades = entry.value;

        // Sort chronologically
        dateTrades
            .sort((a, b) => (a.entryTime ?? '').compareTo(b.entryTime ?? ''));

        // Apply max trades filter per day
        if (maxTrades != null && dateTrades.length > maxTrades) {
          dateTrades = dateTrades.sublist(0, maxTrades);
        }

        _groupedTrades[entry.key] = dateTrades;

        for (var trade in dateTrades) {
          totalTrades++;
          if (trade.pnlPercent > 0) {
            wins++;
          } else if (trade.pnlPercent < 0) {
            losses++;
          }
          totalPnl += trade.pnlPercent;
        }
      }

      String accuracy = totalTrades > 0
          ? ((wins / totalTrades) * 100).toStringAsFixed(2) + "%"
          : "0.00%";

      _summary = ApiBacktestSummary(
        totalTrades: totalTrades,
        wins: wins,
        losses: losses,
        accuracy: accuracy,
        totalPnlPercent: totalPnl.toStringAsFixed(2) + "%",
      );
    });
  }

  Future<void> _runBacktest() async {
    String startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    String endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    setState(() {
      _isLoading = true;
      _summary = null;
      _groupedTrades = {};
    });

    try {
      var result = await BackendOrderService.runBacktest(startStr, endStr);
      if (result != null && result.success) {
        if (result.data != null) {
          _cachedData = result.data;
          _applyFilters();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result?.message ?? 'Failed to run backtest')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort dates in descending order (newest first)
    List<String> sortedDates = _groupedTrades.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Backtest'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectEndDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _runBacktest,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Run'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartTime(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: Text(_startTime.format(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectEndTime(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: Text(_endTime.format(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxTradesController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _applyFilters(),
                    decoration: const InputDecoration(
                      labelText: 'Max Trades',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_summary != null)
              Card(
                color: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Text("Total PnL: ${_summary!.totalPnlPercent}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                              "Total", "${_summary!.totalTrades}"),
                          _buildSummaryItem(
                              "Wins", "${_summary!.wins}", Colors.green),
                          _buildSummaryItem(
                              "Losses", "${_summary!.losses}", Colors.red),
                          _buildSummaryItem(
                              "Accuracy", "${_summary!.accuracy}"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _groupedTrades.isEmpty
                  ? const Center(child: Text('No trades data'))
                  : ListView.builder(
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        String dateStr = sortedDates[index];
                        List<ApiBacktestTrade> dateTrades =
                            _groupedTrades[dateStr]!;

                        double dailyPnL = dateTrades.fold(
                            0.0, (sum, trade) => sum + trade.pnlPercent);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 4.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.grey),
                                  ),
                                  Text(
                                    "${dailyPnL >= 0 ? '+' : ''}${dailyPnL.toStringAsFixed(2)}%",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: dailyPnL >= 0
                                            ? Colors.green
                                            : Colors.red),
                                  ),
                                ],
                              ),
                            ),
                            ...dateTrades.map((trade) {
                              bool isProfit = trade.pnlPercent > 0;
                              String timeStr = trade.entryTime != null
                                  ? trade.entryTime!
                                      .split('T')
                                      .last
                                      .substring(0, 5)
                                  : '';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(
                                    isProfit
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isProfit ? Colors.green : Colors.red,
                                  ),
                                  title: Text(
                                    "${trade.stockName.isNotEmpty ? trade.stockName : 'Token: ${trade.token}'} - ${trade.exitReason}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    "Entry: ${trade.entryPrice} | Exit: ${trade.exitPrice}\nPnL: ${trade.pnlPercent.toStringAsFixed(2)}%",
                                  ),
                                  trailing: Text(
                                    timeStr,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, [Color? color]) {
    return Column(
      children: [
        Text(label),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }
}
