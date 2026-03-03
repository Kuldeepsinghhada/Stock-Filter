import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/math_utils.dart';
import 'package:stock_demo/Utils/candle_utils.dart';

class ChartData {
  final DateTime x;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? ema20;
  final double? supertrend;

  ChartData(
      this.x,
      this.open,
      this.high,
      this.low,
      this.close,
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

  double? _savedZoomFactor;
  double? _savedZoomPosition;

  bool _showEma = true;
  bool _showSupertrend = true;

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
    final List<HistoricalDataModel> candles =
        widget.stock.historyFiveMin ?? [];

    if (candles.isEmpty) {
      _chartData = [];
      return;
    }

    CandleUtils.sortByTime(candles);

    final closes = candles.map((c) => c.close).toList();
    final ema20 = MathUtils.emaAligned(closes, 20);
    final supertrend = IndicatorUtils.supertrendSeries(candles);

    _chartData.clear();
    final startIndex = candles.length > 100 ? candles.length - 100 : 0;
    for (int i = startIndex; i < candles.length; i++) {
      final c = candles[i];

      _chartData.add(
        ChartData(
          c.timestamp,
          c.open,
          c.high,
          c.low,
          c.close,
          i < ema20.length ? ema20[i] : null,
          i < supertrend.length && supertrend[i] != 0.0
              ? supertrend[i]
              : null,
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}-${dt.month} "
        "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
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
            : SfCartesianChart(
          backgroundColor: Colors.black,
          zoomPanBehavior: _zoomPanBehavior,

          /// 🔥 Save Zoom Data
          onZoomEnd: (ZoomPanArgs args) {
            if (args.axis?.name == 'Time') {
              _savedZoomFactor = args.currentZoomFactor;
              _savedZoomPosition = args.currentZoomPosition;
            }
          },

          /// 🔥 Trackball with OHLC
          trackballBehavior: TrackballBehavior(
            enable: true,
            activationMode: ActivationMode.singleTap,
            tooltipDisplayMode:
            TrackballDisplayMode.floatAllPoints,
            lineType: TrackballLineType.vertical,
            lineColor: Colors.white38,
            builder: (context, details) {
              if (details.pointIndex == null)
                return const SizedBox();

              final data =
              _chartData[details.pointIndex!];

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius:
                  BorderRadius.circular(6),
                  border:
                  Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDate(data.x),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        "O: ${data.open.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Colors.white70)),
                    Text(
                        "H: ${data.high.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Colors.green)),
                    Text(
                        "L: ${data.low.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Colors.red)),
                    Text(
                        "C: ${data.close.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Colors.white)),
                  ],
                ),
              );
            },
          ),

          legend: const Legend(
            isVisible: true,
            position: LegendPosition.bottom,
            textStyle:
            TextStyle(color: Colors.white70),
          ),

          /// 🔥 Important → Named Axis
          primaryXAxis: DateTimeCategoryAxis(
            name: 'Time',
            majorGridLines: const MajorGridLines(
                width: 0.3,
                color: Colors.white10),
            axisLine:
            const AxisLine(color: Colors.white24),
            labelStyle:
            const TextStyle(color: Colors.white70),
            plotOffsetEnd: 40,
            initialZoomFactor: 0.30257161495588086,
            initialZoomPosition: 0.6974283850441192,
          ),

          primaryYAxis: const NumericAxis(
            opposedPosition: true,
            majorGridLines: MajorGridLines(
                width: 0.3,
                color: Colors.white10),
            axisLine:
            AxisLine(color: Colors.white24),
            labelStyle:
            TextStyle(color: Colors.white70),
            enableAutoIntervalOnZooming: true,
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
              bullColor:
              const Color(0xff26a69a),
              bearColor:
              const Color(0xffef5350),
              enableSolidCandles: true,
              width: 0.8,
              spacing: 0.05,
            ),

            if (_showEma)
              LineSeries<ChartData, DateTime>(
                name: 'EMA 20',
                dataSource: _chartData,
                xValueMapper: (data, _) => data.x,
                yValueMapper: (data, _) => data.ema20,
                color:
                const Color(0xff42a5f5),
                width: 2,
              ),

            if (_showSupertrend)
              LineSeries<ChartData, DateTime>(
                name: 'Supertrend',
                dataSource: _chartData,
                xValueMapper: (data, _) => data.x,
                yValueMapper:
                    (data, _) => data.supertrend,
                color:
                const Color(0xffffa726),
                width: 2,
              ),
          ],
        ),
      ),
    );
  }
}