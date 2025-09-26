import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:stock_demo/Services/notification_service.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/notification_model.dart';
import 'package:stock_demo/model/stock_model.dart';

class Utilities {
  static String formatIndianNumber(num value) {
    final isInteger = value == value.roundToDouble();
    final formatter = NumberFormat.decimalPattern('en_IN');
    return isInteger
        ? formatter.format(value)
        : NumberFormat.currency(
          locale: 'en_IN',
          symbol: '',
          decimalDigits: 2,
        ).format(value).trim();
  }

  // --------Load stocks list from local JSON file--------
  static Future<void> loadStocksList() async {
    final String jsonString = await rootBundle.loadString('assets/main.json');
    final List<dynamic> jsonData = json.decode(jsonString);
    DataManager.instance.stocksList =
        jsonData.map((item) {
          return StockModel(
            symbol: item['tradingsymbol']?.toString(),
            name: item['name']?.toString(),
            token: item['instrument_token']?.toString(),
            sector:
                item['sector']
                    ?.toString(), // If sector is missing, will be null
          );
        }).toList();
  }

  // -----------Convert Live Data to StockModel-------------
  static List<StockModel> convertDataToStockModel(
    Map<String, dynamic> stockMap,
  ) {
    List<StockModel> stockList = [];
    stockMap.forEach((key, value) {
      stockList.add(
        StockModel.fromMap({
          'symbol': key,
          'name': value['tradable']?.toString() ?? '',
          'token': value['instrument_token'],
          'timestamp': value['timestamp'],
          'last_trade_time': value['last_trade_time'],
          'last_price': value['last_price'],
          'last_quantity': value['last_quantity'],
          'buy_quantity': value['buy_quantity'],
          'sell_quantity': value['sell_quantity'],
          'volume': value['volume'],
          'average_price': value['average_price'],
          'oi': value['oi'],
          'oi_day_high': value['oi_day_high'],
          'oi_day_low': value['oi_day_low'],
          'net_change': value['net_change'],
          'lower_circuit_limit': value['lower_circuit_limit'],
          'upper_circuit_limit': value['upper_circuit_limit'],
          'ohlc': value['ohlc'],
        }),
      );
    });
    return stockList;
  }

  // ------------Notification Process---------------
  static Future<void> addAndShowNotification(List<StockModel> finalList) async {
    List<NotificationModel> notificationsList =
        await SharedPreferenceHelper.instance.getNotificationList();

    List<String> newStockSymbols = [];
    for (var stock in finalList) {
      bool exists = notificationsList.any(
        (n) =>
            n.stocksNameList?.toUpperCase().contains(
              stock.symbol!.toUpperCase(),
            ) ??
            false,
      );
      if (!exists) {
        newStockSymbols.add(stock.symbol!);
      }
    }

    // Add new notifications
    if (newStockSymbols.isNotEmpty) {
      notificationsList.add(
        NotificationModel(
          stocksNameList: newStockSymbols.join(','),
          time: Utilities.formatDDMMMHHMMDateTime(DateTime.now()),
        ),
      );
      // Show notification
      await NotificationService.showNotification(
        title: "Stock Alert",
        body:
            "${newStockSymbols.join(', ')} \n ${Utilities.formatDDMMMHHMMDateTime(DateTime.now())}",
      );
      log(
        "Notification triggered at ${Utilities.formatDDMMMHHMMDateTime(DateTime.now())}",
      );
    }

    await SharedPreferenceHelper.instance.saveNotificationList(
      notificationsList,
    );
  }

  // -----------GET END DATE FOR HISTORICAL DATA -----------
  static DateTime getLastWorkingDay(DateTime now) {
    // Saturday → Friday
    if (now.weekday == DateTime.saturday) {
      return now.subtract(const Duration(days: 1));
    }
    // Sunday → Friday
    else if (now.weekday == DateTime.sunday) {
      return now.subtract(const Duration(days: 2));
    }
    // Monday before 9:05 AM → Friday
    else if (now.weekday == DateTime.monday &&
        (now.hour < 9 || (now.hour == 9 && now.minute < 5))) {
      return now.subtract(const Duration(days: 3));
    }
    // Otherwise → same day
    else {
      return now;
    }
  }

  // -----------GET START DATE FOR HISTORICAL DATA -----------
  static String getBusinessDaysAgo(DateTime today, int businessDays) {
    DateTime date = today;
    int daysCounted = 0;
    while (daysCounted < businessDays) {
      date = date.subtract(const Duration(days: 1));
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        daysCounted++;
      }
    }
    final String fromDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return fromDate;
  }

  static List<HistoricalDataModel> resampleCandles(
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

  static HistoricalDataModel _aggregate(
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

  /// Convert 5-min candles → Daily candles using `_aggregate`
  static List<HistoricalDataModel> convertToDaily(
    List<HistoricalDataModel> fiveMinCandles,
  ) {
    if (fiveMinCandles.isEmpty) return [];

    final Map<String, List<HistoricalDataModel>> grouped = {};

    for (var c in fiveMinCandles) {
      final dayKey =
          "${c.timestamp.year}-${c.timestamp.month}-${c.timestamp.day}";
      grouped.putIfAbsent(dayKey, () => []).add(c);
    }

    final daily = <HistoricalDataModel>[];
    for (var entry in grouped.entries) {
      final candles = entry.value;
      candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // mark bucket start as market open
      final bucketStart = DateTime(
        candles.first.timestamp.year,
        candles.first.timestamp.month,
        candles.first.timestamp.day,
        9,
        15,
      );
      // use existing aggregate
      daily.add(_aggregate(candles, bucketStart));
    }
    daily.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return daily;
  }

  static String formatDDMMMHHMMDateTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('dd MMM HH:mm');
    return formatter.format(dateTime);
  }
}
