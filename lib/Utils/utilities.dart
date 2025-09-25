import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:stock_demo/Services/notification_service.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
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
  static List<StockModel> convertDataToStockModel(Map<String, dynamic> stockMap) {
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
          time: DateTime.now().toString(),
        ),
      );
      // Show notification
      await NotificationService.showNotification(
        id: 0,
        title: "Stock Alert",
        body: "${newStockSymbols.join(', ')} -- ${DateTime.now()}",
      );
      log("Notification triggered at ${DateTime.now()}");
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
}
