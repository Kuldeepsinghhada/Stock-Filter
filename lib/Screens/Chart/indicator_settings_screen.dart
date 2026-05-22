import 'package:flutter/material.dart';
import '../../Utils/sharepreference_helper.dart';
import '../Settings/volume_settings_screen.dart';

class IndicatorSettingsScreen extends StatefulWidget {
  const IndicatorSettingsScreen({super.key});

  @override
  State<IndicatorSettingsScreen> createState() =>
      _IndicatorSettingsScreenState();
}

class _IndicatorSettingsScreenState extends State<IndicatorSettingsScreen> {
  bool _emaEnabled = true;
  bool _supertrendEnabled = true;
  bool _swingScannerEnabled = true;
  bool _onlyGreenEnabled = false;
  bool _nearEmaOrSupertrendEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = SharedPreferenceHelper.instance;
    final ema = await prefs.getEmaVisible();
    final supertrend = await prefs.getSupertrendVisible();
    final swing = await prefs.getEnableSwingScannerLoose();
    final onlyGreen = await prefs.getClosedInGreenEnabled();
    final nearEma = await prefs.getNearEmaOrSupertrendEnabled();
    
    setState(() {
      _emaEnabled = ema;
      _supertrendEnabled = supertrend;
      _swingScannerEnabled = swing;
      _onlyGreenEnabled = onlyGreen;
      _nearEmaOrSupertrendEnabled = nearEma;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff131722),
      appBar: AppBar(
        title: const Text("Indicator Settings",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff131722),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader("Scanner Settings"),
          _buildSwitchTile(
            title: "Swing Scanner (Loose)",
            subtitle:
                "Enable/Disable the loose swing trading strategy in bulk analysis.",
            value: _swingScannerEnabled,
            onChanged: (val) async {
              await SharedPreferenceHelper.instance
                  .setEnableSwingScannerLoose(val);
              setState(() => _swingScannerEnabled = val);
            },
            icon: Icons.radar,
            iconColor: Colors.purpleAccent,
          ),
          _buildSwitchTile(
            title: "Only Green Candles",
            subtitle:
                "Filter results to only show stocks that closed in green today.",
            value: _onlyGreenEnabled,
            onChanged: (val) async {
              await SharedPreferenceHelper.instance
                  .setClosedInGreenEnabled(val);
              setState(() => _onlyGreenEnabled = val);
            },
            icon: Icons.filter_list,
            iconColor: Colors.green,
          ),
          _buildSwitchTile(
            title: "Near EMA20 or Supertrend",
            subtitle: "Only show stocks currently trading near EMA20 or Supertrend.",
            value: _nearEmaOrSupertrendEnabled,
            onChanged: (val) async {
              await SharedPreferenceHelper.instance.setNearEmaOrSupertrendEnabled(val);
              setState(() => _nearEmaOrSupertrendEnabled = val);
            },
            icon: Icons.near_me,
            iconColor: Colors.cyanAccent,
          ),
          const Divider(color: Colors.white10, height: 32),
          _buildSectionHeader("Chart Indicators"),
          _buildSwitchTile(
            title: "Exponential Moving Average (EMA 20)",
            subtitle: "Shows short-term trend direction on the chart.",
            value: _emaEnabled,
            onChanged: (val) async {
              await SharedPreferenceHelper.instance.setEmaVisible(val);
              setState(() => _emaEnabled = val);
            },
            icon: Icons.trending_up,
            iconColor: Colors.blue,
          ),
          _buildSwitchTile(
            title: "Supertrend",
            subtitle:
                "Assists in identifying buy/sell signals based on volatility.",
            value: _supertrendEnabled,
            onChanged: (val) async {
              await SharedPreferenceHelper.instance.setSupertrendVisible(val);
              setState(() => _supertrendEnabled = val);
            },
            icon: Icons.bolt,
            iconColor: Colors.orange,
          ),
          const Divider(color: Colors.white10, height: 32),
          _buildSectionHeader("Advanced Settings"),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VolumeSettingsScreen()),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bar_chart, color: Colors.blueAccent, size: 24),
              ),
              title: const Text("Volume Multiplier Settings",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text("Adjust multipliers for volume strong check.",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blueAccent,
        ),
      ),
    );
  }
}
