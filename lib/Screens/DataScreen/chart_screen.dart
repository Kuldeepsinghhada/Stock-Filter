import 'package:flutter/material.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/chart_data.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/math_utils.dart';
import 'package:stock_demo/Utils/candle_utils.dart';

import 'package:intl/intl.dart';
import '../../Widgets/custom_trading_chart.dart';

class ChartScreen extends StatefulWidget {
  final StockModel stock;

  const ChartScreen({super.key, required this.stock});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  List<ChartData> _chartData = [];

  double _maxVolume = 0;

  bool _showEma = true;
  bool _showSupertrend = true;

  final ValueNotifier<ChartData?> _hoveredData = ValueNotifier(null);

  @override
  void dispose() {
    _hoveredData.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _calculateChartData();
  }

  void _calculateChartData() {
    final List<HistoricalDataModel> candles = widget.stock.historyFiveMin ?? [];

    if (candles.isEmpty) {
      _chartData = [];
      return;
    }

    CandleUtils.sortByTime(candles);

    final closes = candles.map((c) => c.close).toList();
    final ema20 = MathUtils.emaAligned(closes, 20);
    final supertrend = IndicatorUtils.supertrendSeries(candles);

    _chartData.clear();
    _maxVolume = 0;
    final startIndex = candles.length > 200 ? candles.length - 200 : 0;
    for (int i = startIndex; i < candles.length; i++) {
      final c = candles[i];
      if (c.volume > _maxVolume) _maxVolume = c.volume.toDouble();

      _chartData.add(
        ChartData(
          c.timestamp,
          c.open,
          c.high,
          c.low,
          c.close,
          c.volume.toDouble(),
          i < ema20.length && ema20[i] != 0.0 ? ema20[i] : null,
          i < supertrend.length && supertrend[i] != 0.0 ? supertrend[i] : null,
        ),
      );
    }
  }

  String _formatVolume(double vol) {
    if (vol >= 10000000) return "${(vol / 10000000).toStringAsFixed(2)}Cr";
    if (vol >= 100000) return "${(vol / 100000).toStringAsFixed(2)}L";
    if (vol >= 1000) return "${(vol / 1000).toStringAsFixed(2)}K";
    return vol.toStringAsFixed(0);
  }

  Widget _buildInfoItem(String label, double value, Color? valueColor) {
    final bool isVolume = label == "V";
    return Row(
      children: [
        Text("$label: ",
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        Text(isVolume ? _formatVolume(value) : "₹${value.toStringAsFixed(2)}",
            style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showEma ? Icons.trending_up : Icons.trending_flat,
                color: Colors.blue),
            onPressed: () => setState(() => _showEma = !_showEma),
            tooltip: "Toggle EMA",
          ),
          IconButton(
            icon: Icon(_showSupertrend ? Icons.bolt : Icons.flash_off,
                color: Colors.orange),
            onPressed: () => setState(() => _showSupertrend = !_showSupertrend),
            tooltip: "Toggle Supertrend",
          ),
        ],
        title: Text(
          widget.stock.symbol ?? '',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _chartData.isEmpty
            ? const Center(
                child: Text(
                  "No historical data available.",
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : Column(
                children: [
                  ValueListenableBuilder<ChartData?>(
                    valueListenable: _hoveredData,
                    builder: (context, hoveredData, _) {
                      final data = hoveredData ?? _chartData.last;

                      // Calculate change percent relative to previous candle close
                      double change = 0;
                      double changePercent = 0;
                      if (_chartData.length > 1) {
                        final lastIndex = hoveredData != null
                            ? _chartData.indexOf(hoveredData)
                            : _chartData.length - 1;

                        if (lastIndex > 0) {
                          final prevClose = _chartData[lastIndex - 1].close;
                          change = data.close - prevClose;
                          changePercent = (change / prevClose) * 100;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "₹${data.close.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color: change >= 0
                                        ? const Color(0xff26a69a)
                                        : const Color(0xffef5350),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${change >= 0 ? '+' : ''}₹${change.abs().toStringAsFixed(2)} (${changePercent.toStringAsFixed(2)}%)",
                                  style: TextStyle(
                                    color: change >= 0
                                        ? const Color(0xff26a69a)
                                        : const Color(0xffef5350),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoItem("O", data.open, null),
                                _buildInfoItem(
                                    "H", data.high, const Color(0xff26a69a)),
                                _buildInfoItem(
                                    "L", data.low, const Color(0xffef5350)),
                                _buildInfoItem("C", data.close, null),
                                _buildInfoItem(
                                    "V", data.volume, Colors.blueAccent),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: CustomTradingChart(
                      data: _chartData,
                      showEma: _showEma,
                      showSupertrend: _showSupertrend,
                      onHover: (data) {
                        _hoveredData.value = data;
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
