import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/notification_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> notificationsList = [];

  @override
  void initState() {
    super.initState();
    getNotifications();
  }

  getNotifications() async {
    notificationsList =
        await SharedPreferenceHelper.instance.getNotificationList();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.builder(
        itemCount: notificationsList.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(notificationsList[index].stocksNameList ?? ''),
            subtitle: Text(notificationsList[index].time ?? ''),
            leading: const Icon(Icons.notifications),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Handle notification tap
            },
          );
        },
      ),
    );
  }
}
