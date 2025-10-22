import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'stock_candle_check_screen.dart';

class SearchStocksScreen extends StatefulWidget {
  const SearchStocksScreen({super.key});

  @override
  State<SearchStocksScreen> createState() => _SearchStocksScreenState();
}

class _SearchStocksScreenState extends State<SearchStocksScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<StockModel> _filteredList;

  @override
  void initState() {
    super.initState();
    _filteredList = List<StockModel>.from(
      DataManager.instance.preFilteredStocksList,
    );
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
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Stocks')),
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
                suffixIcon:
                    _searchController.text.isNotEmpty
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
            child:
                _filteredList.isEmpty
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
                        return ListTile(
                          leading: Text(position.toString()),
                          title: Text(
                            obj.symbol ?? '',
                            style: const TextStyle(fontSize: 18),
                          ),
                          dense: true,
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // Navigate to the candle check screen for this stock
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => StockCandleCheckScreen(stock: obj),
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
