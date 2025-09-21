import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/IndCheck/stock_check_screen.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'dashboard_services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isLoading = true;
  List<String> messages = [];

  List<StockModel> quoteList = [];

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchQuotesFromService();
  }

  Future<void> _fetchQuotesFromService() async {
    setState(() {
      isLoading = true;
    });
    final result = await DashboardService.instance.fetchQuotes();
    setState(() {
      quoteList = result;
      log("Filtered Quotes Count: ${quoteList.length}");
      log(quoteList.map((e) => e.symbol).join(", "));
      isLoading = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<StockModel> get filteredQuoteList {
    // Filter by search query first
    final filtered =
        searchQuery.isEmpty
            ? quoteList
            : quoteList
                .where(
                  (stock) =>
                      stock.symbol != null &&
                      stock.symbol!
                          .replaceAll('NSE:', '')
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()),
                )
                .toList();
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          isLoading
              ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchQuotesFromService,
                tooltip: 'Refresh',
              ),
          IconButton(onPressed: (){
            Navigator.pushNamed(context, '/notifications');
          }, icon: Icon(Icons.notifications))
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by symbol',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredQuoteList.length,
              itemBuilder: (context, index) {
                final stock = filteredQuoteList[index];
                print(
                  "${stock.symbol?.replaceAll("NSE:", "") ?? ''} : ${stock.volume}",
                );
                return ListTile(
                  leading: Text(
                    (index + 1).toString(),
                    style: TextStyle(fontSize: 16),
                  ),
                  title: Text(stock.symbol?.replaceAll("NSE:", "") ?? ''),
                  subtitle: Text(
                    'Token: ${stock.token}, Price: ${stock.lastPrice}',
                  ),
                  trailing: Builder(
                    builder: (context) {
                      double? percentChange;
                      if (stock.ohlc != null &&
                          stock.ohlc!.open != null &&
                          stock.ohlc!.open != 0 &&
                          stock.lastPrice != null) {
                        percentChange =
                            ((stock.lastPrice! - stock.ohlc!.open!) /
                                stock.ohlc!.open!) *
                            100;
                      }
                      return percentChange != null
                          ? Text(
                            '${percentChange.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color:
                                  percentChange >= 0
                                      ? Colors.green
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : const SizedBox();
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockCheckScreen(stock: stock),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
