import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/notification_model.dart';

class SharedPreferenceHelper {
  String kNotificationListKey = 'notificationList';
  String kAlarmRunning = "alarmRunning";
  String quotesKey = "quotes";
  String tokenKey = "access_token";
  String accessTokenExpiry = "access_token_expiry";
  String daily = "daily";

  // Private constructor
  SharedPreferenceHelper._internal();

  // Singleton instance
  static final SharedPreferenceHelper instance =
      SharedPreferenceHelper._internal();

  Future<bool?> setToken(String token) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    var status = await preferences.setString(tokenKey, token);
    return status;
  }

  Future<String?> getToken() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    var data = preferences.getString(tokenKey);
    return data;
  }

  Future<bool?> setTokenExpiryToken() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    final midnight =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    var status = await preferences.setInt(accessTokenExpiry, midnight);
    return status;
  }

  Future<int?> getTokenExpiry() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    var data = preferences.getInt(accessTokenExpiry);
    return data;
  }

  Future<void> saveDailyData(List<HistoricalDataModel> candles) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = candles.map((e) => e.toJson()).toList();
    await prefs.setString(daily, jsonEncode(jsonList));
  }

  Future<List<HistoricalDataModel>> loadDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(daily);
    if (data == null) return [];

    final list = jsonDecode(data) as List;
    return list.map((e) => HistoricalDataModel.fromJson(e)).toList();
  }

  Future<void> saveStocks(List<FinalStockModel> quotes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = quotes.map((q) => q.toJson()).toList();
    await prefs.setString(quotesKey, jsonEncode(jsonList));
  }

  Future<List<FinalStockModel>> getStocks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(quotesKey);
    if (jsonString == null) return [];
    final List decoded = jsonDecode(jsonString);
    return decoded.map((e) => FinalStockModel.fromJson(e)).toList();
  }

  Future<List<NotificationModel>> getNotificationList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var awesomeList = prefs.getStringList(kNotificationListKey) ?? [];
    List<NotificationModel> notifications =
        awesomeList
            .map((item) => NotificationModel.fromJson(jsonDecode(item)))
            .toList();
    return notifications;
  }

  Future<void> saveNotificationList(
    List<NotificationModel> notifications,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      kNotificationListKey,
      notifications.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }

  Future<void> clearNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(kNotificationListKey);
  }

  Future<void> setAlarmRunning(bool isRunning) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAlarmRunning, isRunning);
  }

  Future<bool> getAlarmRunning() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kAlarmRunning) ?? false;
  }

  Future<bool> clearData() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    return true;
  }
}
