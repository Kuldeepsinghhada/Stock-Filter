import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/notification_model.dart';

class BuyAlertPage extends StatefulWidget {
  const BuyAlertPage({super.key});

  @override
  State<BuyAlertPage> createState() => _BuyAlertPageState();
}

class _BuyAlertPageState extends State<BuyAlertPage> {
  List<NotificationModel> butAlertList = [];
  Future<bool> getNotifications() async {
    butAlertList = await SharedPreferenceHelper.instance.getBuyAlertLists();
    butAlertList = butAlertList.reversed.toList();
    setState(() {});
    return true;
  }

  @override
  void initState() {
    getNotifications();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buy Signal")),
      body: RefreshIndicator(
        onRefresh: getNotifications,
        child: ListView.builder(
          itemCount: butAlertList.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(butAlertList[index].stocksNameList ?? ''),
              subtitle: Text(butAlertList[index].time ?? ''),
              leading: const Icon(Icons.notifications),
              onTap: () {},
            );
          },
        ),
      ),
    );
  }
}
