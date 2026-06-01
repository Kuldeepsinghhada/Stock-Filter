import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';

class StrategySelectionScreen extends StatefulWidget {
  const StrategySelectionScreen({Key? key}) : super(key: key);

  @override
  State<StrategySelectionScreen> createState() => _StrategySelectionScreenState();
}

class _StrategySelectionScreenState extends State<StrategySelectionScreen> {
  String _selectedPlan = "Controlled Trade";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final plan = await SharedPreferenceHelper.instance.getSelectedPlan();
    setState(() {
      _selectedPlan = plan;
      _isLoading = false;
    });
  }

  Future<void> _updatePlan(String? value) async {
    if (value != null) {
      setState(() {
        _selectedPlan = value;
      });
      await SharedPreferenceHelper.instance.setSelectedPlan(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy Selection'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select which strategy logic you want to use for filtering stocks:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    child: RadioListTile<String>(
                      title: const Text("Controlled Trade"),
                      subtitle: const Text("Uses existing complex volume and indicator combination logic."),
                      value: "Controlled Trade",
                      groupValue: _selectedPlan,
                      onChanged: _updatePlan,
                      activeColor: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    child: RadioListTile<String>(
                      title: const Text("Volume TRADE"),
                      subtitle: const Text("Daily EMA 20 & Supertrend breakout + 50x Volume spike on 5m."),
                      value: "Volume TRADE",
                      groupValue: _selectedPlan,
                      onChanged: _updatePlan,
                      activeColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

