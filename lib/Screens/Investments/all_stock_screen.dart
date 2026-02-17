import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/stock_model.dart';

class AllStockScreen extends StatefulWidget {
  const AllStockScreen({super.key});

  @override
  State<AllStockScreen> createState() => _AllStockScreenState();
}

class _AllStockScreenState extends State<AllStockScreen> {
  List<StockModel> allStocksList = [];
  List<StockModel> filteredList = [];
  List<String> savedInvestmentList = [];
  final TextEditingController _searchController = TextEditingController();

  bool showOnlyInvestments = false;

  @override
  void initState() {
    fetchStockList();
    super.initState();
  }

  Future<void> fetchStockList() async {
    await Utilities.loadStocksList();
    allStocksList = DataManager.instance.stocksList;
    filteredList = allStocksList;
    savedInvestmentList =
        await SharedPreferenceHelper.instance.getInvestmentList();

    // Remove duplicates safely
    savedInvestmentList =
        savedInvestmentList.map((e) => e.toUpperCase()).toSet().toList();

    setState(() {});
  }

  Future<void> updateInvestmentList(String symbol) async {
    symbol = symbol.toUpperCase();

    if (savedInvestmentList.contains(symbol)) {
      savedInvestmentList.remove(symbol);
    } else {
      savedInvestmentList.add(symbol);
    }

    // Remove duplicates again for safety
    savedInvestmentList = savedInvestmentList.toSet().toList();

    await SharedPreferenceHelper.instance.setInvestmentList(
      savedInvestmentList.toSet().toList(),
    );

    setState(() {});
  }

  void _filterStocks(String query) {
    if (query.isEmpty) {
      filteredList = allStocksList;
    } else {
      filteredList =
          allStocksList
              .where(
                (stock) => (stock.symbol ?? '').toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();
    }
    setState(() {});
  }

  List<StockModel> get displayList {
    if (showOnlyInvestments) {
      return filteredList
          .where(
            (stock) =>
                savedInvestmentList.contains(stock.symbol?.toUpperCase()),
          )
          .toList();
    }
    return filteredList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          showOnlyInvestments
              ? "My Investments (${savedInvestmentList.length})"
              : "All Stocks",
        ),
        actions: [
          IconButton(
            icon: Icon(showOnlyInvestments ? Icons.visibility_off : Icons.star),
            onPressed: () {
              setState(() {
                showOnlyInvestments = !showOnlyInvestments;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStocks,
              decoration: InputDecoration(
                hintText: "Search stock...",
                prefixIcon: const Icon(Icons.search),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // 📋 List
          Expanded(
            child:
                displayList.isEmpty
                    ? const Center(child: Text("No Stocks Found"))
                    : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final stock = displayList[index];
                        final isInvested = savedInvestmentList.contains(
                          stock.symbol?.toUpperCase(),
                        );

                        return ListTile(
                          title: Text(stock.symbol ?? ""),
                          leading: const Icon(Icons.monetization_on_outlined),
                          onTap: () {
                            updateInvestmentList(stock.symbol!);
                          },
                          trailing: IconButton(
                            onPressed: () {
                              updateInvestmentList(stock.symbol!);
                            },
                            icon:
                                isInvested
                                    ? const Icon(
                                      Icons.remove,
                                      color: Colors.red,
                                    )
                                    : const Icon(
                                      Icons.add,
                                      color: Colors.green,
                                    ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
