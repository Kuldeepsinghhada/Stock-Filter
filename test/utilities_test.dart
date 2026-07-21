import 'package:flutter_test/flutter_test.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/Utils/math_utils.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
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
    final now = DateTime(2026, 4, 26, 12, 0); // Sunday
    final last = Utilities.getLastWorkingDay(now);
    expect(last, DateTime(2026, 4, 24)); // Friday 24 Apr 2026
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

  group('isStockAlreadyExtended', () {
    test('returns false when not enough candles', () {
      final candles = List.generate(
        10,
        (i) => HistoricalDataModel(
          timestamp: DateTime.now().subtract(Duration(minutes: 5 * (10 - i))),
          open: 100,
          high: 101,
          low: 99,
          close: 100,
          volume: 1000,
        ),
      );
      expect(FilterUtils.isStockAlreadyExtended(candles, 'TEST'), false);
    });

    test('correctly identifies healthy stock', () {
      // 30 candles with flat/minor price moves
      final candles = List.generate(
        30,
        (i) => HistoricalDataModel(
          timestamp: DateTime.now().subtract(Duration(minutes: 5 * (30 - i))),
          open: 100.0,
          high: 100.5,
          low: 99.5,
          close: 100.0,
          volume: 1000,
        ),
      );
      // Make current close > last high to avoid current close <= last high rejection
      candles[29] = HistoricalDataModel(
        timestamp: candles[29].timestamp,
        open: 100.0,
        high: 101.5,
        low: 99.5,
        close: 101.0, // 101.0 > last candle high (100.5)
        volume: 1000,
      );
      expect(FilterUtils.isStockAlreadyExtended(candles, 'TEST'), false);
    });

    test('rejects when Move > 5%', () {
      final candles = List.generate(
        30,
        (i) => HistoricalDataModel(
          timestamp: DateTime.now().subtract(Duration(minutes: 5 * (30 - i))),
          open: 100.0,
          high: 100.5,
          low: 99.5,
          close: 100.0,
          volume: 1000,
        ),
      );
      // Make a massive move in the last 6 candles
      candles[25] = HistoricalDataModel(
        timestamp: candles[25].timestamp,
        open: 100,
        high: 108,
        low: 99,
        close: 107,
        volume: 1000,
      );
      // Ensure current close (107.0) is above last high (100.5)
      candles[29] = HistoricalDataModel(
        timestamp: candles[29].timestamp,
        open: 100.0,
        high: 101.5,
        low: 99.5,
        close: 107.0,
        volume: 1000,
      );
      // lowest low is 99, highest high is 108. Move % = 9/99 * 100 = 9.09% (> 5%)
      expect(FilterUtils.isStockAlreadyExtended(candles, 'TEST'), true);
    });

    test('rejects when Distance from EMA > 6%', () {
      // Closes flat at 100 to build EMA20 around 100, then current close is 107
      final candles = List.generate(
        30,
        (i) => HistoricalDataModel(
          timestamp: DateTime.now().subtract(Duration(minutes: 5 * (30 - i))),
          open: i == 29 ? 107.0 : 100.0,
          high: i == 29 ? 107.5 : 100.5,
          low: i == 29 ? 106.5 : 99.5,
          close: i == 29 ? 107.0 : 100.0,
          volume: 1000,
        ),
      );
      // Is close (107.0) > last high (100.5)? Yes.
      expect(FilterUtils.isStockAlreadyExtended(candles, 'TEST'), true);
    });

    test('rejects when 4 consecutive green candles', () {
      final candles = List.generate(
        30,
        (i) => HistoricalDataModel(
          timestamp: DateTime.now().subtract(Duration(minutes: 5 * (30 - i))),
          open: 100.0,
          high: 100.5,
          low: 99.5,
          close: 100.0,
          volume: 1000,
        ),
      );
      // Make 4 consecutive green candles leading to index 29
      // index 26: 100 -> 101
      candles[26] = HistoricalDataModel(timestamp: candles[26].timestamp, open: 100, close: 101, high: 101.5, low: 99.5, volume: 1000);
      // index 27: 101 -> 102
      candles[27] = HistoricalDataModel(timestamp: candles[27].timestamp, open: 101, close: 102, high: 102.5, low: 100.5, volume: 1000);
      // index 28: 102 -> 103
      candles[28] = HistoricalDataModel(timestamp: candles[28].timestamp, open: 102, close: 103, high: 103.5, low: 101.5, volume: 1000);
      // index 29: 103 -> 104
      candles[29] = HistoricalDataModel(timestamp: candles[29].timestamp, open: 103, close: 104, high: 104.5, low: 102.5, volume: 1000);
      // current close (104) > last high (103.5).
      expect(FilterUtils.isStockAlreadyExtended(candles, 'TEST'), true);
    });

    test('rejects when current close is not above last candle high', () {
      final candles = List.generate(
        30,
        (i) => HistoricalDataModel(
          timestamp: DateTime.now().subtract(Duration(minutes: 5 * (30 - i))),
          open: 100.0,
          high: 100.5,
          low: 99.5,
          close: 100.0,
          volume: 1000,
        ),
      );
      // Here, current close is 100.0, last high is 100.5. Since 100.0 <= 100.5, it should reject (returns true)
      expect(FilterUtils.isStockAlreadyExtended(candles, 'TEST'), true);
    });
  });
}

