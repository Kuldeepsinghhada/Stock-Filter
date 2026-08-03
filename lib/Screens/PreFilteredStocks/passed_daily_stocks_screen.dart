import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/passed_daily_stock_model.dart';

class PassedDailyStocksScreen extends StatefulWidget {
  const PassedDailyStocksScreen({super.key});

  @override
  State<PassedDailyStocksScreen> createState() => _PassedDailyStocksScreenState();
}

class _PassedDailyStocksScreenState extends State<PassedDailyStocksScreen> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  String? errorMessage;
  PassedDailyData? responseData;
  String apiMessage = '';

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPassedStocks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchPassedStocks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final formattedDate = _formatDate(selectedDate);
    final response = await BackendOrderService.fetchPassedDailyTimeframeStocks(formattedDate);

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
        apiMessage = response?.message ?? "Failed to load data";
        errorMessage = response?.message ?? "Failed to connect to backend service.";
        isLoading = false;
      });
    }
  }

  List<PassedDailyStockModel> get _filteredStocks {
    if (responseData == null) return [];
    final stocks = responseData!.passedStocks;
    if (searchQuery.trim().isEmpty) return stocks;

    final q = searchQuery.trim().toLowerCase();
    return stocks.where((stock) {
      final symbolMatch = stock.symbol.toLowerCase().contains(q);
      final tokenMatch = stock.token.toString().contains(q);
      final priceSourceMatch = stock.priceSource.toLowerCase().contains(q);
      final reasonMatch = stock.reasons.any((r) => r.toLowerCase().contains(q));
      return symbolMatch || tokenMatch || priceSourceMatch || reasonMatch;
    }).toList();
  }

  void _copyAllSymbols() {
    final stocks = _filteredStocks;
    if (stocks.isEmpty) return;
    final symbols = stocks.map((s) => s.symbol).join(', ');
    Clipboard.setData(ClipboardData(text: symbols));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${stocks.length} symbol(s) to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStocks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passed Daily Timeframe Stocks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Symbols',
            onPressed: _copyAllSymbols,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchPassedStocks,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPassedStocks,
        child: Column(
          children: [
            _buildDateAndSearchHeader(),
            if (isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Fetching passed daily timeframe stocks...'),
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
                        const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchPassedStocks,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.search_off, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'No stocks match "$searchQuery"'
                                    : 'No stocks passed daily timeframe for this date.',
                                style: const TextStyle(fontSize: 15, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(filtered.length, (index) {
                        final stock = filtered[index];
                        return _buildStockCard(stock, index + 1);
                      }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateAndSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Date: ${_formatDate(selectedDate)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && picked != selectedDate) {
                    setState(() {
                      selectedDate = picked;
                    });
                    _fetchPassedStocks();
                  }
                },
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text('Change Date'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by symbol, token, price source or reason...',
              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (responseData == null) return const SizedBox.shrink();

    final data = responseData!;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade900.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (apiMessage.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      apiMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18, color: Colors.white24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Target Date', data.targetDate, Icons.event),
                _buildStatColumn('Checked Till', data.checkedTillDate, Icons.history),
                _buildStatColumn('Evaluated', '${data.totalEvaluated}', Icons.analytics),
                _buildStatColumn('Passed', '${data.totalPassed}', Icons.verified, color: Colors.greenAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.blueAccent),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildStockCard(PassedDailyStockModel stock, int index) {
    final bool isPassed = stock.passed;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPassed ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isPassed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
          child: Text(
            '$index',
            style: TextStyle(
              color: isPassed ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                stock.symbol,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPassed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isPassed ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPassed ? Icons.check_circle : Icons.cancel,
                    size: 14,
                    color: isPassed ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPassed ? 'PASSED' : 'FAILED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPassed ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price: ₹${stock.stockPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.greenAccent,
                ),
              ),
              Text(
                'Token: ${stock.token}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 10),
                
                // Detailed Information Table / Grid
                _buildInfoRow('Price Source', stock.priceSource),
                if (stock.previousDailySupertrend != null)
                  _buildInfoRow(
                    'Prev Daily Supertrend',
                    '₹${stock.previousDailySupertrend!.toStringAsFixed(2)}',
                    highlightColor: Colors.amberAccent,
                  ),
                if (stock.lastCompletedDailyDate != null)
                  _buildInfoRow(
                    'Last Completed Daily Date',
                    stock.lastCompletedDailyDate!,
                  ),
                
                const SizedBox(height: 10),
                const Text(
                  'Resistance Analysis',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Nearest Resistance Price',
                        stock.nearestResistancePrice != null
                            ? '₹${stock.nearestResistancePrice!.toStringAsFixed(2)}'
                            : 'N/A',
                      ),
                      _buildInfoRow(
                        'Resistance Touches',
                        stock.nearestResistanceTouches != null
                            ? '${stock.nearestResistanceTouches}'
                            : 'N/A',
                      ),
                      _buildInfoRow(
                        'Distance to Resistance',
                        stock.distanceToResistancePercent != null
                            ? '${stock.distanceToResistancePercent!.toStringAsFixed(2)}%'
                            : 'N/A',
                        highlightColor: (stock.distanceToResistancePercent ?? 0) < 2
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                    ],
                  ),
                ),

                // Checks Breakdown
                if (stock.checks != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Evaluation Checks',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (stock.checks!.supertrend != null)
                        Expanded(
                          child: _buildCheckChip(
                            'Supertrend Check',
                            stock.checks!.supertrend!.passed,
                            detail: stock.checks!.supertrend!.previousDailySupertrend != null
                                ? 'ST: ₹${stock.checks!.supertrend!.previousDailySupertrend!.toStringAsFixed(1)}'
                                : null,
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (stock.checks!.resistance != null)
                        Expanded(
                          child: _buildCheckChip(
                            'Resistance Check',
                            stock.checks!.resistance!.passed,
                            detail: stock.checks!.resistance!.isNearResistance != null
                                ? (stock.checks!.resistance!.isNearResistance!
                                    ? 'Near Resistance'
                                    : 'Not Near Resistance')
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],

                // Reasons List
                if (stock.reasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Reasons',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...stock.reasons.map((reason) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 16, color: Colors.greenAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reason,
                                style: const TextStyle(fontSize: 13, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Symbol'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: stock.symbol));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied ${stock.symbol} to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlightColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckChip(String title, bool passed, {String? detail}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: passed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: passed ? Colors.greenAccent : Colors.redAccent,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: passed ? Colors.greenAccent : Colors.redAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade300),
            ),
          ],
        ],
      ),
    );
  }
}
