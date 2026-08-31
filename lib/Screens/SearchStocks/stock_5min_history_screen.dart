import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/check_stock_5min_history_model.dart';

class Stock5MinHistoryScreen extends StatefulWidget {
  final String? initialSymbol;
  final String? initialDate;

  const Stock5MinHistoryScreen({
    super.key,
    this.initialSymbol,
    this.initialDate,
  });

  @override
  State<Stock5MinHistoryScreen> createState() => _Stock5MinHistoryScreenState();
}

class _Stock5MinHistoryScreenState extends State<Stock5MinHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _symbolController;
  late DateTime _selectedDate;
  bool _isLoading = false;
  CheckStock5MinHistoryResponse? _apiResponse;
  String _candleFilter = "ALL"; // ALL, PASSED, FAILED
  final TextEditingController _candleSearchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(
      text: widget.initialSymbol?.toUpperCase() ?? "RELIANCE",
    );

    if (widget.initialDate != null && widget.initialDate!.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(widget.initialDate!);
      } catch (_) {
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
    }

    _tabController = TabController(length: 2, vsync: this);
    _fetchHistory();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _candleSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final symbol = _symbolController.text.trim().toUpperCase();
    if (symbol.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a stock symbol')),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() {
      _isLoading = true;
    });

    final response = await BackendOrderService.checkStock5MinHistory(symbol, dateStr);

    if (mounted) {
      setState(() {
        _apiResponse = response;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _apiResponse?.data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('5-Min Stock History Check'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndDateHeader(),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Evaluating 5-minute candles & daily context...'),
                  ],
                ),
              ),
            )
          else if (_apiResponse == null)
            const Expanded(
              child: Center(
                child: Text('Enter symbol and date to check stock 5-minute timeframe.'),
              ),
            )
          else if (!_apiResponse!.success && data == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _apiResponse!.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Builder(
                builder: (context) {
                  final historyData = data!;
                  return NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: _buildOverallSummaryCard(historyData),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverTabBarDelegate(
                            TabBar(
                              controller: _tabController,
                              labelColor: Theme.of(context).colorScheme.primary,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Theme.of(context).colorScheme.primary,
                              tabs: [
                                Tab(
                                  icon: const Icon(Icons.candlestick_chart),
                                  text: '5-Min Candles (${historyData.total5MinCandles})',
                                ),
                                Tab(
                                  icon: const Icon(Icons.calendar_today),
                                  text: 'Daily Context',
                                ),
                              ],
                            ),
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _build5MinCandlesTab(historyData),
                        _buildDailyTimeframeTab(historyData),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndDateHeader() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _symbolController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Stock Symbol',
                    hintText: 'e.g. RELIANCE',
                    prefixIcon: const Icon(Icons.show_chart),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => _fetchHistory(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade600),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _fetchHistory,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Fetch'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallSummaryCard(Stock5MinHistoryData data) {
    final isPassed = data.overallPassed;
    final statusColor = isPassed ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            isPassed ? Icons.check_circle : Icons.cancel,
            color: statusColor,
          ),
        ),
        title: Row(
          children: [
            Text(
              data.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                isPassed ? "OVERALL PASSED" : "OVERALL FAILED",
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          "Date: ${data.targetDate}${data.previousTradingDate != null ? ' (Prev: ${data.previousTradingDate})' : ''} | Token: ${data.token ?? 'N/A'}",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatChip("Total 5-Min Candles", "${data.total5MinCandles}", Colors.blue),
                    _buildStatChip("Passed", "${data.passed5MinCandlesCount}", Colors.green),
                    _buildStatChip("Failed", "${data.failed5MinCandlesCount}", Colors.red),
                  ],
                ),
                if (data.prevDayAvg5MinVolume != null && data.prevDayAvg5MinVolume! > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bar_chart, size: 16, color: Colors.tealAccent),
                      const SizedBox(width: 6),
                      Text(
                        "Prev Day Avg 5-Min Vol: ${data.prevDayAvg5MinVolume?.toStringAsFixed(1)}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.tealAccent),
                      ),
                    ],
                  ),
                ],
                if (data.overallFailureReasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "Evaluation Reasons Summary:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orangeAccent),
                  ),
                  const SizedBox(height: 6),
                  ...data.overallFailureReasons.map((reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                reason,
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                if (_apiResponse?.message != null && _apiResponse!.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _apiResponse!.message,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _build5MinCandlesTab(Stock5MinHistoryData data) {
    final filteredCandles = data.fiveMinCandles.where((c) {
      if (_candleFilter == "PASSED") return c.passed;
      if (_candleFilter == "FAILED") return !c.passed;
      return true;
    }).where((c) {
      final query = _candleSearchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      final timeStr = (c.timeIst ?? c.time ?? '').toLowerCase();
      final reasonsStr = c.failureReasons.join(' ').toLowerCase();
      final alignmentStr = (c.emaAlignment ?? '').toLowerCase();
      final signalStr = (c.supertrendSignal ?? '').toLowerCase();
      return timeStr.contains(query) || reasonsStr.contains(query) || alignmentStr.contains(query) || signalStr.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text("All (${data.total5MinCandles})"),
                  selected: _candleFilter == "ALL",
                  onSelected: (val) => setState(() => _candleFilter = "ALL"),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: Text("Passed (${data.passed5MinCandlesCount})"),
                  selected: _candleFilter == "PASSED",
                  selectedColor: Colors.green.withValues(alpha: 0.3),
                  onSelected: (val) => setState(() => _candleFilter = "PASSED"),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: Text("Failed (${data.failed5MinCandlesCount})"),
                  selected: _candleFilter == "FAILED",
                  selectedColor: Colors.red.withValues(alpha: 0.3),
                  onSelected: (val) => setState(() => _candleFilter = "FAILED"),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _candleSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search time/reason',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filteredCandles.isEmpty
              ? const Center(child: Text("No candles match selected filter"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: filteredCandles.length,
                  itemBuilder: (context, index) {
                    final candle = filteredCandles[index];
                    return _build5MinCandleCard(candle, index + 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _build5MinCandleCard(FiveMinCandleItem candle, int index) {
    final statusColor = candle.passed ? Colors.green : Colors.red;

    String displayTime = candle.timeIst ?? candle.time ?? '';
    if (displayTime.contains('T')) {
      displayTime = displayTime.split('T').last.replaceAll('Z', '');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            candle.passed ? "PASSED" : "FAILED",
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayTime,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              "Close: ₹${candle.close?.toStringAsFixed(2) ?? 'N/A'}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: candle.close != null && candle.open != null
                    ? (candle.close! >= candle.open! ? Colors.greenAccent : Colors.redAccent)
                    : Colors.white,
              ),
            ),
          ],
        ),
        subtitle: Text(
          "O: ${candle.open?.toStringAsFixed(1)} | H: ${candle.high?.toStringAsFixed(1)} | L: ${candle.low?.toStringAsFixed(1)} | Vol: ${candle.volume?.toStringAsFixed(0)}${candle.volumeMultiplierVsPrevDayAvg != null ? ' (${candle.volumeMultiplierVsPrevDayAvg?.toStringAsFixed(1)}x)' : ''}",
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Technical Indicators & Context:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildIndicatorBadge("EMA 20", candle.ema20?.toStringAsFixed(2)),
                    if (candle.ema50 != null) _buildIndicatorBadge("EMA 50", candle.ema50?.toStringAsFixed(2)),
                    if (candle.ema200 != null) _buildIndicatorBadge("EMA 200", candle.ema200?.toStringAsFixed(2)),
                    if (candle.emaAlignment != null)
                      _buildStatusBadge("EMA Align", candle.emaAlignment!, candle.emaAlignment == "BULLISH_STACK" ? Colors.green : Colors.orange),
                    _buildIndicatorBadge("Supertrend", candle.supertrend?.toStringAsFixed(2)),
                    if (candle.supertrendSignal != null)
                      _buildStatusBadge("Supertrend Signal", candle.supertrendSignal!, candle.supertrendSignal == "BULLISH" ? Colors.green : Colors.red),
                    _buildIndicatorBadge("RSI", candle.rsi?.toStringAsFixed(1)),
                    if (candle.rsiState != null) _buildIndicatorBadge("RSI State", candle.rsiState),
                    _buildIndicatorBadge("VWAP", candle.vwap?.toStringAsFixed(2)),
                    if (candle.priceVsVwap != null)
                      _buildStatusBadge("Price vs VWAP", candle.priceVsVwap!, candle.priceVsVwap == "ABOVE" ? Colors.green : Colors.red),
                    _buildIndicatorBadge("ATR", candle.atr?.toStringAsFixed(2)),
                    _buildIndicatorBadge("ADX", candle.adx?.toStringAsFixed(1)),
                    _buildIndicatorBadge("+DI", candle.plusDI?.toStringAsFixed(1)),
                    _buildIndicatorBadge("-DI", candle.minusDI?.toStringAsFixed(1)),
                    if (candle.avgVolume20 != null) _buildIndicatorBadge("Avg Vol 20", candle.avgVolume20?.toStringAsFixed(0)),
                    if (candle.prevDayAvg5MinVolume != null) _buildIndicatorBadge("Prev Day Avg 5m Vol", candle.prevDayAvg5MinVolume?.toStringAsFixed(0)),
                    if (candle.volumeMultiplierVsPrevDayAvg != null)
                      _buildIndicatorBadge("Vol Multiplier", "${candle.volumeMultiplierVsPrevDayAvg?.toStringAsFixed(1)}x"),
                    if (candle.isVolume4xPlus != null)
                      _buildStatusBadge("Vol 4x+", candle.isVolume4xPlus! ? "YES" : "NO", candle.isVolume4xPlus! ? Colors.green : Colors.grey),
                  ],
                ),
                if (candle.failureReasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    "Candle Evaluation Reasons:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orangeAccent),
                  ),
                  const SizedBox(height: 4),
                  ...candle.failureReasons.map((reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(candle.passed ? Icons.check : Icons.close, color: candle.passed ? Colors.green : Colors.red, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(fontSize: 11, color: candle.passed ? Colors.greenAccent : Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                if (candle.checks != null && candle.checks!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    "Individual Check Breakdown:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amberAccent),
                  ),
                  const SizedBox(height: 6),
                  _buildChecksBreakdown(candle.checks!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorBadge(String label, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        "$label: ${value ?? 'N/A'}",
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildStatusBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        "$label: $value",
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildChecksBreakdown(Map<String, dynamic> checks) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: checks.entries.map((entry) {
          final checkName = entry.key;
          final checkData = entry.value;

          bool? isPassed;
          String details = "";

          if (checkData is Map) {
            isPassed = checkData['passed'] == true;
            final mapCopy = Map<String, dynamic>.from(checkData)..remove('passed');
            if (mapCopy.isNotEmpty) {
              details = mapCopy.entries.map((e) => "${e.key}: ${e.value}").join(", ");
            }
          } else if (checkData is bool) {
            isPassed = checkData;
          }

          final iconColor = isPassed == true
              ? Colors.green
              : (isPassed == false ? Colors.red : Colors.grey);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Icon(
                  isPassed == true ? Icons.check_circle_outline : Icons.highlight_off,
                  color: iconColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  checkName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: isPassed == true ? Colors.white : Colors.white70,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "($details)",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyTimeframeTab(Stock5MinHistoryData data) {
    final daily = data.dailyContext;
    final dailyCandles = data.dailyCandles;

    if (daily == null && dailyCandles.isEmpty) {
      return const Center(child: Text("No daily context data available."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (daily != null) ...[
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: (daily.dailyPassedFilter ? Colors.green : Colors.red).withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Daily Context Evaluation",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (daily.dailyPassedFilter ? Colors.green : Colors.red).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: daily.dailyPassedFilter ? Colors.green : Colors.red),
                          ),
                          child: Text(
                            daily.dailyPassedFilter ? "PASSED" : "FAILED",
                            style: TextStyle(
                              color: daily.dailyPassedFilter ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildMetricRow("Stock Price / Latest Close", "₹${daily.stockPrice?.toStringAsFixed(2) ?? daily.latestDailyClose?.toStringAsFixed(2) ?? 'N/A'}"),
                    if (daily.previousDayDate != null)
                      _buildMetricRow("Previous Day Date", daily.previousDayDate!),
                    if (daily.previousDayClose != null)
                      _buildMetricRow("Previous Day Close", "₹${daily.previousDayClose?.toStringAsFixed(2)}"),
                    if (daily.previousDayVolume != null)
                      _buildMetricRow("Previous Day Volume", daily.previousDayVolume?.toStringAsFixed(0) ?? 'N/A'),
                    _buildMetricRow("Daily 20 EMA", "₹${daily.dailyEma20?.toStringAsFixed(2) ?? 'N/A'}"),
                    _buildMetricRow("Daily 50 EMA", "₹${daily.dailyEma50?.toStringAsFixed(2) ?? 'N/A'}"),
                    _buildMetricRow("Daily 200 EMA", "₹${daily.dailyEma200?.toStringAsFixed(2) ?? 'N/A'}"),
                    _buildMetricRow("Daily Supertrend", "₹${daily.dailySupertrend?.toStringAsFixed(2) ?? daily.previousDailySupertrend?.toStringAsFixed(2) ?? 'N/A'}"),
                    _buildMetricRow("Nearest Resistance", "₹${daily.nearestResistancePrice?.toStringAsFixed(2) ?? 'N/A'} (${daily.nearestResistanceTouches ?? 0} touches, ${daily.distanceToResistancePercent?.toStringAsFixed(2) ?? 0}%)"),
                    if (daily.topResistances.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "Top Resistances:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orangeAccent),
                      ),
                      const SizedBox(height: 4),
                      ...daily.topResistances.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              "• Price: ₹${r.price.toStringAsFixed(2)} | Touches: ${r.touches}${r.strengthScore != null ? ' | Strength: ${(r.strengthScore! * 100).toStringAsFixed(0)}%' : ''}",
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          )),
                    ],
                    if (daily.topSupports.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "Top Supports:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.greenAccent),
                      ),
                      const SizedBox(height: 4),
                      ...daily.topSupports.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              "• Price: ₹${s.price.toStringAsFixed(2)} | Touches: ${s.touches}${s.strengthScore != null ? ' | Strength: ${(s.strengthScore! * 100).toStringAsFixed(0)}%' : ''}",
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          )),
                    ],
                    if (daily.dailyReasons.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "Daily Evaluation Reasons:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.cyanAccent),
                      ),
                      const SizedBox(height: 6),
                      ...daily.dailyReasons.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.arrow_right, size: 18, color: Colors.cyanAccent),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (dailyCandles.isNotEmpty) ...[
            const Text(
              "Daily Candles History",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Date/Time')),
                  DataColumn(label: Text('Open')),
                  DataColumn(label: Text('High')),
                  DataColumn(label: Text('Low')),
                  DataColumn(label: Text('Close')),
                  DataColumn(label: Text('Volume')),
                  DataColumn(label: Text('EMA 20')),
                  DataColumn(label: Text('Supertrend')),
                ],
                rows: dailyCandles.map((c) {
                  return DataRow(cells: [
                    DataCell(Text(c.time?.split('T').first ?? '')),
                    DataCell(Text(c.open?.toStringAsFixed(1) ?? '')),
                    DataCell(Text(c.high?.toStringAsFixed(1) ?? '')),
                    DataCell(Text(c.low?.toStringAsFixed(1) ?? '')),
                    DataCell(Text(
                      c.close?.toStringAsFixed(1) ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: c.close != null && c.open != null
                            ? (c.close! >= c.open! ? Colors.greenAccent : Colors.redAccent)
                            : Colors.white,
                      ),
                    )),
                    DataCell(Text(c.volume?.toStringAsFixed(0) ?? '')),
                    DataCell(Text(c.ema20?.toStringAsFixed(1) ?? '')),
                    DataCell(Text(c.supertrend?.toStringAsFixed(1) ?? '')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this._tabBar, {required this.backgroundColor});

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
