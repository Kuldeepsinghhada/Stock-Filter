import 'dart:math';
import 'package:stock_demo/Utils/math_utils.dart';
import 'indicator_engine.dart';

class IndicatorCache {
  final IndicatorEngine engine;

  IndicatorCache(this.engine);

  final Map<int, List<double?>> _emaCache = {};
  final Map<int, List<double>> _atrCache = {};

  List<double?> getEma(int period) {
    if (_emaCache.containsKey(period)) {
      return _emaCache[period]!;
    }
    final closes = engine.closes;
    final ema = MathUtils.emaAligned(closes, period);
    _emaCache[period] = ema;
    return ema;
  }

  List<double> getAtr(int period) {
    if (_atrCache.containsKey(period)) {
      return _atrCache[period]!;
    }
    
    final highs = engine.highs;
    final lows = engine.lows;
    final closes = engine.closes;
    final n = closes.length;
    
    if (n < 2 || highs.length != n || lows.length != n) return [];

    final tr = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      if (i == 0) {
        tr[i] = highs[i] - lows[i];
      } else {
        tr[i] = max(
          highs[i] - lows[i],
          max(
            (highs[i] - closes[i - 1]).abs(),
            (lows[i] - closes[i - 1]).abs(),
          ),
        );
      }
    }

    if (n < period) return [];

    final atr = List<double>.filled(n, 0.0);
    double initialAtr = 0.0;
    for (int i = 0; i < period; i++) {
      initialAtr += tr[i];
    }
    initialAtr /= period;
    atr[period - 1] = initialAtr;

    for (int i = period; i < n; i++) {
      atr[i] = ((atr[i - 1] * (period - 1)) + tr[i]) / period;
    }

    _atrCache[period] = atr;
    return atr;
  }
}
