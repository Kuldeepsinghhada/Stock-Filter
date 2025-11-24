import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/Filterstocks/filtered_stocks.dart';
import 'package:stock_demo/Screens/Notification/notification_screen.dart';

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
      const FilteredStockScreen(),
      NotificationScreen(key: UniqueKey()), // give unique key for refresh
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // refresh NotificationScreen every time when selected
            if (index == 1) {
              _screens[1] = NotificationScreen(key: UniqueKey());
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_center_focus),
            label: "FILTERED",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.crisis_alert_sharp),
            label: "ALERT",
          ),
        ],
      ),
    );
  }
}