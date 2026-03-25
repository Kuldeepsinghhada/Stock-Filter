import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/candle_utils.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:stock_demo/Screens/DataScreen/intraday_service.dart';

class IntradayStockData {
  final StockModel stock;
  double yesterdayAvgVolume = 0;
  double todayAvgVolume = 0;
  double volumePercent = 0;
  String signal = "NONE";
  bool isLoading = true;
  String? error;

  IntradayStockData({required this.stock});

  Color get signalColor {
    if (signal == "SUPER HOT") return Colors.greenAccent;
    if (signal == "VERY HOT") return Colors.orangeAccent;
    if (signal == "HOT") return Colors.greenAccent;
    if (signal == "NORMAL") return Colors.redAccent;
    return Colors.white70;
  }
}

class IntradayScreen extends StatefulWidget {
  const IntradayScreen({super.key});

  @override
  State<IntradayScreen> createState() => _IntradayScreenState();
}

class _IntradayScreenState extends State<IntradayScreen> {
  bool isTaskRunning = false;
  List<IntradayStockData> intradayList = [];
  Timer? _timer;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allStocksMaster = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool isHistoryMode = false;

  DateTime get _effectiveDateTime {
    if (!isHistoryMode) return DateTime.now();
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    _loadSavedStocks();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    try {
      await Utilities.loadStocksList();
      // We can also use rootBundle to get the full raw list if needed,
      // but DataManager.instance.stocksList usually has what we need.
    } catch (e) {
      log("Error loading master data: $e");
    }
  }

  Future<void> _loadSavedStocks() async {
    final List<String> savedSymbols = (await SharedPreferenceHelper.instance
            .getStringList('intraday_symbols')) ??
        [];

    if (savedSymbols.isNotEmpty) {
      setState(() {
        intradayList = savedSymbols
            .map((s) => IntradayStockData(stock: StockModel(symbol: s)))
            .toList();
      });
    }
  }

  Future<void> _saveStocks() async {
    final symbols = intradayList.map((e) => e.stock.symbol!).toList();
    await SharedPreferenceHelper.instance
        .setStringList('intraday_symbols', symbols);
  }

  void _addStock(String symbol, String token, String name) {
    if (intradayList.any((e) => e.stock.symbol == symbol)) return;
    setState(() {
      intradayList.add(IntradayStockData(
        stock: StockModel(symbol: symbol, token: token, name: name),
      ));
    });
    _saveStocks();
    if (isTaskRunning) _fetchDataForStock(intradayList.last);
  }

  void _removeStock(int index) {
    setState(() {
      intradayList.removeAt(index);
    });
    _saveStocks();
  }

  void _resetScannerData() {
    for (var item in intradayList) {
      item.isLoading = true;
      item.yesterdayAvgVolume = 0;
      item.todayAvgVolume = 0;
      item.volumePercent = 0;
      item.signal = "NONE";
    }
  }

  Future<void> startTask() async {
    await WakelockPlus.enable();
    setState(() => isTaskRunning = true);
    _fetchLoop();
  }

  void stopTask() async {
    await WakelockPlus.disable();
    _timer?.cancel();
    setState(() => isTaskRunning = false);
  }

  Future<void> _fetchLoop() async {
    if (!isTaskRunning) return;

    for (var data in intradayList) {
      if (!isTaskRunning) break;
      await _fetchDataForStock(data);
    }

    // CONTINUOUS FETCH only in LIVE mode
    if (isTaskRunning && !isHistoryMode) {
      _timer = Timer(const Duration(seconds: 10), _fetchLoop);
    } else if (isHistoryMode) {
      // STOP automatically after one pass in history mode
      setState(() => isTaskRunning = false);
      WakelockPlus.disable();
    }
  }

  Future<void> _fetchDataForStock(IntradayStockData data) async {
    try {
      // 1. Ensure we have a token
      if (data.stock.token == null || data.stock.token!.isEmpty) {
        if (DataManager.instance.stocksList.isEmpty) {
          await Utilities.loadStocksList();
        }
        final master = DataManager.instance.stocksList.firstWhere(
          (s) => s.symbol == data.stock.symbol,
          orElse: () => StockModel(symbol: data.stock.symbol),
        );
        if (master.token != null) {
          data.stock.token = master.token;
          data.stock.name = master.name;
        }
      }

      final token = data.stock.token;
      if (token == null) return;

      // 2. Use Service for API call and calculations
      final result = await IntradayService.instance.calculateIntradayVolumeData(
        token: token.toString(),
        effectiveDateTime: _effectiveDateTime,
      );

      if (result['error'] == null) {
        data.yesterdayAvgVolume = result['yesterdayAvgVolume'];
        data.todayAvgVolume = result['todayAvgVolume'];
        data.volumePercent = result['volumePercent'];
        data.stock.lastPrice = result['lastPrice'];
        data.error = null;
        data.isLoading = false;

        // 3. Update Signals
        if (data.volumePercent > 200) {
          data.signal = "SUPER HOT";
        } else if (data.volumePercent > 180) {
          data.signal = "VERY HOT";
        } else if (data.volumePercent > 100) {
          data.signal = "HOT";
        } else {
          data.signal = "NORMAL";
        }

        if (mounted) {
          setState(() {
            intradayList
                .sort((a, b) => b.volumePercent.compareTo(a.volumePercent));
          });
        }
      } else {
        data.error = result['error'];
        data.isLoading = false;
        if (mounted) setState(() {});
      }
    } catch (e) {
      data.error = e.toString();
      data.isLoading = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff131722),
      appBar: AppBar(
        title: Text(isHistoryMode ? "History" : "Live Scanner"),
        backgroundColor: const Color(0xff131722),
        actions: [
          IconButton(
            icon: Icon(Icons.settings,
                color: isHistoryMode ? Colors.orangeAccent : Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IntradaySettingsScreen(
                    initialMode: isHistoryMode,
                    initialDate: _selectedDate,
                    initialTime: _selectedTime,
                  ),
                ),
              );

              if (result != null && result is Map) {
                setState(() {
                  isHistoryMode = result['isHistoryMode'];
                  _selectedDate = result['selectedDate'];
                  _selectedTime = result['selectedTime'];
                  _resetScannerData();
                });
                // If we were running, stop and optionally restart or let user restart
                if (isTaskRunning) stopTask();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchSheet(context),
          )
        ],
      ),
      body: Column(
        children: [
          _buildSummaryHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // 1. Reload list from local storage
                await _loadSavedStocks();
              },
              color: Colors.greenAccent,
              child: intradayList.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Text("Add stocks to start scanning",
                                style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: intradayList.length,
                      itemBuilder: (context, index) {
                        final item = intradayList[index];
                        return _buildStockCard(item, index);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isTaskRunning ? stopTask : startTask,
        label: Text(isTaskRunning ? "STOP" : "START"),
        icon: Icon(isTaskRunning ? Icons.stop : Icons.play_arrow),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.white.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Stocks: ${intradayList.length}",
              style: const TextStyle(color: Colors.white70)),
          if (isTaskRunning)
            const Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.greenAccent)),
                ),
                SizedBox(width: 8),
                Text("Scanning...",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildStockCard(IntradayStockData item, int index) {
    return Dismissible(
      key: Key(item.stock.symbol!),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeStock(index),
      child: Card(
        color: const Color(0xff1e222d),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.stock.symbol ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(item.stock.name ?? '',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                              "₹${item.stock.lastPrice?.toStringAsFixed(2) ?? '0.00'}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close,
                                color: Colors.white38, size: 18),
                            onPressed: () => _removeStock(index),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.signalColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item.signal,
                            style: TextStyle(
                                color: item.signalColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat("Yest Avg Vol",
                      item.yesterdayAvgVolume.toStringAsFixed(0)),
                  _buildStat(
                      "Today Avg Vol", item.todayAvgVolume.toStringAsFixed(0)),
                  _buildStat(
                      "Vol %", "${item.volumePercent.toStringAsFixed(1)}%",
                      color: item.signalColor),
                ],
              ),
              if (item.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(item.error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 10)),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: color ?? Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1e222d),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _SearchStockWidget(
          onStockSelected: (s) {
            _addStock(s.symbol!, s.token!, s.name ?? '');
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _SearchStockWidget extends StatefulWidget {
  final Function(StockModel) onStockSelected;
  const _SearchStockWidget({required this.onStockSelected});

  @override
  State<_SearchStockWidget> createState() => _SearchStockWidgetState();
}

class _SearchStockWidgetState extends State<_SearchStockWidget> {
  final TextEditingController _controller = TextEditingController();
  List<StockModel> _results = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search stock symbol...",
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onChanged: _performSearch,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final s = _results[index];
              return ListTile(
                title: Text(s.symbol ?? '',
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(s.name ?? '',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () => widget.onStockSelected(s),
              );
            },
          ),
        ),
      ],
    );
  }

  void _performSearch(String query) {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    final results = DataManager.instance.stocksList
        .where((s) {
          return (s.symbol?.toLowerCase().contains(query.toLowerCase()) ??
                  false) ||
              (s.name?.toLowerCase().contains(query.toLowerCase()) ?? false);
        })
        .take(20)
        .toList();
    setState(() => _results = results);
  }
}

class IntradaySettingsScreen extends StatefulWidget {
  final bool initialMode;
  final DateTime initialDate;
  final TimeOfDay initialTime;

  const IntradaySettingsScreen({
    super.key,
    required this.initialMode,
    required this.initialDate,
    required this.initialTime,
  });

  @override
  State<IntradaySettingsScreen> createState() => _IntradaySettingsScreenState();
}

class _IntradaySettingsScreenState extends State<IntradaySettingsScreen> {
  late bool isHistoryMode;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    isHistoryMode = widget.initialMode;
    _selectedDate = widget.initialDate;
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff131722),
      appBar: AppBar(
        title: const Text("Scanner Settings"),
        backgroundColor: const Color(0xff131722),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'isHistoryMode': isHistoryMode,
                'selectedDate': _selectedDate,
                'selectedTime': _selectedTime,
              });
            },
            child: const Text("DONE",
                style: TextStyle(
                    color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader("SCAN MODE"),
          _buildModeTile(),
          if (isHistoryMode) ...[
            const SizedBox(height: 24),
            _buildSectionHeader("HISTORY PARAMETERS"),
            _buildHistoryControls(),
          ],
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Note: Live mode refreshes every 10 seconds. History mode fetches data once for the selected timestamp.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12),
      child: Text(title,
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }

  Widget _buildModeTile() {
    return Card(
      color: const Color(0xff1e222d),
      child: ListTile(
        title: Text(isHistoryMode ? "History Analysis" : "Live Streaming",
            style: const TextStyle(color: Colors.white)),
        subtitle: Text(
            isHistoryMode
                ? "Check volume data for a specific past date/time"
                : "Monitor latest market volume continuously",
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Switch(
          value: isHistoryMode,
          activeColor: Colors.orangeAccent,
          onChanged: (val) => setState(() => isHistoryMode = val),
        ),
      ),
    );
  }

  Widget _buildHistoryControls() {
    return Card(
      color: const Color(0xff1e222d),
      child: Column(
        children: [
          ListTile(
            leading:
                const Icon(Icons.calendar_today, color: Colors.orangeAccent),
            title: const Text("Select Date",
                style: TextStyle(color: Colors.white)),
            trailing: Text(DateFormat('dd MMM yyyy').format(_selectedDate),
                style: const TextStyle(color: Colors.white70)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.access_time, color: Colors.orangeAccent),
            title: const Text("Select Time",
                style: TextStyle(color: Colors.white)),
            trailing: Text(_selectedTime.format(context),
                style: const TextStyle(color: Colors.white70)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (picked != null) setState(() => _selectedTime = picked);
            },
          ),
        ],
      ),
    );
  }
}
