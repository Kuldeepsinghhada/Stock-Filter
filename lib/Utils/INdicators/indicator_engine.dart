import 'package:stock_demo/Utils/candle_utils.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'indicator_cache.dart';

class IndicatorEngine {
  final List<HistoricalDataModel> candles;
  late final Map<String, List<dynamic>> _arrays;
  late final IndicatorCache cache;

  IndicatorEngine(List<HistoricalDataModel> input)
      : candles = List<HistoricalDataModel>.from(input) {
    CandleUtils.sortByTime(candles);
    _arrays = CandleUtils.toArrays(candles);
    cache = IndicatorCache(this);
  }

  late final Map<DateTime, List<HistoricalDataModel>> groupedByDate =
      CandleUtils.groupByDate(candles);

  late final List<HistoricalDataModel> dailyCandles =
      Utilities.convertToDaily(candles);

  HistoricalDataModel get last => candles.last;

  List<double> get closes => _arrays['close']!.cast<double>();
  List<double> get highs => _arrays['high']!.cast<double>();
  List<double> get lows => _arrays['low']!.cast<double>();
  List<double> get opens => _arrays['open']!.cast<double>();
  List<int> get volumes => _arrays['volume']!.cast<int>();
}
