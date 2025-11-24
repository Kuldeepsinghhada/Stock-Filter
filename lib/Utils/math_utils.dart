
/// Math helpers: SMA, EMA (aligned), rolling sums, etc.
class MathUtils {
  /// Simple moving average for last `period` values. Returns null if not enough values.
  static double? sma(List<double> values, int period, {int endIndex = -1}) {
    if (period <= 0) return null;
    final n = values.length;
    if (n < period) return null;
    endIndex = endIndex == -1 ? n - 1 : endIndex;
    if (endIndex - period + 1 < 0) return null;
    double sum = 0;
    for (int i = endIndex - period + 1; i <= endIndex; i++) {
      sum += values[i];
    }
    return sum / period;
  }

  /// EMA aligned: returns a list of length values.length where entries before period-1 are null.
  /// Uses Wilder/standard EMA formula (k = 2/(period+1)).
  static List<double?> emaAligned(List<double> values, int period) {
    final n = values.length;
    List<double?> out = List<double?>.filled(n, null);
    if (n < period) return out;

    // initial SMA for first EMA value (at index period-1)
    double initialSma = 0.0;
    for (int i = 0; i < period; i++) initialSma += values[i];
    initialSma /= period;
    out[period - 1] = initialSma;

    double prev = initialSma;
    final k = 2.0 / (period + 1);
    for (int i = period; i < n; i++) {
      double next = (values[i] - prev) * k + prev;
      out[i] = next;
      prev = next;
    }
    return out;
  }

  /// Rolling max of last `period` values ending at index (inclusive). Returns null if not enough values.
  static double? rollingMax(List<double> arr, int period, {int endIndex = -1}) {
    final n = arr.length;
    endIndex = endIndex == -1 ? n - 1 : endIndex;
    if (endIndex - period + 1 < 0) return null;
    double maxVal = arr[endIndex - period + 1];
    for (int i = endIndex - period + 2; i <= endIndex; i++) {
      if (arr[i] > maxVal) maxVal = arr[i];
    }
    return maxVal;
  }
}