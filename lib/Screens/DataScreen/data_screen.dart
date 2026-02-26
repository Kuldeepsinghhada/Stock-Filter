import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'history_data_screen.dart';
import 'package:intl/intl.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  _DataScreenState createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  List<dynamic> allStocks = [];
  List<dynamic> filteredStocks = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadStocksData();
  }

  Future<void> _loadStocksData() async {
    try {
      final String response = await rootBundle.loadString('assets/main.json');
      final data = await json.decode(response);
      setState(() {
        allStocks = data;
        filteredStocks = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading json: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterStocks(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredStocks = allStocks;
      });
    } else {
      setState(() {
        filteredStocks =
            allStocks
                .where(
                  (stock) =>
                      stock['tradingsymbol'].toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      stock['name'].toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList()
                .reversed
                .toList();
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _navigateToHistory(dynamic stock) {
    final instrumentToken = stock['instrument_token'];
    final stockName = stock['tradingsymbol'];

    // Calculate dates: from 440 days ago to selected date
    final DateTime toDate = selectedDate;
    final DateTime fromDate = toDate.subtract(const Duration(days: 440));

    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String toDateString = formatter.format(toDate);
    final String fromDateString = formatter.format(fromDate);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => HistoryDataScreen(
              instrumentToken: instrumentToken.toString(),
              stockName: stockName,
              fromDate: fromDateString,
              toDate: toDateString,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Screen'),
      actions: [
        IconButton(onPressed: (){

        }, icon: Icon(Icons.score_outlined))
      ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: _filterStocks,
                            decoration: const InputDecoration(
                              labelText: 'Search Stocks',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton.icon(
                          onPressed: () => _selectDate(context),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat('dd MMM yyyy').format(selectedDate),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 16.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredStocks.length,
                      itemBuilder: (context, index) {
                        final stock = filteredStocks[index];
                        return ListTile(
                          title: Text(stock['tradingsymbol'] ?? 'Unknown'),
                          subtitle: Text(stock['name'] ?? ''),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => _navigateToHistory(stock),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
