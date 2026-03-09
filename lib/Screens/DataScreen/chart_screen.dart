import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/math_utils.dart';
import 'package:stock_demo/Utils/candle_utils.dart';

import 'package:intl/intl.dart';

class ChartData {
  final DateTime x;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double? ema20;
  final double? supertrend;

  ChartData(
    this.x,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.ema20,
    this.supertrend,
  );
}

class ChartScreen extends StatefulWidget {
  final StockModel stock;

  const ChartScreen({super.key, required this.stock});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  List<ChartData> _chartData = [];
  late ZoomPanBehavior _zoomPanBehavior;

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

    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      zoomMode: ZoomMode.x,
      enableDirectionalZooming: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
    );

    _calculateChartData();

    /// 🔥 Initial Zoom → Always show last 100 candles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      double visiblePercent =
          _chartData.length > 0 ? (100 / _chartData.length) : 1;

      if (visiblePercent < 1) {
        _zoomPanBehavior.zoomByFactor(
          1 - visiblePercent, // 👈 Always END
        );
      }
    });
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
    final startIndex = candles.length > 100 ? candles.length - 100 : 0;
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
    return Row(
      children: [
        Text("$label: ",
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        Text(value > 1000 ? _formatVolume(value) : value.toStringAsFixed(2),
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
                    builder: (context, data, _) {
                      if (data == null) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem("O", data.open, null),
                            _buildInfoItem("H", data.high, Colors.green),
                            _buildInfoItem("L", data.low, Colors.red),
                            _buildInfoItem("C", data.close, null),
                            _buildInfoItem("V", data.volume, Colors.blueAccent),
                          ],
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: SfCartesianChart(
                      backgroundColor: Colors.black,
                      zoomPanBehavior: _zoomPanBehavior,

                      onTrackballPositionChanging: (TrackballArgs args) {
                        final int? index = args.chartPointInfo.dataPointIndex;
                        if (index != null &&
                            index >= 0 &&
                            index < _chartData.length) {
                          Future.microtask(
                              () => _hoveredData.value = _chartData[index]);
                        }
                      },

                      trackballBehavior: TrackballBehavior(
                        enable: true,
                        activationMode: ActivationMode.singleTap,
                        tooltipDisplayMode: TrackballDisplayMode
                            .none, // Hide default center tooltip
                        lineType: TrackballLineType.none,
                      ),

                      /// 🔥 Full Crosshair lines
                      crosshairBehavior: CrosshairBehavior(
                        enable: true,
                        activationMode: ActivationMode.singleTap,
                        lineType: CrosshairLineType.both,
                        lineDashArray: const <double>[5, 5],
                        lineColor: Colors.white54,
                      ),

                      legend: const Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                        textStyle: TextStyle(color: Colors.white70),
                      ),

                      axes: <ChartAxis>[
                        NumericAxis(
                          name: 'VolumeAxis',
                          opposedPosition: false,
                          isVisible: false, // hide labels for a clean overlay
                          minimum: 0,
                          maximum: _maxVolume *
                              4, // Keeps volume bars in the bottom 25% of chart
                        )
                      ],

                      /// 🔥 Important → Named Axis
                      primaryXAxis: DateTimeCategoryAxis(
                        name: 'Time',
                        majorGridLines: const MajorGridLines(
                            width: 0.3, color: Colors.white10),
                        axisLine: const AxisLine(color: Colors.white24),
                        labelStyle: const TextStyle(color: Colors.white70),
                        plotOffsetEnd: 40,
                        initialZoomFactor: 0.30257161495588086,
                        initialZoomPosition: 0.6974283850441192,
                        dateFormat: DateFormat('dd MMM yy HH:mm'),
                        interactiveTooltip: const InteractiveTooltip(
                          enable: true,
                          color: Color(0xff293144),
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      primaryYAxis: const NumericAxis(
                        opposedPosition: true,
                        majorGridLines:
                            MajorGridLines(width: 0.3, color: Colors.white10),
                        axisLine: AxisLine(color: Colors.white24),
                        labelStyle: TextStyle(color: Colors.white70),
                        enableAutoIntervalOnZooming: true,
                        interactiveTooltip: const InteractiveTooltip(
                          enable: true,
                          color: Color(0xff293144),
                          decimalPlaces: 2,
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      series: [
                        CandleSeries<ChartData, DateTime>(
                          name: 'Price',
                          dataSource: _chartData,
                          xValueMapper: (data, _) => data.x,
                          lowValueMapper: (data, _) => data.low,
                          highValueMapper: (data, _) => data.high,
                          openValueMapper: (data, _) => data.open,
                          closeValueMapper: (data, _) => data.close,
                          bullColor: const Color(0xff26a69a),
                          bearColor: const Color(0xffef5350),
                          enableSolidCandles: true,
                          // Width must be between 0 and 1 (relative width). Use 0.9
                          // for a visually thicker candle while staying within the
                          // valid range.
                          width: 0.9,
                          spacing: 0.02,
                        ),
                        ColumnSeries<ChartData, DateTime>(
                          name: 'Volume',
                          dataSource: _chartData,
                          xValueMapper: (data, _) => data.x,
                          yValueMapper: (data, _) => data.volume,
                          yAxisName: 'VolumeAxis',
                          pointColorMapper: (data, _) => data.close >= data.open
                              ? const Color(0xff26a69a).withAlpha((0.5 * 255).round())
                              : const Color(0xffef5350).withAlpha((0.5 * 255).round()),
                        ),
                        if (_showEma)
                          LineSeries<ChartData, DateTime>(
                            name: 'EMA 20',
                            dataSource: _chartData,
                            xValueMapper: (data, _) => data.x,
                            yValueMapper: (data, _) => data.ema20,
                            color: const Color(0xffef5350), // Changed to red
                            width: 2,
                          ),
                        if (_showSupertrend)
                          LineSeries<ChartData, DateTime>(
                            name: 'Supertrend',
                            dataSource: _chartData,
                            xValueMapper: (data, _) => data.x,
                            yValueMapper: (data, _) => data.supertrend,
                            pointColorMapper: (data, _) => data.supertrend !=
                                        null &&
                                    data.close < data.supertrend!
                                ? const Color(
                                    0xffef5350) // Red if price below supertrend
                                : const Color(0xff26a69a), // Green otherwise
                            width: 2,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
