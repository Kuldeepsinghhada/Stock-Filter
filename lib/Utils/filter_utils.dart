import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:stock_demo/Utils/bullish_pattern_detector.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'candle_utils.dart';
import 'math_utils.dart';

class FilterUtils {
  // Static cached variables to avoid querying SharedPreferences repetitively
  static double cachedLastMultiplier = 3.0;
  static double cachedOtherMultiplier = 2.0;
  static bool cachedIsVolAvgEnabled = true;
  static bool cachedIsPatternEnabled = true;
  static bool cachedIsSupertrendEnabled = true;
  static bool cachedIsEma20Enabled = true;
  static bool cachedIsVolBreakoutEnabled = true;

  /// Loads and caches the settings from SharedPreferences
  static Future<void> cacheFilterSettings() async {
    final prefs = SharedPreferenceHelper.instance;
    cachedLastMultiplier = await prefs.getLastCandleMultiplier();
    cachedOtherMultiplier = await prefs.getOtherCandlesMultiplier();
    cachedIsVolAvgEnabled = await prefs.getVolumeAverageEnabled();
    cachedIsPatternEnabled = await prefs.getPatternEnabled();
    cachedIsSupertrendEnabled = await prefs.getSupertrendEnabled();
    cachedIsEma20Enabled = await prefs.getEma20Enabled();
    cachedIsVolBreakoutEnabled = await prefs.getVolumeBreakoutEnabled();
  }

  static bool passesFilter(List<HistoricalDataModel> candles, String token) {
    final timeStr =
        candles.isNotEmpty ? candles.last.timestamp.toString() : "Unknown Time";

    var isPercentChange = IndicatorUtils.isNotAbove10Percent(candles);
    if (!isPercentChange) {
      debugPrint("Failed: $token at $timeStr - Reason: Price Change > 13%");
      return false;
    }

    if (candles.last.volume < 15000) {
      debugPrint(
          "Failed: $token at $timeStr - Reason: Low Volume (${candles.last.volume})");
      return false;
    }

    var rangeExpansion = IndicatorUtils.getRangeExpansion(candles);
    if (rangeExpansion > 6) {
      debugPrint(
          "Failed: $token at $timeStr - Reason: Range Expansion ($rangeExpansion)");
      return false;
    }

    // Max 2 continuous green candles check
    // if (candles.length >= 3) {
    //   final last2 = candles[candles.length - 2];
    //   final last3 = candles[candles.length - 3];
    //
    //   bool isGreen(HistoricalDataModel c) => c.close > c.open;
    //
    //   var isOverExtend = isGreen(last2) && isGreen(last3);
    //   if (isOverExtend) {
    //     debugPrint(
    //         "Failed: $token at $timeStr - Reason: 3 Continuous Green Candles");
    //     return false;
    //   }
    // }

    // if (candles.last.volume < 80000) {
    //   debugPrint(
    //       "Failed: $token at $timeStr - Reason: Low Volume (${candles.last.volume})");
    //   return false;
    // }

    // var isNearResistance = IndicatorUtils.isNearResistance(candles);
    // if (isNearResistance) {
    //   debugPrint("Failed: $token at $timeStr - Reason: Near Resistance Level");
    //   return false;
    // }

    // var isAlreadyMoved = IndicatorUtils.isAlreadyMoved(candles);
    // if (isAlreadyMoved) {
    //   debugPrint(
    //       "Failed: $token at $timeStr - Reason: Already Moved Significantly");
    //   return false;
    // }
    //
    // var isProbabilityScore = IndicatorUtils.probabilityScore(candles);
    // if(isProbabilityScore > 70){
    //   debugPrint(
    //       "Failed: $token at $timeStr - Reason: Low Probability Score");
    //   return false;
    // }

    // var isAbove10Days = IndicatorUtils.isAboveLast10DayHigh(candles);
    // if (!isAbove10Days) {
    //   debugPrint(
    //       "Failed: $token at $timeStr - Reason: Not Above Last 10 Days High");
    //   return false;
    // }

    // 3. EMA20 Check
    if (cachedIsEma20Enabled) {
      bool aboveEma20 = IndicatorUtils.isCloseAboveEMA(candles, 20).isPassed;
      if (!aboveEma20) {
        debugPrint("Failed: $token at $timeStr - Reason: Below EMA20");
        return false;
      }
    }

    // 4. Supertrend Check
    if (cachedIsSupertrendEnabled) {
      bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
        candles,
        atrPeriod: 10,
        multiplier: 3,
      ).isPassed;
      if (!aboveSupertrend) {
        debugPrint("Failed: $token at $timeStr - Reason: Below Supertrend");
        return false;
      }
    }

    // 5. ATR Check
    bool atrOk = IndicatorUtils.isAtrGreaterThanAdaptive(candles);
    if (!atrOk) {
      debugPrint("Failed: $token at $timeStr - Reason: Low ATR");
      return false;
    }

    // 6. ADX Check
    bool adxRes = IndicatorUtils.isAdxBullish(candles);
    if (!adxRes) {
      debugPrint("Failed: $token at $timeStr - Reason: ADX Not Bullish");
      return false;
    }

    // 7. Score Check (getSmartPriceActionScore)
    // int score = getIntradayMomentumScore(candles);
    // if (score < 80) {
    //   debugPrint(
    //       "Failed: $token at $timeStr - Reason: Low Smart Score ($score)");
    //   return false;
    // }

    // 9. Day Pass Check (requires converting to daily, slightly heavier)
    final dailyCandles = Utilities.convertToDaily(candles);
    final isDayPass = isPassHistoryChart(dailyCandles, token, 1);
    if (!isDayPass) {
      debugPrint(
          "Failed: $token at $timeStr - Reason: Day History Chart Failed");
      return false;
    }
    // 10. Pattern Check (requires daily candles)
    // if (cachedIsPatternEnabled) {
    //   var isPattern = BullishPatternDetector.isBullishStructure(dailyCandles);
    //   if (!isPattern.bullish) {
    //     debugPrint("Failed: $token at $timeStr - Reason: No Bullish Pattern");
    //     return false;
    //   }
    // }

    // 2. Volume Avg Check
    final volumeStrength = IndicatorUtils.checkDualVolumeStrength(candles);
    if (!volumeStrength.isVolumeSpike40x) {
      return false;
    }
    debugPrint("Passed : $token");
    return true;
  }

  /// 🔹 Get the last fully closed 5-minute candle
  static HistoricalDataModel getLastClosed5MinCandle(
      List<HistoricalDataModel> candles) {
    if (candles.isEmpty) throw Exception("Empty candles list");
    final now = DateTime.now();
    if (now.difference(candles.last.timestamp).inMinutes < 5 &&
        candles.length > 1) {
      return candles[candles.length - 2];
    }
    return candles.last;
  }

  /// 🔹 Check if stock is near 20EMA or Supertrend on 5m (Buying zone)
  static String? isNearBuyingZone5Min(List<HistoricalDataModel> allCandles,
      {double threshold = 0.0050}) {
    if (allCandles.length < 20) return null;

    // Use only closed candles
    List<HistoricalDataModel> candles = List.from(allCandles);
    final now = DateTime.now();
    if (now.difference(candles.last.timestamp).inMinutes < 5 &&
        candles.length > 1) {
      candles.removeLast();
    }

    // Block Buy Alerts between 10:50 and 12:20
    final ts = candles.last.timestamp.toLocal();
    final timeInMinutes = ts.hour * 60 + ts.minute;
    if (timeInMinutes >= 650 && timeInMinutes <= 740) {
      return null; // Buy alert logic 10:50 se 12:20 ke bich me nhi aana chahiye.
    }

    // Must be a green candle
    if (candles.last.close <= candles.last.open) return null;

    // Green candle's close must be above the last red candle's close
    HistoricalDataModel? lastRedCandle;
    for (int i = candles.length - 2; i >= 0; i--) {
      if (candles[i].close < candles[i].open) {
        lastRedCandle = candles[i];
        break;
      }
    }
    if (lastRedCandle != null && candles.last.close <= lastRedCandle.close) {
      return null;
    }

    final currentLow = candles.last.low;

    // EMA 20 calculation
    final closes = candles.map((e) => e.close).toList();
    final ema20List = MathUtils.emaAligned(closes, 20);

    bool nearEmaCurrent = false;
    if (ema20List.isNotEmpty && ema20List.last != null) {
      final ema20 = ema20List.last!;
      final distanceToEma = ((currentLow - ema20).abs() / ema20);
      if (distanceToEma <= threshold) {
        nearEmaCurrent = true;
      }
    }

    if (nearEmaCurrent) {
      int nearEmaCount = 0;
      int startIndex = candles.length > 6 ? candles.length - 6 : 0;
      for (int i = startIndex; i < candles.length; i++) {
        if (ema20List[i] != null) {
          final emaVal = ema20List[i]!;
          final dist = ((candles[i].low - emaVal).abs() / emaVal);
          if (dist <= threshold) {
            nearEmaCount++;
          }
        }
      }

      if (nearEmaCount >= 2) {
        return "20EMA";
      }
    }

    // Supertrend calculation
    final stRes = IndicatorUtils.isCloseAboveSupertrend(candles,
        atrPeriod: 10, multiplier: 3);
    if (stRes.value != null && stRes.value! > 0) {
      final stValue = stRes.value!;
      final distanceToSt = ((currentLow - stValue).abs() / stValue);
      if (distanceToSt <= threshold) return "Supertrend";
    }

    return null;
  }

  /// 🔹 Main multi-timeframe validation
  static Future<bool> isPassAllTimeFrame(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
  ) async {
    final is5MinPass =
        isPassHistoryChart(historyCandles, stock.token.toString(), 5);
    if (!is5MinPass) return false;

    final is15MinPass = isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 15),
      ),
      stock.token.toString(),
      15,
    );
    if (!is15MinPass) return false;

    final is30MinPass = isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 30),
      ),
      stock.token.toString(),
      30,
    );
    if (!is30MinPass) return false;

    final is1HourPass = isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 60),
      ),
      stock.token.toString(),
      60,
    );
    if (!is1HourPass) return false;

    // final isDayPass = await isPassHistoryChart(
    //   Utilities.convertToDaily(historyCandles ?? []),
    //   stock,
    //   1,
    // );
    // if (!isDayPass) return false;
    final isPattern = BullishPatternDetector.detect(
        Utilities.convertToDaily(historyCandles ?? []));
    debugPrint(isPattern.name);
    if (!isPattern.found) {
      return false;
    }
    debugPrint("✅ Stock Passed All Timeframes: ${stock.symbol}");
    return true;
  }

  /// 🔹 Handles individual timeframe logic
  static bool isPassHistoryChart(
    List<HistoricalDataModel>? historyCandles,
    String token,
    int timeFrame,
  ) {
    if (historyCandles == null || historyCandles.isEmpty) return false;

    switch (timeFrame) {
      case 5:
        bool isPass = passesFilter(historyCandles, token.toString());
        return isPass;

      case 15:
        bool isAboveSupertrend =
            IndicatorUtils.isCloseAboveSupertrend(historyCandles).isPassed;
        return isAboveSupertrend;

      case 1:
        bool isEMA20 =
            IndicatorUtils.isCloseAboveEMA(historyCandles, 20).isPassed;
        bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
          historyCandles,
          atrPeriod: 10,
        ).isPassed;
        return isEMA20 || aboveSupertrend;

      default:
        return false;
    }
  }

  /// 🔹 Final tradability rule check (price, circuit, volume etc.)
  static bool isTradable(StockModel stock) {
    final lastPrice = stock.lastPrice;
    final lowerLimit = stock.lowerCircuitLimit;
    final upperLimit = stock.upperCircuitLimit;
    final ohlc = stock.ohlc;

    final close = ohlc?.close;
    final open = ohlc?.open;
    final high = ohlc?.high;
    final low = ohlc?.low;

    final volume = stock.volume;

    if (lastPrice == null ||
        close == null ||
        open == null ||
        high == null ||
        low == null ||
        lowerLimit == null ||
        upperLimit == null ||
        volume == null) {
      return false;
    }

    final percentChange = ((lastPrice - open) / open) * 100;
    final rangePercent = ((high - low) / open) * 100;

    // ✅ Price range filter
    if (lastPrice < 30 || lastPrice > 1000) return false;

    // ✅ Must be green today
    if (lastPrice <= open) return false;

    // ✅ Momentum required
    if (percentChange < 2) return false;

    // ✅ Must have movement
    if (rangePercent < 1) return false;

    // ✅ Liquidity filter
    if (volume < 15000) return false;

    // ✅ Working day volume check
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);

    final isWorkingDay = lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    if (isWorkingDay) {
      if (volume < 15000) return false;
    }
    return true;
  }

  static bool isDayTradable(StockModel stock) {
    final symbol = stock.symbol!.toLowerCase();
    // remove ETF / BEES / gold / silver
    if (symbol.contains("etf") ||
        symbol.contains("bees") ||
        symbol.contains("gold") ||
        symbol.contains("silver")) {
      return false;
    }
    final lastPrice = stock.lastPrice;
    final lowerLimit = stock.lowerCircuitLimit;
    final upperLimit = stock.upperCircuitLimit;
    final ohlc = stock.ohlc;
    final close = ohlc?.close;
    final volume = stock.volume;

    if (lastPrice == null ||
        close == null ||
        lowerLimit == null ||
        upperLimit == null ||
        volume == null) {
      return false;
    }

    if (lastPrice <= 50) return false;
    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) return false;

    // Only enforce the volume threshold on working days.
    // If today is a weekend or a holiday (Utilities.getLastWorkingDay shifts back),
    // skip the volume check.
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);
    final isWorkingDay = lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    if (isWorkingDay) {
      if (volume <= 100000) return false;
    }
    return true;
  }

  static double getVolumeMultiplication(List<HistoricalDataModel> candles) {
    final daily = Utilities.convertToDaily(candles);
    if (daily.length < 10) return 0.0;

    final recent5 = daily.sublist(daily.length - 5);
    final prev5 = daily.sublist(
      daily.length - 10,
      daily.length - 5,
    );

    final recentAvgVolume =
        recent5.map((e) => e.volume).reduce((a, b) => a + b) / recent5.length;

    final prevAvgVolume =
        prev5.map((e) => e.volume).reduce((a, b) => a + b) / prev5.length;

    if (prevAvgVolume == 0) return 0.0;
    return recentAvgVolume / prevAvgVolume;
  }

  static int getIntradayMomentumScore(
    List<HistoricalDataModel> candles,
  ) {
    if (candles.length < 50) return 0;

    CandleUtils.sortByTime(candles);

    int score = 0;

    final last = candles.last;

    // =====================================================
    // HARD FILTERS
    // =====================================================

    if (last.close < 50) {
      return 0;
    }

    // =====================================================
    // VWAP
    // =====================================================

    final vwap = IndicatorUtils.isCloseAboveVWAP(candles);

    if (vwap) {
      score += 20;
    } else {
      return 0;
    }

    // =====================================================
    // STRONG CANDLE
    // =====================================================

    final candlePct = ((last.close - last.open) / last.open) * 100;

    if (last.close > last.open && candlePct >= 0.8) {
      score += 15;
    }

    // =====================================================
    // LOW UPPER WICK
    // =====================================================

    final body = (last.close - last.open).abs();

    final upperWick = last.high - max(last.close, last.open);

    if (body > 0 && upperWick <= body * 0.5) {
      score += 10;
    }

    // =====================================================
    // VOLUME SPIKE
    // =====================================================

    final recent20 = candles.sublist(candles.length - 21, candles.length - 1);

    final avgVolume =
        recent20.map((e) => e.volume).reduce((a, b) => a + b) / recent20.length;

    if (last.volume > avgVolume * 2) {
      score += 20;
    }

    // =====================================================
    // HH HL STRUCTURE
    // =====================================================

    bool hhhl = true;

    for (int i = candles.length - 5; i < candles.length - 1; i++) {
      if (candles[i + 1].high < candles[i].high ||
          candles[i + 1].low < candles[i].low) {
        hhhl = false;
        break;
      }
    }

    if (hhhl) {
      score += 15;
    }

    // =====================================================
    // ORB BREAKOUT
    // =====================================================

    if (candles.length >= 4) {
      double orbHigh = 0;

      for (int i = 0; i < 3; i++) {
        orbHigh = max(orbHigh, candles[i].high);
      }

      if (last.close > orbHigh) {
        score += 20;
      }
    }

    // =====================================================
    // ADX
    // =====================================================

    final adx = IndicatorUtils.isAdxBullish(
      candles,
      diPeriod: 14,
    );
    if (adx) {
      score += 20;
    }

    // =====================================================
    // NO BIG RED CANDLE
    // =====================================================

    int redCount = 0;

    for (final c in candles.sublist(candles.length - 10)) {
      if (c.close < c.open) {
        redCount++;
      }
    }

    if (redCount <= 2) {
      score += 10;
    }

    return score;
  }

  static int getSmartPriceActionScore(
    List<HistoricalDataModel> candles,
  ) {
    if (candles.isEmpty) return 0;

    final groupedByDate = CandleUtils.groupByDate(candles);
    final sortedDates = groupedByDate.keys.toList()..sort();
    if (sortedDates.isNotEmpty) {
      final todayCandles = groupedByDate[sortedDates.last]!;
      for (var c in todayCandles) {
        if (c.volume <= 5000) {
          return 0;
        }
      }
    }

    // =========================================================
    // 5 MIN → DAILY
    // =========================================================

    final daily = Utilities.convertToDaily(candles);

    if (daily.length < 20) {
      return 0;
    }

    CandleUtils.sortByTime(daily);

    int score = 0;

    final previousDayVolume = daily[daily.length - 2].volume;

    final volume1Lakh = previousDayVolume >= 100000;

    if (!volume1Lakh) {
      return 0;
    }

    final last = daily.last;

    final close = last.close;
    final open = last.open;
    final high = last.high;

    // =========================================================
    // 1️⃣ CLOSE NEAR DAY HIGH
    // Strong closing = institutions buying
    // =========================================================

    final closeNearHigh = close >= high * 0.985;

    if (closeNearHigh) {
      score += 15;
    }

    // =========================================================
    // 2️⃣ LOW UPPER WICK
    // Avoid profit booking candles
    // =========================================================

    final body = (close - open).abs();

    final upperWick = high - max(open, close);

    final lowUpperWick = body > 0 && upperWick <= body * 0.6;

    if (lowUpperWick) {
      score += 10;
    }

    // =========================================================
    // 3️⃣ STRONG GREEN CANDLE
    // =========================================================

    final candlePct = ((close - open).abs() / open) * 100;

    final strongGreen = close > open && candlePct >= 1.2;

    if (strongGreen) {
      score += 15;
    }

    // =========================================================
    // 4️⃣ VOLUME EXPANSION
    // Real momentum
    // =========================================================

    final recent5 = daily.sublist(daily.length - 5);

    final prev5 = daily.sublist(
      daily.length - 10,
      daily.length - 5,
    );

    final recentAvgVolume =
        recent5.map((e) => e.volume).reduce((a, b) => a + b) / recent5.length;

    final prevAvgVolume =
        prev5.map((e) => e.volume).reduce((a, b) => a + b) / prev5.length;

    final volumeExpansion = recentAvgVolume > prevAvgVolume * 1.4;

    if (volumeExpansion) {
      score += 20;
    }

    // =========================================================
    // 5️⃣ SMOOTH STRUCTURE
    // Remove operator/choppy stocks
    // =========================================================

    int badWickCount = 0;

    final recentCandles = daily.sublist(daily.length - 10);

    for (final c in recentCandles) {
      final cBody = (c.close - c.open).abs();

      final cUpperWick = c.high - max(c.open, c.close);

      final cLowerWick = min(c.open, c.close) - c.low;

      final totalWick = cUpperWick + cLowerWick;

      if (cBody > 0 && totalWick > cBody * 1.5) {
        badWickCount++;
      }
    }

    final smoothStructure = badWickCount <= 1;

    if (smoothStructure) {
      score += 20;
    }

    // =========================================================
    // 6️⃣ TIGHT CONSOLIDATION
    // Strong stocks move cleanly
    // =========================================================

    double recentHigh = 0;
    double recentLow = double.infinity;

    for (int i = daily.length - 5; i < daily.length; i++) {
      if (daily[i].high > recentHigh) {
        recentHigh = daily[i].high;
      }

      if (daily[i].low < recentLow) {
        recentLow = daily[i].low;
      }
    }

    final rangePct = ((recentHigh - recentLow) / recentLow) * 100;

    final tightStructure = rangePct <= 4.5;

    if (tightStructure) {
      score += 15;
    }

    // =========================================================
    // 7️⃣ BREAKOUT QUALITY
    // Fresh breakout only
    // =========================================================

    double highestHigh = 0;

    for (int i = daily.length - 20; i < daily.length - 1; i++) {
      if (daily[i].high > highestHigh) {
        highestHigh = daily[i].high;
      }
    }

    final breakout = close > highestHigh * 1.002;

    if (breakout) {
      score += 20;
    }

    // =========================================================
    // 8️⃣ HEALTHY PULLBACK
    // Avoid weak structures
    // =========================================================

    int redCount = 0;

    final last7 = daily.sublist(daily.length - 7);

    for (final c in last7) {
      if (c.close < c.open) {
        redCount++;
      }
    }

    final healthyPullback = redCount <= 2;

    if (healthyPullback) {
      score += 10;
    }

    // =========================================================
    // 9️⃣ AVOID PARABOLIC MOVE
    // Retail trap removal
    // =========================================================

    final tenDayAgoClose = daily[daily.length - 10].close;

    final runUpPct = ((close - tenDayAgoClose) / tenDayAgoClose) * 100;

    final notOverExtended = runUpPct <= 18;

    if (notOverExtended) {
      score += 10;
    }

    // =========================================================
    // 🔟 NO BIG GAP-UP
    // Late entries avoid
    // =========================================================

    final gapPct = ((open - daily[daily.length - 2].close) /
            daily[daily.length - 2].close) *
        100;

    final controlledGap = gapPct <= 2.5;

    if (controlledGap) {
      score += 10;
    }

    // =========================================================
    // FINAL
    // =========================================================

    // final nearBuyingZone = IndicatorUtils.isNearEMA20OrSupertrendAutoForDay(
    //   daily,
    //   tolerancePercent: 5,
    // );
    //
    // if (!nearBuyingZone) {
    //   return false;
    // }
    //
    return score;
  }

  /// 🔹 Calculates accuracy of the 1st Buy Alert for the current day
  static Map<String, dynamic>? calculateBuyAlertAccuracy(
      List<HistoricalDataModel> history, String token,
      {bool useRadarAlert = false}) {
    if (history.isEmpty) return null;

    final targetDate = history.last.timestamp;
    List<HistoricalDataModel> todayCandles = history
        .where((c) =>
            c.timestamp.year == targetDate.year &&
            c.timestamp.month == targetDate.month &&
            c.timestamp.day == targetDate.day)
        .toList();

    if (todayCandles.isEmpty) return null;

    HistoricalDataModel? alertCandle;
    double? entryPrice;
    double? supertrendValue;
    bool hasPassedRadar = false;

    // Simulate going through today's candles one by one
    // Start at least 20 candles in to allow EMA calculations if possible
    for (int i = 0; i < todayCandles.length; i++) {
      int globalIndex = history.indexOf(todayCandles[i]);
      if (globalIndex < 20) continue; // Need minimum data for EMA

      List<HistoricalDataModel> historySoFar =
          history.sublist(0, globalIndex + 1);

      if (!hasPassedRadar) {
        hasPassedRadar = passesFilter(historySoFar, token);
      }

      if (hasPassedRadar) {
        if (useRadarAlert) {
          // Trigger entry on the exact candle that passed the radar
          HistoricalDataModel targetCandle =
              getLastClosed5MinCandle(historySoFar);

          if (targetCandle.timestamp.day == targetDate.day) {
            alertCandle = targetCandle;
            entryPrice = targetCandle.close;
            final stRes = IndicatorUtils.isCloseAboveSupertrend(historySoFar,
                atrPeriod: 10, multiplier: 3);
            supertrendValue = stRes.value;
            break;
          }
        } else {
          String? isNearReason = isNearBuyingZone5Min(historySoFar);
          if (isNearReason != null) {
            HistoricalDataModel targetCandle =
                getLastClosed5MinCandle(historySoFar);

            if (targetCandle.timestamp.day == targetDate.day) {
              alertCandle = targetCandle;
              entryPrice = targetCandle.close;

              // Need supertrend value at this point
              final stRes = IndicatorUtils.isCloseAboveSupertrend(historySoFar,
                  atrPeriod: 10, multiplier: 3);
              supertrendValue = stRes.value;
              break; // Check only 1st time buy alert
            }
          }
        }
      }
    }

    if (alertCandle == null || entryPrice == null || supertrendValue == null) {
      return null; // No alert today
    }

    double target = entryPrice * 1.02; // Up by 2%
    double stoploss = supertrendValue * 0.9975; // 0.25% below the supertrend
    double maxStoploss = entryPrice * 0.97; // Max 3% loss
    if (stoploss < maxStoploss) {
      stoploss = maxStoploss;
    }

    String status = "Pending";
    double percentPnL = 0.0;
    bool tradeClosed = false;

    int globalAlertIndex = history.indexOf(alertCandle);
    for (int i = globalAlertIndex + 1; i < history.length; i++) {
      var c = history[i];
      if (c.low <= stoploss) {
        // Check stoploss first to be conservative
        status = "Loss";
        percentPnL = ((stoploss - entryPrice) / entryPrice) * 100;
        tradeClosed = true;
        break;
      }
      if (c.high >= target) {
        status = "Win";
        percentPnL = 2.0;
        tradeClosed = true;
        break;
      }
    }

    if (!tradeClosed) {
      // Calculate Open PnL based on the last available candle
      final lastClose = history.last.close;
      percentPnL = ((lastClose - entryPrice) / entryPrice) * 100;
    }

    return {
      "status": status,
      "entryPrice": entryPrice,
      "target": target,
      "stoploss": stoploss,
      "percentPnL": percentPnL,
      "alertTime": alertCandle.timestamp,
    };
  }
}
