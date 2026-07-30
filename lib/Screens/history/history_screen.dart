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
      body: historyModel.isEmpty
          ? Center(child: Text("No data found"))
          : ListView.separated(
              itemCount: historyModel.length,
              itemBuilder: (context, position) {
                return ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Time: ${Utilities.formatDDMMMHHMMDateTime(historyModel[position].dateTime ?? DateTime.now())}",
                      ),
                      if (historyModel[position].apiPassed != null)
                        Text(
                          historyModel[position].apiPassed! ? "API: Passed" : "API: Rejected",
                          style: TextStyle(
                            color: historyModel[position].apiPassed! ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      if (historyModel[position].apiPassed == false && historyModel[position].apiReason != null && historyModel[position].apiReason!.isNotEmpty)
                        Text(
                          historyModel[position].apiReason!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                    ],
                  ),
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
