with open('lib/Utils/ai_score_calculator.dart', 'r') as f:
    text = f.read()
text = text.replace('IndicatorUtils.probabilityScore(dailyCandles)', 'IndicatorUtils.probabilityScore(IndicatorEngine(dailyCandles))')
text = text.replace('IndicatorUtils.hasSmoothTrend(dailyCandles)', 'IndicatorUtils.hasSmoothTrend(IndicatorEngine(dailyCandles))')
text = text.replace('IndicatorUtils.getVolumeScore(dailyCandles)', 'IndicatorUtils.getVolumeScore(IndicatorEngine(dailyCandles))')
text = text.replace('IndicatorUtils.probabilityScore(\n        dailyCandles', 'IndicatorUtils.probabilityScore(\n        IndicatorEngine(dailyCandles)')
text = text.replace('IndicatorUtils.hasSmoothTrend(\n        dailyCandles', 'IndicatorUtils.hasSmoothTrend(\n        IndicatorEngine(dailyCandles)')
text = text.replace('IndicatorUtils.getVolumeScore(\n        dailyCandles', 'IndicatorUtils.getVolumeScore(\n        IndicatorEngine(dailyCandles)')
text = text.replace('IndicatorUtils.getSmartPriceActionScore(candles)', 'IndicatorUtils.getSmartPriceActionScore(IndicatorEngine(candles))')
with open('lib/Utils/ai_score_calculator.dart', 'w') as f:
    f.write(text)

with open('lib/Utils/filter_utils.dart', 'r') as f:
    text = f.read()
text = text.replace('IndicatorUtils.getSmartPriceActionScore(candles)', 'IndicatorUtils.getSmartPriceActionScore(IndicatorEngine(candles))')
text = text.replace('IndicatorUtils.isYesterdayTotalVolumeAbove1M(candles)', 'IndicatorUtils.isYesterdayTotalVolumeAbove1M(IndicatorEngine(candles))')
text = text.replace('IndicatorUtils.isYesterdayAverageVolumeAbove(\n          candles,', 'IndicatorUtils.isYesterdayAverageVolumeAbove(\n          IndicatorEngine(candles),')
with open('lib/Utils/filter_utils.dart', 'w') as f:
    f.write(text)

with open('lib/Utils/utilities.dart', 'r') as f:
    text = f.read()
text = text.replace('IndicatorUtils.probabilityScore(\n          historyCandles,', 'IndicatorUtils.probabilityScore(\n          IndicatorEngine(historyCandles),')
text = text.replace('IndicatorUtils.isYesterdayAverageVolumeAbove(\n            historyCandles,', 'IndicatorUtils.isYesterdayAverageVolumeAbove(\n            IndicatorEngine(historyCandles),')
text = text.replace('IndicatorUtils.isYesterdayTotalVolumeAbove1M(historyCandles)', 'IndicatorUtils.isYesterdayTotalVolumeAbove1M(IndicatorEngine(historyCandles))')
text = text.replace('IndicatorUtils.isVolumeBreakoutStrongV2(candles, failureCount)', 'IndicatorUtils.isVolumeBreakoutStrongV2(IndicatorEngine(candles), failureCount)')
text = text.replace('IndicatorUtils.isVolumeBreakoutStrongV3(candles, failureCount)', 'IndicatorUtils.isVolumeBreakoutStrongV3(IndicatorEngine(candles), failureCount)')
text = text.replace('IndicatorUtils.isVolumeBreakoutStrongV2(historyCandles, 1)', 'IndicatorUtils.isVolumeBreakoutStrongV2(IndicatorEngine(historyCandles), 1)')
text = text.replace('IndicatorUtils.isCloseAboveYesterdayHighByPctAndYesterdayBullish(\n            historyCandles,', 'IndicatorUtils.isCloseAboveYesterdayHighByPctAndYesterdayBullish(\n            IndicatorEngine(historyCandles),')
text = text.replace('IndicatorUtils.isCloseAboveYesterdayHighByPct(historyCandles,', 'IndicatorUtils.isCloseAboveYesterdayHighByPct(IndicatorEngine(historyCandles),')
text = text.replace('IndicatorUtils.isVolumeBreakoutStrongV3(\n              historyCandles,', 'IndicatorUtils.isVolumeBreakoutStrongV3(\n              IndicatorEngine(historyCandles),')
with open('lib/Utils/utilities.dart', 'w') as f:
    f.write(text)

