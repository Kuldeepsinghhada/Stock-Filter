import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/Screens/DataScreen/history_services.dart';
import 'package:stock_demo/Utils/ai_score_calculator.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/api_response.dart';

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
  List<dynamic> _allStocks = [];
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _loadStocksData();
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

  Future<void> _analyzeSymbols() async {
    FocusScope.of(context).unfocus();
    final inputText = _symbolsController.text.trim();
    if (inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one symbol')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Parsing symbols...";
      _results.clear();
    });

    final List<String> symbols = inputText
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    if (_allStocks.isEmpty) {
      await _loadStocksData();
    }

    final DateTime toDate = _selectedDate;
    final DateTime fromDate = toDate.subtract(const Duration(days: 440));
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String toDateString = formatter.format(toDate);
    final String fromDateString = formatter.format(fromDate);

    List<Future<Map<String, dynamic>?>> fetchTasks = [];

    for (String symbol in symbols) {
      // Find the instrument token from main.json
      final stockMatch = _allStocks.firstWhere(
        (stock) =>
            stock['tradingsymbol'].toString().toUpperCase() == symbol,
        orElse: () => null,
      );

      if (stockMatch == null) {
        // Skip or add to error format
        fetchTasks.add(Future.value({
          "symbol": symbol,
          "error": "Symbol not found in local data"
        }));
        continue;
      }

      final String instrumentToken = stockMatch['instrument_token'].toString();

      fetchTasks.add(_fetchAndScore(
        symbol,
        instrumentToken,
        fromDateString,
        toDateString,
      ));
    }

    setState(() {
      _statusMessage = "Fetching historical data (${symbols.length} symbols)...";
    });

    final resultsList = await Future.wait(fetchTasks);

    List<Map<String, dynamic>> validResults = [];
    for (var res in resultsList) {
      if (res != null) {
        validResults.add(res);
      }
    }

    // Sort valid results by score descending
    validResults.sort((a, b) {
      final int scoreA = a['score'] ?? -1;
      final int scoreB = b['score'] ?? -1;
      return scoreB.compareTo(scoreA); // Descending
    });

    setState(() {
      _isLoading = false;
      _results = validResults;
    });
  }

  Future<Map<String, dynamic>?> _fetchAndScore(
    String symbol,
    String instrumentToken,
    String fromDate,
    String toDate,
  ) async {
    try {
      final APIResponse response = await HistoryServices.instance
          .getHistoricalData(instrumentToken, fromDate, toDate);

      if (response.status && response.data != null) {
        final List<HistoricalDataModel> historyData =
            response.data as List<HistoricalDataModel>;
        
        try {
          final Map<String, dynamic> scoreResult =
              AIScoreCalculator.calculateAIScore(historyData);
          scoreResult['symbol'] = symbol;
          return scoreResult;
        } catch (e) {
          return {
            "symbol": symbol,
            "error": "Failed to calculate score: ${e.toString()}"
          };
        }
      } else {
        return {
          "symbol": symbol,
          "error": response.error ?? "Failed to fetch data"
        };
      }
    } catch (e) {
      return {
        "symbol": symbol,
        "error": "Network/Parsing error"
      };
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk AI Analysis'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _symbolsController,
              decoration: const InputDecoration(
                labelText: 'Enter symbols (comma-separated)',
                hintText: 'e.g., RELIANCE, TCS, INFY',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                      ),
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

                  if (result.containsKey('error')) {
                    return Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        title: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(result['error'], style: const TextStyle(color: Colors.red)),
                      ),
                    );
                  }

                  final score = result['score'];
                  final verdict = result['verdict'];
                  final price = result['currentPrice'];
                  final verdictColor = _getVerdictColor(score);

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                symbol,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: verdictColor.withOpacity(0.1),
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
                            ],
                          ),
                          const Divider(),
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
                          )
                        ],
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
