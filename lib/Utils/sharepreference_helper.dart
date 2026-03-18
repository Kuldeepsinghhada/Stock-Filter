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
  String tokenList = "tokenList";
  String bullishKey = "isBullish";
  String bearishKey = "isBearish";
  String buyAlertListKey = "buyAlertList";
  String investmentList = "investmentList";
  // new boolean preference: when true, only show symbols whose last candle closed green
  String closedInGreenKey = "closedInGreen";
  String emaVisibleKey = "emaVisible";
  String supertrendVisibleKey = "supertrendVisible";

  // Private constructor
  SharedPreferenceHelper._internal();

  // Singleton instance
  static final SharedPreferenceHelper instance =
      SharedPreferenceHelper._internal();

  String enableSwingScannerLooseKey = "enableSwingScannerLoose";

  Future<void> setEnableSwingScannerLoose(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enableSwingScannerLooseKey, value);
  }

  Future<bool> getEnableSwingScannerLoose() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Default to true
    return prefs.getBool(enableSwingScannerLooseKey) ?? true;
  }

  Future<void> setBullish(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(bullishKey, value);
  }

  Future<bool> getBullish() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(bullishKey) ?? false;
  }

  Future<void> setBearish(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(bearishKey, value);
  }

  Future<bool> getBearish() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(bearishKey) ?? false;
  }

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
    List<NotificationModel> notifications = awesomeList
        .map((item) => NotificationModel.fromJson(jsonDecode(item)))
        .toList();
    return notifications;
  }

  Future<void> saveNotificationList(
    List<NotificationModel> notifications,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> investmentList = await getInvestmentList();
    List<String> newSymbol = [];
    for (var n in notifications) {
      for (var stock in investmentList) {
        if (!n.stocksNameList!.contains(stock)) {
          if (!newSymbol.contains(stock)) {
            newSymbol.add(stock);
          }
        }
      }
    }
    investmentList.addAll(newSymbol.toSet().toList());
    await setInvestmentList(investmentList.toSet().toList());
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

  Future<void> setStockTokenLists(List<String> stockList) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(tokenList, stockList);
  }

  Future<List<String>> getStockTokenList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(tokenList) ?? [];
  }

  Future<bool> clearData() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    var investmentList = await getInvestmentList();
    await preferences.clear();
    await setInvestmentList(investmentList);
    return true;
  }

  Future<List<NotificationModel>> getBuyAlertLists() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var awesomeList = prefs.getStringList(buyAlertListKey) ?? [];
    List<NotificationModel> notifications = awesomeList
        .map((item) => NotificationModel.fromJson(jsonDecode(item)))
        .toList();
    return notifications;
  }

  Future<void> setBuyAlertList(List<NotificationModel> notifications) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      buyAlertListKey,
      notifications.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }

  Future<List<String>> getInvestmentList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var awesomeList = prefs.getStringList(investmentList) ?? [];
    return awesomeList;
  }

  Future<void> setInvestmentList(List<String> symbolList) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(investmentList, symbolList);
  }

  // Store whether to show only green-closed candles. Default: false (show both)
  Future<void> setClosedInGreenEnabled(bool enabled) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(closedInGreenKey, enabled);
  }

  Future<bool> getClosedInGreenEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(closedInGreenKey) ?? false;
  }

  Future<void> setEmaVisible(bool enabled) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(emaVisibleKey, enabled);
  }

  Future<bool> getEmaVisible() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(emaVisibleKey) ?? true;
  }

  Future<void> setSupertrendVisible(bool enabled) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(supertrendVisibleKey, enabled);
  }

  Future<bool> getSupertrendVisible() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(supertrendVisibleKey) ?? true;
  }
}
