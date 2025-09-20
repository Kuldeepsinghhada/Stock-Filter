import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/model/stock_model.dart';

class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key, required this.stock});
  final StockModel stock;
  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen> {
  StockModel? stock;

  @override
  void initState() {
    super.initState();
    stock = widget.stock;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getStockSignal(stock!);
    });
  }

  getStockSignal(StockModel stock) {
    final history = stock.historicalData;
    if (history == null || history.length < 21) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Indicator Check'),
              content: const Text('Not enough historical data.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }
    // Parse arrays
    final highs = history.map((e) => e.high).toList();
    final lows = history.map((e) => e.low).toList();
    final closes = history.map((e) => e.close).toList();
    final volumes = history.map((e) => e.volume).toList();
    // Indicator checks
    final emaPass = IndicatorUtils.isAboveEMA(closes, 20);
    final smaPass = IndicatorUtils.isAboveSMA(closes, 20);
    final rsiPass = IndicatorUtils.isRsiBetween(closes, 14, 55, 85);
    final atrPass = IndicatorUtils.isAtrGreaterThan(
      highs,
      lows,
      closes,
      14,
      1.0,
    );
    final vwapPass = IndicatorUtils.isCloseAboveVWAP(
      highs,
      lows,
      closes,
      volumes,
    );
    final adx = IndicatorUtils.adxConditions(highs, lows, closes, 14, 15);
    final adxPass = adx['adxOk'] == true && adx['plusGreater'] == true;
    final supertrendPass = IndicatorUtils.isCloseAboveSupertrend(
      highs,
      lows,
      closes,
      9,
      3.0,
    );
    final allPassed =
        emaPass &&
        smaPass &&
        rsiPass &&
        atrPass &&
        vwapPass &&
        adxPass &&
        supertrendPass;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Indicator Check'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allPassed
                      ? 'All indicators passed.'
                      : 'Not all indicators passed.',
                ),
                const SizedBox(height: 12),
                Text("EMA (20): ${emaPass ? 'Pass' : 'Fail'}"),
                Text("SMA (20): ${smaPass ? 'Pass' : 'Fail'}"),
                Text("RSI (14) 55-85: ${rsiPass ? 'Pass' : 'Fail'}"),
                Text("ATR (14) > 1.0: ${atrPass ? 'Pass' : 'Fail'}"),
                Text("VWAP (20): ${vwapPass ? 'Pass' : 'Fail'}"),
                Text("ADX (14) > 20 & +DI > -DI: ${adxPass ? 'Pass' : 'Fail'}"),
                Text("Supertrend (9,3): ${supertrendPass ? 'Pass' : 'Fail'}"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Check Screen')),
      body: const Center(child: Text('This is the Stock Check Screen')),
    );
  }
}
