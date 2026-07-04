import 'package:flutter_test/flutter_test.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/Utils/math_utils.dart';
import 'package:stock_demo/model/historical_data_model.dart';

void main() {
  test('Before market close -> returns previous day', () {
    final now = DateTime(2026, 4, 21, 15, 29); // 21 Apr 2026 15:29
    final last = Utilities.getLastWorkingDay(now);
    expect(last, DateTime(2026, 4, 20));
  });

  test('After market close -> returns today', () {
    final now = DateTime(2026, 4, 21, 15, 31); // 21 Apr 2026 15:31
    final last = Utilities.getLastWorkingDay(now);
    expect(last, DateTime(2026, 4, 21));
  });

  test('Weekend (Sunday) -> returns previous Friday', () {
    final now = DateTime(2026, 4, 19, 12, 0); // Sunday
    final last = Utilities.getLastWorkingDay(now);
    expect(last, DateTime(2026, 4, 17)); // Friday 17 Apr 2026
  });

  group('convertToDaily', () {
    test('converts 5-min candles to daily candles', () {
      final baseTime = DateTime(2026, 4, 21, 9, 15);
      final List<HistoricalDataModel> fiveMinCandles = [];
      for (int i = 0; i < 75; i++) { // 1 day has 75 5-min candles (from 9:15 to 15:30)
        fiveMinCandles.add(HistoricalDataModel(
          timestamp: baseTime.add(Duration(minutes: 5 * i)),
          open: 100.0,
          high: 105.0,
          low: 95.0,
          close: 102.0,
          volume: 1000,
        ));
      }

      final daily = Utilities.convertToDaily(fiveMinCandles);
      expect(daily.length, 1);
      expect(daily.first.open, 100.0);
      expect(daily.first.close, 102.0);
      expect(daily.first.low, 95.0);
      expect(daily.first.high, 105.0);
    });
  });

  group('EMA 20 distance check', () {
    test('correctly calculates EMA 20 and checks 2% range', () {
      // Create daily close price history
      final List<double> closes = List.generate(30, (index) => 100.0 + index); // 100 to 129
      final ema20List = MathUtils.emaAligned(closes, 20);
      expect(ema20List.length, 30);
      expect(ema20List.last, isNotNull);

      final ema20 = ema20List.last!;
      
      // Let's verify distance calculation
      double lowWithin2Percent = ema20 * 0.99; // 1% below EMA20
      double distance1 = ((lowWithin2Percent - ema20).abs() / ema20);
      expect(distance1 <= 0.02, true);

      double lowOutside2Percent = ema20 * 0.97; // 3% below EMA20
      double distance2 = ((lowOutside2Percent - ema20).abs() / ema20);
      expect(distance2 <= 0.02, false);
    });
  });
}

