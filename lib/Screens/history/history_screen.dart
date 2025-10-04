import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/history_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.stockName,
    required this.historyModel,
  });
  final List<HistoryModel> historyModel;
  final String stockName;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(stockName)),
      body: ListView.separated(
        itemCount: historyModel.length,
        itemBuilder: (context, position) {
          return ListTile(
            title: Text(
              "Time: ${Utilities.formatDDMMMHHMMDateTime(historyModel[position].dateTime ?? DateTime.now())}",
            ),
            // subtitle: Text(
            //   "Trigger Price is : ${historyModel[position].price.toString()}",
            // ),
            trailing: Text(
              " Price: ${historyModel[position].price.toString()}",
              style: TextStyle(fontSize: 16),
            ),
          );
        },
        separatorBuilder: (context, position) {
          return Divider();
        },
      ),
    );
  }
}
