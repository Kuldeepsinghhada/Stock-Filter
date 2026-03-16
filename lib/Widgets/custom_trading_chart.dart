import 'package:flutter/material.dart';
import 'dart:ui' show TextDirection;
import 'package:intl/intl.dart' as intl;
import 'dart:math' as math;
import '../model/chart_data.dart';

class CustomTradingChart extends StatefulWidget {
  final List<ChartData> data;
  final bool showEma;
  final bool showSupertrend;
  final Function(ChartData?)? onHover;

  const CustomTradingChart({
    super.key,
    required this.data,
    this.showEma = true,
    this.showSupertrend = true,
    this.onHover,
  });

  @override
  State<CustomTradingChart> createState() => _CustomTradingChartState();
}

class _CustomTradingChartState extends State<CustomTradingChart> {
  // Horizontal scale/scroll
  double _candleWidth = 10.0;
  double _scrollOffset = 0.0;

  // Vertical scale/offset
  double _priceScale = 1.0;
  double _priceOffset =
      0.0; // Offset from the bottom or center? Let's use it as a shift.

  // Interaction states
  Offset? _crosshairPosition;
  bool _isDraggingPriceAxis = false;
  double _lastScale = 1.0;

  // To handle auto-scale
  bool _autoScale = true;

  @override
  void initState() {
    super.initState();
    // Initialize scroll to show the latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    if (widget.data.isEmpty) return;
    setState(() {
      final totalWidth = widget.data.length * _candleWidth;
      final viewportWidth = context.size?.width ?? 400;
      final extraSpace = (viewportWidth - 60) * 0.2; // 20% right padding
      _scrollOffset =
          math.max(-extraSpace, totalWidth - (viewportWidth - 60) + extraSpace);
    });
  }

  void _updateHoveredData(Offset position, double chartWidth) {
    if (position.dx > chartWidth || position.dx < 0) {
      widget.onHover?.call(null);
      return;
    }
    int index = ((_scrollOffset + position.dx) / _candleWidth).floor();
    if (index >= 0 && index < widget.data.length) {
      widget.onHover?.call(widget.data[index]);
    } else {
      widget.onHover?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double chartWidth = width - 60; // 60 for price axis
        final double chartHeight = height - 30; // 30 for time axis

        return Stack(
          children: [
            GestureDetector(
              onScaleStart: (details) {
                _lastScale = _candleWidth;
                if (details.localFocalPoint.dx > chartWidth) {
                  _isDraggingPriceAxis = true;
                } else {
                  _isDraggingPriceAxis = false;
                }
              },
              onScaleUpdate: (details) {
                setState(() {
                  if (details.pointerCount == 2) {
                    _candleWidth =
                        (_lastScale * details.scale).clamp(2.0, 50.0);

                    // Optional: Vertical zoom if not in auto-scale
                    if (!_autoScale) {
                      _priceScale *= details.verticalScale;
                    }
                  } else if (details.pointerCount == 1) {
                    if (_isDraggingPriceAxis) {
                      // Drag on price axis to scale vertically
                      // TradingView style: dragging DOWN expands (smaller scale factor?),
                      // actually dragging UP usually compresses/scales up.
                      double deltaY = details.focalPointDelta.dy;
                      _priceScale *= (1 - deltaY / height);
                      _priceScale = _priceScale.clamp(0.01, 100.0);
                      _autoScale = false;
                    } else {
                      // Pan
                      _scrollOffset -= details.focalPointDelta.dx;
                      // Allow scrolling to see whitespace on the right (TradingView style)
                      final maxScroll = widget.data.length * _candleWidth;
                      _scrollOffset = _scrollOffset.clamp(
                          -chartWidth * 0.8, maxScroll + chartWidth * 0.5);

                      if (!_autoScale) {
                        _priceOffset -= details.focalPointDelta.dy;
                      }

                      _crosshairPosition = details.localFocalPoint;
                      _updateHoveredData(details.localFocalPoint, chartWidth);
                    }
                  }
                });
              },
              onTapDown: (details) {
                setState(() {
                  _crosshairPosition = details.localPosition;
                  _updateHoveredData(details.localPosition, chartWidth);
                });
              },
              onDoubleTap: () {
                setState(() {
                  _autoScale = !_autoScale;
                  if (_autoScale) {
                    _priceScale = 1.0;
                    _priceOffset = 0.0;
                  }
                });
              },
              onLongPressStart: (details) {
                setState(() {
                  _crosshairPosition = details.localPosition;
                  _updateHoveredData(details.localPosition, chartWidth);
                });
              },
              onLongPressMoveUpdate: (details) {
                setState(() {
                  _crosshairPosition = details.localPosition;
                  _updateHoveredData(details.localPosition, chartWidth);
                });
              },
              child: CustomPaint(
                size: Size(width, height),
                painter: ChartPainter(
                  data: widget.data,
                  candleWidth: _candleWidth,
                  scrollOffset: _scrollOffset,
                  priceScale: _priceScale,
                  priceOffset: _priceOffset,
                  crosshairPosition: _crosshairPosition,
                  showEma: widget.showEma,
                  showSupertrend: widget.showSupertrend,
                  autoScale: _autoScale,
                ),
              ),
            ),
            // Reset Button
            Positioned(
              right: 70,
              bottom: 40,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _candleWidth = 10.0;
                    _scrollOffset = 0.0;
                    _priceScale = 1.0;
                    _priceOffset = 0.0;
                    _autoScale = true;
                    _scrollToEnd();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff293144).withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_motion,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<ChartData> data;
  final double candleWidth;
  final double scrollOffset;
  final double priceScale;
  final double priceOffset;
  final Offset? crosshairPosition;
  final bool showEma;
  final bool showSupertrend;
  final bool autoScale;

  ChartPainter({
    required this.data,
    required this.candleWidth,
    required this.scrollOffset,
    required this.priceScale,
    required this.priceOffset,
    required this.crosshairPosition,
    required this.showEma,
    required this.showSupertrend,
    required this.autoScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double chartWidth = size.width - 60;
    final double chartHeight = size.height - 30;

    // 1. Determine visible range
    int startIndex = (scrollOffset / candleWidth).floor();
    int endIndex = ((scrollOffset + chartWidth) / candleWidth).ceil();

    startIndex = startIndex.clamp(0, data.length - 1);
    endIndex = endIndex.clamp(0, data.length - 1);

    // 2. Calculate min/max price for visible range
    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;

    for (int i = startIndex; i <= endIndex; i++) {
      if (data[i].low < minPrice) minPrice = data[i].low;
      if (data[i].high > maxPrice) maxPrice = data[i].high;
    }

    // Add some padding
    double padding = (maxPrice - minPrice) * 0.30;
    if (padding == 0) padding = 1.0;
    minPrice -= padding;
    maxPrice += padding;

    final double scaleY = autoScale
        ? chartHeight / (maxPrice - minPrice)
        : (chartHeight / (maxPrice - minPrice)) * priceScale;

    final double offsetY = autoScale
        ? -minPrice * scaleY + chartHeight
        : -minPrice * scaleY + chartHeight + priceOffset;

    double worldToScreenY(double price) {
      return chartHeight -
          ((price - minPrice) * scaleY) -
          (autoScale ? 0 : priceOffset);
      // Wait, let's simplify Y mapping
    }

    // Better Y mapping
    double getY(double price) {
      if (autoScale) {
        return chartHeight -
            ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;
      } else {
        // Center the scaling around the middle of the chart?
        // Or just apply scale and offset.
        double normalized = (price - minPrice) / (maxPrice - minPrice);
        return chartHeight -
            (normalized * chartHeight * priceScale) -
            priceOffset;
      }
    }

    // Drawing helpers
    final Paint gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;

    final Paint bullPaint = Paint()
      ..color = const Color(0xff26a69a)
      ..style = PaintingStyle.fill;

    final Paint bearPaint = Paint()
      ..color = const Color(0xffef5350)
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 3. Draw Grid Lines
    // Vertical grid
    for (int i = startIndex; i <= endIndex; i++) {
      if (i % 10 == 0) {
        double x = (i * candleWidth) - scrollOffset + candleWidth / 2;
        if (x >= 0 && x <= chartWidth) {
          canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), gridPaint);
        }
      }
    }

    // Horizontal grid & Dynamic Price Axis Labels
    // Use fixed pixel intervals (e.g. every 50-80 pixels) for modern feel
    const double labelStepY = 50.0;
    for (double y = 0; y <= chartHeight; y += labelStepY) {
      double price = _getTooltipPrice(y, minPrice, maxPrice, chartHeight);

      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);

      // Draw price labels on the right
      TextSpan span = TextSpan(
        style: const TextStyle(color: Colors.white70, fontSize: 10),
        text: "₹${price.toStringAsFixed(2)}",
      );
      TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(chartWidth + 5, y - tp.height / 2));
    }

    // 4. Draw Volume Bars (at bottom 20% of chart)
    double maxVolume = 0;
    for (int i = startIndex; i <= endIndex; i++) {
      if (data[i].volume > maxVolume) maxVolume = data[i].volume;
    }

    for (int i = startIndex; i <= endIndex; i++) {
      final d = data[i];
      double x = (i * candleWidth) - scrollOffset;
      if (x + candleWidth < 0 || x > chartWidth) continue;

      double volHeight = (d.volume / (maxVolume * 4)) *
          chartHeight; // Use maxVolume * 4 for 25% height
      Color volColor = d.close >= d.open
          ? const Color(0xff26a69a).withOpacity(0.3)
          : const Color(0xffef5350).withOpacity(0.3);

      canvas.drawRect(
          Rect.fromLTWH(x + candleWidth * 0.1, chartHeight - volHeight,
              candleWidth * 0.8, volHeight),
          Paint()..color = volColor);
    }

    // 5. Draw Candlesticks and Indicators
    for (int i = startIndex; i <= endIndex; i++) {
      final d = data[i];
      double x = (i * candleWidth) - scrollOffset;
      double centerX = x + candleWidth / 2;

      if (x + candleWidth < 0 || x > chartWidth) continue;

      double highY = getY(d.high);
      double lowY = getY(d.low);
      double openY = getY(d.open);
      double closeY = getY(d.close);

      Color color =
          d.close >= d.open ? const Color(0xff26a69a) : const Color(0xffef5350);
      Paint candlePaint = Paint()..color = color;

      // Wick
      canvas.drawLine(
          Offset(centerX, highY), Offset(centerX, lowY), candlePaint);

      // Body
      double bodyTop = math.min(openY, closeY);
      double bodyBottom = math.max(openY, closeY);
      if ((bodyBottom - bodyTop).abs() < 1) {
        bodyBottom = bodyTop + 1;
      }

      canvas.drawRect(
          Rect.fromLTRB(x + candleWidth * 0.1, bodyTop, x + candleWidth * 0.9,
              bodyBottom),
          candlePaint);
    }

    // 5. Indicators (Lines)
    if (showEma) {
      final Paint emaPaint = Paint()
        ..color = const Color(0xffef5350)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      Path path = Path();
      bool first = true;
      for (int i = startIndex; i <= endIndex; i++) {
        if (data[i].ema20 == null) continue;
        double x = (i * candleWidth) - scrollOffset + candleWidth / 2;
        double y = getY(data[i].ema20!);

        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, emaPaint);
    }

    if (showSupertrend) {
      // Drawing supertrend with color changes
      for (int i = startIndex + 1; i <= endIndex; i++) {
        if (data[i].supertrend == null || data[i - 1].supertrend == null)
          continue;

        double x1 = ((i - 1) * candleWidth) - scrollOffset + candleWidth / 2;
        double y1 = getY(data[i - 1].supertrend!);
        double x2 = (i * candleWidth) - scrollOffset + candleWidth / 2;
        double y2 = getY(data[i].supertrend!);

        Color color = data[i].close < data[i].supertrend!
            ? const Color(0xffef5350)
            : const Color(0xff26a69a);
        canvas.drawLine(
            Offset(x1, y1),
            Offset(x2, y2),
            Paint()
              ..color = color
              ..strokeWidth = 2);
      }
    }

    // 6. Time Axis Labels
    for (int i = startIndex; i <= endIndex; i++) {
      if (i % (chartWidth / candleWidth / 4).ceil() == 0 ||
          i == startIndex ||
          i == endIndex) {
        double x = (i * candleWidth) - scrollOffset + candleWidth / 2;
        if (x >= 0 && x <= chartWidth) {
          String timeText = intl.DateFormat('HH:mm').format(data[i].x);
          if (i == 0 || data[i].x.day != data[i - 1].x.day) {
            timeText = intl.DateFormat('dd MMM').format(data[i].x);
          }

          TextPainter tp = TextPainter(
            text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                text: timeText),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x - tp.width / 2, chartHeight + 10));
        }
      }
    }

    // 7. Crosshair
    if (crosshairPosition != null &&
        crosshairPosition!.dx <= chartWidth &&
        crosshairPosition!.dy <= chartHeight) {
      final Paint crosshairPaint = Paint()
        ..color = Colors.white54
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      _drawDashedLine(canvas, Offset(0, crosshairPosition!.dy),
          Offset(chartWidth, crosshairPosition!.dy), crosshairPaint);
      _drawDashedLine(canvas, Offset(crosshairPosition!.dx, 0),
          Offset(crosshairPosition!.dx, chartHeight), crosshairPaint);

      // Tooltips on axes
      // Price tooltip
      _drawTooltip(
          canvas,
          "₹${_getTooltipPrice(crosshairPosition!.dy, minPrice, maxPrice, chartHeight).toStringAsFixed(2)}",
          Offset(chartWidth + 5, crosshairPosition!.dy - 10));

      // Time tooltip
      int index =
          ((scrollOffset + crosshairPosition!.dx) / candleWidth).floor();
      if (index >= 0 && index < data.length) {
        String timeText = intl.DateFormat('dd MMM HH:mm').format(data[index].x);
        _drawTooltip(canvas, timeText,
            Offset(crosshairPosition!.dx - 30, chartHeight + 5));
      }
    }

    // 8. Draw Indicator Labels on Y-axis
    final lastData = data.last;

    // EMA Label
    if (showEma && lastData.ema20 != null) {
      _drawPriceAxisLabel(canvas, lastData.ema20!, const Color(0xffef5350),
          chartWidth, chartHeight, getY);
    }

    // Supertrend Label
    if (showSupertrend && lastData.supertrend != null) {
      final Color stColor = lastData.close < lastData.supertrend!
          ? const Color(0xffef5350)
          : const Color(0xff26a69a);
      _drawPriceAxisLabel(
          canvas, lastData.supertrend!, stColor, chartWidth, chartHeight, getY,
          isSecondary: true);
    }

    // 9. Draw Last Price Label on Y-axis
    final double lastPriceY = getY(lastData.close);
    if (lastPriceY >= 0 && lastPriceY <= chartHeight) {
      final Color lastPriceColor = lastData.close >= lastData.open
          ? const Color(0xff26a69a)
          : const Color(0xffef5350);

      _drawPriceAxisLabel(
          canvas, lastData.close, lastPriceColor, chartWidth, chartHeight, getY,
          drawDashedLine: true);
    }
  }

  void _drawPriceAxisLabel(Canvas canvas, double price, Color color,
      double width, double height, double Function(double) getY,
      {bool drawDashedLine = false, bool isSecondary = false}) {
    final double y = getY(price);
    if (y < 0 || y > height) return;

    final Paint paint = Paint()..color = color;
    final String priceText = "₹${price.toStringAsFixed(2)}";
    final TextPainter tp = TextPainter(
      text: TextSpan(
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        text: priceText,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double labelWidth = tp.width + 8;
    final double labelHeight = tp.height + 4;

    // Background rect
    canvas.drawRect(
        Rect.fromLTWH(width, y - labelHeight / 2, labelWidth, labelHeight),
        paint);

    // Text
    tp.paint(canvas, Offset(width + 4, y - tp.height / 2));

    if (drawDashedLine) {
      final Paint dashedLinePaint = Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 0.5;
      _drawDashedLine(canvas, Offset(0, y), Offset(width, y), dashedLinePaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 5;
    const double dashSpace = 5;
    double distance = (p2 - p1).distance;
    double dx = (p2.dx - p1.dx) / distance;
    double dy = (p2.dy - p1.dy) / distance;
    double currentDistance = 0;
    while (currentDistance < distance) {
      canvas.drawLine(
        Offset(p1.dx + dx * currentDistance, p1.dy + dy * currentDistance),
        Offset(
          p1.dx + dx * math.min(currentDistance + dashWidth, distance),
          p1.dy + dy * math.min(currentDistance + dashWidth, distance),
        ),
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  double _getTooltipPrice(
      double y, double minPrice, double maxPrice, double height) {
    if (autoScale) {
      return maxPrice - (y / height) * (maxPrice - minPrice);
    } else {
      // Inverse of getY
      // y = height - (normalized * height * priceScale) - priceOffset
      double normalized = (height - y - priceOffset) / (height * priceScale);
      return normalized * (maxPrice - minPrice) + minPrice;
    }
  }

  void _drawTooltip(Canvas canvas, String text, Offset offset) {
    TextPainter tp = TextPainter(
      text: TextSpan(
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          text: text),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.drawRect(
        Rect.fromLTWH(
            offset.dx - 2, offset.dy - 2, tp.width + 4, tp.height + 4),
        Paint()..color = const Color(0xff293144));
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return true; // Simplified for now
  }
}
