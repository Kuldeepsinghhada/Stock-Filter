import 'package:stock_demo/model/historical_data_model.dart';

class PatternResult {
  final bool found;
  final String name;
  final double score;

  PatternResult({
    required this.found,
    required this.name,
    required this.score,
  });

  @override
  String toString() {
    return "Pattern: $name | Found: $found | Score: $score";
  }
}

class BullishPatternDetector {

  static bool detectTop3Patterns85(List<HistoricalDataModel> candles) {
    if (candles.length < 6) return false;

    // Last 2 completed candles
    final prev = candles[candles.length - 2];
    final curr = candles[candles.length - 1];

    // Previous trend candles
    final c3 = candles[candles.length - 3];
    final c4 = candles[candles.length - 4];
    final c5 = candles[candles.length - 5];

    List<PatternResult> basePatterns = [
      bullishEngulfRecovery(prev, curr),
      bearTrapReversal(prev, curr),
      supportBounce(prev, curr),
      powerCloseBreakout(prev, curr),
      volumeMomentumShift(prev, curr),
    ];

    for (var p in basePatterns) {
      if (!p.found) continue;

      double score = p.score;

      // 1. Relative Volume
      double avgVol = (c3.volume + c4.volume + c5.volume) / 3;
      if (curr.volume > avgVol * 2) score += 1.5;

      // 2. Strong Close Near High
      double range = curr.high - curr.low;
      if (range > 0 &&
          (curr.high - curr.close) <= range * 0.15) {
        score += 1.2;
      }

      // 3. Break Previous High
      if (curr.close > prev.high) score += 1.5;

      // 4. Strong Body
      double body = (curr.close - curr.open).abs();
      if (range > 0 && body >= range * 0.55) {
        score += 1.0;
      }

      // 5. Uptrend Confirmation
      if (curr.close > c3.close) score += 1.0;

      // 6. Small Upper Wick
      double upperWick = curr.high - curr.close;
      if (range > 0 && upperWick <= range * 0.10) {
        score += 0.8;
      }

      // Final Score Threshold
      if (score >= 9) {
        return true;
      }
    }
    return false;
  }

  static List<PatternResult> detectTop3Patterns(List<HistoricalDataModel> candles) {
    // Need minimum 2 completed candles
    if (candles.length < 2) {
      return [
        PatternResult(
          found: false,
          name: "No Data",
          score: 0,
        )
      ];
    }

    // Last 2 closed candles only
    final c1 = candles[candles.length - 2];
    final c2 = candles[candles.length - 1];

    final checks = [
      bullishEngulfRecovery(c1, c2),
      bearTrapReversal(c1, c2),
      supportBounce(c1, c2),
      powerCloseBreakout(c1, c2),
      volumeMomentumShift(c1, c2),
    ];

    // Only matched patterns
    final matched = checks.where((e) => e.found).toList();

    if (matched.isEmpty) {
      return [
        PatternResult(
          found: false,
          name: "No Bullish Pattern",
          score: 0,
        )
      ];
    }

    // Highest score first
    matched.sort((a, b) => b.score.compareTo(a.score));

    // Return top 3
    return matched.take(3).toList();
  }

  static PatternResult detect(List<HistoricalDataModel> candles) {
    // Need minimum 2 completed candles
    if (candles.length < 2) {
      return PatternResult(
        found: false,
        name: "No Data",
        score: 0,
      );
    }

    // Current running candle ignore kar diya
    // Last 2 closed candles use honge

    final c1 = candles[candles.length - 2]; // previous closed
    final c2 = candles[candles.length - 1]; // latest closed

    final checks = [
      bullishEngulfRecovery(c1, c2),
      bearTrapReversal(c1, c2),
      supportBounce(c1, c2),
      powerCloseBreakout(c1, c2),
      volumeMomentumShift(c1, c2),
    ];

    checks.sort((a, b) => b.score.compareTo(a.score));

    if (checks.first.found) {
      return checks.first;
    }
    return PatternResult(
      found: false,
      name: "No Bullish Pattern",
      score: 0,
    );
  }

  // ------------------------------
  // 1. Bullish Engulf Recovery
  static PatternResult bullishEngulfRecovery(
      HistoricalDataModel prev, HistoricalDataModel curr) {
    bool cond = prev.close < prev.open &&
        curr.close > curr.open &&
        curr.open <= prev.close &&
        curr.close >= prev.open;

    return PatternResult(
      found: cond,
      name: "Bullish Engulf Recovery",
      score: cond ? 9.2 : 0,
    );
  }

  // ------------------------------
  // 2. Bear Trap Reversal
  static PatternResult bearTrapReversal(
      HistoricalDataModel prev, HistoricalDataModel curr) {
    bool cond = curr.low < prev.low &&
        curr.close > curr.open &&
        curr.close > prev.close;

    return PatternResult(
      found: cond,
      name: "Bear Trap Reversal",
      score: cond ? 8.9 : 0,
    );
  }

  // ------------------------------
  // 3. Support Bounce
  static PatternResult supportBounce(
      HistoricalDataModel prev, HistoricalDataModel curr) {
    double lowerWick = curr.open - curr.low;

    bool cond =
        lowerWick > (curr.high - curr.low) * 0.35 && curr.close > curr.open;

    return PatternResult(
      found: cond,
      name: "Support Bounce",
      score: cond ? 8.3 : 0,
    );
  }

  // ------------------------------
  // 4. Power Close Breakout
  static PatternResult powerCloseBreakout(
      HistoricalDataModel prev, HistoricalDataModel curr) {
    bool cond = curr.close > prev.high &&
        (curr.high - curr.close) < (curr.high - curr.low) * 0.15;

    return PatternResult(
      found: cond,
      name: "Power Close Breakout",
      score: cond ? 9.0 : 0,
    );
  }

  // ------------------------------
  // 5. Inside Breakout Bullish
  static PatternResult insideBreakout(
      HistoricalDataModel c1, HistoricalDataModel c2, HistoricalDataModel c3) {
    bool inside = c2.high < c1.high && c2.low > c1.low;

    bool breakout = c3.close > c2.high;

    bool cond = inside && breakout;

    return PatternResult(
      found: cond,
      name: "Inside Breakout Bullish",
      score: cond ? 8.6 : 0,
    );
  }

  // ------------------------------
  // 6. Dip Buy Continuation
  static PatternResult dipBuyContinuation(
      HistoricalDataModel c1, HistoricalDataModel c2, HistoricalDataModel c3) {
    bool uptrend = c1.close > c1.open;
    bool dip = c2.close < c2.open;
    bool resume = c3.close > c3.open && c3.close > c2.high;

    bool cond = uptrend && dip && resume;

    return PatternResult(
      found: cond,
      name: "Dip Buy Continuation",
      score: cond ? 8.5 : 0,
    );
  }

  // ------------------------------
  // 7. Reclaim Move
  static PatternResult reclaimMove(
      HistoricalDataModel c1, HistoricalDataModel c2, HistoricalDataModel c3) {
    double avg = (c1.close + c2.close) / 2;

    bool cond = c2.close < avg && c3.close > avg;

    return PatternResult(
      found: cond,
      name: "Reclaim Move",
      score: cond ? 8.1 : 0,
    );
  }

  // ------------------------------
  // 8. Volume Momentum Shift
  static PatternResult volumeMomentumShift(
      HistoricalDataModel prev, HistoricalDataModel curr) {
    bool cond = curr.close > curr.open && curr.volume > prev.volume * 1.5;

    return PatternResult(
      found: cond,
      name: "Volume Momentum Shift",
      score: cond ? 9.1 : 0,
    );
  }
}
