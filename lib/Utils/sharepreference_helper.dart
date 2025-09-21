import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_demo/model/notification_model.dart';

class SharedPreferenceHelper {
  String kNotificationListKey = 'notificationList';

  // Private constructor
  SharedPreferenceHelper._internal();

  // Singleton instance
  static final SharedPreferenceHelper instance =
      SharedPreferenceHelper._internal();

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
}
