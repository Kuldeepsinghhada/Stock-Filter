import re

# 1. Fix indicator_cache.dart
with open('lib/Utils/INdicators/indicator_cache.dart', 'r') as f:
    text = f.read()

text = text.replace('Map<int, List<double>> _emaCache', 'Map<int, List<double?>> _emaCache')
text = text.replace('List<double> getEma', 'List<double?> getEma')

with open('lib/Utils/INdicators/indicator_cache.dart', 'w') as f:
    f.write(text)


# 2. Fix chart_screen.dart
with open('lib/Screens/Chart/chart_screen.dart', 'r') as f:
    text = f.read()
if 'indicator_engine.dart' not in text:
    text = text.replace("import 'package:stock_demo/Utils/indicators.dart';", "import 'package:stock_demo/Utils/indicators.dart';\nimport 'package:stock_demo/Utils/INdicators/indicator_engine.dart';")
text = text.replace('IndicatorUtils.supertrendSeries(candles)', 'IndicatorUtils.supertrendSeries(IndicatorEngine(candles))')
with open('lib/Screens/Chart/chart_screen.dart', 'w') as f:
    f.write(text)


# 3. Fix ai_score_calculator.dart
with open('lib/Utils/ai_score_calculator.dart', 'r') as f:
    text = f.read()
if 'indicator_engine.dart' not in text:
    text = text.replace("import 'package:stock_demo/Utils/indicators.dart';", "import 'package:stock_demo/Utils/indicators.dart';\nimport 'package:stock_demo/Utils/INdicators/indicator_engine.dart';")
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(dailyCandles)', 'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(dailyCandles))')
text = text.replace('IndicatorUtils.probabilityScore(candles)', 'IndicatorUtils.probabilityScore(IndicatorEngine(candles))')
text = text.replace('IndicatorUtils.probabilityScore(\n        candles,', 'IndicatorUtils.probabilityScore(\n        IndicatorEngine(candles),')
text = text.replace('IndicatorUtils.hasSmoothTrend(candles', 'IndicatorUtils.hasSmoothTrend(IndicatorEngine(candles)')
text = text.replace('IndicatorUtils.hasSmoothTrend(\n        candles,', 'IndicatorUtils.hasSmoothTrend(\n        IndicatorEngine(candles),')
text = text.replace('IndicatorUtils.getVolumeScore(candles', 'IndicatorUtils.getVolumeScore(IndicatorEngine(candles)')
text = text.replace('IndicatorUtils.getVolumeScore(\n        candles,', 'IndicatorUtils.getVolumeScore(\n        IndicatorEngine(candles),')
with open('lib/Utils/ai_score_calculator.dart', 'w') as f:
    f.write(text)


# 4. Fix filter_utils.dart
with open('lib/Utils/filter_utils.dart', 'r') as f:
    text = f.read()
text = text.replace('IndicatorUtils.isCloseAboveVWAP(candles)', 'IndicatorUtils.isCloseAboveVWAP(IndicatorEngine(candles))')
text = text.replace('IndicatorUtils.isAdxBullish(\n      candles,', 'IndicatorUtils.isAdxBullish(\n      IndicatorEngine(candles),')
text = text.replace('IndicatorUtils.isAdxBullish(candles,', 'IndicatorUtils.isAdxBullish(IndicatorEngine(candles),')
text = text.replace('IndicatorUtils.isAdxBullish(candles)', 'IndicatorUtils.isAdxBullish(IndicatorEngine(candles))')
text = text.replace('IndicatorUtils.checkDualVolumeStrength(candles', 'IndicatorUtils.checkDualVolumeStrength(IndicatorEngine(candles)')
with open('lib/Utils/filter_utils.dart', 'w') as f:
    f.write(text)


# 5. Fix utilities.dart
with open('lib/Utils/utilities.dart', 'r') as f:
    text = f.read()
if 'indicator_engine.dart' not in text:
    text = text.replace("import 'package:stock_demo/Utils/indicators.dart';", "import 'package:stock_demo/Utils/indicators.dart';\nimport 'package:stock_demo/Utils/INdicators/indicator_engine.dart';")
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(historyCandles)', 'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(historyCandles))')
text = text.replace('IndicatorUtils.isCloseAboveEMA(historyCandles, 20)', 'IndicatorUtils.isCloseAboveEMA(IndicatorEngine(historyCandles), 20)')
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(\n            historyCandles,\n            atrPeriod: 10,\n          )', 'IndicatorUtils.isCloseAboveSupertrend(\n            IndicatorEngine(historyCandles),\n            atrPeriod: 10,\n          )')
text = text.replace('IndicatorUtils.checkDualVolumeStrength(\n      historyCandles,', 'IndicatorUtils.checkDualVolumeStrength(\n      IndicatorEngine(historyCandles),')
text = text.replace('IndicatorUtils.checkDualVolumeStrength(historyCandles', 'IndicatorUtils.checkDualVolumeStrength(IndicatorEngine(historyCandles)')
with open('lib/Utils/utilities.dart', 'w') as f:
    f.write(text)

