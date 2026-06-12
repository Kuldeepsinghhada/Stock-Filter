import 'package:flutter/material.dart';
import '../../Utils/sharepreference_helper.dart';

class TradeSettingPage extends StatefulWidget {
  const TradeSettingPage({super.key});

  @override
  State<TradeSettingPage> createState() => _TradeSettingPageState();
}

class _TradeSettingPageState extends State<TradeSettingPage> {
  final TextEditingController _lastMultiplierController =
      TextEditingController();
  final TextEditingController _otherMultiplierController =
      TextEditingController();

  bool _isVolumeAverageOK = true;
  bool _isPattern = true;
  bool _aboveSupertrend = true;
  bool _aboveEma20 = true;
  bool _isVolumeBreakout = true;
  bool _telegramAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = SharedPreferenceHelper.instance;
    final lastMultiplier = await prefs.getLastCandleMultiplier();
    final otherMultiplier = await prefs.getOtherCandlesMultiplier();

    final volAvg = await prefs.getVolumeAverageEnabled();
    final pattern = await prefs.getPatternEnabled();
    final supertrend = await prefs.getSupertrendEnabled();
    final ema20 = await prefs.getEma20Enabled();
    final volBreakout = await prefs.getVolumeBreakoutEnabled();
    final telegram = await prefs.getTelegramAlertsEnabled();

    setState(() {
      _lastMultiplierController.text = lastMultiplier.toString();
      _otherMultiplierController.text = otherMultiplier.toString();
      _isVolumeAverageOK = volAvg;
      _isPattern = pattern;
      _aboveSupertrend = supertrend;
      _aboveEma20 = ema20;
      _isVolumeBreakout = volBreakout;
      _telegramAlerts = telegram;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = SharedPreferenceHelper.instance;
    final last = double.tryParse(_lastMultiplierController.text);
    final other = double.tryParse(_otherMultiplierController.text);

    if (last != null && other != null) {
      await prefs.setLastCandleMultiplier(last);
      await prefs.setOtherCandlesMultiplier(other);

      await prefs.setVolumeAverageEnabled(_isVolumeAverageOK);
      await prefs.setPatternEnabled(_isPattern);
      await prefs.setSupertrendEnabled(_aboveSupertrend);
      await prefs.setEma20Enabled(_aboveEma20);
      await prefs.setVolumeBreakoutEnabled(_isVolumeBreakout);
      await prefs.setTelegramAlertsEnabled(_telegramAlerts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings saved successfully!")),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Please enter valid numbers for multipliers")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff131722),
      appBar: AppBar(
        title:
            const Text("Trade Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff131722),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white10, height: 40),
            const Text("Filter Conditions",
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildToggleTile(
              label: "Volume Average (isVolumeAverageOK)",
              value: _isVolumeAverageOK,
              onChanged: (val) => setState(() => _isVolumeAverageOK = val),
            ),
            _buildToggleTile(
              label: "Bullish Pattern (isPattern)",
              value: _isPattern,
              onChanged: (val) => setState(() => _isPattern = val),
            ),
            _buildToggleTile(
              label: "Above Supertrend",
              value: _aboveSupertrend,
              onChanged: (val) => setState(() => _aboveSupertrend = val),
            ),
            _buildToggleTile(
              label: "Above EMA20",
              value: _aboveEma20,
              onChanged: (val) => setState(() => _aboveEma20 = val),
            ),
            _buildToggleTile(
              label: "Volume Breakout",
              value: _isVolumeBreakout,
              onChanged: (val) => setState(() => _isVolumeBreakout = val),
            ),
            _buildToggleTile(
              label: "Telegram Buy Alerts",
              value: _telegramAlerts,
              onChanged: (val) => setState(() => _telegramAlerts = val),
            ),
            const Divider(color: Colors.white10, height: 40),
            const Text("Volume Multipliers",
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMultiplierInput(
              label: "Last Candle Volume Multiplier",
              controller: _lastMultiplierController,
              helperText: "e.g., 15",
            ),
            const SizedBox(height: 20),
            _buildMultiplierInput(
              label: "Other Candles Volume Multiplier",
              controller: _otherMultiplierController,
              helperText: "e.g., 10",
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Save All Settings",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 15)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.blueAccent,
      activeTrackColor: const Color.fromRGBO(68, 138, 255, 0.25),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildMultiplierInput({
    required String label,
    required TextEditingController controller,
    required String helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
            hintText: helperText,
            hintStyle: const TextStyle(color: Colors.white24),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blueAccent)),
          ),
        ),
      ],
    );
  }
}
