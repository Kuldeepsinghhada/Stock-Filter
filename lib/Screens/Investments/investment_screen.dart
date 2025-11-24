import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/Investments/Service/investment_service.dart';
import 'package:stock_demo/model/final_stock_model.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen>
    with WidgetsBindingObserver {
  bool isLoading = true;
  bool isTaskRunning = false;
  String searchQuery = '';
  List<FinalStockModel> quoteList = [];
  Timer? _timer;
  DateTime? selectedDate; // <-- selected date state

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await fetchQuotesFromService(selectedDate: selectedDate); // always fetch fresh data once
  }

  // Accept optional selectedDate so UI can pass chosen date
  Future<void> fetchQuotesFromService({DateTime? selectedDate}) async {
    setState(() => isLoading = true);
    try {
      final result = await InvestmentService.instance.fetchQuotes(selectedDate);
      setState(() => quoteList = result);
    } catch (e) {
      log("Fetch quotes failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<FinalStockModel> get _filteredQuotes {
    if (searchQuery.isEmpty) return quoteList;
    return quoteList
        .where(
          (s) => (s.stockSymbol ?? "").toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuotes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('INVESTMENTS'),
        actions: [
          // Show selected date or calendar icon
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () async {
              final now = DateTime.now();
              final initial = selectedDate ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: now,
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
                await fetchQuotesFromService(selectedDate: picked);
              }
            },
            tooltip: 'Select date',
          ),
          if (selectedDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
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
              onChanged: (value) => setState(() => searchQuery = value.trim()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => fetchQuotesFromService(selectedDate: selectedDate),
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final stock = filtered[index];
                  final symbol =
                      stock.stockSymbol?.replaceAll("NSE:", "") ?? '';
                  final percentChange =
                      (stock.open != null &&
                              stock.open != 0 &&
                              stock.lastPrice != null)
                          ? ((stock.lastPrice! - stock.open!) / stock.open!) *
                              100
                          : null;

                  return ListTile(
                    leading: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    title: Text(symbol),
                    subtitle: Text(
                      'Token: ${stock.token}, Price: ${stock.lastPrice}',
                    ),
                    trailing: percentChange != null
                        ? Text(
                            '${percentChange.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: percentChange >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const SizedBox(),
                    onTap: () {
                      print(stock.link);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
