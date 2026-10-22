import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/investment_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/Screens/Chart/chart_screen.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Widgets/app_drawer.dart';

class _SwingSummary {
  final int totalTrades;
  final int wins;
  final int losses;
  final int targetHits;
  final int stoplossHits;
  final int trailingSlHits;
  final int squareOffHits;
  final String accuracy;
  final String totalPnlPercent;
  final double totalPnlNum;

  _SwingSummary({
    required this.totalTrades,
    required this.wins,
    required this.losses,
    required this.targetHits,
    required this.stoplossHits,
    required this.trailingSlHits,
    required this.squareOffHits,
    required this.accuracy,
    required this.totalPnlPercent,
    required this.totalPnlNum,
  });
}

class InvestmentScreen extends StatefulWidget {
  final String? initialStartDate;
  final String? initialEndDate;

  const InvestmentScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _maxTradesController = TextEditingController();
  String _statusFilter = 'ALL'; // ALL, WIN, LOSS, OPEN

  bool _isLoading = false;
  InvestmentData? _cachedData;
  _SwingSummary? _summary;
  Map<String, List<InvestmentRecommendation>> _groupedTrades = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      try {
        _startDate = DateTime.parse(widget.initialStartDate!);
        _endDate = DateTime.parse(widget.initialEndDate!);
      } catch (_) {
        _startDate = now.subtract(const Duration(days: 365));
        _endDate = now;
      }
    } else {
      // Default: Last 1 year (365 days) to Today
      _startDate = now.subtract(const Duration(days: 365));
      _endDate = now;
    }
    _runBacktest();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _maxTradesController.dispose();
    super.dispose();
  }

  String _getDateKey(InvestmentRecommendation trade) {
    String raw = trade.entryDate ?? trade.date ?? trade.createdAt;
    if (raw.contains('T')) return raw.split('T').first.trim();
    if (raw.contains(' ')) return raw.split(' ').first.trim();
    return raw.trim();
  }

  String _formatDate(String? dStr) {
    if (dStr == null || dStr.isEmpty) return '';
    if (dStr.contains('T')) return dStr.split('T').first.trim();
    if (dStr.contains(' ')) return dStr.split(' ').first.trim();
    return dStr.trim();
  }

  Map<String, List<InvestmentRecommendation>> _groupBy(
    List<InvestmentRecommendation> list,
    String Function(InvestmentRecommendation) keyFunc,
  ) {
    Map<String, List<InvestmentRecommendation>> map = {};
    for (var item in list) {
      var key = keyFunc(item);
      if (!map.containsKey(key)) {
        map[key] = [];
      }
      map[key]!.add(item);
    }
    return map;
  }

  void _applyFilters() {
    if (_cachedData == null) return;

    setState(() {
      int? maxTrades = int.tryParse(_maxTradesController.text);
      String query = _searchController.text.trim().toLowerCase();

      var filteredTrades = _cachedData!.recommendations.where((trade) {
        // Search query filter
        if (query.isNotEmpty) {
          final symMatch = trade.symbol.toLowerCase().contains(query);
          final nameMatch = trade.stockName != null &&
              trade.stockName!.toLowerCase().contains(query);
          final reasonMatch = trade.exitReason != null &&
              trade.exitReason!.toLowerCase().contains(query);
          if (!symMatch && !nameMatch && !reasonMatch) return false;
        }

        // Status filter
        final pnl = trade.realizedPnlPercent ?? 0.0;
        final isWin = pnl > 0 ||
            trade.status.toUpperCase() == 'WIN' ||
            trade.winLoss == 'WIN' ||
            (trade.exitReason?.toUpperCase() == 'TARGET_HIT');
        final isLoss = pnl < 0 ||
            trade.status.toUpperCase() == 'LOSS' ||
            trade.winLoss == 'LOSS' ||
            (trade.exitReason?.toUpperCase() == 'STOP_LOSS_HIT');
        final isOpen = trade.status.toUpperCase() == 'OPEN' ||
            trade.winLoss == 'OPEN' ||
            (trade.exitReason?.toUpperCase() == 'OPEN');

        if (_statusFilter == 'WIN' && !isWin) return false;
        if (_statusFilter == 'LOSS' && !isLoss) return false;
        if (_statusFilter == 'OPEN' && !isOpen) return false;

        return true;
      }).toList();

      var tempGrouped = _groupBy(filteredTrades, _getDateKey);

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

        // Apply max trades filter per day if valid and > 0
        if (maxTrades != null &&
            maxTrades > 0 &&
            dateTrades.length > maxTrades) {
          dateTrades = dateTrades.sublist(0, maxTrades);
        }

        _groupedTrades[entry.key] = dateTrades;

        for (var trade in dateTrades) {
          totalTrades++;
          final pnl = trade.realizedPnlPercent ?? 0.0;
          if (pnl > 0) {
            wins++;
          } else if (pnl < 0) {
            losses++;
          }
          totalPnl += pnl;

          String reason =
              (trade.exitReason ?? trade.status).toUpperCase().trim();

          if (reason.contains('TRAILING') ||
              reason.contains('TSL') ||
              reason.contains('TRAIL')) {
            trailingSlHits++;
          } else if (reason.contains('TARGET') || reason.contains('TGT')) {
            targetHits++;
          } else if (reason.contains('STOPLOSS') ||
              reason.contains('STOP_LOSS') ||
              reason.contains('SL')) {
            stoplossHits++;
          } else if (reason.contains('SQUARE') ||
              reason.contains('TIME') ||
              reason.contains('EXPIRED')) {
            squareOffHits++;
          } else {
            if (pnl > 0) {
              targetHits++;
            } else if (pnl < 0) {
              stoplossHits++;
            } else {
              squareOffHits++;
            }
          }
        }
      }

      int resolvedTrades = wins + losses;
      String accuracy = resolvedTrades > 0
          ? "${((wins / resolvedTrades) * 100).toStringAsFixed(2)}%"
          : (totalTrades > 0
              ? "${((wins / totalTrades) * 100).toStringAsFixed(2)}%"
              : "0.00%");

      _summary = _SwingSummary(
        totalTrades: totalTrades,
        wins: wins,
        losses: losses,
        targetHits: targetHits,
        stoplossHits: stoplossHits,
        trailingSlHits: trailingSlHits,
        squareOffHits: squareOffHits,
        accuracy: accuracy,
        totalPnlPercent:
            "${totalPnl >= 0 ? '+' : ''}${totalPnl.toStringAsFixed(2)}%",
        totalPnlNum: totalPnl,
      );
    });
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
      _runBacktest();
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
      _runBacktest();
    }
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
      final response = await BackendOrderService.fetchInvestmentRecommendations(
        startDate: startStr,
        endDate: endStr,
      );

      if (response != null && response.success) {
        if (response.data != null) {
          _cachedData = response.data;
          _applyFilters();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response?.message ?? 'Failed to load swing backtest data',
              ),
            ),
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

  void _copyAllSymbols() {
    List<String> symbols = [];
    for (var list in _groupedTrades.values) {
      for (var t in list) {
        if (!symbols.contains(t.symbol)) {
          symbols.add(t.symbol);
        }
      }
    }
    if (symbols.isEmpty) {
      Fluttertoast.showToast(msg: "No symbols to copy");
      return;
    }
    Clipboard.setData(ClipboardData(text: symbols.join(', ')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${symbols.length} symbol(s) to clipboard'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, [Color? color]) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort dates in descending order (newest date first)
    List<String> sortedDates = _groupedTrades.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      // drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Swing Backtest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Symbols',
            onPressed: _copyAllSymbols,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _runBacktest,
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
            // Row 1: Start Date and End Date Pickers
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
            // Row 2: Search Symbol, Status Filter, and Max Trades
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _applyFilters(),
                    decoration: const InputDecoration(
                      labelText: 'Search Symbol',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        isDense: true,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                          DropdownMenuItem(value: 'WIN', child: Text('WIN')),
                          DropdownMenuItem(value: 'LOSS', child: Text('LOSS')),
                          DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _statusFilter = val;
                            });
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _maxTradesController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _applyFilters(),
                    decoration: const InputDecoration(
                      labelText: 'Max/Day',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Clean Summary Card
            if (_summary != null)
              Card(
                color: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Text(
                        "Total PnL: ${_summary!.totalPnlPercent}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _summary!.totalPnlNum >= 0
                              ? Colors.green
                              : Colors.redAccent,
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
                            _summary!.accuracy,
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
            // Date-grouped Trade List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Loading swing backtest...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _groupedTrades.isEmpty
                      ? const Center(child: Text('No trades data'))
                      : ListView.builder(
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            String dateStr = sortedDates[index];
                            List<InvestmentRecommendation> dateTrades =
                                _groupedTrades[dateStr]!;

                            double dailyPnL = dateTrades.fold(
                              0.0,
                              (sum, trade) =>
                                  sum + (trade.realizedPnlPercent ?? 0.0),
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
                                  final pnl =
                                      trade.realizedPnlPercent ?? 0.0;
                                  final isWin = pnl > 0 ||
                                      trade.status.toUpperCase() == 'WIN' ||
                                      trade.winLoss == 'WIN' ||
                                      (trade.exitReason?.toUpperCase() ==
                                          'TARGET_HIT');
                                  final isLoss = pnl < 0 ||
                                      trade.status.toUpperCase() == 'LOSS' ||
                                      trade.winLoss == 'LOSS' ||
                                      (trade.exitReason?.toUpperCase() ==
                                          'STOP_LOSS_HIT');

                                  IconData iconData = isWin
                                      ? Icons.check_circle
                                      : (isLoss
                                          ? Icons.cancel
                                          : Icons.remove_circle_outline);
                                  Color iconColor = isWin
                                      ? Colors.green
                                      : (isLoss
                                          ? Colors.red
                                          : Colors.orange);

                                  String entryDateStr = _formatDate(
                                    trade.entryDate ?? trade.date,
                                  );
                                  String exitDateStr = _formatDate(
                                    trade.exitDate ?? trade.exitTime,
                                  );

                                  String entryDetails =
                                      "Entry: ₹${trade.entryPrice.toStringAsFixed(2)}${entryDateStr.isNotEmpty ? ' ($entryDateStr)' : ''}";
                                  String exitDetails = trade.exitPrice !=
                                              null &&
                                          trade.exitPrice! > 0
                                      ? "Exit: ₹${trade.exitPrice!.toStringAsFixed(2)}${exitDateStr.isNotEmpty ? ' ($exitDateStr)' : ''}"
                                      : "Holding / Open";

                                  String slTargetText = "";
                                  if (trade.stopLossPrice > 0 ||
                                      trade.targetPrice > 0) {
                                    slTargetText =
                                        "\nSL: ₹${trade.stopLossPrice > 0 ? trade.stopLossPrice.toStringAsFixed(2) : '-'} | Tgt: ₹${trade.targetPrice > 0 ? trade.targetPrice.toStringAsFixed(2) : '-'}";
                                  }

                                  String holdingDaysText =
                                      trade.holdingDays != null &&
                                              trade.holdingDays! > 0
                                          ? " | ${trade.holdingDays}d"
                                          : "";

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      onTap: () {
                                        String cleanName = trade.symbol
                                            .replaceAll("NSE:", "")
                                            .replaceAll("BSE:", "")
                                            .split("-")
                                            .first
                                            .trim();
                                        StockModel stock = DataManager
                                            .instance.stocksList
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
                                                : trade.token.toString(),
                                            name: cleanName.isNotEmpty
                                                ? cleanName
                                                : trade.token.toString(),
                                            token: trade.token.toString(),
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
                                        iconData,
                                        color: iconColor,
                                      ),
                                      title: Text(
                                        "${trade.symbol} - ${(trade.exitReason ?? trade.status).replaceAll('_HIT', '')}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "$entryDetails\n$exitDetails$slTargetText$holdingDaysText",
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            trade.realizedPnlPercentage ??
                                                "${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: iconColor,
                                            ),
                                          ),
                                        ],
                                      ),
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
}
