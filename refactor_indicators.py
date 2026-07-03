import re

with open('lib/Utils/indicators.dart', 'r') as f:
    content = f.read()

# Add imports
if 'indicator_engine.dart' not in content:
    content = content.replace("import 'candle_utils.dart';", "import 'candle_utils.dart';\nimport 'package:stock_demo/Utils/INdicators/indicator_engine.dart';")

# Method signatures
content = re.sub(r'(static\s+[a-zA-Z0-9_<>\?\{\}\(\)]+\s+[a-zA-Z0-9_]+)\(\s*List<HistoricalDataModel>\s+candles', r'\1(IndicatorEngine engine', content)

# Candle list properties
content = re.sub(r'\bcandles\.(length|isEmpty|isNotEmpty|sublist|map|any|where|lastWhere|fold|sort|last|first)\b', r'engine.candles.\1', content)
content = re.sub(r'\bcandles\[', r'engine.candles[', content)
content = re.sub(r'for\s*\(\s*(final|var|HistoricalDataModel)\s+([a-zA-Z0-9_]+)\s+in\s+candles\s*\)', r'for (\1 \2 in engine.candles)', content)
# other references to candles being passed to other IndicatorUtils methods
content = re.sub(r'IndicatorUtils\.([a-zA-Z0-9_]+)\(\s*candles', r'IndicatorUtils.\1(engine', content)

# Remove sorts
content = re.sub(r'CandleUtils\.sortByTime\(engine\.candles\);', r'// sorted by engine', content)
content = re.sub(r'engine\.candles\.sort\(\s*\(a,\s*b\)\s*=>\s*a\.timestamp\.compareTo\(b\.timestamp\)\s*\);', r'// sorted by engine', content)

# Daily candles
content = re.sub(r'Utilities\.convertToDaily\(engine\.candles\)', r'engine.dailyCandles', content)

# Group by date
content = re.sub(r'CandleUtils\.groupByDate\(engine\.candles\)', r'engine.groupedByDate', content)

# Arrays
content = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['close'\]!\.cast<double>\(\)", r"engine.closes", content)
content = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['high'\]!\.cast<double>\(\)", r"engine.highs", content)
content = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['low'\]!\.cast<double>\(\)", r"engine.lows", content)
content = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['open'\]!\.cast<double>\(\)", r"engine.opens", content)
content = re.sub(r"CandleUtils\.toArrays\(engine\.candles\)\['volume'\]!\.cast<int>\(\)", r"engine.volumes", content)

# Manual array assignments in methods like Supertrend
content = re.sub(r'final\s+arrs\s*=\s*CandleUtils\.toArrays\(engine\.candles\);', '', content)
content = re.sub(r"arrs\['close'\]!\.cast<double>\(\)", "engine.closes", content)
content = re.sub(r"arrs\['high'\]!\.cast<double>\(\)", "engine.highs", content)
content = re.sub(r"arrs\['low'\]!\.cast<double>\(\)", "engine.lows", content)
content = re.sub(r"arrs\['open'\]!\.cast<double>\(\)", "engine.opens", content)
content = re.sub(r"arrs\['volume'\]!\.cast<int>\(\)", "engine.volumes", content)

# Fix EMA using cache in isCloseAboveEMA
content = re.sub(
r"""static\s+IndicatorResult\s+isCloseAboveEMA\(\s*IndicatorEngine\s+engine,\s*int\s+period,\s*\)\s*\{[^}]+\}""",
"""static IndicatorResult isCloseAboveEMA(
    IndicatorEngine engine,
    int period,
  ) {
    if (engine.candles.length < period) {
      return IndicatorResult(isPassed: false, value: null);
    }
    final ema = engine.cache.getEma(period);
    final lastEma = ema.isNotEmpty ? ema.last : null;
    if (lastEma == null) return IndicatorResult(isPassed: false, value: null);
    return IndicatorResult(isPassed: engine.closes.last > lastEma, value: lastEma);
  }""", content, flags=re.MULTILINE | re.DOTALL)


with open('lib/Utils/indicators.dart', 'w') as f:
    f.write(content)

