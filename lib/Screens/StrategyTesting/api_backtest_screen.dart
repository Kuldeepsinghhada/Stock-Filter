import 'package:flutter/material.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/api_backtest_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/Screens/Chart/chart_screen.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/Widgets/app_drawer.dart';
import 'package:stock_demo/Utils/file_downloader.dart';

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
  final TextEditingController _maxTradesController = TextEditingController(
    text: '5',
  );
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _forceUpdate = false;
  ApiBacktestData? _cachedData;
  ApiBacktestSummary? _summary;
  Map<String, List<ApiBacktestTrade>> _groupedTrades = {};

  // Custom groupBy function
  Map<String, List<ApiBacktestTrade>> _groupBy(
    List<ApiBacktestTrade> list,
    String Function(ApiBacktestTrade) keyFunc,
  ) {
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
        String cleanName = trade.stockName
            .replaceAll("NSE:", "")
            .split("-")
            .first;
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
      int targetHits = 0;
      int stoplossHits = 0;
      int trailingSlHits = 0;
      int squareOffHits = 0;
      double totalPnl = 0.0;

      _groupedTrades = {};

      for (var entry in tempGrouped.entries) {
        var dateTrades = entry.value;

        // Sort chronologically
        dateTrades.sort(
          (a, b) => (a.entryTime ?? '').compareTo(b.entryTime ?? ''),
        );

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

          String reason = trade.exitReason.toLowerCase().trim();
          String status = (trade.status ?? '').toLowerCase().trim();

          if (reason.contains('trailing') ||
              reason.contains('tsl') ||
              reason.contains('trail') ||
              status.contains('trailing') ||
              status.contains('tsl') ||
              status.contains('trail')) {
            trailingSlHits++;
          } else if (reason.contains('target') || reason.contains('tgt')) {
            targetHits++;
          } else if (reason.contains('stoploss') ||
              reason.contains('stop loss') ||
              reason.contains('sl')) {
            stoplossHits++;
          } else if (reason.contains('square') ||
              reason.contains('sqr') ||
              reason.contains('eod') ||
              reason.contains('time')) {
            squareOffHits++;
          } else {
            if (trade.pnlPercent > 0) {
              targetHits++;
            } else if (trade.pnlPercent < 0) {
              stoplossHits++;
            } else {
              squareOffHits++;
            }
          }
        }
      }

      String accuracy = totalTrades > 0
          ? ((wins / totalTrades) * 100).toStringAsFixed(2) + "%"
          : "0.00%";

      _summary = ApiBacktestSummary(
        totalTrades: totalTrades,
        wins: wins,
        losses: losses,
        targetHits: targetHits,
        stoplossHits: stoplossHits,
        trailingSlHits: trailingSlHits,
        squareOffHits: squareOffHits,
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
      var result = await BackendOrderService.runBacktest(
        startStr,
        endStr,
        force: _forceUpdate,
      );
      if (result != null && result.success) {
        if (result.data != null) {
          _cachedData = result.data;
          _applyFilters();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?.message ?? 'Failed to run backtest'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadJson() async {
    String startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    String endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    setState(() {
      _isDownloading = true;
    });

    try {
      String? jsonContent = await BackendOrderService.downloadBacktestJson(
        startDate: startStr,
        endDate: endStr,
      );

      if (jsonContent != null && jsonContent.isNotEmpty) {
        String fileName = "backtest_${startStr}_to_$endStr.json";
        String saveMessage = await FileDownloader.downloadFile(
          content: jsonContent,
          filename: fileName,
        );
        print("File saved path: $saveMessage");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(saveMessage),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download backtest JSON')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error downloading file: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
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
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('API Backtest'),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download Backtest JSON',
            onPressed: _isDownloading ? null : _downloadJson,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Force',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Switch(
                value: _forceUpdate,
                activeThumbColor: Colors.orangeAccent,
                onChanged: (val) {
                  setState(() {
                    _forceUpdate = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _runBacktest,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_isLoading ? "Running..." : "Run Backtest"),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                    ),
                  ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _downloadJson,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: const Text('Download JSON'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
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
                      Text(
                        "Total PnL: ${_summary!.totalPnlPercent}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            "Total",
                            "${_summary!.totalTrades}",
                          ),
                          _buildSummaryItem(
                            "Wins",
                            "${_summary!.wins}",
                            Colors.green,
                          ),
                          _buildSummaryItem(
                            "Losses",
                            "${_summary!.losses}",
                            Colors.red,
                          ),
                          _buildSummaryItem(
                            "Accuracy",
                            "${_summary!.accuracy}",
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Colors.white24),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            "Target Hit",
                            "${_summary!.targetHits}",
                            Colors.green,
                          ),
                          _buildSummaryItem(
                            "Stoploss Hit",
                            "${_summary!.stoplossHits}",
                            Colors.red,
                          ),
                          _buildSummaryItem(
                            "Trailing SL",
                            "${_summary!.trailingSlHits}",
                            Colors.blueAccent,
                          ),
                          _buildSummaryItem(
                            "Square Off",
                            "${_summary!.squareOffHits}",
                            Colors.orange,
                          ),
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
                          0.0,
                          (sum, trade) => sum + trade.pnlPercent,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 4.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    "${dailyPnL >= 0 ? '+' : ''}${dailyPnL.toStringAsFixed(2)}%",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: dailyPnL >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
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
                                  onTap: () {
                                    String cleanName = trade.stockName
                                        .replaceAll("NSE:", "")
                                        .split("-")
                                        .first
                                        .trim();
                                    StockModel stock = DataManager
                                        .instance
                                        .stocksList
                                        .firstWhere(
                                          (s) =>
                                              (s.symbol != null &&
                                                  (s.symbol == cleanName ||
                                                      s.symbol!
                                                              .replaceAll(
                                                                "NSE:",
                                                                "",
                                                              )
                                                              .split("-")
                                                              .first ==
                                                          cleanName)) ||
                                              (s.token != null &&
                                                  s.token.toString() ==
                                                      trade.token.toString()),
                                          orElse: () => StockModel(
                                            symbol: cleanName.isNotEmpty
                                                ? cleanName
                                                : trade.token,
                                            name: cleanName.isNotEmpty
                                                ? cleanName
                                                : trade.token,
                                            token: trade.token,
                                          ),
                                        );

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ChartScreen(stock: stock),
                                      ),
                                    );
                                  },
                                  leading: Icon(
                                    isProfit
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isProfit ? Colors.green : Colors.red,
                                  ),
                                  title: Text(
                                    "${trade.stockName.isNotEmpty ? trade.stockName : 'Token: ${trade.token}'} - ${trade.exitReason}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}
