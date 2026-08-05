import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/server_setting_model.dart';

class ServerSettingScreen extends StatefulWidget {
  const ServerSettingScreen({super.key});

  @override
  State<ServerSettingScreen> createState() => _ServerSettingScreenState();
}

class _ServerSettingScreenState extends State<ServerSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _maxTradeAmountController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  TimeOfDay _squareOffTime = const TimeOfDay(hour: 15, minute: 15);
  bool _enableTelegramAlert = true;
  bool _enableAutoTrading = false;
  String? _updatedAt;

  @override
  void initState() {
    super.initState();
    _fetchLiveSettings();
  }

  @override
  void dispose() {
    _maxTradeAmountController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await BackendOrderService.getServerSettings();

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final settings = response.data!;
      setState(() {
        _maxTradeAmountController.text =
            settings.maxTradeAmount.toStringAsFixed(2);
        _squareOffTime = _parseTimeString(settings.squareOffTime);
        _enableTelegramAlert = settings.enableTelegramAlert;
        _enableAutoTrading = settings.enableAutoTrading;
        _updatedAt = settings.updatedAt;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message.isNotEmpty
            ? response.message
            : "Failed to load live server settings.";
        _isLoading = false;
      });
    }
  }

  Future<void> _saveServerSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final maxAmount = double.tryParse(_maxTradeAmountController.text.trim());
    if (maxAmount == null || maxAmount <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid trade amount");
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final newSettings = ServerSettings(
      maxTradeAmount: maxAmount,
      squareOffTime: _formatTimeOfDay(_squareOffTime),
      enableTelegramAlert: _enableTelegramAlert,
      enableAutoTrading: _enableAutoTrading,
    );

    final response = await BackendOrderService.updateServerSettings(newSettings);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (response.isSuccess) {
      Fluttertoast.showToast(
        msg: response.message.isNotEmpty
            ? response.message
            : "Server settings updated successfully!",
        backgroundColor: Colors.green,
      );

      if (response.data != null) {
        setState(() {
          _maxTradeAmountController.text =
              response.data!.maxTradeAmount.toStringAsFixed(2);
          _squareOffTime = _parseTimeString(response.data!.squareOffTime);
          _enableTelegramAlert = response.data!.enableTelegramAlert;
          _enableAutoTrading = response.data!.enableAutoTrading;
          _updatedAt = response.data!.updatedAt ?? DateTime.now().toIso8601String();
        });
      } else {
        setState(() {
          _updatedAt = DateTime.now().toIso8601String();
        });
      }
    } else {
      Fluttertoast.showToast(
        msg: response.message.isNotEmpty
            ? response.message
            : "Failed to update server settings",
        backgroundColor: Colors.red,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${response.message}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0].trim());
        final minute = int.parse(parts[1].trim());
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return const TimeOfDay(hour: 15, minute: 15);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Future<void> _selectSquareOffTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _squareOffTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null && picked != _squareOffTime) {
      setState(() {
        _squareOffTime = picked;
      });
    }
  }

  String _formatUpdatedAt(String? rawDateStr) {
    if (rawDateStr == null || rawDateStr.isEmpty) return "N/A";
    try {
      final dt = DateTime.parse(rawDateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return rawDateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Live Settings',
            onPressed: _isLoading || _isSaving ? null : _fetchLiveSettings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Fetching live server settings...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                "Unable to Load Live Settings",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchLiveSettings,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry Connection"),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLiveSettings,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Header Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: Colors.blueAccent.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.dns, color: Colors.blueAccent, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Live Server Configuration",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Changes apply directly to server-side trading operations.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Trade Settings
            const Text(
              "TRADING PARAMETERS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Max Trade Amount Field
                    TextFormField(
                      controller: _maxTradeAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Max Trade Amount (₹)',
                        hintText: 'e.g. 50000.00',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        helperText:
                            'Maximum capital allowed per trade on server',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Max Trade Amount is required';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid amount greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Square Off Time Picker Tile
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_filled,
                          color: Colors.orangeAccent),
                      title: const Text('Square Off Time'),
                      subtitle: Text(
                        'Scheduled time to close intraday positions (${_formatTimeOfDay(_squareOffTime)})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orangeAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTimeOfDay(_squareOffTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit,
                                size: 16, color: Colors.orangeAccent),
                          ],
                        ),
                      ),
                      onTap: () => _selectSquareOffTime(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Automation & Notifications
            const Text(
              "AUTOMATION & ALERTS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary:
                        const Icon(Icons.send_rounded, color: Colors.lightBlue),
                    title: const Text('Enable Telegram Alert'),
                    subtitle: const Text(
                      'Receive instant signal & trade updates via Telegram',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _enableTelegramAlert,
                    onChanged: (bool value) {
                      setState(() {
                        _enableTelegramAlert = value;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.smart_toy_rounded,
                      color: _enableAutoTrading
                          ? Colors.greenAccent
                          : Colors.grey,
                    ),
                    title: const Text('Enable Auto Trading'),
                    subtitle: Text(
                      _enableAutoTrading
                          ? 'Server will execute trades automatically based on signals'
                          : 'Auto trading is disabled on server',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            _enableAutoTrading ? Colors.green : Colors.grey,
                      ),
                    ),
                    value: _enableAutoTrading,
                    onChanged: (bool value) {
                      setState(() {
                        _enableAutoTrading = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Updated At Chip
            if (_updatedAt != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        "Last Updated: ${_formatUpdatedAt(_updatedAt)}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveServerSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Saving to Server...",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded),
                          SizedBox(width: 8),
                          Text(
                            "Save Server Settings",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
