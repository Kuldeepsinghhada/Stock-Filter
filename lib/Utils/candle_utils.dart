import '../model/historical_data_model.dart';

/// Candle related helpers (grouping, prepping arrays)
class CandleUtils {
  /// Ensure candles sorted ascending by timestamp
  static List<HistoricalDataModel> sortByTime(List<HistoricalDataModel> candles) {
    candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return candles;
  }

  static Map<DateTime, List<HistoricalDataModel>> groupByDate(
      List<HistoricalDataModel> candles) {
    final grouped = <DateTime, List<HistoricalDataModel>>{};
    DateTime? lastDate;
    
    for (var c in candles) {
      if (lastDate == null || 
          lastDate.year != c.timestamp.year || 
          lastDate.month != c.timestamp.month || 
          lastDate.day != c.timestamp.day) {
        lastDate = DateTime(c.timestamp.year, c.timestamp.month, c.timestamp.day);
      }
      grouped.putIfAbsent(lastDate, () => []).add(c);
    }
    // ensure each day's candles sorted
    for (var k in grouped.keys) {
      grouped[k]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    return grouped;
  }

  /// Flatten lists: returns closes, highs, lows, volumes in same order as candles
  static Map<String, List<num>> toArrays(List<HistoricalDataModel> candles) {
    final closes = <num>[];
    final highs = <num>[];
    final lows = <num>[];
    final volumes = <num>[];
    final open = <num>[];

    for (var c in candles) {
      closes.add(c.close);
      highs.add(c.high);
      lows.add(c.low);
      volumes.add(c.volume);
      open.add(c.open);
    }
    return {
      'close': closes,
      'high': highs,
      'low': lows,
      'volume': volumes,
      'open': open
    };
  }
}