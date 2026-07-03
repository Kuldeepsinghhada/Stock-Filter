import re

with open('lib/Utils/indicators.dart', 'r') as f:
    text = f.read()

# Add import
if 'indicator_engine.dart' not in text:
    text = text.replace("import 'candle_utils.dart';", "import 'candle_utils.dart';\nimport 'package:stock_demo/Utils/INdicators/indicator_engine.dart';")

# Replace method signatures:
# `List<HistoricalDataModel> candles` -> `IndicatorEngine engine`
text = text.replace('List<HistoricalDataModel> candles', 'IndicatorEngine engine')
text = text.replace('List<HistoricalDataModel>? historyCandles', 'IndicatorEngine? engine')
text = text.replace('IndicatorUtils.isCloseAboveEMA(\n      history,', 'IndicatorUtils.isCloseAboveEMA(\n      IndicatorEngine(history),')
text = text.replace('IndicatorUtils.isCloseAboveEMA(candles', 'IndicatorUtils.isCloseAboveEMA(engine')
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(\n      candles', 'IndicatorUtils.isCloseAboveSupertrend(\n      engine')
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(candles', 'IndicatorUtils.isCloseAboveSupertrend(engine')
text = text.replace('IndicatorUtils.isAdxBullish(candles', 'IndicatorUtils.isAdxBullish(engine')
text = text.replace('IndicatorUtils.checkDualVolumeStrength(candles)', 'IndicatorUtils.checkDualVolumeStrength(engine)')
text = text.replace('IndicatorUtils.isNotAbove10Percent(candles)', 'IndicatorUtils.isNotAbove10Percent(engine)')
text = text.replace('IndicatorUtils.isNotAlreadyMoved(candles)', 'IndicatorUtils.isNotAlreadyMoved(engine)')
text = text.replace('IndicatorUtils.getRangeExpansion(candles)', 'IndicatorUtils.getRangeExpansion(engine)')
text = text.replace('IndicatorUtils.isCloseAboveVWAP(candles)', 'IndicatorUtils.isCloseAboveVWAP(engine)')

# Candles properties
text = re.sub(r'\bcandles\b', 'engine.candles', text)

# Since we replaced "List<HistoricalDataModel> engine.candles", we have to fix the method signatures back!
text = text.replace('IndicatorEngine engine.candles', 'IndicatorEngine engine')
text = text.replace('IndicatorEngine? engine.candles', 'IndicatorEngine? engine')
text = text.replace('List<HistoricalDataModel> engine.candles,', 'List<HistoricalDataModel> candles,') # for places where it didn't match the exact 'List<HistoricalDataModel> candles' like 'List<HistoricalDataModel> allCandles'

# Fix arrays
text = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['close'\]!\.cast<double>\(\)", r"engine.closes", text)
text = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['high'\]!\.cast<double>\(\)", r"engine.highs", text)
text = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['low'\]!\.cast<double>\(\)", r"engine.lows", text)
text = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['open'\]!\.cast<double>\(\)", r"engine.opens", text)
text = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['volume'\]!\.cast<int>\(\)", r"engine.volumes", text)

text = text.replace("final arrs = CandleUtils.toArrays(engine.candles);", "")
text = text.replace("arrs['high']!.cast<double>()", "engine.highs")
text = text.replace("arrs['low']!.cast<double>()", "engine.lows")
text = text.replace("arrs['close']!.cast<double>()", "engine.closes")
text = text.replace("arrs['open']!.cast<double>()", "engine.opens")
text = text.replace("arrs['volume']!.cast<int>()", "engine.volumes")

# Remove redundant sorting and array creations
text = text.replace("CandleUtils.sortByTime(engine.candles);", "// sorted by engine")
text = text.replace("Utilities.convertToDaily(engine.candles)", "engine.dailyCandles")
text = text.replace("CandleUtils.groupByDate(engine.candles)", "engine.groupedByDate")


with open('lib/Utils/indicators.dart', 'w') as f:
    f.write(text)

