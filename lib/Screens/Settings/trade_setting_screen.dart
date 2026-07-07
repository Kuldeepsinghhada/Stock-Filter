import 'package:flutter/material.dart';
import '../../Utils/sharepreference_helper.dart';
import 'package:stock_demo/trading/trading_manager.dart';

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
  final TextEditingController _maxTradeAmountController =
      TextEditingController();

  final TextEditingController _atrPeriodController = TextEditingController();
  final TextEditingController _atrMultiplierController = TextEditingController();
  final TextEditingController _riskRewardController = TextEditingController();
  final TextEditingController _supertrendPeriodController = TextEditingController();
  final TextEditingController _supertrendMultiplierController = TextEditingController();
  final TextEditingController _squareOffTimeController = TextEditingController();
  bool _squareOffEnabled = true;

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
    final maxTradeAmount = await prefs.getMaxTradeAmount();

    final volAvg = await prefs.getVolumeAverageEnabled();
    final pattern = await prefs.getPatternEnabled();
    final supertrend = await prefs.getSupertrendEnabled();
    final ema20 = await prefs.getEma20Enabled();
    final volBreakout = await prefs.getVolumeBreakoutEnabled();
    final telegram = await prefs.getTelegramAlertsEnabled();

    final atrPeriod = await prefs.getAtrPeriod();
    final atrMultiplier = await prefs.getAtrMultiplier();
    final riskReward = await prefs.getRiskReward();
    final supertrendPeriod = await prefs.getSupertrendPeriod();
    final supertrendMultiplier = await prefs.getSupertrendMultiplier();
    final squareOffTime = await prefs.getSquareOffTime();
    final squareOffEnabled = await prefs.getSquareOffEnabled();

    setState(() {
      _lastMultiplierController.text = lastMultiplier.toString();
      _otherMultiplierController.text = otherMultiplier.toString();
      _maxTradeAmountController.text = maxTradeAmount.toString();
      _isVolumeAverageOK = volAvg;
      _isPattern = pattern;
      _aboveSupertrend = supertrend;
      _aboveEma20 = ema20;
      _isVolumeBreakout = volBreakout;
      _telegramAlerts = telegram;

      _atrPeriodController.text = atrPeriod.toString();
      _atrMultiplierController.text = atrMultiplier.toString();
      _riskRewardController.text = riskReward.toString();
      _supertrendPeriodController.text = supertrendPeriod.toString();
      _supertrendMultiplierController.text = supertrendMultiplier.toString();
      _squareOffTimeController.text = squareOffTime;
      _squareOffEnabled = squareOffEnabled;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = SharedPreferenceHelper.instance;
    final last = double.tryParse(_lastMultiplierController.text);
    final other = double.tryParse(_otherMultiplierController.text);
    final maxAmount = double.tryParse(_maxTradeAmountController.text);

    final atrPeriod = int.tryParse(_atrPeriodController.text);
    final atrMultiplier = double.tryParse(_atrMultiplierController.text);
    final riskReward = double.tryParse(_riskRewardController.text);
    final supertrendPeriod = int.tryParse(_supertrendPeriodController.text);
    final supertrendMultiplier = double.tryParse(_supertrendMultiplierController.text);
    final squareOffTime = _squareOffTimeController.text.trim();

    if (last != null &&
        other != null &&
        maxAmount != null &&
        atrPeriod != null &&
        atrMultiplier != null &&
        riskReward != null &&
        supertrendPeriod != null &&
        supertrendMultiplier != null &&
        squareOffTime.isNotEmpty) {
      await prefs.setLastCandleMultiplier(last);
      await prefs.setOtherCandlesMultiplier(other);
      await prefs.setMaxTradeAmount(maxAmount);

      await prefs.setVolumeAverageEnabled(_isVolumeAverageOK);
      await prefs.setPatternEnabled(_isPattern);
      await prefs.setSupertrendEnabled(_aboveSupertrend);
      await prefs.setEma20Enabled(_aboveEma20);
      await prefs.setVolumeBreakoutEnabled(_isVolumeBreakout);
      await prefs.setTelegramAlertsEnabled(_telegramAlerts);

      await prefs.setAtrPeriod(atrPeriod);
      await prefs.setAtrMultiplier(atrMultiplier);
      await prefs.setRiskReward(riskReward);
      await prefs.setSupertrendPeriod(supertrendPeriod);
      await prefs.setSupertrendMultiplier(supertrendMultiplier);
      await prefs.setSquareOffTime(squareOffTime);
      await prefs.setSquareOffEnabled(_squareOffEnabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings saved successfully!")),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Please enter valid numbers/values for all fields")),
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
            const Text("Auto Trading",
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildToggleTile(
              label: "Enable Auto Trading",
              value: TradingManager.instance.isAutoTradingEnabled,
              onChanged: (val) async {
                await TradingManager.instance.setAutoTradingStatus(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            _buildMultiplierInput(
              label: "Max Trade Amount (₹)",
              controller: _maxTradeAmountController,
              helperText: "e.g., 5000",
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
            const Divider(color: Colors.white10, height: 40),
            const Text("Breakout Strategy Settings",
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMultiplierInput(
                    label: "ATR Period",
                    controller: _atrPeriodController,
                    helperText: "e.g., 14",
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMultiplierInput(
                    label: "ATR Multiplier",
                    controller: _atrMultiplierController,
                    helperText: "e.g., 1.5",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMultiplierInput(
              label: "Risk Reward Ratio (e.g. 2 for 1:2)",
              controller: _riskRewardController,
              helperText: "e.g., 2.0",
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMultiplierInput(
                    label: "Supertrend Period",
                    controller: _supertrendPeriodController,
                    helperText: "e.g., 10",
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMultiplierInput(
                    label: "Supertrend Multiplier",
                    controller: _supertrendMultiplierController,
                    helperText: "e.g., 3.0",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildToggleTile(
              label: "EOD Square-off Enabled",
              value: _squareOffEnabled,
              onChanged: (val) => setState(() => _squareOffEnabled = val),
            ),
            const SizedBox(height: 16),
            _buildMultiplierInput(
              label: "Square-off Time (HH:MM)",
              controller: _squareOffTimeController,
              helperText: "e.g., 15:15",
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _showTestTradeDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Run Test Trade (Qty 1)",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestTradeDialog(BuildContext context) {
    final TextEditingController symbolController =
        TextEditingController(text: 'SAKSOFT');
    final TextEditingController priceController =
        TextEditingController(text: '100.0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1e222d),
          title:
              const Text('Test Trade', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: symbolController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Stock Symbol',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Current Price (Dummy)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final symbol = symbolController.text.trim().toUpperCase();
                final price =
                    double.tryParse(priceController.text.trim()) ?? 100.0;

                TradingManager.instance.testTradeExecution(symbol, price);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Test trade initiated for $symbol! Check console logs.')),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent),
              child: const Text('Execute'),
            ),
          ],
        );
      },
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
