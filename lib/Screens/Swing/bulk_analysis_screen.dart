import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/Screens/DataScreen/history_services.dart';
import 'package:stock_demo/Screens/Chart/chart_screen.dart'; // Added import
import 'package:stock_demo/Utils/ai_score_calculator.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../Chart/indicator_settings_screen.dart';

class BulkAnalysisScreen extends StatefulWidget {
  final DateTime selectedDate;

  const BulkAnalysisScreen({super.key, required this.selectedDate});

  @override
  _BulkAnalysisScreenState createState() => _BulkAnalysisScreenState();
}

class _BulkAnalysisScreenState extends State<BulkAnalysisScreen> {
  final TextEditingController _symbolsController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = "";
  List<Map<String, dynamic>> _results = [];
  // Raw results contain per-symbol calculated data (including swingPass)
  List<Map<String, dynamic>> _rawResults = [];
  // Last analyzed symbols for re-assembling errors when filtering locally
  List<String> _lastAnalyzedSymbols = [];
  List<dynamic> _allStocks = [];
  late DateTime _selectedDate;
  List<String> _searchHistory = [];
  List<String> _intradaySymbols = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _loadStocksData();
    _loadSearchHistory();
    _loadIntradaySymbols();
  }

  Future<void> _loadIntradaySymbols() async {
    final List<String> current = (await SharedPreferenceHelper.instance
            .getStringList('intraday_symbols')) ??
        [];
    setState(() {
      _intradaySymbols = current;
    });
  }

  @override
  void dispose() {
    _symbolsController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('bulk_search_history') ?? [];
    setState(() {
      _searchHistory = history;
    });
    // Set text to the very first item if exist? No, user prefers hint list.
    // We'll just load the history so it shows in the UI.
    if (history.isNotEmpty && _symbolsController.text.isEmpty) {
      _symbolsController.text = history.first;
    }
  }

  Future<void> _openSearchBottomSheet() async {
    // Present the bottom sheet full-screen. Keep isScrollControlled true so
    // the sheet can grow to the full height; wrap the sheet content in a
    // SizedBox sized to the device height so it visually appears full-screen.
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final height = MediaQuery.of(context).size.height;
        return SizedBox(
          height: height *
              0.85, // leave a small top gap so status bar remains visible
          child: _SearchBottomSheetScreen(
            controller: _symbolsController,
            allStocks: _allStocks,
            searchHistory: _searchHistory,
            onSearch: () {
              if (_symbolsController.text.trim().isNotEmpty) {
                _analyzeSymbols();
              }
            },
          ),
        );
      },
    );

    // Refresh parent search history after the bottom sheet closes so the
    // main screen reflects deletions made inside the sheet immediately.
    await _loadSearchHistory();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      if (_symbolsController.text.trim().isNotEmpty) {
        _analyzeSymbols();
      }
    }
  }

  Future<void> _loadStocksData() async {
    try {
      final String response = await rootBundle.loadString('assets/main.json');
      _allStocks = await json.decode(response);
    } catch (e) {
      debugPrint("Error loading json: $e");
    }
  }

  Future<void> _analyzeSymbols({bool isRefresh = false}) async {
    FocusScope.of(context).unfocus();
    final inputText = _symbolsController.text.trim();
    if (inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one symbol')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_searchHistory.contains(inputText)) {
      _searchHistory.remove(inputText);
    }
    _searchHistory.insert(0, inputText);
    if (_searchHistory.length > 20) {
      _searchHistory = _searchHistory.sublist(0, 20);
    }
    await prefs.setStringList('bulk_search_history', _searchHistory);

    setState(() {
      _isLoading = true;
      _statusMessage = isRefresh ? "Refreshing data..." : "Parsing symbols...";
      _results.clear();
      _rawResults.clear();
    });

    try {
      await WakelockPlus.enable();

      final List<String> symbols = inputText
          .split(',')
          .map((e) => e.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toList();

      // Save last analyzed symbols so local filters can re-create errors for missing ones
      _lastAnalyzedSymbols = List<String>.from(symbols);

      if (_allStocks.isEmpty) {
        await _loadStocksData();
      }

      final DateTime toDate = _selectedDate;

      setState(() {
        _statusMessage = isRefresh
            ? "Refreshing historical data (${symbols.length} symbols)..."
            : "Fetching local/historical data (${symbols.length} symbols)...";
      });

      final enableSwingScannerLoose =
          await SharedPreferenceHelper.instance.getEnableSwingScannerLoose();

      // Read boolean preference: if true, show only symbols whose last candle closed green
      final closedInGreenEnabled =
          await SharedPreferenceHelper.instance.getClosedInGreenEnabled();

      // Call the batch fetching logic in HistoryServices to get StockModel objects
      List<StockModel> fetched = await HistoryServices.instance.fetchQuotes(
        toDate,
        symbols,
        isRefresh: isRefresh,
      );

      // Build raw results by calculating score for each available stock locally.
      List<Map<String, dynamic>> raw = [];

      fetched.removeWhere(
        (item) =>
            (item.historyFiveMin != null && item.historyFiveMin!.length < 200),
      );

      for (var stock in fetched) {
        if (symbols.contains(stock.symbol)) {
          if (stock.historyFiveMin != null && stock.historyFiveMin!.isNotEmpty) {
            try {
              // Always compute scoreResult so we can re-filter locally later
              final Map<String, dynamic> scoreResult =
                  AIScoreCalculator.calculateAIScoreV2(
                stock.historyFiveMin!,
                targetDate: toDate,
              );
              // Mark symbol and stock reference
              scoreResult['symbol'] = stock.symbol;
              scoreResult['stock'] = stock;

              raw.add(scoreResult);
            } catch (e) {
              raw.add({
                "symbol": stock.symbol,
                "error": "Failed to calculate score: ${e.toString()}",
              });
            }
          } else {
            raw.add({
              "symbol": stock.symbol,
              "error": "Insufficient historical data",
            });
          }
        }
      }

      // Also add missing symbols that were not present in fetched list as errors
      final fetchedSymbolsSet = raw.map((r) => r['symbol']).toSet();
      for (final symbol in symbols) {
        if (!fetchedSymbolsSet.contains(symbol)) {
          raw.add({
            "symbol": symbol,
            "error": "Failed to fetch data or symbol not found",
          });
        }
      }

      // Store raw results and apply active settings filters locally (no network/db needed)
      _rawResults = raw;

      // Apply filters and update displayed _results
      await _applyFiltersFromSettings(isRefresh: isRefresh);
    } catch (e) {
      debugPrint("Analysis failed: $e");
    } finally {
      await WakelockPlus.disable();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Apply current settings to _rawResults and update _results without network calls
  Future<void> _applyFiltersFromSettings({bool isRefresh = false}) async {
    final enableSwingScannerLoose =
        await SharedPreferenceHelper.instance.getEnableSwingScannerLoose();
    final closedInGreenEnabled =
        await SharedPreferenceHelper.instance.getClosedInGreenEnabled();
    final nearEmaOrSupertrendEnabled =
        await SharedPreferenceHelper.instance.getNearEmaOrSupertrendEnabled();

    // Split raw into successes and errors
    final errors = _rawResults.where((r) => r.containsKey('error')).toList();
    final successes =
        _rawResults.where((r) => !r.containsKey('error')).toList();

    // Apply swing scanner filter if enabled (use precomputed swingPass field)
    var filtered = enableSwingScannerLoose
        ? successes.where((r) => r['swingPass'] == true).toList()
        : List<Map<String, dynamic>>.from(successes);

    // Apply closed-in-green filter if enabled
    if (closedInGreenEnabled) {
      filtered = filtered.where((r) => r['isLastCandleGreen'] == true).toList();
    }

    // Apply near EMA or Supertrend filter if enabled
    if (nearEmaOrSupertrendEnabled) {
      filtered = filtered.where((r) => r['isNearBuyZone'] == true).toList();
    }

    // Sort successes by score
    filtered.sort((a, b) {
      final int scoreA = a['score'] ?? -1;
      final int scoreB = b['score'] ?? -1;
      return scoreB.compareTo(scoreA);
    });

    // Reassemble final list: successes followed by errors (and ensure missing symbol errors exist)
    final resultList = <Map<String, dynamic>>[];
    resultList.addAll(filtered);

    // Determine which symbols are already represented
    final represented = resultList.map((r) => r['symbol']).toSet();
    for (final symbol in _lastAnalyzedSymbols) {
      if (!represented.contains(symbol)) {
        // If there is an error entry for this symbol in errors, append it; otherwise add a not-found error
        final err =
            errors.firstWhere((e) => e['symbol'] == symbol, orElse: () => {});
        if (err.isNotEmpty) {
          resultList.add(err);
        } else {
          resultList.add({
            'symbol': symbol,
            'error': 'Failed to fetch data or symbol not found',
          });
        }
      }
    }

    setState(() {
      _isLoading = false;
      _results = resultList;
      _statusMessage = isRefresh
          ? "Refreshed ${filtered.length} results${closedInGreenEnabled ? ' (closed in green only)' : ''}"
          : "Found ${filtered.length} results${closedInGreenEnabled ? ' (closed in green only)' : ''}";
    });
  }

  Color _getVerdictColor(dynamic scoreVal) {
    if (scoreVal == null) return Colors.grey;
    final int score = int.tryParse(scoreVal.toString()) ?? 0;
    if (score >= 75) {
      return Colors.green;
    } else if (score >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Future<void> _toggleIntraday(String symbol) async {
    final List<String> current = (await SharedPreferenceHelper.instance
            .getStringList('intraday_symbols')) ??
        [];

    if (current.contains(symbol)) {
      current.remove(symbol);
      await SharedPreferenceHelper.instance
          .setStringList('intraday_symbols', current);
      setState(() {
        _intradaySymbols = current;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $symbol from Intraday list')),
        );
      }
      return;
    }

    current.add(symbol);
    await SharedPreferenceHelper.instance
        .setStringList('intraday_symbols', current);
    setState(() {
      _intradaySymbols = current;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $symbol to Intraday list')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ANALYSIS'.toUpperCase()),
        actions: [
          IconButton(
            onPressed: () {
              final passedSymbols = _results
                  .where((r) =>
                      r['symbol'] != null &&
                      !r.containsKey('error') &&
                      (r['score'] ?? 0) > 50)
                  .map((r) => r['symbol'].toString())
                  .join(', ');
              if (passedSymbols.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: passedSymbols));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Copied ${passedSymbols.split(',').length} symbols to clipboard')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No symbols with score > 50')));
              }
            },
            icon: const Icon(Icons.copy, color: Colors.white),
            tooltip: 'Copy symbols > 50%',
          ),
          IconButton(
            onPressed:
                _isLoading ? null : () => _analyzeSymbols(isRefresh: true),
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              // Open settings and reapply local filters on return without network
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const IndicatorSettingsScreen()),
              );
              // Reapply filters using stored _rawResults
              await _applyFiltersFromSettings();
            },
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            InkWell(
              onTap: _openSearchBottomSheet,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _symbolsController.text.isNotEmpty
                            ? _symbolsController.text
                            : 'Search symbols (e.g. RELIANCE, TCS)',
                        style: TextStyle(
                          color: _symbolsController.text.isNotEmpty
                              ? Theme.of(context).textTheme.bodyLarge?.color
                              : Colors.grey,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _analyzeSymbols,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Analyze Symbols'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              const SizedBox(height: 20),
              Text(_statusMessage, style: const TextStyle(fontSize: 16)),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  final symbol = result['symbol'] ?? 'Unknown';

                  // target and stoploss are accessed via result['target']/result['stoploss']
                  // when building the UI below, so we don't need separate local vars.

                  var price = result['currentPrice'];

                  if (result.containsKey('error')) {
                    return SizedBox();
                  }
                  // if (result.containsKey('error') ||
                  //     result['isLastCandleGreen'] == false ||
                  //     (price != null &&
                  //         supertrend != null &&
                  //         price < supertrend)) {
                  //   return SizedBox();
                  // }

                  final score = result['score'];
                  final verdict = result['verdict'];
                  final verdictColor = _getVerdictColor(score);
                  final isNearBuyZone = result['isNearBuyZone'] == true;
                  final support = result['support'];
                  final isNearSupport = support != null &&
                      price != null &&
                      support > 0 &&
                      ((price - support) / support) <= 0.03;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (result['stock'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChartScreen(stock: result['stock']),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  spacing: 10,
                                  children: [
                                    Text(
                                      symbol,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isNearBuyZone)
                                      const Tooltip(
                                        message: 'Near Buy Zone',
                                        child: Icon(
                                          Icons.star,
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                    if (isNearSupport)
                                      const Tooltip(
                                        message: 'Near Support (within 3%)',
                                        child: Icon(
                                          Icons.star,
                                          color: Colors.blue,
                                        ),
                                      ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: verdictColor
                                            .withAlpha((0.1 * 255).round()),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: verdictColor),
                                      ),
                                      child: Text(
                                        "$score% - $verdict",
                                        style: TextStyle(
                                          color: verdictColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                          _intradaySymbols.contains(symbol)
                                              ? Icons.check_circle
                                              : Icons.add_circle_outline,
                                          size: 20,
                                          color: _intradaySymbols
                                                  .contains(symbol)
                                              ? Colors.greenAccent
                                              : Colors.blueAccent),
                                      onPressed: () => _toggleIntraday(symbol),
                                      tooltip: _intradaySymbols.contains(symbol)
                                          ? "Remove from Intraday"
                                          : "Add to Intraday",
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (result['patterns'] != null &&
                                (result['patterns'] as List).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Patterns: ${(result['patterns'] as List).join(', ')}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (result['institutionalPatterns'] != null &&
                                (result['institutionalPatterns'] as List)
                                    .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Institutional Patterns: ${(result['institutionalPatterns'] as List).join(', ')}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (result['date'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Date: ${result['date']}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const Divider(),
                            if (result['performance'] != null &&
                                result['performance'] != 'N/A') ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Status:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        result['performance'] ==
                                                'Target Achieved'
                                            ? Icons.check_circle
                                            : result['performance'] ==
                                                    'Stoploss Hit'
                                                ? Icons.cancel
                                                : Icons.pending,
                                        size: 16,
                                        color: result['performance'] ==
                                                'Target Achieved'
                                            ? Colors.green
                                            : result['performance'] ==
                                                    'Stoploss Hit'
                                                ? Colors.red
                                                : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${result['performance']} ${result['daysToHit'] > 0 ? '(${result['daysToHit']} days)' : ''}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: result['performance'] ==
                                                  'Target Achieved'
                                              ? Colors.green
                                              : result['performance'] ==
                                                      'Stoploss Hit'
                                                  ? Colors.red
                                                  : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStat("Price", price),
                                _buildStat("Target", result['target']),
                                _buildStat("Stoploss", result['stoploss']),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStat("RSI", result['rsi']),
                                _buildStat("ADX", result['adx']),
                                _buildStat("Support", result['support']),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildStat(String label, dynamic value) {
    String displayValue = "-";
    if (value != null) {
      if (value is double) {
        displayValue = value.toStringAsFixed(2);
      } else {
        displayValue = value.toString();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          displayValue,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _SearchBottomSheetScreen extends StatefulWidget {
  final TextEditingController controller;
  final List<dynamic> allStocks;
  final List<String> searchHistory;
  final VoidCallback onSearch;

  const _SearchBottomSheetScreen({
    Key? key,
    required this.controller,
    required this.allStocks,
    required this.searchHistory,
    required this.onSearch,
  }) : super(key: key);

  @override
  __SearchBottomSheetScreenState createState() =>
      __SearchBottomSheetScreenState();
}

class __SearchBottomSheetScreenState extends State<_SearchBottomSheetScreen> {
  late FocusNode _focusNode;
  List<dynamic> _suggestions = [];
  // Local mutable copy of the recent searches so we can remove items locally.
  // Initialize to empty to avoid LateInitializationError while async load runs.
  List<String> _localHistory = [];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.controller.addListener(_onTextChanged);

    // Auto-focus the text field so keyboard opens immediately
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });

    // Check if there's already text to show suggestions for
    _onTextChanged();

    // Load local history from shared preferences so the bottom sheet
    // always reflects the current stored history (and not a possibly stale
    // parent copy).
    _loadLocalHistory();
  }

  Future<void> _loadLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('bulk_search_history') ?? [];
      if (mounted) {
        setState(() {
          _localHistory = List<String>.from(history);
        });
      } else {
        _localHistory = List<String>.from(history);
      }
    } catch (e) {
      debugPrint('Failed to load local history: $e');
      _localHistory = List<String>.from(widget.searchHistory);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _removeHistoryItem(String item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('bulk_search_history') ?? [];
      if (existing.contains(item)) {
        existing.remove(item);
        await prefs.setStringList('bulk_search_history', existing);
      }
      if (mounted) {
        setState(() {
          _localHistory.remove(item);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "$item" from recent searches')),
        );
      }
    } catch (e) {
      // ignore errors silently; don't crash the bottom sheet
      debugPrint('Failed to remove history item: $e');
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      if (mounted) {
        setState(() {
          _suggestions = [];
        });
      }
      return;
    }

    final parts = text.split(',');
    final currentWord = parts.last.trim().toUpperCase();
    if (currentWord.isEmpty) {
      if (mounted) {
        setState(() {
          _suggestions = [];
        });
      }
      return;
    }

    final matches = widget.allStocks
        .where((stock) {
          final symbol =
              (stock['tradingsymbol'] as String?)?.toUpperCase() ?? '';
          final name = (stock['name'] as String?)?.toUpperCase() ?? '';
          return symbol.contains(currentWord) || name.contains(currentWord);
        })
        .take(8)
        .toList();

    if (mounted) {
      setState(() {
        _suggestions = matches;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The parent shows this widget inside a SizedBox sized to the screen
    // height. Make this widget expand to that height (mainAxisSize.max)
    // and let the list/scroll area take the remaining space using Expanded.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      Navigator.pop(context);
                      widget.onSearch();
                    },
                    decoration: InputDecoration(
                      labelText: 'Enter symbols (comma-separated)',
                      hintText: 'e.g., RELIANCE, TCS, INFY',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          widget.controller.clear();
                        },
                      ),
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final allSymbols = widget.allStocks
                        .map((stock) => stock['tradingsymbol'])
                        .join(',');
                    widget.controller.text = allSymbols;
                    Navigator.pop(context);
                    widget.onSearch();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: const Text('All Stocks'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSearch();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _suggestions.isNotEmpty
                  ? ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final stock = _suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            stock['tradingsymbol'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(stock['name'] ?? ''),
                          onTap: () {
                            final parts = widget.controller.text.split(',');
                            parts[parts.length - 1] =
                                (parts.length > 1 ? ' ' : '') +
                                    (stock['tradingsymbol'] ?? '');
                            widget.controller.text = parts.join(',') + ', ';
                            widget.controller.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: widget.controller.text.length),
                            );
                          },
                        );
                      },
                    )
                  : (_localHistory.isNotEmpty
                      ? SingleChildScrollView(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recent Searches',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: -8,
                              children: _localHistory.map((history) {
                                return InputChip(
                                  label: Text(
                                    history,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () {
                                    widget.controller.text = history;
                                    widget.controller.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                        offset: widget.controller.text.length,
                                      ),
                                    );
                                  },
                                  onDeleted: () async {
                                    // Remove from shared prefs and local list
                                    await _removeHistoryItem(history);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ))
                      : Center(
                          child: Text(
                            'No suggestions',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color),
                          ),
                        )),
            ),
          ],
        ),
      ),
    );
  }
}
