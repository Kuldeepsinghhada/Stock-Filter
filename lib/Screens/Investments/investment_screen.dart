import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/Investments/all_stock_screen.dart';
import 'package:stock_demo/Screens/Investments/investment_service.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/final_stock_model.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  bool isLoading = false;
  DateTime selectedDate = DateTime.now();
  List<String> investmentList = [];
  List<FinalStockModel> apiResultList = [];
  List<String> filteredInvestmentList = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    fetchData();
    super.initState();
  }

  Future<void> getInvestmentList() async {
    investmentList = await SharedPreferenceHelper.instance.getInvestmentList();
    filteredInvestmentList = investmentList.toSet().toList();
    setState(() {});
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);

    try {
      // 1️⃣ Always load investment list
      getInvestmentList();
      filteredInvestmentList = investmentList;

      // 2️⃣ API Call
      final result = await InvestmentService.instance.fetchQuotes(
        dateTime: selectedDate,
      );
      apiResultList = result;
    } catch (e) {
      log("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterStocks(String query) {
    if (query.isEmpty) {
      setState(() => filteredInvestmentList = investmentList);
    } else {
      setState(() {
        filteredInvestmentList =
            investmentList
                .where(
                  (symbol) =>
                      symbol.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      });
    }
  }

  bool hasBuySignal(String symbol) {
    return apiResultList.any((stock) => stock.stockSymbol == symbol);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });

      // 👉 Yaha tum API re-fetch ya filter logic laga sakte ho
      fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Investment"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllStockScreen()),
              );
              getInvestmentList();
            },
            icon: const Icon(Icons.list),
          ),
        ],
      ),
      body: Column(
        children: [
          /// 🔍 Search
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStocks,
              decoration: InputDecoration(
                hintText: "Search stock...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          /// 📋 List
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: fetchData,
                      child:
                          filteredInvestmentList.isEmpty
                              ? const Center(child: Text("No Stocks Found"))
                              : ListView.separated(
                                itemCount: filteredInvestmentList.length,
                                itemBuilder: (context, index) {
                                  final symbol = filteredInvestmentList[index];
                                  final buySignal = hasBuySignal(symbol);
                                  if (!buySignal) {
                                    return SizedBox();
                                  }
                                  return ListTile(
                                    title: Text(symbol),
                                    leading: const Icon(
                                      Icons.monetization_on_outlined,
                                    ),
                                    trailing:
                                        buySignal
                                            ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                "BUY",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                            : null,
                                  );
                                },
                                separatorBuilder: (context, index) {
                                  final symbol = filteredInvestmentList[index];
                                  final buySignal = hasBuySignal(symbol);
                                  if (!buySignal) {
                                    return SizedBox();
                                  }
                                  return const Divider();
                                },
                              ),
                    ),
          ),
        ],
      ),
    );
  }
}
