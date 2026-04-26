import 'package:flutter/material.dart';
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
  bool isDayBreakOut = false;
  bool isLoading = false;

  @override
  void initState() {
    _initialize();
    super.initState();
  }

  Future<void> _initialize() async {
    setState(() {
      isLoading = true;
      historyList.clear();
    });
    var result = await Utilities.buildTodayHistory(
      widget.stock.historyFiveMin ?? [],
      widget.stock,
      isDayBreakOut: isDayBreakOut,
    );
    if (result.isNotEmpty) {
      historyList = result;
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stock.symbol ?? ''}'),
        actions: [
          Row(
            children: [
              const Text('DayBreakOut', style: TextStyle(fontSize: 12)),
              Switch(
                value: isDayBreakOut,
                onChanged: (val) {
                  setState(() {
                    isDayBreakOut = val;
                  });
                  _initialize();
                },
              ),
            ],
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : historyList.isEmpty
              ? const Center(child: Text('No candle data matches filters'))
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
                    subtitle: Text(
                      obj.dateTime.toString(),
                    ),
                    dense: true,
                  );
                },
              ),
    );
  }
}
