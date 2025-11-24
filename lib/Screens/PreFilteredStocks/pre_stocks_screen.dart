import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/IndCheck/stock_check_screen.dart';
import 'package:stock_demo/Screens/history/history_screen.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/history_model.dart';
import 'package:stock_demo/model/stock_model.dart';

class PreFilteredStock extends StatefulWidget {
  const PreFilteredStock({super.key});

  @override
  State<PreFilteredStock> createState() => _PreFilteredStockState();
}

class _PreFilteredStockState extends State<PreFilteredStock> {
  String searchQuery = '';
  List<StockModel> quoteList = [];
  List<List<HistoryModel>> historyList = [];
  var isLoading = false;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    quoteList.clear();
    Future.delayed(const Duration(milliseconds: 200), () async {
      setState(() {
        isLoading = true;
      });
      for (var item in DataManager.instance.preFilteredStocksList) {
        var result = await Utilities.buildTodayHistory(
          item.historyFiveMin ?? [],
          item,
        );
        if (result.isNotEmpty) {
          quoteList.add(item);
          historyList.add(result);
        }
      }
      print(historyList.length);
      setState(() {
        isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<StockModel> get _filteredQuotes {
    if (searchQuery.isEmpty) return quoteList;
    return quoteList
        .where(
          (s) => (s.symbol ?? "").toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuotes;
    return Scaffold(
      appBar: AppBar(title: const Text('Pre Filtered Stocks')),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _initialize,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search by symbol',
                          border: OutlineInputBorder(),
                        ),
                        onChanged:
                            (value) =>
                                setState(() => searchQuery = value.trim()),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final stock = filtered[index];
                          final symbol =
                              stock.symbol?.replaceAll("NSE:", "") ?? '';
                          return ListTile(
                            leading: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            title: Text(symbol),
                            subtitle: Text(
                              'Token: ${stock.token}, Price: ${stock.lastPrice}',
                            ),
                            trailing: Text(
                              historyList[index].length.toString(),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => HistoryScreen(
                                        stockName: stock.symbol ?? '',
                                        historyModel: historyList[index],
                                      ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
