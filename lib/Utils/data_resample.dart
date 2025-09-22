import 'package:stock_demo/model/historical_data_model.dart';

List<HistoricalDataModel> resampleCandles(
  List<HistoricalDataModel> candles,
  Duration interval,
) {
  if (candles.isEmpty) return [];

  List<HistoricalDataModel> result = [];
  List<HistoricalDataModel> bucket = [];
  DateTime? bucketStart;

  for (var candle in candles) {
    final marketOpen = DateTime(
      candle.timestamp.year,
      candle.timestamp.month,
      candle.timestamp.day,
      9,
      15,
    );
    final marketClose = DateTime(
      candle.timestamp.year,
      candle.timestamp.month,
      candle.timestamp.day,
      15,
      30,
    );

    // skip anything outside market hours
    if (candle.timestamp.isBefore(marketOpen) ||
        candle.timestamp.isAfter(marketClose)) {
      continue;
    }

    // reset bucket start if it's a new day
    if (bucketStart == null || candle.timestamp.day != bucketStart.day) {
      // flush old bucket
      if (bucket.isNotEmpty) {
        result.add(_aggregate(bucket, bucketStart!));
        bucket.clear();
      }

      bucketStart = marketOpen;
    }

    // move bucketStart forward until candle fits
    while (candle.timestamp.isAfter(bucketStart!.add(interval))) {
      if (bucket.isNotEmpty) {
        result.add(_aggregate(bucket, bucketStart));
        bucket.clear();
      }
      bucketStart = bucketStart.add(interval);

      // stop creating buckets beyond market close
      if (bucketStart.isAfter(marketClose)) break;
    }

    // add candle to current bucket
    if (bucketStart.isBefore(marketClose.add(Duration(seconds: 1)))) {
      bucket.add(candle);
    }
  }

  // last bucket
  if (bucket.isNotEmpty && bucketStart != null) {
    result.add(_aggregate(bucket, bucketStart));
  }

  return result;
}

HistoricalDataModel _aggregate(
  List<HistoricalDataModel> bucket,
  DateTime start,
) {
  return HistoricalDataModel(
    timestamp: start,
    open: bucket.first.open,
    high: bucket.map((c) => c.high).reduce((a, b) => a > b ? a : b),
    low: bucket.map((c) => c.low).reduce((a, b) => a < b ? a : b),
    close: bucket.last.close,
    volume: bucket.map((c) => c.volume).reduce((a, b) => a + b),
  );
}
