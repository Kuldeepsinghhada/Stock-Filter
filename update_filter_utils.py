import re

with open('lib/Utils/filter_utils.dart', 'r') as f:
    text = f.read()

# Add import
if 'indicator_engine.dart' not in text:
    text = text.replace("import 'package:stock_demo/Utils/indicators.dart';", "import 'package:stock_demo/Utils/indicators.dart';\nimport 'package:stock_demo/Utils/INdicators/indicator_engine.dart';")

# Re-write passesFilter completely using regex or string replacement
old_passes_filter = """  static bool passesFilter(List<HistoricalDataModel> candles, String token,
      {bool isHistoryCheck = false}) {
    final timeStr =
        candles.isNotEmpty ? candles.last.timestamp.toString() : "Unknown Time";

    var isLaseChanged = IndicatorUtils.isNotAlreadyMoved(candles);
    if (!isLaseChanged) {
      debugPrint(
          "Failed: $token at $timeStr - Reason: Last Candle Already Moved Significantly");
      return false;
    }

    if (!isHistoryCheck) {
      var isPercentChange = IndicatorUtils.isNotAbove10Percent(candles);
      if (!isPercentChange) {
        debugPrint("Failed: $token at $timeStr - Reason: Price Change > 13%");
        return false;
      }
    }

    int minVolume = isHistoryCheck ? 15000 : 15000;
    if (candles.last.volume < minVolume) {
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
  }"""

new_passes_filter = """  static bool passesFilter(List<HistoricalDataModel> candles, String token,
      {bool isHistoryCheck = false}) {
    if (candles.isEmpty) return false;
    
    final timeStr = candles.last.timestamp.toString();
    final engine = IndicatorEngine(candles);

    // 1. Volume
    int minVolume = 15000;
    if (engine.last.volume < minVolume) {
      debugPrint("Failed: $token at $timeStr - Reason: Low Volume (${engine.last.volume})");
      return false;
    }

    // 2. AlreadyMoved
    var isLaseChanged = IndicatorUtils.isNotAlreadyMoved(engine);
    if (!isLaseChanged) {
      debugPrint("Failed: $token at $timeStr - Reason: Last Candle Already Moved Significantly");
      return false;
    }

    // 3. RangeExpansion
    var rangeExpansion = IndicatorUtils.getRangeExpansion(engine);
    if (rangeExpansion > 6) {
      debugPrint("Failed: $token at $timeStr - Reason: Range Expansion ($rangeExpansion)");
      return false;
    }

    // 4. PriceChange
    if (!isHistoryCheck) {
      var isPercentChange = IndicatorUtils.isNotAbove10Percent(engine);
      if (!isPercentChange) {
        debugPrint("Failed: $token at $timeStr - Reason: Price Change > 13%");
        return false;
      }
    }

    // 5. VolumeSpike
    final volumeStrength = IndicatorUtils.checkDualVolumeStrength(engine);
    if (!volumeStrength.isVolumeSpike40x) {
      return false;
    }

    // 6. EMA
    if (cachedIsEma20Enabled) {
      bool aboveEma20 = IndicatorUtils.isCloseAboveEMA(engine, 20).isPassed;
      if (!aboveEma20) {
        debugPrint("Failed: $token at $timeStr - Reason: Below EMA20");
        return false;
      }
    }

    // 7. ATR
    bool atrOk = IndicatorUtils.isAtrGreaterThanAdaptive(engine);
    if (!atrOk) {
      debugPrint("Failed: $token at $timeStr - Reason: Low ATR");
      return false;
    }

    // 8. Supertrend
    if (cachedIsSupertrendEnabled) {
      bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
        engine,
        atrPeriod: 10,
        multiplier: 3,
      ).isPassed;
      if (!aboveSupertrend) {
        debugPrint("Failed: $token at $timeStr - Reason: Below Supertrend");
        return false;
      }
    }

    // 9. ADX
    bool adxRes = IndicatorUtils.isAdxBullish(engine);
    if (!adxRes) {
      debugPrint("Failed: $token at $timeStr - Reason: ADX Not Bullish");
      return false;
    }

    // 10. History
    final isDayPass = isPassHistoryChart(engine.dailyCandles, token, 1);
    if (!isDayPass) {
      debugPrint("Failed: $token at $timeStr - Reason: Day History Chart Failed");
      return false;
    }

    // 11. Pattern
    // if (cachedIsPatternEnabled) {
    //   var isPattern = BullishPatternDetector.isBullishStructure(engine.dailyCandles);
    //   if (!isPattern.bullish) {
    //     debugPrint("Failed: $token at $timeStr - Reason: No Bullish Pattern");
    //     return false;
    //   }
    // }

    debugPrint("Passed : $token");
    return true;
  }"""

if old_passes_filter in text:
    text = text.replace(old_passes_filter, new_passes_filter)
else:
    print("Warning: old passes_filter block not found. Checking if already applied or mismatched.")
    # attempt a fallback regex if we can't do exact match
    import sys
    sys.exit(1)

# Now apply IndicatorEngine refactor to other methods in filter_utils.dart

# isNearBuyingZone5Min
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(candles,', 'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(candles),')
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(historyCandles)', 'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(historyCandles))')
text = text.replace('IndicatorUtils.isCloseAboveEMA(historyCandles, 20)', 'IndicatorUtils.isCloseAboveEMA(IndicatorEngine(historyCandles), 20)')
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(\n          historyCandles,\n          atrPeriod: 10,\n        )', 'IndicatorUtils.isCloseAboveSupertrend(\n          IndicatorEngine(historyCandles),\n          atrPeriod: 10,\n        )')

with open('lib/Utils/filter_utils.dart', 'w') as f:
    f.write(text)

