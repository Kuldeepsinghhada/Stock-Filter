import re

# filter_utils.dart
with open('lib/Utils/filter_utils.dart', 'r') as f:
    text = f.read()

# 855: IndicatorUtils.isCloseAboveVWAP(candles) or something
text = re.sub(r'IndicatorUtils\.isCloseAboveVWAP\(\s*candles\s*\)', r'IndicatorUtils.isCloseAboveVWAP(IndicatorEngine(candles))', text)
text = re.sub(r'IndicatorUtils\.isAdxBullish\(\s*candles\s*,', r'IndicatorUtils.isAdxBullish(IndicatorEngine(candles),', text)
with open('lib/Utils/filter_utils.dart', 'w') as f:
    f.write(text)


# utilities.dart
with open('lib/Utils/utilities.dart', 'r') as f:
    text = f.read()
text = re.sub(r'IndicatorUtils\.isCloseAboveEMA\(\s*([a-zA-Z0-9_]+)\s*,', r'IndicatorUtils.isCloseAboveEMA(IndicatorEngine(\1),', text)
text = re.sub(r'IndicatorUtils\.isCloseAboveSupertrend\(\s*([a-zA-Z0-9_]+)\s*,', r'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(\1),', text)
text = re.sub(r'IndicatorUtils\.isCloseAboveSupertrend\(\s*([a-zA-Z0-9_]+)\s*\)', r'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(\1))', text)
text = re.sub(r'IndicatorUtils\.checkDualVolumeStrength\(\s*([a-zA-Z0-9_]+)\s*,', r'IndicatorUtils.checkDualVolumeStrength(IndicatorEngine(\1),', text)
text = re.sub(r'IndicatorUtils\.checkDualVolumeStrength\(\s*([a-zA-Z0-9_]+)\s*\)', r'IndicatorUtils.checkDualVolumeStrength(IndicatorEngine(\1))', text)
with open('lib/Utils/utilities.dart', 'w') as f:
    f.write(text)


# ai_score_calculator.dart
with open('lib/Utils/ai_score_calculator.dart', 'r') as f:
    text = f.read()
text = re.sub(r'IndicatorUtils\.probabilityScore\(\s*([a-zA-Z0-9_]+)\s*,', r'IndicatorUtils.probabilityScore(IndicatorEngine(\1),', text)
text = re.sub(r'IndicatorUtils\.probabilityScore\(\s*([a-zA-Z0-9_]+)\s*\)', r'IndicatorUtils.probabilityScore(IndicatorEngine(\1))', text)
text = re.sub(r'IndicatorUtils\.hasSmoothTrend\(\s*([a-zA-Z0-9_]+)\s*,', r'IndicatorUtils.hasSmoothTrend(IndicatorEngine(\1),', text)
text = re.sub(r'IndicatorUtils\.hasSmoothTrend\(\s*([a-zA-Z0-9_]+)\s*\)', r'IndicatorUtils.hasSmoothTrend(IndicatorEngine(\1))', text)
text = re.sub(r'IndicatorUtils\.getVolumeScore\(\s*([a-zA-Z0-9_]+)\s*,', r'IndicatorUtils.getVolumeScore(IndicatorEngine(\1),', text)
text = re.sub(r'IndicatorUtils\.getVolumeScore\(\s*([a-zA-Z0-9_]+)\s*\)', r'IndicatorUtils.getVolumeScore(IndicatorEngine(\1))', text)
text = re.sub(r'IndicatorUtils\.isCloseAboveSupertrend\(\s*([a-zA-Z0-9_]+)\s*,', r'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(\1),', text)
text = re.sub(r'IndicatorUtils\.isCloseAboveSupertrend\(\s*([a-zA-Z0-9_]+)\s*\)', r'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(\1))', text)
text = re.sub(r'IndicatorUtils\.isCloseAboveEMA\(\s*([a-zA-Z0-9_]+)\s*,', r'IndicatorUtils.isCloseAboveEMA(IndicatorEngine(\1),', text)
text = re.sub(r'IndicatorUtils\.isCloseAboveEMA\(\s*([a-zA-Z0-9_]+)\s*\)', r'IndicatorUtils.isCloseAboveEMA(IndicatorEngine(\1))', text)
with open('lib/Utils/ai_score_calculator.dart', 'w') as f:
    f.write(text)

