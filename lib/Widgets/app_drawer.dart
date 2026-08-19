import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/Settings/server_setting_screen.dart';
import 'package:stock_demo/Screens/Settings/settings_screen.dart';
import 'package:stock_demo/Screens/Settings/trade_setting_screen.dart';
import 'package:stock_demo/Screens/StrategyTesting/api_backtest_screen.dart';
import 'package:stock_demo/Screens/SearchStocks/stock_5min_history_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.indigoAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.candlestick_chart, size: 42, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'Stock Filter Suite',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Live Trading & Analytics',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // 5-Min History Check
          ListTile(
            leading: const Icon(Icons.history, color: Colors.lightBlueAccent),
            title: const Text('Check 5-Min History'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Stock5MinHistoryScreen(),
                ),
              );
            },
          ),
          // Backtest
          ListTile(
            leading: const Icon(Icons.data_usage, color: Colors.tealAccent),
            title: const Text('Backtest & Strategy'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ApiBacktestScreen()),
              );
            },
          ),

          const Divider(),

          // Server Settings
          ListTile(
            leading: const Icon(Icons.dns, color: Colors.amberAccent),
            title: const Text('Server Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ServerSettingScreen()),
              );
            },
          ),

          // Trade Settings
          ListTile(
            leading: const Icon(Icons.tune, color: Colors.orangeAccent),
            title: const Text('Trade Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TradeSettingPage()),
              );
            },
          ),

          // All App Settings
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('All App Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
