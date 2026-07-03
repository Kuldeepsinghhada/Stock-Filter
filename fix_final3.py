with open('lib/Utils/ai_score_calculator.dart', 'r') as f:
    text = f.read()
text = text.replace('IndicatorUtils.supertrendSeries(candles)', 'IndicatorUtils.supertrendSeries(IndicatorEngine(candles))')
text = text.replace('IndicatorUtils.isNearEMA20OrSupertrendAutoForDay(candles)', 'IndicatorUtils.isNearEMA20OrSupertrendAutoForDay(IndicatorEngine(candles))')
with open('lib/Utils/ai_score_calculator.dart', 'w') as f:
    f.write(text)

with open('lib/Utils/filter_utils.dart', 'r') as f:
    text = f.read()
text = text.replace('IndicatorUtils.isCloseAboveSupertrend(historySoFar,', 'IndicatorUtils.isCloseAboveSupertrend(IndicatorEngine(historySoFar),')
with open('lib/Utils/filter_utils.dart', 'w') as f:
    f.write(text)

with open('lib/Utils/utilities.dart', 'r') as f:
    text = f.read()
text = text.replace('IndicatorUtils.supertrendSeries(stock.historyFiveMin!)', 'IndicatorUtils.supertrendSeries(IndicatorEngine(stock.historyFiveMin!))')
text = text.replace('IndicatorUtils.getAllCandlesAvgX(stock.historyFiveMin!)', 'IndicatorUtils.getAllCandlesAvgX(IndicatorEngine(stock.historyFiveMin!))')
text = text.replace('IndicatorUtils.getTodayAvgVolume(stock.historyFiveMin!)', 'IndicatorUtils.getTodayAvgVolume(IndicatorEngine(stock.historyFiveMin!))')
text = text.replace('IndicatorUtils.getOtherCandlesAvgX(historySoFar)', 'IndicatorUtils.getOtherCandlesAvgX(IndicatorEngine(historySoFar))')
with open('lib/Utils/utilities.dart', 'w') as f:
    f.write(text)

