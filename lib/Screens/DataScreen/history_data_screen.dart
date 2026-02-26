import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Screens/DataScreen/history_services.dart';
import 'package:stock_demo/model/historical_data_model.dart';

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

    final response = await HistoryServices.instance.getHistoricalData(
      widget.instrumentToken,
      widget.fromDate,
      widget.toDate,
    );

    if (response.status) {
      setState(() {
        historyData = response.data as List<HistoricalDataModel>;
        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = response.error ?? "Failed to fetch data";
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

  Map<String, dynamic> calculateAIScore() {
    List<HistoricalDataModel> candles = historyData;
    if (candles.length < 200) {
      throw Exception("Minimum 200 candles required");
    }
    final closes = candles.map((c) => c.close).toList();
    final highs = candles.map((c) => c.high).toList();
    final lows = candles.map((c) => c.low).toList();
    final volumes = candles.map((c) => c.volume.toDouble()).toList();
    final last = candles.last;

    double sma(List<double> arr, int period) {
      return arr.sublist(arr.length - period).reduce((a, b) => a + b) / period;
    }

    double ema(List<double> arr, int period) {
      final k = 2 / (period + 1);
      double emaVal = sma(arr.sublist(0, period), period);

      for (int i = period; i < arr.length; i++) {
        emaVal = arr[i] * k + emaVal * (1 - k);
      }
      return emaVal;
    }

    double calculateRSI(List<double> arr, {int period = 14}) {
      double gains = 0, losses = 0;

      for (int i = arr.length - period - 1; i < arr.length - 1; i++) {
        final diff = arr[i + 1] - arr[i];
        if (diff > 0) {
          gains += diff;
        } else {
          losses -= diff;
        }
      }

      final avgGain = gains / period;
      final avgLoss = losses == 0 ? 1 : losses / period;
      final rs = avgGain / avgLoss;

      return 100 - (100 / (1 + rs));
    }

    double calculateATR({int period = 14}) {
      List<double> trs = [];

      for (int i = highs.length - period; i < highs.length; i++) {
        final prevClose = closes[i - 1];
        final tr = [
          highs[i] - lows[i],
          (highs[i] - prevClose).abs(),
          (lows[i] - prevClose).abs(),
        ].reduce((a, b) => a > b ? a : b);

        trs.add(tr);
      }

      return trs.reduce((a, b) => a + b) / period;
    }

    double calculateADX({int period = 14}) {
      double plusDM = 0, minusDM = 0, trSum = 0;

      for (int i = highs.length - period; i < highs.length; i++) {
        final upMove = highs[i] - highs[i - 1];
        final downMove = lows[i - 1] - lows[i];

        if (upMove > downMove && upMove > 0) plusDM += upMove;
        if (downMove > upMove && downMove > 0) minusDM += downMove;

        final tr = [
          highs[i] - lows[i],
          (highs[i] - closes[i - 1]).abs(),
          (lows[i] - closes[i - 1]).abs(),
        ].reduce((a, b) => a > b ? a : b);

        trSum += tr;
      }

      final plusDI = (plusDM / trSum) * 100;
      final minusDI = (minusDM / trSum) * 100;

      return ((plusDI - minusDI).abs() / (plusDI + minusDI)) * 100;
    }

    final ema20 = ema(closes, 20);
    final ema50 = ema(closes, 50);
    final ema200 = ema(closes, 200);
    final rsi = calculateRSI(closes);
    final atr = calculateATR();
    final adx = calculateADX();
    final avgVol20 = sma(volumes, 20);

    double score = 0;

    // Trend (25)
    if (ema20 > ema50) score += 10;
    if (ema50 > ema200) score += 10;
    if (last.close > ema20) score += 5;

    // Momentum (20)
    if (rsi > 55 && rsi < 70) score += 10;
    if (adx > 20) score += 5;
    if (last.high > highs[highs.length - 2]) score += 5;

    // Volume (20)
    if (last.volume > avgVol20) score += 8;
    if (last.volume > avgVol20 * 1.5) score += 7;
    if (volumes.sublist(volumes.length - 3).every((v) => v > avgVol20 * 0.8))
      score += 5;

    // Structure (20)
    final recentLow = lows
        .sublist(lows.length - 20)
        .reduce((a, b) => a < b ? a : b);
    final prevLow = lows
        .sublist(lows.length - 40, lows.length - 20)
        .reduce((a, b) => a < b ? a : b);

    if (recentLow > prevLow) score += 10;
    if (last.close > ema50) score += 10;

    // Risk Reward (15)
    final stoploss = last.close - (1.5 * atr);
    final target = last.close + (2 * atr);

    final risk = last.close - stoploss;
    final reward = target - last.close;

    if (reward / risk >= 1.5) score += 8;
    if (risk / last.close <= 0.05) score += 7;

    String verdict = "Avoid";
    if (score >= 75) {
      verdict = "Strong Buy";
    } else if (score >= 60) {
      verdict = "Moderate Buy";
    } else if (score >= 45) {
      verdict = "Average";
    }

    return {
      "score": score.round(),
      "verdict": verdict,
      "currentPrice": last.close,
      "support": recentLow,
      "resistance": highs
          .sublist(highs.length - 20)
          .reduce((a, b) => a > b ? a : b),
      "stoploss": stoploss,
      "target": target,
      "rsi": rsi,
      "adx": adx,
      "atr": atr,
    };
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
              final result = calculateAIScore();
              showAIResultDialog(context, result);
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
