import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Screens/DataScreen/history_services.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/Utils/ai_score_calculator.dart';

class HistoryDataScreen extends StatefulWidget {
  final String instrumentToken;
  final String stockName;
  final String fromDate;
  final String toDate;

  const HistoryDataScreen({
    super.key,
    required this.instrumentToken,
    required this.stockName,
    required this.fromDate,
    required this.toDate,
  });

  @override
  _HistoryDataScreenState createState() => _HistoryDataScreenState();
}

class _HistoryDataScreenState extends State<HistoryDataScreen> {
  bool isLoading = true;
  String errorMessage = "";
  List<HistoricalDataModel> historyData = [];

  @override
  void initState() {
    super.initState();
    _fetchHistoricalData();
  }

  Future<void> _fetchHistoricalData() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      final DateTime toDateDT = DateTime.parse(widget.toDate);
      final int token = int.tryParse(widget.instrumentToken) ?? 0;
      
      final response = await HistoryServices.instance.fetchHistoricalData(
        token,
        toDateDT,
        symbols: [widget.stockName],
      );

      if (response != null) {
        setState(() {
          historyData = response;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to fetch data";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (historyData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to copy')));
      return;
    }

    final List<Map<String, dynamic>> jsonList =
        historyData.map((e) => e.toJson()).toList();
    final jsonString = json.encode(jsonList);
    Clipboard.setData(ClipboardData(text: jsonString)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History Data copied to clipboard!')),
      );
    });
  }



  void showAIResultDialog(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) {
        final score = result["score"];
        final verdict = result["verdict"];

        Color verdictColor;
        if (score >= 75) {
          verdictColor = Colors.green;
        } else if (score >= 60) {
          verdictColor = Colors.orange;
        } else {
          verdictColor = Colors.red;
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Center(
            child: Text(
              "AI Trade Analysis",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score
              Center(
                child: Column(
                  children: [
                    Text(
                      "$score%",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: verdictColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      verdict,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: verdictColor,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              Divider(),

              SizedBox(height: 10),

              _buildRow("Current Price", result["currentPrice"]),
              _buildRow("Support", result["support"]),
              _buildRow("Resistance", result["resistance"]),
              _buildRow("Stoploss", result["stoploss"]),
              _buildRow("Target", result["target"]),

              SizedBox(height: 12),

              Divider(),

              SizedBox(height: 10),

              _buildRow("RSI", result["rsi"]),
              _buildRow("ADX", result["adx"]),
              _buildRow("ATR", result["atr"]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value.toStringAsFixed != null && value is double
                ? value.toStringAsFixed(2)
                : value.toString(),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stockName} History'),
        actions: [
          IconButton(
            onPressed: () {
              try {
                final result = AIScoreCalculator.calculateAIScoreV2(historyData);
                showAIResultDialog(context, result);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            icon: Icon(Icons.score_outlined),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy JSON',
            onPressed: () {
              if (!isLoading && errorMessage.isEmpty) {
                _copyToClipboard();
              }
            },
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : historyData.isEmpty
              ? const Center(child: Text("No data available"))
              : ListView.builder(
                itemCount: historyData.length,
                itemBuilder: (context, index) {
                  final HistoricalDataModel candle = historyData[index];
                  final String timestamp = candle.timestamp
                      .toIso8601String()
                      .substring(0, 10);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Date: $timestamp",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Open: ${candle.open}"),
                              Text("High: ${candle.high}"),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Low: ${candle.low}"),
                              Text("Close: ${candle.close}"),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("Volume: ${candle.volume}"),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
