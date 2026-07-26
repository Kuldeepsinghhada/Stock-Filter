import 'package:stock_demo/model/historical_data_model.dart';

class PriceLevel {
  final double price;
  int touches;
  bool isResistance;

  PriceLevel({
    required this.price,
    required this.isResistance,
    this.touches = 1,
  });

  double get score => touches.toDouble();
}

class SupportResistanceEngine {
  /// left/right candles used for pivot
  static const int pivot = 2;

  /// Merge distance (0.8%)
  static const double mergePercent = 0.008;

  static List<PriceLevel> calculate(
    List<HistoricalDataModel> candles,
  ) {
    if (candles.length < 20) return [];

    List<PriceLevel> levels = [];

    //-----------------------------------
    // Find Pivot Highs
    //-----------------------------------

    for (int i = pivot; i < candles.length - pivot; i++) {
      if (_isPivotHigh(candles, i)) {
        _addLevel(
          levels,
          candles[i].high,
          true,
        );
      }

      if (_isPivotLow(candles, i)) {
        _addLevel(
          levels,
          candles[i].low,
          false,
        );
      }
    }

    levels.sort((a, b) => b.touches.compareTo(a.touches));

    return levels;
  }

  //-----------------------------------
  // Pivot High
  //-----------------------------------

  static bool _isPivotHigh(
    List<HistoricalDataModel> c,
    int i,
  ) {
    double h = c[i].high;

    return h > c[i - 1].high &&
        h > c[i - 2].high &&
        h > c[i + 1].high &&
        h > c[i + 2].high;
  }

  //-----------------------------------
  // Pivot Low
  //-----------------------------------

  static bool _isPivotLow(
    List<HistoricalDataModel> c,
    int i,
  ) {
    double l = c[i].low;

    return l < c[i - 1].low &&
        l < c[i - 2].low &&
        l < c[i + 1].low &&
        l < c[i + 2].low;
  }

  //-----------------------------------
  // Merge nearby levels
  //-----------------------------------

  static void _addLevel(
    List<PriceLevel> levels,
    double price,
    bool resistance,
  ) {
    for (final level in levels) {
      if (level.isResistance != resistance) continue;

      double diff = (price - level.price).abs() / level.price;

      if (diff <= mergePercent) {
        level.touches++;
        return;
      }
    }

    levels.add(
      PriceLevel(
        price: price,
        isResistance: resistance,
      ),
    );
  }

  //-----------------------------------
  // Nearest Resistance
  //-----------------------------------

  static PriceLevel? nearestResistance(
    List<PriceLevel> levels,
    double currentPrice,
  ) {
    PriceLevel? best;

    for (final l in levels) {
      if (!l.isResistance) continue;

      if (l.price > currentPrice) {
        if (best == null || l.price < best.price) {
          best = l;
        }
      }
    }

    return best;
  }

  //-----------------------------------
  // Nearest Support
  //-----------------------------------

  static PriceLevel? nearestSupport(
    List<PriceLevel> levels,
    double currentPrice,
  ) {
    PriceLevel? best;

    for (final l in levels) {
      if (l.isResistance) continue;

      if (l.price < currentPrice) {
        if (best == null || l.price > best.price) {
          best = l;
        }
      }
    }

    return best;
  }

  //-----------------------------------
  // Near Resistance?
  //-----------------------------------

  static bool isNearResistance(
    List<PriceLevel> levels,
    double price,
    double percent,
  ) {
    final r = nearestResistance(levels, price);

    if (r == null) return false;

    return ((r.price - price) / price) <= percent;
  }

  //-----------------------------------
  // Near Support?
  //-----------------------------------

  static bool isNearSupport(
    List<PriceLevel> levels,
    double price,
    double percent,
  ) {
    final s = nearestSupport(levels, price);

    if (s == null) return false;

    return ((price - s.price) / price) <= percent;
  }
}
