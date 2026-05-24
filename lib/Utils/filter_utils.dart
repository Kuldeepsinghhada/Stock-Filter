import 'dart:developer';
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
  /// 🔹 Checks if all core indicator filters are passed
  static Future<bool> passesFilter(
      List<HistoricalDataModel> candles, String token) async {
    List<String> failedReasons = [];

    final lastMultiplier =
        await SharedPreferenceHelper.instance.getLastCandleMultiplier();
    final otherMultiplier =
        await SharedPreferenceHelper.instance.getOtherCandlesMultiplier();

    // bool yesGreen = IndicatorUtils.wasYesterdayGreenFrom5Min(candles);
    // if(!yesGreen) failedReasons.add("Yesterday NOT Green from 5Min");

    bool aboveEma20 = IndicatorUtils.isCloseAboveEMA(candles, 20).isPassed;
    if (!aboveEma20) failedReasons.add("Close NOT above EMA20");

    bool rsiOk = IndicatorUtils.isRsiBetween(candles, 14, min: 60, max: 95);
    if (!rsiOk) failedReasons.add("RSI not between 60–95");

    bool atrOk = IndicatorUtils.isAtrGreaterThanAdaptive(candles);
    if (!atrOk) failedReasons.add("ATR not greater than adaptive threshold");

    bool aboveVwap = IndicatorUtils.isCloseAboveVWAP(candles);
    if (!aboveVwap) failedReasons.add("Close NOT above VWAP");

    bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
      candles,
      atrPeriod: 10,
      multiplier: 3,
    ).isPassed;
    if (!aboveSupertrend) failedReasons.add("Close NOT above Supertrend");

    bool adxRes = IndicatorUtils.isAdxBullish(candles);
    if (!adxRes) failedReasons.add("ADX NOT bullish");

    bool isVolumeOk = IndicatorUtils.isVolumeOk(candles);
    if (!isVolumeOk) {
      failedReasons.add("Volume NOT > 15000 (vol=$isVolumeOk)");
    }

    // bool isYesterdayAvgVolumeOk = IndicatorUtils.isYesterdayAverageVolumeAbove(
    //   candles,token
    // );
    // if (!isYesterdayAvgVolumeOk) {
    //   failedReasons.add("Yesterday Volume Not Enough");
    // }

    bool isVolume1M = IndicatorUtils.isPreviousTradingDayVolumeAbove1M(candles);

    bool isVolumeBreakout = IndicatorUtils.isVolumeBreakoutStrong(candles);
    if (!isVolumeBreakout) failedReasons.add("Volume breakout weak");

    bool is2PcChange =
        IndicatorUtils.isCloseAboveYesterdayHighByPctAndYesterdayBullish(
      candles,
    );
    if (!is2PcChange) failedReasons.add("2% Up + Yesterday Bullish failed");

    bool isVolumeAverageOK = IndicatorUtils.isEveryCandleVolumeStrong(
        candles, failedReasons.length,
        lastMultiplier: lastMultiplier, otherMultiplier: otherMultiplier);

    bool isPattern = BullishPatternDetector.detectTop3Patterns85(
      Utilities.convertToDaily(candles),
    );
    if (!isPattern) failedReasons.add("No bullish pattern on daily");

    final prefs = SharedPreferenceHelper.instance;
    final isVolAvgEnabled = await prefs.getVolumeAverageEnabled();
    final isPatternEnabled = await prefs.getPatternEnabled();
    final isSupertrendEnabled = await prefs.getSupertrendEnabled();
    final isEma20Enabled = await prefs.getEma20Enabled();
    final isVolBreakoutEnabled = await prefs.getVolumeBreakoutEnabled();

    bool passVolAvg = !isVolAvgEnabled || isVolumeAverageOK;
    bool passPattern = !isPatternEnabled || isPattern;
    bool passSupertrend = !isSupertrendEnabled || aboveSupertrend;
    bool passEma20 = !isEma20Enabled || aboveEma20;
    bool passVolBreakout = !isVolBreakoutEnabled || isVolumeBreakout;
    bool isNotAbove5Percent = IndicatorUtils.isNotAbove5Percent(candles);
    int score = getSmartPriceActionScore(candles);
    bool isScoreGood = score >= 70;
    if (passVolAvg &&
        passPattern &&
        passSupertrend &&
        passEma20 &&
        isScoreGood) {
      print("Passed : $token");
      return true;
    }
    print(
        "Result: ${candles.last.timestamp}\n Volume:  (Enabled: $isVolAvgEnabled)\n Pattern: $isPattern (Enabled: $isPatternEnabled)\n EMA20: $aboveEma20 (Enabled: $isEma20Enabled)\n Supertrend: $aboveSupertrend (Enabled: $isSupertrendEnabled)\n VolBreakout: $isVolumeBreakout (Enabled: $isVolBreakoutEnabled)");
    return false;

    // FINAL RESULT
    bool result = isVolumeOk &&
        aboveEma20 &&
        rsiOk &&
        aboveVwap &&
        aboveSupertrend &&
        adxRes &&
        atrOk &&
        is2PcChange &&
        isVolume1M &&
        isVolumeBreakout;
    if (failedReasons.length == 1) {
      debugPrint(
          "Stock ${candles.last.timestamp} $token failed filters: ${failedReasons.join(", ")}");
    }
    return result;
  }

  /// 🔹 Main multi-timeframe validation
  static Future<bool> isPassAllTimeFrame(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
  ) async {
    final is5MinPass = await isPassHistoryChart(historyCandles, stock, 5);
    if (!is5MinPass) return false;

    final is15MinPass = await isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 15),
      ),
      stock,
      15,
    );
    if (!is15MinPass) return false;

    final is30MinPass = await isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 30),
      ),
      stock,
      30,
    );
    if (!is30MinPass) return false;

    final is1HourPass = await isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 60),
      ),
      stock,
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
  static Future<bool> isPassHistoryChart(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
    int timeFrame,
  ) async {
    if (historyCandles == null || historyCandles.isEmpty) return false;

    switch (timeFrame) {
      case 5:
        bool isPass =
            await passesFilter(historyCandles, stock.token.toString());
        return isPass;

      case 15:
      case 30:
      case 60:
        bool isEma20 =
            IndicatorUtils.isCloseAboveEMA(historyCandles, 20).isPassed;
        return isEma20;

      case 1:
        bool isEMA20 =
            IndicatorUtils.isCloseAboveEMA(historyCandles, 20).isPassed;
        bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
          historyCandles,
          atrPeriod: 10,
        ).isPassed;
        bool rsiOk = IndicatorUtils.isRsiBetween(
          historyCandles,
          14,
          min: 50,
          max: 70,
        );
        return isEMA20 && aboveSupertrend && rsiOk;

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
    if (lastPrice < 30 || lastPrice > 5000) return false;

    // ✅ Avoid circuit stocks
    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) return false;

    // ✅ Must be green today
    if (lastPrice <= open) return false;

    // ✅ Momentum required
    if (percentChange < 1.2) return false;

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

  static bool isBreakDownTradable(StockModel stock) {
    final lastPrice = stock.lastPrice;
    final lowerLimit = stock.lowerCircuitLimit;
    final upperLimit = stock.upperCircuitLimit;
    final ohlc = stock.ohlc;
    final open = ohlc?.open;
    final close = ohlc?.close;
    final volume = stock.volume;

    if (lastPrice == null ||
        open == null ||
        close == null ||
        lowerLimit == null ||
        upperLimit == null ||
        volume == null) {
      return false;
    }

    // Price range filter
    if (lastPrice <= 20 || lastPrice >= 500) return false;

    // Avoid circuit stocks
    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) return false;

    // 🔴 Breakdown condition: price below previous close
    if (lastPrice >= close) return false;

    // % change calculation (negative expected)
    final percentChange = ((lastPrice - open) / open) * 100;

    // Strong red candle only
    if (percentChange >= -1.5) return false;

    // Volume check – only on working day
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);
    final isWorkingDay = lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    if (isWorkingDay) {
      if (volume <= 15000) return false;
    }

    return true;
  }

  static bool passedDayFilter(List<HistoricalDataModel> candles, String token) {
    List<String> failedReasons = [];

    bool aboveEma20 = IndicatorUtils.isCloseAboveEMA(candles, 20).isPassed;
    if (!aboveEma20) failedReasons.add("Close NOT above EMA20");

    bool rsiOk = IndicatorUtils.isRsiBetween(candles, 14, min: 55, max: 95);
    if (!rsiOk) failedReasons.add("RSI not between 60–95");

    bool atrOk = IndicatorUtils.isAtrGreaterThanAdaptive(candles);
    if (!atrOk) failedReasons.add("ATR not greater than adaptive threshold");

    bool aboveVwap = IndicatorUtils.isCloseAboveVWAP(candles);
    if (!aboveVwap) failedReasons.add("Close NOT above VWAP");

    bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
      candles,
      atrPeriod: 10,
      multiplier: 3,
    ).isPassed;
    if (!aboveSupertrend) failedReasons.add("Close NOT above Supertrend");

    bool adxRes = IndicatorUtils.isAdxBullish(candles);
    if (!adxRes) failedReasons.add("ADX NOT bullish");

    // bool isVolumeOk = IndicatorUtils.isVolumeOk(candles);
    // if (!isVolumeOk) {
    //   failedReasons.add("Volume NOT > 15000 (vol=$isVolumeOk)");
    // }

    // bool isNearBuyingZone = IndicatorUtils.isNearEMA20OrSupertrendAutoForDay(
    //   candles,
    // );
    // if (!isNearBuyingZone) {
    //   failedReasons.add("Not near EMA20 or Supertrend for Day");
    // }

    bool isVolumeBreakout = IndicatorUtils.isVolumeBreakoutStrong(candles);
    if (!isVolumeBreakout) failedReasons.add("Volume breakout weak");

    // bool is2PcChange =
    //     IndicatorUtils.isCloseAboveYesterdayHighByPctAndYesterdayBullish(
    //       candles,
    //     );
    // if (!is2PcChange) failedReasons.add("2% Up + Yesterday Bullish failed");

    // FINAL RESULT
    bool result = aboveEma20 && rsiOk && aboveSupertrend && adxRes && atrOk;
    isVolumeBreakout;
    return result;
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
    return true;
    final lastPrice = stock.lastPrice;
    final lowerLimit = stock.lowerCircuitLimit;
    final upperLimit = stock.upperCircuitLimit;
    final ohlc = stock.ohlc;
    final close = ohlc?.close;
    final volume = stock.volume;
    final percentChange =
        ((stock.lastPrice! - stock.ohlc!.open!) / stock.ohlc!.open!) * 100;

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

  /// 🔥 DAILY INSTITUTIONAL TREND FILTER
  ///
  /// Purpose:
  /// Find strong trending stocks
  /// with healthy pullback structure
  /// before intraday entry.
  ///
  /// Use this FIRST.
  /// Then run 5min strategy only
  /// on shortlisted symbols.

  static bool isStrongDailyTrendSetup(
    List<HistoricalDataModel> candles,
  ) {
    if (candles.length < 200) {
      return false;
    }

    CandleUtils.sortByTime(candles);

    final daily = Utilities.convertToDaily(candles);

    final closes = daily.map((e) => e.close).toList();

    final ema20List = MathUtils.emaAligned(
      closes,
      20,
    );

    if (ema20List.isEmpty) {
      return false;
    }

    final ema20 = ema20List.last!;

    /// =========================================
    /// DAILY SUPERTREND
    /// =========================================

    /// =========================================
    /// DAILY RSI HEALTHY
    /// =========================================

    final rsiOk = IndicatorUtils.isRsiBetween(
      daily,
      14,
      min: 52,
      max: 75,
    );

    if (!rsiOk) {
      return false;
    }

    /// =========================================
    /// DAILY VOLUME PARTICIPATION
    /// =========================================

    final dailyVolumes = daily.map((e) => e.volume.toDouble()).toList();

    final avg10Volume = dailyVolumes
            .sublist(
              dailyVolumes.length - 10,
            )
            .reduce((a, b) => a + b) /
        10;

    final currentVolume = dailyVolumes.last;

    if (currentVolume < avg10Volume * 0.8) {
      return false;
    }

    /// =========================================
    /// RECENT MOMENTUM
    /// =========================================

    final currentClose = daily.last.close;

    final oldClose = daily[daily.length - 10].close;

    final movePct = ((currentClose - oldClose) / oldClose) * 100;

    if (movePct < 5) {
      return false;
    }

    /// =========================================
    /// NOT OVEREXTENDED
    /// =========================================

    final distanceFromEMA20 = ((currentClose - ema20) / ema20) * 100;

    if (distanceFromEMA20 > 10) {
      return false;
    }

    /// =========================================
    /// DAILY GREEN CANDLE
    /// =========================================

    final lastDaily = daily.last;

    if (lastDaily.close <= lastDaily.open) {
      return false;
    }

    /// =========================================
    /// CONTROLLED PULLBACK
    /// =========================================

    final recent = daily.sublist(
      daily.length - 5,
    );

    int redCount = 0;

    for (final c in recent) {
      if (c.close < c.open) {
        redCount++;
      }
    }

    if (redCount > 4) {
      return false;
    }

    /// =========================================
    /// VOLUME DRY-UP
    /// =========================================

    final previousTrendCandles = daily.sublist(
      daily.length - 15,
      daily.length - 5,
    );

    final previousAvgVolume =
        previousTrendCandles.map((e) => e.volume).reduce((a, b) => a + b) /
            previousTrendCandles.length;

    final recentAvgVolume =
        recent.map((e) => e.volume).reduce((a, b) => a + b) / recent.length;

    final dryUp = recentAvgVolume < previousAvgVolume * 0.8;

    if (!dryUp) {
      return false;
    }

    /// =========================================
    /// HOLDING EMA20
    /// =========================================

    final nearEMA20 = currentClose >= ema20 * 0.97;

    if (!nearEMA20) {
      return false;
    }

    /// =========================================
    /// RECLAIM CANDLE
    /// =========================================

    final last = daily.last;

    final candleRange = last.high - last.low;

    if (candleRange <= 0) {
      return false;
    }

    final candleBody = (last.close - last.open).abs();

    final bullish = last.close > last.open;

    final closeNearHigh = ((last.high - last.close) / candleRange) < 0.35;

    final upperWick = last.high -
        max(
          last.open,
          last.close,
        );

    final lowUpperWick = upperWick < candleBody * 0.8;

    if (!bullish || !closeNearHigh || !lowUpperWick) {
      return false;
    }

    /// =========================================
    /// AVOID PARABOLIC STOCKS
    /// =========================================

    if (movePct > 30) {
      return false;
    }

    debugPrint(
      "🔥 DAILY STRONG TREND SETUP => "
      "${candles.last.timestamp}",
    );

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

  static int getSmartPriceActionScore(
    List<HistoricalDataModel> candles,
  ) {
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
    final low = last.low;

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
    final passed = score >= 70;

    // bool isVolumeAverageOK = IndicatorUtils.isEveryCandleVolumeStrong(
    //     candles, 0,
    //     lastMultiplier: 1, otherMultiplier: 1);

    // if(!isVolumeAverageOK){
    //   return false;
    // }

    print(
      "${candles.last.timestamp}\n"
      "Smart Price Action Score: $score\n"
      "CloseNearHigh: $closeNearHigh\n"
      "LowUpperWick: $lowUpperWick\n"
      "StrongGreen: $strongGreen\n"
      "VolumeExpansion: $volumeExpansion\n"
      "SmoothStructure: $smoothStructure\n"
      "TightStructure: $tightStructure\n"
      "Breakout: $breakout\n"
      "HealthyPullback: $healthyPullback\n"
      "NotOverExtended: $notOverExtended\n"
      "ControlledGap: $controlledGap",
    );
    return score;
  }
}
