import 'dart:math';
import 'package:stock_demo/Utils/math_utils.dart';
import 'indicator_engine.dart';

class IndicatorCache {
  final IndicatorEngine engine;

  IndicatorCache(this.engine);

  final Map<int, List<double?>> _emaCache = {};
  final Map<int, List<double>> _atrCache = {};
  final Map<String, List<double>> _adxCache = {};

  List<double> getAdx(int diPeriod, int adxSmoothing) {
    final key = '${diPeriod}_$adxSmoothing';
    if (_adxCache.containsKey(key)) {
      return _adxCache[key]!;
    }

    final highs = engine.highs;
    final lows = engine.lows;
    final closes = engine.closes;
    final n = highs.length;

    if (n < diPeriod + adxSmoothing + 2) return [];

    final tr = <double>[];
    final plusDM = <double>[];
    final minusDM = <double>[];

    for (int i = 1; i < n; i++) {
      final upMove = highs[i] - highs[i - 1];
      final downMove = lows[i - 1] - lows[i];
      tr.add(
        max(
          highs[i] - lows[i],
          max(
            (highs[i] - closes[i - 1]).abs(),
            (lows[i] - closes[i - 1]).abs(),
          ),
        ),
      );
      plusDM.add((upMove > downMove && upMove > 0) ? upMove : 0.0);
      minusDM.add((downMove > upMove && downMove > 0) ? downMove : 0.0);
    }

    double atr = tr.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;
    double pdm = plusDM.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;
    double mdm = minusDM.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;

    final dxList = <double>[];

    for (int i = diPeriod; i < tr.length; i++) {
      atr = ((atr * (diPeriod - 1)) + tr[i]) / diPeriod;
      pdm = ((pdm * (diPeriod - 1)) + plusDM[i]) / diPeriod;
      mdm = ((mdm * (diPeriod - 1)) + minusDM[i]) / diPeriod;

      final plusDI = 100 * (pdm / (atr + 1e-9));
      final minusDI = 100 * (mdm / (atr + 1e-9));
      final dx = 100 * ((plusDI - minusDI).abs() / ((plusDI + minusDI) + 1e-9));
      dxList.add(dx);
    }

    if (dxList.length < adxSmoothing + 1) return [];

    double adx = dxList.sublist(0, adxSmoothing).reduce((a, b) => a + b) / adxSmoothing;
    final adxSeries = <double>[adx];

    for (int i = adxSmoothing; i < dxList.length; i++) {
      adx = ((adx * (adxSmoothing - 1)) + dxList[i]) / adxSmoothing;
      adxSeries.add(adx);
    }

    _adxCache[key] = adxSeries;
    return adxSeries;
  }

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
