import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableSwingScannerLoose = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    bool val = await SharedPreferenceHelper.instance.getEnableSwingScannerLoose();
    setState(() {
      _enableSwingScannerLoose = val;
      _isLoading = false;
    });
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
                // Add more settings here in the future
              ],
            ),
    );
  }
}
