import 'package:flutter/material.dart';
import '../../Utils/sharepreference_helper.dart';

class VolumeSettingsScreen extends StatefulWidget {
  const VolumeSettingsScreen({super.key});

  @override
  State<VolumeSettingsScreen> createState() => _VolumeSettingsScreenState();
}

class _VolumeSettingsScreenState extends State<VolumeSettingsScreen> {
  final TextEditingController _lastMultiplierController =
      TextEditingController();
  final TextEditingController _otherMultiplierController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lastMultiplier =
        await SharedPreferenceHelper.instance.getLastCandleMultiplier();
    final otherMultiplier =
        await SharedPreferenceHelper.instance.getOtherCandlesMultiplier();
    setState(() {
      _lastMultiplierController.text = lastMultiplier.toString();
      _otherMultiplierController.text = otherMultiplier.toString();
    });
  }

  Future<void> _saveSettings() async {
    final last = double.tryParse(_lastMultiplierController.text);
    final other = double.tryParse(_otherMultiplierController.text);

    if (last != null && other != null) {
      await SharedPreferenceHelper.instance.setLastCandleMultiplier(last);
      await SharedPreferenceHelper.instance.setOtherCandlesMultiplier(other);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings saved successfully!")),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter valid numbers")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff131722),
      appBar: AppBar(
        title: const Text("Volume Multiplier Settings",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff131722),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildMultiplierInput(
              label: "Last Candle Volume Multiplier",
              controller: _lastMultiplierController,
              helperText: "e.g., 10, 15",
            ),
            const SizedBox(height: 24),
            _buildMultiplierInput(
              label: "Other Candles Volume Multiplier",
              controller: _otherMultiplierController,
              helperText: "e.g., 5, 7, 10",
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
                child: const Text("Save Settings",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
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
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
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
