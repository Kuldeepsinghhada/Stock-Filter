import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/Utils/indicators.dart';

class AIScoreCalculator {
  // ================= PATTERN DETECTOR =================
  static List<String> detectBullishPatterns(List<HistoricalDataModel> candles) {
    if (candles.length < 30) return [];

    List<String> patterns = [];

    final opens = candles.map((c) => c.open).toList();
    final closes = candles.map((c) => c.close).toList();
    final highs = candles.map((c) => c.high).toList();
    final lows = candles.map((c) => c.low).toList();
    final volumes = candles.map((c) => c.volume.toDouble()).toList();

    final last = candles.last;
    final prev = candles[candles.length - 2];

    double avgVol20 =
        volumes.sublist(volumes.length - 20).reduce((a, b) => a + b) / 20;

    // 1️⃣ Bullish Engulfing
    if (prev.close < prev.open &&
        last.close > last.open &&
        last.close > prev.open &&
        last.open < prev.close) {
      patterns.add("Bullish Engulfing");
    }

    // 2️⃣ Volume Breakout
    double recentHigh =
        highs.sublist(highs.length - 20).reduce((a, b) => a > b ? a : b);

    if (last.close > recentHigh && last.volume > avgVol20 * 1.5) {
      patterns.add("Volume Breakout");
    }

    // 3️⃣ HHHL Structure
    double recentLow =
        lows.sublist(lows.length - 10).reduce((a, b) => a < b ? a : b);

    double prevLow = lows
        .sublist(lows.length - 20, lows.length - 10)
        .reduce((a, b) => a < b ? a : b);

    if (recentLow > prevLow) {
      patterns.add("HHHL Structure");
    }

    // 4️⃣ EMA20 Bounce
    double ema20 = IndicatorUtils.isCloseAboveEMA(candles, 20).value;

    if (last.low <= ema20 && last.close > ema20) {
      patterns.add("EMA20 Bounce");
    }

    return patterns;
  }

  // ================= MAIN AI FUNCTION =================
  static Map<String, dynamic> calculateAIScore(
    List<HistoricalDataModel> historyData, {
    DateTime? targetDate,
  }) {
    List<HistoricalDataModel> futureCandles = [];
    List<HistoricalDataModel> candles = [];

    if (targetDate != null) {
      final targetNormalized =
          DateTime(targetDate.year, targetDate.month, targetDate.day);

      for (var candle in historyData) {
        final candleDate = DateTime(candle.timestamp.year,
            candle.timestamp.month, candle.timestamp.day);

        if (candleDate.isAfter(targetNormalized)) {
          futureCandles.add(candle);
        } else {
          candles.add(candle);
        }
      }
    } else {
      candles = List.from(historyData);
    }

    if (candles.length < 200) {
      throw Exception(
          "Minimum 200 candles required before target date, got ${candles.length}");
    }

    final opens = candles.map((c) => c.open).toList();
    final closes = candles.map((c) => c.close).toList();
    final highs = candles.map((c) => c.high).toList();
    final lows = candles.map((c) => c.low).toList();
    final volumes = candles.map((c) => c.volume.toDouble()).toList();
    final last = candles.last;

    // ================= UTIL =================

    double sma(List<double> arr, int period) =>
        arr.sublist(arr.length - period).reduce((a, b) => a + b) / period;

    double ema(List<double> arr, int period) {
      final k = 2 / (period + 1);
      double emaVal = arr.sublist(0, period).reduce((a, b) => a + b) / period;
      for (int i = period; i < arr.length; i++) {
        emaVal = arr[i] * k + emaVal * (1 - k);
      }
      return emaVal;
    }

    double calculateSlope(List<double> arr, int period, {int lookback = 5}) {
      if (arr.length < period + lookback) return 0;

      final k = 2 / (period + 1);
      double emaVal = arr.sublist(0, period).reduce((a, b) => a + b) / period;

      List<double> emaValues = [];

      for (int i = period; i < arr.length; i++) {
        emaVal = arr[i] * k + emaVal * (1 - k);
        emaValues.add(emaVal);
      }

      if (emaValues.length < lookback + 1) return 0;

      final recent = emaValues.last;
      final past = emaValues[emaValues.length - lookback - 1];

      return ((recent - past) / past) * 100;
    }

    double calculateRSI({int period = 14}) {
      double gains = 0, losses = 0;
      for (int i = closes.length - period - 1; i < closes.length - 1; i++) {
        final diff = closes[i + 1] - closes[i];
        if (diff > 0)
          gains += diff;
        else
          losses -= diff;
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

    // ================= INDICATORS =================

    final ema20 = ema(closes, 20);
    final ema50 = ema(closes, 50);
    final ema200 = ema(closes, 200);

    final ema20Slope = calculateSlope(closes, 20);
    final ema50Slope = calculateSlope(closes, 50);

    final rsi = calculateRSI();
    final atr = calculateATR();
    final adx = calculateADX();
    final avgVol20 = sma(volumes, 20);

    final supertrendVals = IndicatorUtils.supertrendSeries(candles);
    final currentSupertrend =
        supertrendVals.isNotEmpty ? supertrendVals.last : 0.0;

    final isNearBuyZone =
        IndicatorUtils.isNearEMA20OrSupertrendAutoForDay(candles);

    final patterns = detectBullishPatterns(candles);

    // ================= SCORING =================

    double score = 0;

    if (ema20 > ema50) score += 8;
    if (ema50 > ema200) score += 8;
    if (last.close > ema20) score += 4;
    if (ema20Slope > 0.5) score += 5;
    if (ema50Slope > 0.3) score += 5;
    if (ema20Slope < 0) score -= 5;

    if (rsi > 55 && rsi < 70) score += 10;
    if (adx > 20) score += 5;
    if (last.high > highs[highs.length - 2]) score += 5;

    if (last.volume > avgVol20) score += 8;
    if (last.volume > avgVol20 * 1.5) score += 7;

    int? strongCandleIndex;
    for (int i = 0; i < 5; i++) {
      int index = volumes.length - 5 + i;
      if (volumes[index] > avgVol20 * 1.2 && closes[index] > opens[index]) {
        strongCandleIndex = index;
      }
    }
    if (strongCandleIndex != null) score += 5;

    final recentLow =
        lows.sublist(lows.length - 20).reduce((a, b) => a < b ? a : b);
    final prevLow = lows
        .sublist(lows.length - 40, lows.length - 20)
        .reduce((a, b) => a < b ? a : b);

    if (recentLow > prevLow) score += 10;
    if (last.close > ema50) score += 10;

    score += patterns.length * 5;

    final stoploss = last.close - (1.5 * atr);
    final target = last.close + (2 * atr);

    final risk = last.close - stoploss;
    final reward = target - last.close;

    if (reward / risk >= 1.5) score += 8;
    if (risk / last.close <= 0.05) score += 7;

    // ================= SCORE NORMALIZATION =================

    final rawScore = score;
    score = score.clamp(0, 100);

    double crossedPercent = 0;
    if (rawScore > 80) {
      crossedPercent = ((rawScore - 80) / 20) * 100;
      if (crossedPercent > 100) crossedPercent = 100;
    }

    final isLastCandleGreen = last.close > last.open;

    // ================= VERDICT =================

    String verdict = "Avoid";
    if (score >= 80)
      verdict = "Strong Buy";
    else if (score >= 65)
      verdict = "Moderate Buy";
    else if (score >= 50) verdict = "Average";

    DateTime dateToReturn = strongCandleIndex != null
        ? candles[strongCandleIndex].timestamp
        : last.timestamp;

    // ================= PERFORMANCE TRACKING =================

    String performance = "Pending";
    int daysToHit = 0;

    if (futureCandles.isNotEmpty && targetDate != null) {
      for (int i = 0; i < futureCandles.length; i++) {
        var fCandle = futureCandles[i];

        if (fCandle.high >= target) {
          performance = "Target Achieved";
          daysToHit = i + 1;
          break;
        } else if (fCandle.low <= stoploss) {
          performance = "Stoploss Hit";
          daysToHit = i + 1;
          break;
        }
      }
    } else if (futureCandles.isEmpty &&
        targetDate != null &&
        targetDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      performance = "Insufficient Data";
    } else {
      performance = "N/A";
    }

    // ================= RETURN =================

    return {
      "score": score.round(),
      "rawScore": rawScore,
      "crossedPercent": crossedPercent.round(),
      "isLastCandleGreen": isLastCandleGreen,
      "verdict": verdict,
      "patterns": patterns,
      "patternCount": patterns.length,
      "date": dateToReturn.toIso8601String().substring(0, 10),
      "currentPrice": last.close,
      "support": recentLow,
      "resistance":
          highs.sublist(highs.length - 20).reduce((a, b) => a > b ? a : b),
      "stoploss": stoploss,
      "target": target,
      "rsi": rsi,
      "adx": adx,
      "atr": atr,
      "ema20Slope": ema20Slope,
      "ema50Slope": ema50Slope,
      "supertrend": currentSupertrend,
      "isNearBuyZone": isNearBuyZone,
      "performance": performance,
      "daysToHit": daysToHit,
      "swingPass": swingScannerLoose(candles),
    };
  }

  static Map<String, dynamic> calculateAIScoreV2(
    List<HistoricalDataModel> historyData, {
    DateTime? targetDate,
  }) {
    List<HistoricalDataModel> futureCandles = [];
    List<HistoricalDataModel> candles = [];

    if (targetDate != null) {
      final targetNormalized =
          DateTime(targetDate.year, targetDate.month, targetDate.day);

      for (var candle in historyData) {
        final candleDate = DateTime(candle.timestamp.year,
            candle.timestamp.month, candle.timestamp.day);

        if (candleDate.isAfter(targetNormalized)) {
          futureCandles.add(candle);
        } else {
          candles.add(candle);
        }
      }
    } else {
      candles = List.from(historyData);
    }

    if (candles.length < 200) {
      throw Exception("Minimum 200 candles required");
    }

    final opens = candles.map((c) => c.open).toList();
    final closes = candles.map((c) => c.close).toList();
    final highs = candles.map((c) => c.high).toList();
    final lows = candles.map((c) => c.low).toList();
    final volumes = candles.map((c) => c.volume.toDouble()).toList();
    final last = candles.last;

    // ================= UTIL =================

    double sma(List<double> arr, int period) =>
        arr.sublist(arr.length - period).reduce((a, b) => a + b) / period;

    double ema(List<double> arr, int period) {
      final k = 2 / (period + 1);
      double emaVal = arr.sublist(0, period).reduce((a, b) => a + b) / period;

      for (int i = period; i < arr.length; i++) {
        emaVal = arr[i] * k + emaVal * (1 - k);
      }
      return emaVal;
    }

    double calculateRSI({int period = 14}) {
      double gains = 0, losses = 0;

      for (int i = closes.length - period - 1; i < closes.length - 1; i++) {
        final diff = closes[i + 1] - closes[i];

        if (diff > 0)
          gains += diff;
        else
          losses -= diff;
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
          (lows[i] - prevClose).abs()
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

    // ================= INDICATORS =================

    final ema20 = ema(closes, 20);
    final ema50 = ema(closes, 50);
    final ema200 = ema(closes, 200);

    final rsi = calculateRSI();
    final atr = calculateATR();
    final adx = calculateADX();
    final avgVol20 = sma(volumes, 20);

    // ================= VOLUME ENGINE =================

    double volumeRatio = last.volume / avgVol20;

    bool accumulation = true;

    for (int i = volumes.length - 5; i < volumes.length; i++) {
      if (volumes[i] < avgVol20) {
        accumulation = false;
      }
    }

    bool smartMoney = last.volume > avgVol20 * 2 && last.close > last.open;

    // ================= BREAKOUT =================

    double resistance =
        highs.sublist(highs.length - 20).reduce((a, b) => a > b ? a : b);

    double distanceFromBreakout =
        ((resistance - last.close) / resistance) * 100;

    bool fakeBreakout = last.close > resistance && last.volume < avgVol20;

    // ================= BREAKOUT PROBABILITY =================

    double breakoutProbability = 0;

    if (volumeRatio > 1.5) breakoutProbability += 30;
    if (rsi > 55) breakoutProbability += 20;
    if (ema20 > ema50) breakoutProbability += 20;
    if (distanceFromBreakout < 2) breakoutProbability += 30;

    // ================= SCORING =================

    double score = 0;

    if (ema20 > ema50) score += 8;
    if (ema50 > ema200) score += 8;
    if (last.close > ema20) score += 4;

    if (rsi > 55 && rsi < 70) score += 10;
    if (adx > 20) score += 5;

    if (volumeRatio > 1.2) score += 8;
    if (volumeRatio > 1.5) score += 7;

    if (accumulation) score += 6;
    if (smartMoney) score += 10;

    final recentLow =
        lows.sublist(lows.length - 20).reduce((a, b) => a < b ? a : b);

    final prevLow = lows
        .sublist(lows.length - 40, lows.length - 20)
        .reduce((a, b) => a < b ? a : b);

    if (recentLow > prevLow) score += 10;

    if (distanceFromBreakout < 2) score += 8;

    if (fakeBreakout) score -= 12;

    // ================= RISK REWARD =================

    final stoploss = last.close - (1.5 * atr);
    final target = last.close + (2 * atr);

    final risk = last.close - stoploss;
    final reward = target - last.close;

    if (reward / risk >= 1.5) score += 8;
    if (risk / last.close <= 0.05) score += 7;

    // ================= CHOPPY FILTER =================

    double volatility = atr / last.close;

    if (volatility < 0.015) {
      score -= 15;
    }

    // ================= SCORE NORMALIZATION =================

    final rawScore = score;
    score = score.clamp(0, 100);

    double crossedPercent = 0;

    if (rawScore > 80) {
      crossedPercent = ((rawScore - 80) / 20) * 100;
      if (crossedPercent > 100) crossedPercent = 100;
    }

    final isLastCandleGreen = last.close > last.open;

    // ================= VERDICT =================

    String verdict = "Avoid";

    if (score >= 80)
      verdict = "Strong Buy";
    else if (score >= 65)
      verdict = "Moderate Buy";
    else if (score >= 50) verdict = "Average";

    // ================= PERFORMANCE =================

    String performance = "Pending";
    int daysToHit = 0;

    for (int i = 0; i < futureCandles.length; i++) {
      var f = futureCandles[i];

      if (f.high >= target) {
        performance = "Target Achieved";
        daysToHit = i + 1;
        break;
      }

      if (f.low <= stoploss) {
        performance = "Stoploss Hit";
        daysToHit = i + 1;
        break;
      }
    }

    final institutionalPatterns = detectInstitutionalPatterns(candles);

    score += institutionalPatterns.length * 10;

    int? strongCandleIndex;
    for (int i = 0; i < 5; i++) {
      int index = volumes.length - 5 + i;
      if (volumes[index] > avgVol20 * 1.2 && closes[index] > opens[index]) {
        strongCandleIndex = index;
      }
    }

    final isNearBuyZone =
        IndicatorUtils.isNearEMA20OrSupertrendAutoForDay(candles);
    if (isNearBuyZone) {
      score += 10;
    }

    DateTime dateToReturn = strongCandleIndex != null
        ? candles[strongCandleIndex].timestamp
        : last.timestamp;
    // ================= RETURN =================

    return {
      "score": score.round(),
      "rawScore": rawScore,
      "crossedPercent": crossedPercent.round(),
      "isLastCandleGreen": isLastCandleGreen,
      "verdict": verdict,
      "date": dateToReturn.toIso8601String().substring(0, 10),
      "currentPrice": last.close,
      "support": recentLow,
      "resistance": resistance,
      "stoploss": stoploss,
      "target": target,
      "rsi": rsi,
      "adx": adx,
      "atr": atr,
      "isNearBuyZone": isNearBuyZone,
      "volumeRatio": volumeRatio,
      "isSmartMoney": smartMoney,
      "isAccumulation": accumulation,
      "breakoutProbability": breakoutProbability.round(),
      "performance": performance,
      "daysToHit": daysToHit,
      "institutionalPatterns": institutionalPatterns,
      "swingPass": swingScannerLoose(candles),
    };
  }

  static List<String> detectInstitutionalPatterns(
      List<HistoricalDataModel> candles) {
    List<String> patterns = [];

    if (detectVCP(candles)) {
      patterns.add("VCP Pattern");
    }

    if (detectBullFlag(candles)) {
      patterns.add("Bull Flag");
    }

    if (detectAscendingTriangle(candles)) {
      patterns.add("Ascending Triangle");
    }
    return patterns;
  }

  static bool detectAscendingTriangle(List<HistoricalDataModel> candles) {
    if (candles.length < 30) return false;

    final highs = candles.map((c) => c.high).toList();
    final lows = candles.map((c) => c.low).toList();

    double resistance =
        highs.sublist(highs.length - 20).reduce((a, b) => a > b ? a : b);

    double recentLow =
        lows.sublist(lows.length - 10).reduce((a, b) => a < b ? a : b);

    double prevLow = lows
        .sublist(lows.length - 20, lows.length - 10)
        .reduce((a, b) => a < b ? a : b);

    bool higherLows = recentLow > prevLow;

    return higherLows && candles.last.close < resistance;
  }

  static bool detectBullFlag(List<HistoricalDataModel> candles) {
    if (candles.length < 30) return false;

    final closes = candles.map((c) => c.close).toList();

    double poleMove = closes[closes.length - 15] - closes[closes.length - 25];

    double consolidation =
        closes[closes.length - 1] - closes[closes.length - 15];

    return poleMove > 0 && consolidation.abs() < poleMove * 0.4;
  }

  static bool detectVCP(List<HistoricalDataModel> candles) {
    if (candles.length < 40) return false;

    final highs = candles.map((c) => c.high).toList();
    final lows = candles.map((c) => c.low).toList();

    double range1 = highs[highs.length - 30] - lows[highs.length - 30];
    double range2 = highs[highs.length - 20] - lows[highs.length - 20];
    double range3 = highs[highs.length - 10] - lows[highs.length - 10];

    bool contraction = range1 > range2 && range2 > range3;

    return contraction;
  }

  static bool swingScanner(List<HistoricalDataModel> candles) {
    if (candles.length < 200) return false;

    final closes = candles.map((c) => c.close).toList();
    final highs = candles.map((c) => c.high).toList();
    final lows = candles.map((c) => c.low).toList();
    final volumes = candles.map((c) => c.volume.toDouble()).toList();

    double sma(List<double> arr, int p) =>
        arr.sublist(arr.length - p).reduce((a, b) => a + b) / p;

    double ema(List<double> arr, int period) {
      final k = 2 / (period + 1);
      double emaVal = arr.sublist(0, period).reduce((a, b) => a + b) / period;

      for (int i = period; i < arr.length; i++) {
        emaVal = arr[i] * k + emaVal * (1 - k);
      }

      return emaVal;
    }

    double calculateRSI({int period = 14}) {
      double gains = 0, losses = 0;

      for (int i = closes.length - period - 1; i < closes.length - 1; i++) {
        final diff = closes[i + 1] - closes[i];

        if (diff > 0)
          gains += diff;
        else
          losses -= diff;
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
          (lows[i] - prevClose).abs()
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

    final rsi = calculateRSI();
    final adx = calculateADX();
    final atr = calculateATR();

    final avgVol20 = sma(volumes, 20);

    final last = candles.last;

    // ================= TREND FILTER =================

    if (!(ema20 > ema50 && ema50 > ema200)) return false;

    // ================= MOMENTUM =================

    if (rsi < 55) return false;

    if (adx < 20) return false;

    // ================= VOLUME =================

    if (last.volume < avgVol20 * 1.5) return false;

    // ================= STRUCTURE =================

    final recentLow =
        lows.sublist(lows.length - 20).reduce((a, b) => a < b ? a : b);

    final prevLow = lows
        .sublist(lows.length - 40, lows.length - 20)
        .reduce((a, b) => a < b ? a : b);

    if (!(recentLow > prevLow)) return false;

    // ================= BREAKOUT =================

    final resistance =
        highs.sublist(highs.length - 20).reduce((a, b) => a > b ? a : b);

    final distanceFromBreakout = ((resistance - last.close) / resistance) * 100;

    if (distanceFromBreakout > 3) return false;

    // ================= CHOPPY FILTER =================

    double volatility = atr / last.close;

    if (volatility < 0.015) return false;

    return true;
  }

  static bool swingScannerLoose(List<HistoricalDataModel> candles) {
    if (candles.length < 200) return false;

    final closes = candles.map((c) => c.close).toList();
    final highs = candles.map((c) => c.high).toList();
    final lows = candles.map((c) => c.low).toList();
    final volumes = candles.map((c) => c.volume.toDouble()).toList();

    final last = candles.last;

    double sma(List<double> arr, int period) =>
        arr.sublist(arr.length - period).reduce((a, b) => a + b) / period;

    double ema(List<double> arr, int period) {
      final k = 2 / (period + 1);

      double emaVal = arr.sublist(0, period).reduce((a, b) => a + b) / period;

      for (int i = period; i < arr.length; i++) {
        emaVal = arr[i] * k + emaVal * (1 - k);
      }

      return emaVal;
    }

    double calculateRSI({int period = 14}) {
      double gains = 0;
      double losses = 0;

      for (int i = closes.length - period - 1; i < closes.length - 1; i++) {
        final diff = closes[i + 1] - closes[i];

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
          (lows[i] - prevClose).abs()
        ].reduce((a, b) => a > b ? a : b);

        trs.add(tr);
      }

      return trs.reduce((a, b) => a + b) / period;
    }

    double calculateADX({int period = 14}) {
      double plusDM = 0;
      double minusDM = 0;
      double trSum = 0;

      for (int i = highs.length - period; i < highs.length; i++) {
        final upMove = highs[i] - highs[i - 1];
        final downMove = lows[i - 1] - lows[i];

        if (upMove > downMove && upMove > 0) {
          plusDM += upMove;
        }

        if (downMove > upMove && downMove > 0) {
          minusDM += downMove;
        }

        final tr = [
          highs[i] - lows[i],
          (highs[i] - closes[i - 1]).abs(),
          (lows[i] - closes[i - 1]).abs()
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

    final rsi = calculateRSI();
    final atr = calculateATR();
    final adx = calculateADX();

    final avgVol20 = sma(volumes, 20);

    final volumeRatio = last.volume / avgVol20;

    final resistance =
        highs.sublist(highs.length - 20).reduce((a, b) => a > b ? a : b);

    final distanceFromBreakout = ((resistance - last.close) / resistance) * 100;

    final volatility = atr / last.close;

    // ================= LOOSE CONDITIONS =================

    bool trend = ema20 > ema50;

    bool momentum = rsi > 50;

    bool volume = volumeRatio > 0.8;

    bool breakoutZone = distanceFromBreakout < 8;

    bool volatilityOk = volatility > 0.008;

    bool trendStrength = adx > 15;
    List<String> errorList = [];
    if (!trend) {
      errorList.add("Trend Failed: EMA20=$ema20 EMA50=$ema50 EMA200=$ema200");
    }

    if (!momentum) {
      errorList.add("❌ Momentum Failed: RSI=$rsi");
    }

    if (!volume) {
      errorList.add("❌ Volume Failed: VolumeRatio=$volumeRatio");
    }

    if (!breakoutZone) {
      errorList.add("❌ Breakout Zone Failed: Distance=$distanceFromBreakout%");
    }

    if (!volatilityOk) {
      errorList.add("❌ Volatility Failed: ATR/Price=$volatility");
    }

    if (!trendStrength) {
      errorList.add("❌ ADX Failed: ADX=$adx");
    }

    // if (errorList.length == 1) {
    //   print(errorList);
    //   return true;
    // }

    return trend &&
        momentum &&
        volume &&
        breakoutZone &&
        volatilityOk &&
        trendStrength;
  }
}
