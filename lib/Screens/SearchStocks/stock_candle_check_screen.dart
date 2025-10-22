import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/history_model.dart';
import 'package:stock_demo/model/stock_model.dart';

class StockCandleCheckScreen extends StatefulWidget {
  final StockModel stock;

  const StockCandleCheckScreen({super.key, required this.stock});

  @override
  State<StockCandleCheckScreen> createState() => _StockCandleCheckScreenState();
}

class _StockCandleCheckScreenState extends State<StockCandleCheckScreen> {
  List<HistoryModel> historyList = [];

  @override
  void initState() {
    _initialize();
    super.initState();
  }

  Future<void> _initialize() async {
    Future.delayed(const Duration(milliseconds: 200), () async {
      for (var item in DataManager.instance.preFilteredStocksList) {
        var result = await Utilities.buildTodayHistory(
          item.historyFiveMin ?? [],
          item,
        );
        if (result.isNotEmpty) {
          historyList = result;
        }
      }
      setState(() {
        //isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stock.symbol ?? ''} - 5m candle check'),
      ),
      body:
          historyList.isEmpty
              ? const Center(child: Text('No 5-min candle data for today'))
              : ListView.separated(
                itemCount: historyList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final obj = historyList[index];
                  return ListTile(
                    leading: Icon(
                      (obj.isPassed == true)
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: (obj.isPassed == true) ? Colors.green : Colors.red,
                    ),
                    title: Text(obj.price.toString()),
                    // subtitle: Text(
                    //   'O: $open  H: $high  L: $low  C: $close',
                    // ),
                    dense: true,
                  );
                },
              ),
    );
  }
}
