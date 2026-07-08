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
  String refreshTokenKey = "refresh_token";
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
  String lastCandleMultiplierKey = "lastCandleMultiplier";
  String otherCandlesMultiplierKey = "otherCandlesMultiplier";
  String isVolumeAverageOKKey = "isVolumeAverageOK";
  String isPatternKey = "isPattern";
  String aboveSupertrendKey = "aboveSupertrend";
  String aboveEma20Key = "aboveEma20";
  String isVolumeBreakoutKey = "isVolumeBreakout";
  String isNearEmaOrSupertrendKey = "isNearEmaOrSupertrend";
  String telegramAlertsKey = "telegramAlerts";
  String maxTradeAmountKey = "maxTradeAmount";
  String defaultQuantityKey = "defaultQuantity";

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

  Future<bool?> setRefreshToken(String token) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    var status = await preferences.setString(refreshTokenKey, token);
    return status;
  }

  Future<String?> getRefreshToken() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    var data = preferences.getString(refreshTokenKey);
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

  Future<void> setStringList(String key, List<String> value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  Future<void> setLastCandleMultiplier(double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(lastCandleMultiplierKey, value);
  }

  Future<double> getLastCandleMultiplier() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(lastCandleMultiplierKey) ?? 5.0;
  }

  Future<void> setOtherCandlesMultiplier(double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(otherCandlesMultiplierKey, value);
  }

  Future<double> getOtherCandlesMultiplier() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(otherCandlesMultiplierKey) ?? 2.0;
  }

  Future<void> setVolumeAverageEnabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isVolumeAverageOKKey, value);
  }

  Future<bool> getVolumeAverageEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isVolumeAverageOKKey) ?? true;
  }

  Future<void> setPatternEnabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isPatternKey, value);
  }

  Future<bool> getPatternEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isPatternKey) ?? true;
  }

  Future<void> setSupertrendEnabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(aboveSupertrendKey, value);
  }

  Future<bool> getSupertrendEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(aboveSupertrendKey) ?? true;
  }

  Future<void> setEma20Enabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(aboveEma20Key, value);
  }

  Future<bool> getEma20Enabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(aboveEma20Key) ?? true;
  }

  Future<void> setVolumeBreakoutEnabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isVolumeBreakoutKey, value);
  }

  Future<bool> getVolumeBreakoutEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isVolumeBreakoutKey) ?? true;
  }

  Future<void> setNearEmaOrSupertrendEnabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isNearEmaOrSupertrendKey, value);
  }

  Future<bool> getNearEmaOrSupertrendEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isNearEmaOrSupertrendKey) ?? false;
  }

  String lastControlledAlertTimeKey = "lastControlledAlertTime_";

  Future<void> setLastControlledAlertTime(String symbol, String timestampStr) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastControlledAlertTimeKey + symbol, timestampStr);
  }

  Future<String?> getLastControlledAlertTime(String symbol) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastControlledAlertTimeKey + symbol);
  }

  Future<void> setTelegramAlertsEnabled(bool enabled) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(telegramAlertsKey, enabled);
  }

  Future<bool> getTelegramAlertsEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Enabled by default
    return prefs.getBool(telegramAlertsKey) ?? true;
  }

  String lastTelegramAlertDateKey = "lastTelegramAlertDate_";

  Future<void> setLastTelegramAlertDate(String symbol, String dateStr) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastTelegramAlertDateKey + symbol, dateStr);
  }

  Future<String?> getLastTelegramAlertDate(String symbol) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastTelegramAlertDateKey + symbol);
  }

  String lastRunDateKey = "lastRunDate";

  Future<void> setLastRunDate(String dateStr) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastRunDateKey, dateStr);
  }

  Future<String?> getLastRunDate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastRunDateKey);
  }

  Future<void> setMaxTradeAmount(double amount) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(maxTradeAmountKey, amount);
  }

  Future<double> getMaxTradeAmount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(maxTradeAmountKey) ?? 5000.0;
  }

  Future<int> getDefaultQuantity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(defaultQuantityKey) ?? 1;
  }

  Future<void> setDefaultQuantity(int quantity) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(defaultQuantityKey, quantity);
  }

  // Intraday breakout trade logic settings
  String atrPeriodKey = "atrPeriod";
  String atrMultiplierKey = "atrMultiplier";
  String riskRewardKey = "riskReward";
  String supertrendPeriodKey = "supertrendPeriod";
  String supertrendMultiplierKey = "supertrendMultiplier";
  String squareOffTimeKey = "squareOffTime";
  String squareOffEnabledKey = "squareOffEnabled";

  Future<void> setAtrPeriod(int value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(atrPeriodKey, value);
  }

  Future<int> getAtrPeriod() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(atrPeriodKey) ?? 14;
  }

  Future<void> setAtrMultiplier(double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(atrMultiplierKey, value);
  }

  Future<double> getAtrMultiplier() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(atrMultiplierKey) ?? 1.5;
  }

  Future<void> setRiskReward(double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(riskRewardKey, value);
  }

  Future<double> getRiskReward() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(riskRewardKey) ?? 2.0;
  }

  Future<void> setSupertrendPeriod(int value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(supertrendPeriodKey, value);
  }

  Future<int> getSupertrendPeriod() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(supertrendPeriodKey) ?? 10;
  }

  Future<void> setSupertrendMultiplier(double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(supertrendMultiplierKey, value);
  }

  Future<double> getSupertrendMultiplier() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(supertrendMultiplierKey) ?? 3.0;
  }

  Future<void> setSquareOffTime(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(squareOffTimeKey, value);
  }

  Future<String> getSquareOffTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(squareOffTimeKey) ?? "15:15";
  }

  Future<void> setSquareOffEnabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(squareOffEnabledKey, value);
  }

  Future<bool> getSquareOffEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(squareOffEnabledKey) ?? true;
  }
}
