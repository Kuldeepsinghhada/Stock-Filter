import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/investment_model.dart';
import 'package:stock_demo/Widgets/app_drawer.dart';

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
  late DateTime startDate;
  late DateTime endDate;
  bool isForce = false;

  bool isLoading = false;
  String? errorMessage;
  InvestmentData? responseData;
  String apiMessage = '';

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String selectedFilterType = 'ALL'; // ALL, WIN, LOSS, TIME_EXPIRED, ACTIVE
  String sortBy = 'DATE'; // DATE, PNL, ACCURACY, SYMBOL, VOLUME_MULT

  @override
  void initState() {
    super.initState();
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      try {
        startDate = DateTime.parse(widget.initialStartDate!);
        endDate = DateTime.parse(widget.initialEndDate!);
      } catch (_) {
        startDate = DateTime(2026, 5, 1);
        endDate = DateTime(2026, 9, 3);
      }
    } else {
      // Default initial range: 2026-05-01 to 2026-09-03 (01/05/2026 to 03/09/2026)
      startDate = DateTime(2026, 5, 1);
      endDate = DateTime(2026, 9, 3);
    }
    _fetchInvestmentRecommendations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatDateDDMMYYYY(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Future<void> _fetchInvestmentRecommendations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final formattedStartDate = _formatDateDDMMYYYY(startDate);
    final formattedEndDate = _formatDateDDMMYYYY(endDate);

    final response = await BackendOrderService.fetchInvestmentRecommendations(
      startDate: formattedStartDate,
      endDate: formattedEndDate,
      force: isForce,
    );

    if (!mounted) return;

    if (response != null && response.success) {
      setState(() {
        responseData = response.data;
        apiMessage = response.message;
        isLoading = false;
      });
    } else {
      setState(() {
        responseData = null;
        apiMessage = response?.message ?? "Failed to load daily backtest data";
        errorMessage =
            response?.message ?? "Failed to connect to backend service.";
        isLoading = false;
      });
    }
  }

  List<InvestmentRecommendation> get _filteredRecommendations {
    if (responseData == null) return [];
    var recs = List<InvestmentRecommendation>.from(
      responseData!.recommendations,
    );

    // Filter by status or winLoss
    if (selectedFilterType == 'WIN' || selectedFilterType == 'TARGET_HIT') {
      recs = recs
          .where(
            (r) =>
                r.status.toUpperCase() == 'TARGET_HIT' ||
                (r.winLoss != null && r.winLoss!.toUpperCase() == 'WIN'),
          )
          .toList();
    } else if (selectedFilterType == 'LOSS' ||
        selectedFilterType == 'STOP_LOSS_HIT') {
      recs = recs
          .where(
            (r) =>
                r.status.toUpperCase() == 'STOP_LOSS_HIT' ||
                (r.winLoss != null && r.winLoss!.toUpperCase() == 'LOSS'),
          )
          .toList();
    } else if (selectedFilterType == 'OPEN') {
      recs = recs
          .where(
            (r) =>
                r.status.toUpperCase() == 'OPEN' ||
                (r.winLoss != null && r.winLoss!.toUpperCase() == 'OPEN') ||
                (r.exitReason != null && r.exitReason!.toUpperCase() == 'OPEN'),
          )
          .toList();
    } else if (selectedFilterType == 'SQUARE_OFF') {
      recs = recs
          .where(
            (r) =>
                r.status.toUpperCase() == 'SQUARE_OFF' ||
                (r.winLoss != null &&
                    r.winLoss!.toUpperCase() == 'SQUARE_OFF') ||
                (r.exitReason != null &&
                    r.exitReason!.toUpperCase() == 'SQUARE_OFF'),
          )
          .toList();
    } else if (selectedFilterType == 'TIME_EXPIRED') {
      recs = recs
          .where(
            (r) =>
                r.status.toUpperCase().contains('TIME_EXPIRED') ||
                (r.exitReason != null &&
                    r.exitReason!.toUpperCase().contains('TIME_EXPIRED')),
          )
          .toList();
    } else if (selectedFilterType == 'ACTIVE') {
      recs = recs.where((r) => r.status.toUpperCase() == 'ACTIVE').toList();
    }

    // Filter by search query
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      recs = recs.where((rec) {
        final symbolMatch =
            rec.symbol.toLowerCase().contains(q) ||
            (rec.stockName != null && rec.stockName!.toLowerCase().contains(q));
        final gradeMatch =
            rec.setupGrade != null && rec.setupGrade!.toLowerCase().contains(q);
        final patternMatch =
            rec.patterns != null && rec.patterns!.toLowerCase().contains(q);
        final statusMatch =
            rec.status.toLowerCase().contains(q) ||
            (rec.winLoss != null && rec.winLoss!.toLowerCase().contains(q)) ||
            (rec.exitReason != null &&
                rec.exitReason!.toLowerCase().contains(q));
        final dateMatch = (rec.date ?? rec.entryDate ?? rec.createdAt)
            .toLowerCase()
            .contains(q);
        final reasonMatch = rec.reasons.any((r) => r.toLowerCase().contains(q));
        return symbolMatch ||
            gradeMatch ||
            patternMatch ||
            statusMatch ||
            dateMatch ||
            reasonMatch;
      }).toList();
    }

    // Sort recommendations
    if (sortBy == 'ACCURACY') {
      recs.sort(
        (a, b) =>
            (b.winLoss == 'WIN' ? 1 : 0).compareTo(a.winLoss == 'WIN' ? 1 : 0),
      );
    } else if (sortBy == 'DATE') {
      recs.sort((a, b) {
        final dateA = a.entryDate ?? a.date ?? a.createdAt;
        final dateB = b.entryDate ?? b.date ?? b.createdAt;
        return dateB.compareTo(dateA);
      });
    } else if (sortBy == 'SYMBOL') {
      recs.sort((a, b) => a.symbol.compareTo(b.symbol));
    } else if (sortBy == 'PNL') {
      recs.sort(
        (a, b) => (b.realizedPnlPercent ?? 0.0).compareTo(
          a.realizedPnlPercent ?? 0.0,
        ),
      );
    } else if (sortBy == 'VOLUME_MULT') {
      recs.sort(
        (a, b) =>
            (b.volumeMultiplier ?? 0.0).compareTo(a.volumeMultiplier ?? 0.0),
      );
    }

    return recs;
  }

  void _copyAllSymbols() {
    final recs = _filteredRecommendations;
    if (recs.isEmpty) {
      Fluttertoast.showToast(msg: "No symbols to copy");
      return;
    }
    final symbols = recs.map((s) => s.symbol).join(', ');
    Clipboard.setData(ClipboardData(text: symbols));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${recs.length} symbol(s) to clipboard'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E222D),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _fetchInvestmentRecommendations();
    }
  }

  void _setPresetRange(DateTime start, DateTime end) {
    setState(() {
      startDate = start;
      endDate = end;
    });
    _fetchInvestmentRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecommendations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment (Daily Backtest)'),
        backgroundColor: const Color(0xFF1E222D),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Symbols',
            onPressed: _copyAllSymbols,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchInvestmentRecommendations,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchInvestmentRecommendations,
        child: Column(
          children: [
            _buildDateRangeControls(),
            _buildStrategySummaryBanner(),
            _buildSearchAndFilterBar(),
            if (isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.cyanAccent),
                      SizedBox(height: 16),
                      Text(
                        'Fetching Daily Backtest recommendations...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              )
            else if (errorMessage != null && responseData == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchInvestmentRecommendations,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(
                              alpha: 0.2,
                            ),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 60,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No backtest trades for ${_formatDateDDMMYYYY(startDate)} to ${_formatDateDDMMYYYY(endDate)}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                        ),
                      ),
                      if (searchQuery.isNotEmpty ||
                          selectedFilterType != 'ALL') ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              searchQuery = '';
                              selectedFilterType = 'ALL';
                            });
                          },
                          child: const Text('Reset Filters'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _CardItemWidget(
                      rec: filtered[index],
                      onPlaceOrder: _placeOrderDialog,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeControls() {
    final startDDMM = _formatDateDDMMYYYY(startDate);
    final endDDMM = _formatDateDDMMYYYY(endDate);
    final isDefaultRange = startDDMM == "01/05/2026" && endDDMM == "03/09/2026";

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: const Color(0xFF181B22),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDateRange(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDefaultRange
                            ? Colors.cyanAccent
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.date_range,
                          size: 16,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$startDDMM  →  $endDDMM',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(
                  color: isForce
                      ? Colors.orange.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isForce ? Colors.orangeAccent : Colors.white24,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      isForce = !isForce;
                    });
                    _fetchInvestmentRecommendations();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt,
                          size: 14,
                          color: isForce ? Colors.orangeAccent : Colors.grey,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Force',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isForce ? Colors.orangeAccent : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: isForce,
                            onChanged: (val) {
                              setState(() {
                                isForce = val;
                              });
                              _fetchInvestmentRecommendations();
                            },
                            activeColor: Colors.orangeAccent,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  label: 'Default Range (01/05/2026 to 03/09/2026)',
                  isSelected: isDefaultRange,
                  onTap: () => _setPresetRange(
                    DateTime(2026, 5, 1),
                    DateTime(2026, 9, 3),
                  ),
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Today',
                  isSelected:
                      startDDMM == _formatDateDDMMYYYY(DateTime.now()) &&
                      endDDMM == _formatDateDDMMYYYY(DateTime.now()),
                  onTap: () {
                    final now = DateTime.now();
                    _setPresetRange(now, now);
                  },
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Last 7 Days',
                  isSelected: false,
                  onTap: () {
                    final now = DateTime.now();
                    _setPresetRange(now.subtract(const Duration(days: 7)), now);
                  },
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Last 30 Days',
                  isSelected: false,
                  onTap: () {
                    final now = DateTime.now();
                    _setPresetRange(
                      now.subtract(const Duration(days: 30)),
                      now,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.2)
              : Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.cyanAccent : Colors.grey[300],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategySummaryBanner() {
    if (responseData == null && apiMessage.isEmpty)
      return const SizedBox.shrink();

    final strategyName =
        responseData?.strategyVersion ??
        responseData?.strategy ??
        "Pure Daily EOD Backtest";

    final summary = responseData?.summary;
    final recs = responseData?.recommendations ?? [];

    final totalTrades =
        summary?.totalTrades ?? responseData?.count ?? recs.length;
    final wins =
        summary?.wins ??
        responseData?.targetHitCount ??
        recs
            .where(
              (r) =>
                  r.winLoss == 'WIN' || r.status.toUpperCase() == 'TARGET_HIT',
            )
            .length;
    final losses =
        summary?.losses ??
        recs
            .where(
              (r) =>
                  r.winLoss == 'LOSS' ||
                  r.status.toUpperCase() == 'STOP_LOSS_HIT',
            )
            .length;
    final openTrades =
        summary?.open ??
        recs
            .where(
              (r) =>
                  r.winLoss == 'OPEN' ||
                  r.status.toUpperCase() == 'OPEN' ||
                  r.exitReason?.toUpperCase() == 'OPEN',
            )
            .length;

    final accuracyStr =
        summary?.accuracy ??
        (responseData?.accuracyPercent != null
            ? "${responseData!.accuracyPercent!.toStringAsFixed(2)}%"
            : totalTrades > 0
            ? "${((wins / totalTrades) * 100).toStringAsFixed(2)}%"
            : "0%");

    final totalPnlStr =
        summary?.totalPnlPercent ??
        (responseData?.totalProfit != null
            ? "${responseData!.totalProfit! >= 0 ? '+' : ''}${responseData!.totalProfit!.toStringAsFixed(2)}%"
            : "0%");

    final isPnlPositive = !totalPnlStr.startsWith('-');
    final profitColor = isPnlPositive ? Colors.greenAccent : Colors.redAccent;

    final isCached = responseData?.fromCache == true;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade900.withValues(alpha: 0.8),
            Colors.blue.shade900.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  strategyName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCached)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 11, color: Colors.amberAccent),
                      SizedBox(width: 2),
                      Text(
                        'Cache',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Total Trades',
                  value: '$totalTrades',
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Wins',
                  value: '$wins',
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Losses',
                  value: '$losses',
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Open',
                  value: '$openTrades',
                  color: Colors.lightBlueAccent,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Accuracy',
                  value: accuracyStr,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Total PnL',
                  value: totalPnlStr,
                  color: profitColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 8.5, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                searchQuery = val;
              });
            },
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search symbol, grade, pattern, status...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              prefixIcon: const Icon(
                Icons.search,
                size: 16,
                color: Colors.cyanAccent,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              filled: true,
              fillColor: const Color(0xFF1E222D),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All'),
                      const SizedBox(width: 4),
                      _buildFilterChip('WIN', 'Wins'),
                      const SizedBox(width: 4),
                      _buildFilterChip('LOSS', 'Losses'),
                      const SizedBox(width: 4),
                      _buildFilterChip('OPEN', 'Open'),
                      const SizedBox(width: 4),
                      _buildFilterChip('SQUARE_OFF', 'Square Off'),
                      const SizedBox(width: 4),
                      _buildFilterChip('TIME_EXPIRED', 'Time Expired'),
                      const SizedBox(width: 4),
                      _buildFilterChip('ACTIVE', 'Active'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                initialValue: sortBy,
                onSelected: (val) {
                  setState(() {
                    sortBy = val;
                  });
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'DATE',
                    child: Text('Sort by Trade Date'),
                  ),
                  PopupMenuItem(
                    value: 'PNL',
                    child: Text('Sort by Realized PnL'),
                  ),
                  PopupMenuItem(
                    value: 'ACCURACY',
                    child: Text('Sort by Win / Loss'),
                  ),
                  PopupMenuItem(value: 'SYMBOL', child: Text('Sort by Symbol')),
                  PopupMenuItem(
                    value: 'VOLUME_MULT',
                    child: Text('Sort by Vol Multiplier'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sort,
                        size: 13,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        sortBy,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = selectedFilterType == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.cyanAccent,
      backgroundColor: const Color(0xFF1E222D),
      showCheckmark: false,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (val) {
        if (val) {
          setState(() {
            selectedFilterType = filterKey;
          });
        }
      },
    );
  }

  void _placeOrderDialog(InvestmentRecommendation rec) {
    final qtyController = TextEditingController(text: '1');
    const transactionType = 'BUY';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Place BUY Order for ${rec.symbol}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                title: const Text('Entry Price'),
                trailing: Text('₹${rec.entryPrice.toStringAsFixed(2)}'),
              ),
              ListTile(
                dense: true,
                title: const Text('Stop Loss'),
                trailing: Text('₹${rec.stopLossPrice.toStringAsFixed(2)}'),
              ),
              ListTile(
                dense: true,
                title: const Text('Target'),
                trailing: Text('₹${rec.targetPrice.toStringAsFixed(2)}'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyController.text) ?? 1;
                Navigator.pop(ctx);
                await BackendOrderService.placeStockOrder(
                  symbol: rec.symbol,
                  exchange: 'NSE',
                  transactionType: transactionType,
                  quantity: qty,
                  product: 'MIS',
                  buyingPrice: rec.entryPrice,
                  stopLoss: rec.stopLossPrice,
                  target: rec.targetPrice,
                );
              },
              child: const Text('Confirm Order'),
            ),
          ],
        );
      },
    );
  }
}

class _CardItemWidget extends StatefulWidget {
  final InvestmentRecommendation rec;
  final Function(InvestmentRecommendation) onPlaceOrder;

  const _CardItemWidget({required this.rec, required this.onPlaceOrder});

  @override
  State<_CardItemWidget> createState() => _CardItemWidgetState();
}

class _CardItemWidgetState extends State<_CardItemWidget> {
  bool isExpanded = false;

  String _formatDateShort(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.rec;
    final bool isWin =
        rec.winLoss == 'WIN' || rec.status.toUpperCase() == 'TARGET_HIT';
    final bool isLoss =
        rec.winLoss == 'LOSS' || rec.status.toUpperCase() == 'STOP_LOSS_HIT';
    final bool isOpen =
        rec.winLoss == 'OPEN' || rec.status.toUpperCase() == 'OPEN';
    final bool isSqOff =
        rec.winLoss == 'SQUARE_OFF' || rec.status.toUpperCase() == 'SQUARE_OFF';

    final Color mainBorderColor = isWin
        ? Colors.greenAccent
        : isLoss
        ? Colors.redAccent
        : isOpen
        ? Colors.blueAccent
        : isSqOff
        ? Colors.orangeAccent
        : Colors.cyanAccent;

    final createdDateStr = _formatDateShort(
      rec.tradeDate ?? rec.entryDate ?? rec.date ?? rec.createdAt,
    );
    final exitDateStr = _formatDateShort(rec.exitTime ?? rec.exitDate);

    final statusWidget = _buildStatusBadge(rec);
    final pnlWidget = _buildPnlBadge(rec);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mainBorderColor.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            isExpanded = !isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER: Symbol + Grade + Pattern & Status/PnL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          rec.symbol,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (rec.setupGrade != null &&
                            rec.setupGrade!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.purpleAccent.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Text(
                              rec.setupGrade!.replaceAll('_', ' '),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.purpleAccent,
                              ),
                            ),
                          ),
                        if (rec.patterns != null && rec.patterns!.isNotEmpty)
                          Text(
                            rec.patterns!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      statusWidget,
                      if (pnlWidget != null) ...[
                        const SizedBox(width: 4),
                        pnlWidget,
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // 2. COMPACT PRICE GRID (Full Width - 100% Symmetrical!)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF14171F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactPriceCell(
                            'Entry',
                            '₹${rec.entryPrice.toStringAsFixed(2)}',
                            null,
                            Colors.white,
                          ),
                        ),
                        Expanded(
                          child: _buildCompactPriceCell(
                            rec.exitPrice != null ? 'Exit' : 'Status',
                            rec.exitPrice != null
                                ? '₹${rec.exitPrice!.toStringAsFixed(2)}'
                                : rec.status.replaceAll('_', ' '),
                            null,
                            rec.exitPrice != null
                                ? Colors.cyanAccent
                                : Colors.amberAccent,
                          ),
                        ),
                        Expanded(
                          child: _buildCompactPriceCell(
                            'Target',
                            '₹${rec.targetPrice.toStringAsFixed(2)}',
                            '+${rec.targetPercent.toStringAsFixed(1)}%',
                            Colors.greenAccent,
                          ),
                        ),
                        Expanded(
                          child: _buildCompactPriceCell(
                            'Stop Loss',
                            '₹${rec.stopLossPrice.toStringAsFixed(2)}',
                            '-${rec.stopLossPercent.toStringAsFixed(1)}%',
                            Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    if (rec.supportPrice != null) ...[
                      const SizedBox(height: 4),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Support Price',
                            style: TextStyle(fontSize: 9.5, color: Colors.grey),
                          ),
                          Text(
                            '₹${rec.supportPrice!.toStringAsFixed(2)} ${rec.supportDistPct != null ? "(${rec.supportDistPct!.toStringAsFixed(2)}% dist)" : ""}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // 3. COMPACT FOOTER META LINE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'R:R ${rec.riskRewardRatio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (rec.volumeMultiplier != null) ...[
                        const Text(
                          '  •  ',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          'Vol ${rec.volumeMultiplier!.toStringAsFixed(2)}x',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (createdDateStr.isNotEmpty || exitDateStr.isNotEmpty)
                    Text(
                      exitDateStr.isNotEmpty && exitDateStr != createdDateStr
                          ? '$createdDateStr → $exitDateStr'
                          : createdDateStr,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),

              // 4. EXPANDABLE DETAILS SECTION
              if (isExpanded) ...[
                const Divider(color: Colors.white12, height: 12),
                if (rec.reasons.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recommendation Reasons:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...rec.reasons.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 13,
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              r,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _buildTradeMetricsSection(rec),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rec.symbol));
                        Fluttertoast.showToast(msg: "Copied ${rec.symbol}");
                      },
                      icon: const Icon(Icons.copy, size: 12),
                      label: const Text(
                        'Copy Symbol',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => widget.onPlaceOrder(rec),
                      icon: const Icon(Icons.shopping_cart_checkout, size: 12),
                      label: const Text(
                        'Place Order',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.withValues(
                          alpha: 0.2,
                        ),
                        foregroundColor: Colors.greenAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactPriceCell(
    String label,
    String value,
    String? badge,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 2),
                Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(InvestmentRecommendation rec) {
    Color bg;
    Color border;
    Color fg;
    IconData icon;
    final statusUpper = rec.status.toUpperCase();
    final winLossUpper = rec.winLoss?.toUpperCase() ?? '';
    final exitReasonUpper = rec.exitReason?.toUpperCase() ?? '';

    String label = statusUpper.replaceAll('_', ' ');

    if (statusUpper == 'TARGET_HIT' ||
        winLossUpper == 'WIN' ||
        exitReasonUpper == 'TARGET_HIT') {
      bg = Colors.green.withValues(alpha: 0.2);
      border = Colors.greenAccent;
      fg = Colors.greenAccent;
      icon = Icons.task_alt;
      label = "TG HIT";
    } else if (statusUpper == 'STOP_LOSS_HIT' ||
        winLossUpper == 'LOSS' ||
        exitReasonUpper == 'STOP_LOSS_HIT') {
      bg = Colors.red.withValues(alpha: 0.2);
      border = Colors.redAccent;
      fg = Colors.redAccent;
      icon = Icons.cancel_outlined;
      label = "SL HIT";
    } else if (statusUpper == 'OPEN' ||
        winLossUpper == 'OPEN' ||
        exitReasonUpper == 'OPEN') {
      bg = Colors.blue.withValues(alpha: 0.2);
      border = Colors.blueAccent;
      fg = Colors.lightBlueAccent;
      icon = Icons.timelapse;
      label = "OPEN";
    } else if (statusUpper == 'SQUARE_OFF' ||
        winLossUpper == 'SQUARE_OFF' ||
        exitReasonUpper == 'SQUARE_OFF') {
      bg = Colors.orange.withValues(alpha: 0.2);
      border = Colors.orangeAccent;
      fg = Colors.orangeAccent;
      icon = Icons.swap_horiz;
      label = "SQ OFF";
    } else if (statusUpper.contains('TIME_EXPIRED') ||
        exitReasonUpper.contains('TIME_EXPIRED')) {
      bg = Colors.amber.withValues(alpha: 0.2);
      border = Colors.amberAccent;
      fg = Colors.amberAccent;
      icon = Icons.timer_outlined;
      label = "EXPIRED";
    } else if (statusUpper == 'ACTIVE') {
      bg = Colors.blue.withValues(alpha: 0.2);
      border = Colors.blueAccent;
      fg = Colors.cyanAccent;
      icon = Icons.play_circle_outline;
      label = "ACTIVE";
    } else {
      bg = Colors.grey.withValues(alpha: 0.2);
      border = Colors.grey;
      fg = Colors.grey;
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildPnlBadge(InvestmentRecommendation rec) {
    final text =
        rec.realizedPnlPercentage ??
        (rec.realizedPnlPercent != null
            ? '${rec.realizedPnlPercent! >= 0 ? "+" : ""}${rec.realizedPnlPercent!.toStringAsFixed(2)}%'
            : null);

    if (text == null || text.isEmpty) return null;

    final isPositive =
        !text.contains('-') &&
        (rec.realizedPnlPercent == null || rec.realizedPnlPercent! >= 0);
    final color = isPositive ? Colors.greenAccent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeMetricsSection(InvestmentRecommendation rec) {
    final ind = rec.indicators;
    final rsiVal = rec.rsi ?? ind?.rsi;
    final ema20Val = rec.ema20 ?? ind?.ema20;
    final stVal = rec.supertrend ?? ind?.supertrend;
    final atrVal = rec.atr ?? ind?.atr;
    final volVal = rec.volume ?? ind?.volume;
    final volMultVal = rec.volumeMultiplier ?? ind?.volumeRatio;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Technical Indicators & Details:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              if (rsiVal != null)
                _buildIndicatorChip('RSI', rsiVal.toStringAsFixed(1)),
              if (ema20Val != null)
                _buildIndicatorChip('EMA20', '₹${ema20Val.toStringAsFixed(2)}'),
              if (stVal != null)
                _buildIndicatorChip(
                  'Supertrend',
                  '₹${stVal.toStringAsFixed(2)}',
                ),
              if (atrVal != null)
                _buildIndicatorChip('ATR', atrVal.toStringAsFixed(2)),
              if (volVal != null)
                _buildIndicatorChip('Volume', _formatVolume(volVal)),
              if (volMultVal != null)
                _buildIndicatorChip(
                  'Vol Multiplier',
                  '${volMultVal.toStringAsFixed(2)}x',
                ),
              if (rec.supportPrice != null)
                _buildIndicatorChip(
                  'Support Price',
                  '₹${rec.supportPrice!.toStringAsFixed(2)}',
                ),
              if (rec.supportDistPct != null)
                _buildIndicatorChip(
                  'Support Dist',
                  '${rec.supportDistPct!.toStringAsFixed(2)}%',
                ),
              if (rec.exitReason != null)
                _buildIndicatorChip('Exit Reason', rec.exitReason!),
              if (rec.exitTime != null)
                _buildIndicatorChip(
                  'Exit Time',
                  _formatDateShort(rec.exitTime),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVolume(num vol) {
    if (vol >= 10000000) {
      return '${(vol / 10000000).toStringAsFixed(2)} Cr';
    } else if (vol >= 100000) {
      return '${(vol / 100000).toStringAsFixed(2)} L';
    } else if (vol >= 1000) {
      return '${(vol / 1000).toStringAsFixed(1)} K';
    }
    return vol.toString();
  }

  Widget _buildIndicatorChip(String key, String val) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$key: ',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          val,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
