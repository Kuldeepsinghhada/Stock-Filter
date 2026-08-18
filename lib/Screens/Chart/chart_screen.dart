import 'package:flutter/material.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/chart_data.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/INdicators/indicator_engine.dart';
import 'package:stock_demo/Utils/math_utils.dart';
import 'package:stock_demo/Utils/candle_utils.dart';
import '../../Widgets/custom_trading_chart.dart';
import '../DataScreen/history_services.dart';
import 'indicator_settings_screen.dart';
import '../../Utils/sharepreference_helper.dart';

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

  String _currentTimeframe = "D";
  bool _isLoading = false;

  final ValueNotifier<ChartData?> _hoveredData = ValueNotifier(null);

  @override
  void dispose() {
    _hoveredData.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadIndicatorSettings();
    if (widget.stock.historyFiveMin != null &&
        widget.stock.historyFiveMin!.isNotEmpty) {
      _calculateChartData(widget.stock.historyFiveMin!);
    } else {
      _loadTimeframeData("D");
    }
  }

  Future<void> _loadIndicatorSettings() async {
    final prefs = SharedPreferenceHelper.instance;
    final emaVisible = await prefs.getEmaVisible();
    final supertrendVisible = await prefs.getSupertrendVisible();
    if (mounted) {
      setState(() {
        _showEma = emaVisible;
        _showSupertrend = supertrendVisible;
      });
    }
  }

  Future<void> _loadTimeframeData(String timeframe) async {
    setState(() {
      _isLoading = true;
      _currentTimeframe = timeframe;
    });

    try {
      final HistoryServices historyServices = HistoryServices.instance;
      final candles =
          await historyServices.fetchIntervalData(widget.stock, timeframe);
      _calculateChartData(candles);
    } catch (e) {
      debugPrint("Error loading timeframe data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateChartData(List<HistoricalDataModel> candles) {
    if (candles.isEmpty) {
      setState(() {
        _chartData = [];
      });
      return;
    }

    CandleUtils.sortByTime(candles);

    final closes = candles.map((c) => c.close).toList();
    final ema20 = MathUtils.emaAligned(closes, 20);
    final supertrend = IndicatorUtils.supertrendSeries(IndicatorEngine(candles));

    setState(() {
      _chartData.clear();
      _maxVolume = 0;
      final startIndex = candles.length > 500 ? candles.length - 500 : 0;
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
            i < supertrend.length && supertrend[i] != 0.0
                ? supertrend[i]
                : null,
          ),
        );
      }
    });
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
        title: Text(
          widget.stock.symbol ?? '',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _currentTimeframe,
            tooltip: "Select Timeframe",
            onSelected: (tf) {
              if (tf != _currentTimeframe) {
                _loadTimeframeData(tf);
              }
            },
            itemBuilder: (context) => ["5m", "15m", "1h", "D"].map((tf) {
              return PopupMenuItem<String>(
                value: tf,
                child: Row(
                  children: [
                    Icon(
                      tf == "D" ? Icons.calendar_today : Icons.access_time,
                      size: 18,
                      color: _currentTimeframe == tf
                          ? Colors.blue
                          : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tf == "5m"
                          ? "5 Minutes"
                          : tf == "15m"
                              ? "15 Minutes"
                              : tf == "1h"
                                  ? "1 Hour"
                                  : "Daily",
                      style: TextStyle(
                        color: _currentTimeframe == tf
                            ? Colors.blue
                            : Colors.white,
                        fontWeight: _currentTimeframe == tf
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.query_stats,
                      size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 6),
                  Text(
                    _currentTimeframe,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IndicatorSettingsScreen(),
                ),
              );
              _loadIndicatorSettings();
            },
            tooltip: "Indicator Settings",
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_chartData.isEmpty && !_isLoading)
              const Center(
                child: Text(
                  "No historical data available.",
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else if (_chartData.isNotEmpty)
              Column(
                children: [
                  ValueListenableBuilder<ChartData?>(
                    valueListenable: _hoveredData,
                    builder: (context, hoveredData, _) {
                      if (_chartData.isEmpty) return const SizedBox.shrink();
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
                      key: ValueKey(_currentTimeframe),
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
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
