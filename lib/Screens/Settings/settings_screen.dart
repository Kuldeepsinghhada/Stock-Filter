import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'trade_setting_screen.dart';
import 'package:stock_demo/Screens/StrategyTesting/strategy_testing_screen.dart';
import 'package:stock_demo/Screens/Settings/strategy_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _enableSwingScannerLoose = true;
  bool _closedInGreen = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load both settings: swing scanner and closed-in-green
    final swingEnabled =
        await SharedPreferenceHelper.instance.getEnableSwingScannerLoose();
    final closedGreenEnabled =
        await SharedPreferenceHelper.instance.getClosedInGreenEnabled();
    setState(() {
      _enableSwingScannerLoose = swingEnabled;
      _closedInGreen = closedGreenEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleClosedInGreen(bool value) async {
    setState(() {
      _closedInGreen = value;
    });
    await SharedPreferenceHelper.instance.setClosedInGreenEnabled(value);
  }

  Future<void> _toggleSwingScannerLoose(bool value) async {
    setState(() {
      _enableSwingScannerLoose = value;
    });
    await SharedPreferenceHelper.instance.setEnableSwingScannerLoose(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Enable Swing Scanner Loose Condition'),
                  subtitle: const Text(
                      'If enabled, filters stocks using the swing scanner loose condition during bulk analysis.'),
                  value: _enableSwingScannerLoose,
                  onChanged: _toggleSwingScannerLoose,
                ),
                SwitchListTile(
                  title: const Text('Closed in green only'),
                  subtitle: const Text(
                      'When enabled, bulk analysis will show only symbols whose last candle closed green.'),
                  value: _closedInGreen,
                  onChanged: _toggleClosedInGreen,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_suggest,
                      color: Colors.blueAccent),
                  title: const Text('Trade Logic Settings'),
                  subtitle: const Text(
                      'Configure filter toggles and volume multipliers'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TradeSettingPage()),
                    );
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.analytics, color: Colors.blueAccent),
                  title: const Text('Strategy Testing'),
                  subtitle:
                      const Text('Test backtest accuracy for specific stocks'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const StrategyTestingScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.compare_arrows,
                      color: Colors.blueAccent),
                  title: const Text('Strategy Selection'),
                  subtitle: const Text(
                      'Toggle between Controlled Trade and Volume TRADE'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const StrategySelectionScreen()),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
