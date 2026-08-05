import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/StrategyTesting/api_backtest_screen.dart';
import 'package:stock_demo/Screens/Filterstocks/filtered_stocks.dart';
import 'package:stock_demo/Screens/Orders/orders_screen.dart';

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
      FilteredStockScreen(),
      const OrderScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_center_focus),
            label: "TRADE",
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: "ORDERS"),
        ],
      ),
    );
  }
}
