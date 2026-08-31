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
  String selectedFilterType = 'ALL'; // ALL, TARGET_HIT, TIME_EXPIRED, ACTIVE
  String sortBy = 'ACCURACY'; // ACCURACY, PNL, DATE, SYMBOL

  @override
  void initState() {
    super.initState();
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      try {
        startDate = DateTime.parse(widget.initialStartDate!);
        endDate = DateTime.parse(widget.initialEndDate!);
      } catch (_) {
        startDate = DateTime(2026, 7, 1);
        endDate = DateTime(2026, 7, 31);
      }
    } else {
      // Default initial range: 2026-07-01 to 2026-07-31
      startDate = DateTime(2026, 7, 1);
      endDate = DateTime(2026, 7, 31);
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

  String _formatDateShort(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    }
  }

  Future<void> _fetchInvestmentRecommendations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final formattedStartDate = _formatDate(startDate);
    final formattedEndDate = _formatDate(endDate);

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
        apiMessage =
            response?.message ?? "Failed to load investment recommendations";
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

    // Filter by status
    if (selectedFilterType == 'TARGET_HIT') {
      recs = recs.where((r) => r.status.toUpperCase() == 'TARGET_HIT').toList();
    } else if (selectedFilterType == 'TIME_EXPIRED') {
      recs = recs
          .where((r) => r.status.toUpperCase().contains('TIME_EXPIRED'))
          .toList();
    } else if (selectedFilterType == 'ACTIVE') {
      recs = recs.where((r) => r.status.toUpperCase() == 'ACTIVE').toList();
    }

    // Filter by search query
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      recs = recs.where((rec) {
        final symbolMatch = rec.symbol.toLowerCase().contains(q);
        final typeMatch = rec.recommendationType.toLowerCase().contains(q);
        final statusMatch = rec.status.toLowerCase().contains(q);
        final dateMatch = (rec.date ?? rec.createdAt).toLowerCase().contains(q);
        final reasonMatch = rec.reasons.any((r) => r.toLowerCase().contains(q));
        return symbolMatch ||
            typeMatch ||
            statusMatch ||
            dateMatch ||
            reasonMatch;
      }).toList();
    }

    // Sort recommendations
    if (sortBy == 'ACCURACY') {
      recs.sort((a, b) => b.accuracy.compareTo(a.accuracy));
    } else if (sortBy == 'DATE') {
      recs.sort(
        (a, b) => (b.date ?? b.createdAt).compareTo(a.date ?? a.createdAt),
      );
    } else if (sortBy == 'SYMBOL') {
      recs.sort((a, b) => a.symbol.compareTo(b.symbol));
    } else if (sortBy == 'PNL') {
      recs.sort(
        (a, b) => (b.realizedPnlPercent ?? 0.0).compareTo(
          a.realizedPnlPercent ?? 0.0,
        ),
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
        title: const Text('Investment'),
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
                        'Fetching investment recommendations...',
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
                        'No recommendations for ${_formatDate(startDate)} to ${_formatDate(endDate)}',
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
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildRecommendationCard(filtered[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeControls() {
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(endDate);
    final isJulyRange = startStr == "2026-07-01" && endStr == "2026-07-31";

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                        color: isJulyRange ? Colors.cyanAccent : Colors.white24,
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
                              '$startStr  →  $endStr',
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
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  label: 'Jul 2026 (2026-07-01 to 2026-07-31)',
                  isSelected: isJulyRange,
                  onTap: () => _setPresetRange(
                    DateTime(2026, 7, 1),
                    DateTime(2026, 7, 31),
                  ),
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Today',
                  isSelected:
                      startStr == _formatDate(DateTime.now()) &&
                      endStr == _formatDate(DateTime.now()),
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

    final strategy =
        responseData?.strategy ?? "Short-Term Investment Recommendation";
    final recs = responseData?.recommendations ?? [];
    final totalCount = responseData?.count ?? recs.length;

    final targetHitCount =
        responseData?.targetHitCount ??
        recs.where((r) => r.status.toUpperCase() == 'TARGET_HIT').length;

    final totalProfit =
        responseData?.totalProfit ??
        recs.fold<double>(0.0, (sum, r) => sum + (r.realizedPnlPercent ?? 0.0));

    // Accuracy calculation:
    // 1. Use API accuracyPercent if provided
    // 2. Otherwise use average model accuracy across recommendations (e.g. 77.2%)
    // 3. Fallback to minAccuracyRequired (e.g. 75.0%)
    double accuracyVal = responseData?.accuracyPercent ?? 0.0;
    if (accuracyVal == 0.0 && recs.isNotEmpty) {
      final totalAcc = recs.fold<double>(0.0, (sum, r) => sum + r.accuracy);
      accuracyVal = totalAcc / recs.length;
    }
    if (accuracyVal == 0.0) {
      accuracyVal = responseData?.minAccuracyRequired ?? 75.0;
    }

    final profitStr =
        '${totalProfit >= 0 ? "+" : ""}${totalProfit.toStringAsFixed(2)}%';
    final profitColor = totalProfit >= 0
        ? Colors.greenAccent
        : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade900.withValues(alpha: 0.8),
            Colors.blue.shade900.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Colors.cyanAccent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  strategy,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Total Count',
                  value: '$totalCount',
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Target Hit',
                  value: '$targetHitCount',
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Accuracy %',
                  value: '${accuracyVal.toStringAsFixed(1)}%',
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHeaderBadge(
                  label: 'Total Profit',
                  value: profitStr,
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
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
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search symbol, status, or reasons...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Colors.cyanAccent,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 10,
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
                      const SizedBox(width: 6),
                      _buildFilterChip('TARGET_HIT', 'Target Hit'),
                      const SizedBox(width: 6),
                      _buildFilterChip('TIME_EXPIRED', 'Time Expired'),
                      const SizedBox(width: 6),
                      _buildFilterChip('ACTIVE', 'Active'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                initialValue: sortBy,
                onSelected: (val) {
                  setState(() {
                    sortBy = val;
                  });
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'ACCURACY',
                    child: Text('Sort by Accuracy'),
                  ),
                  PopupMenuItem(
                    value: 'PNL',
                    child: Text('Sort by Realized PnL'),
                  ),
                  PopupMenuItem(value: 'DATE', child: Text('Sort by Date')),
                  PopupMenuItem(value: 'SYMBOL', child: Text('Sort by Symbol')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
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
                        size: 14,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sortBy,
                        style: const TextStyle(
                          fontSize: 10,
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
          fontSize: 11,
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.cyanAccent,
      backgroundColor: const Color(0xFF1E222D),
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() {
            selectedFilterType = filterKey;
          });
        }
      },
    );
  }

  Widget _buildRecommendationCard(InvestmentRecommendation rec) {
    const mainColor = Colors.greenAccent;
    final typeBadgeText = rec.recommendationType.replaceAll('_', ' ');

    final createdDateStr = _formatDateShort(
      rec.createdAt.isNotEmpty ? rec.createdAt : rec.date,
    );
    final exitDateStr = _formatDateShort(rec.exitDate);

    final statusWidget = _buildStatusBadge(rec.status);
    final pnlWidget = _buildPnlBadge(rec);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E222D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: mainColor.withValues(alpha: 0.3), width: 1),
      ),
      elevation: 3,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(12),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        collapsedIconColor: Colors.grey,
        iconColor: Colors.cyanAccent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    rec.symbol,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: mainColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: mainColor.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 12,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        typeBadgeText,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 11, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        rec.accuracyPercentage.isNotEmpty
                            ? rec.accuracyPercentage
                            : '${rec.accuracy}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildPriceMetric(
                    'Entry Price',
                    '₹${rec.entryPrice.toStringAsFixed(2)}',
                    Colors.white,
                  ),
                ),
                if (rec.exitPrice != null)
                  Expanded(
                    child: _buildPriceMetric(
                      'Exit Price',
                      '₹${rec.exitPrice!.toStringAsFixed(2)}',
                      Colors.cyanAccent,
                    ),
                  ),
                Expanded(
                  child: _buildPriceMetric(
                    'Target',
                    '₹${rec.targetPrice.toStringAsFixed(2)} (+${rec.targetPercent.toStringAsFixed(2)}%)',
                    Colors.greenAccent,
                  ),
                ),
                Expanded(
                  child: _buildPriceMetric(
                    'Stop Loss',
                    '₹${rec.stopLossPrice.toStringAsFixed(2)} (-${rec.stopLossPercent.toStringAsFixed(2)}%)',
                    Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  statusWidget,
                  if (pnlWidget != null) ...[
                    const SizedBox(width: 6),
                    pnlWidget,
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'R:R ${rec.riskRewardRatio}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rec.holdingDays != null
                        ? 'Holding: ${rec.holdingDays} Days'
                        : 'Period: ${rec.holdingPeriod}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              if (createdDateStr.isNotEmpty || exitDateStr.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 11,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      exitDateStr.isNotEmpty
                          ? '$createdDateStr → $exitDateStr'
                          : createdDateStr,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
            ],
          ),
        ),
        children: [
          const Divider(color: Colors.white12, height: 16),
          if (rec.reasons.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recommendation Reasons:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ...rec.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (rec.indicators != null) ...[
            _buildIndicatorsSection(rec.indicators!),
            const SizedBox(height: 10),
          ],
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: rec.symbol));
                  Fluttertoast.showToast(msg: "Copied ${rec.symbol}");
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text(
                  'Copy Symbol',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _placeOrderDialog(rec),
                icon: const Icon(Icons.shopping_cart_checkout, size: 14),
                label: const Text(
                  'Place Order',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor.withValues(alpha: 0.2),
                  foregroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color border;
    Color fg;
    IconData icon;
    String label = status.replaceAll('_', ' ');

    switch (status.toUpperCase()) {
      case 'TARGET_HIT':
        bg = Colors.green.withValues(alpha: 0.2);
        border = Colors.greenAccent;
        fg = Colors.greenAccent;
        icon = Icons.task_alt;
        break;
      case 'TIME_EXPIRED_EXIT':
        bg = Colors.amber.withValues(alpha: 0.2);
        border = Colors.amberAccent;
        fg = Colors.amberAccent;
        icon = Icons.timer_outlined;
        break;
      case 'STOP_LOSS_HIT':
        bg = Colors.red.withValues(alpha: 0.2);
        border = Colors.redAccent;
        fg = Colors.redAccent;
        icon = Icons.cancel_outlined;
        break;
      case 'ACTIVE':
        bg = Colors.blue.withValues(alpha: 0.2);
        border = Colors.blueAccent;
        fg = Colors.cyanAccent;
        icon = Icons.play_circle_outline;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.2);
        border = Colors.grey;
        fg = Colors.grey;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorsSection(InvestmentIndicators ind) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Technical Indicators & Metrics:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (ind.ema20 != null)
                _buildIndicatorChip('EMA20', ind.ema20!.toStringAsFixed(2)),
              if (ind.ema50 != null)
                _buildIndicatorChip('EMA50', ind.ema50!.toStringAsFixed(2)),
              if (ind.ema200 != null)
                _buildIndicatorChip('EMA200', ind.ema200!.toStringAsFixed(2)),
              if (ind.supertrend != null)
                _buildIndicatorChip(
                  'Supertrend',
                  ind.supertrend!.toStringAsFixed(2),
                ),
              if (ind.rsi != null)
                _buildIndicatorChip('RSI', ind.rsi!.toStringAsFixed(1)),
              if (ind.adx != null)
                _buildIndicatorChip('ADX', ind.adx!.toStringAsFixed(1)),
              if (ind.plusDI != null)
                _buildIndicatorChip('+DI', ind.plusDI!.toStringAsFixed(1)),
              if (ind.minusDI != null)
                _buildIndicatorChip('-DI', ind.minusDI!.toStringAsFixed(1)),
              if (ind.volumeRatio != null)
                _buildIndicatorChip(
                  'Vol Ratio',
                  '${ind.volumeRatio!.toStringAsFixed(2)}x',
                ),
              if (ind.confidenceScore != null)
                _buildIndicatorChip(
                  'Confidence',
                  '${ind.confidenceScore!.toStringAsFixed(0)}%',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorChip(String key, String val) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$key: ',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          val,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
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
