with open('lib/Utils/indicators.dart', 'r') as f:
    lines = f.readlines()

def replace_in_line(line_num, old, new):
    lines[line_num - 1] = lines[line_num - 1].replace(old, new)

# 1508: `IndicatorUtils.isCloseAboveSupertrend(engine.candles,` -> `IndicatorUtils.isCloseAboveSupertrend(engine,`
replace_in_line(1508, 'engine.candles', 'engine')

# 1631: `IndicatorUtils.isCloseAboveSupertrend(engine.candles,`
replace_in_line(1631, 'engine.candles', 'engine')

# 1650: `isRsiBetween(engine.candles, 14, min: rsiMin, max: 80);`
replace_in_line(1650, 'engine.candles', 'engine')

# 1689: `IndicatorUtils.isCloseAboveSupertrend(engine.candles,`
replace_in_line(1689, 'engine.candles', 'engine')

with open('lib/Utils/indicators.dart', 'w') as f:
    f.writelines(lines)

