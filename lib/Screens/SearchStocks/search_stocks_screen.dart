import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/notification_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'stock_candle_check_screen.dart';

class SearchStocksScreen extends StatefulWidget {
  const SearchStocksScreen({super.key});

  @override
  State<SearchStocksScreen> createState() => _SearchStocksScreenState();
}

class _SearchStocksScreenState extends State<SearchStocksScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<StockModel> _filteredList;
  bool _sortDescending = true; // true = highest percent first

  List<NotificationModel> notificationList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = List<StockModel>.from(
      DataManager.instance.preFilteredStocksList,
    );
    // keep clear icon reactive
    _searchController.addListener(() => setState(() {}));
    // Apply initial sort after first frame so UI shows sorted list by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applySort();
      getSavedTokenList();
    });
  }

  double? _percentChange(StockModel s) {
    final last = s.lastPrice;
    final open = s.ohlc?.open;
    if (last == null || open == null || open == 0) return null;
    return ((last - open) / open) * 100.0;
  }

  void _applySort() {
    setState(() {
      _filteredList.sort((a, b) {
        final pa = _percentChange(a);
        final pb = _percentChange(b);
        // Place missing values at the end regardless of direction
        if (pa == null && pb == null) return 0;
        if (pa == null) return 1;
        if (pb == null) return -1;
        // Both non-null: compare
        if (_sortDescending) {
          return pb.compareTo(pa);
        } else {
          return pa.compareTo(pb);
        }
      });
    });
  }

  void _filterStocks(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredList = List<StockModel>.from(
          DataManager.instance.preFilteredStocksList,
        );
      } else {
        _filteredList =
            DataManager.instance.preFilteredStocksList.where((item) {
          final symbol = (item.symbol ?? '').toLowerCase();
          return symbol.contains(q);
        }).toList();
      }
      // apply current sort after filtering
      _applySort();
    });
  }

  getSavedTokenList() async {
    notificationList =
        await SharedPreferenceHelper.instance.getNotificationList();
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Stocks'),
        actions: [
          IconButton(
            tooltip: _sortDescending ? 'Sort by % (desc)' : 'Sort by % (asc)',
            icon: Icon(
              _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: () {
              _sortDescending = !_sortDescending;
              _applySort();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _filterStocks,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by symbol',
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterStocks('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _filteredList.isEmpty
                ? const Center(
                    child: Text(
                      'No matching symbols',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredList.length,
                    itemBuilder: (context, position) {
                      var obj = _filteredList[position];
                      // compute percent change vs today's open (if available)
                      final ohlc = obj.ohlc;
                      final last = obj.lastPrice;
                      String pctText = '';
                      Color pctColor = Colors.black54;
                      if (last != null &&
                          ohlc?.open != null &&
                          ohlc!.open! != 0) {
                        final pct = ((last - ohlc.open!) / ohlc.open!) * 100;
                        pctText =
                            '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';
                        pctColor = pct >= 0 ? Colors.green : Colors.red;
                      }
                      var nIndex = notificationList.indexWhere(
                        (item) =>
                            item.stocksNameList?.toUpperCase().contains(
                                  obj.symbol!.toUpperCase(),
                                ) ??
                            false,
                      );

                      return ListTile(
                        leading: Text(
                          pctText,
                          style: TextStyle(color: pctColor),
                        ),
                        title: Text(
                          obj.symbol ?? '',
                          style: const TextStyle(fontSize: 18),
                        ),
                        dense: true,
                        trailing: IconButton(
                          onPressed: () {
                            if (nIndex != -1) {
                              notificationList.removeAt(nIndex);
                            } else {
                              notificationList.add(
                                NotificationModel(
                                  stocksNameList: obj.symbol,
                                  time: Utilities.formatDDMMMHHMMDateTime(
                                      DateTime.now()),
                                ),
                              );
                            }
                            SharedPreferenceHelper.instance
                                .saveNotificationList(notificationList);
                            setState(() {});
                          },
                          icon: nIndex != -1
                              ? Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                )
                              : Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.green,
                                ),
                        ),
                        onTap: () async {
                          var savedTokenList = await SharedPreferenceHelper
                              .instance
                              .getStockTokenList();
                          if (savedTokenList.contains(obj.token.toString())) {
                            Fluttertoast.showToast(
                                msg: "Already Saved for Candle Check");
                          } else {
                            savedTokenList.add(obj.token.toString());
                            await SharedPreferenceHelper.instance
                                .setStockTokenLists(savedTokenList);
                          }
                          // Navigate to the candle check screen for this stock
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  StockCandleCheckScreen(stock: obj),
                            ),
                          );
                        },
                      );
                    },
                    separatorBuilder: (context, positoin) {
                      return const Divider();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
