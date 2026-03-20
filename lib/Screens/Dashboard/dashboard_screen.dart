import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/DataScreen/bulk_analysis_screen.dart';
import 'package:stock_demo/Screens/Filterstocks/filtered_stocks.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      BulkAnalysisScreen(selectedDate: DateTime.now()),
      FilteredStockScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.data_usage), label: "INVESTMENT"),
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_center_focus),
            label: "TRADE",
          )
        ],
      ),
    );
  }
}
