import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/server_setting_model.dart';

class ServerSettingScreen extends StatefulWidget {
  const ServerSettingScreen({super.key});

  @override
  State<ServerSettingScreen> createState() => _ServerSettingScreenState();
}

class _ServerSettingScreenState extends State<ServerSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _maxTradeAmountIntradayController =
      TextEditingController();
  final TextEditingController _maxTradePerDayController =
      TextEditingController();
  final TextEditingController _maxTradeAmountSwingController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isBackendConnected = false;
  bool _isConnecting = false;
  String? _errorMessage;

  TimeOfDay _squareOffTime = const TimeOfDay(hour: 15, minute: 15);
  bool _enableTelegramAlert = true;
  bool _enableAutoTradingIntraday = false;
  bool _enableAutoTradingSwing = false;
  String _swingProduct = "CNC";
  bool _enableScreenerSync = true;
  String? _updatedAt;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    _fetchLiveSettings();
  }

  Future<void> _checkConnectionStatus() async {
    try {
      final isSessionValid = await BackendOrderService.isSessionActive();
      if (mounted) {
        setState(() {
          _isBackendConnected = isSessionValid;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBackendConnected = false;
        });
      }
    }
  }

  Future<void> _connectBackend() async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
    });

    try {
      final isHealthy = await BackendOrderService.healthCheck();
      if (!isHealthy) {
        Fluttertoast.showToast(
            msg: "Backend health check failed. Check server status.");
        return;
      }

      final accessToken = await SharedPreferenceHelper.instance.getToken();
      final refreshToken =
          await SharedPreferenceHelper.instance.getRefreshToken();

      if (accessToken == null || accessToken.isEmpty) {
        Fluttertoast.showToast(
            msg: "No Kite Access Token found. Please log in first.");
        return;
      }

      final isSaved = await BackendOrderService.saveZerodhaSession(
        accessToken,
        refreshToken ?? "",
      );

      if (isSaved) {
        if (mounted) {
          setState(() {
            _isBackendConnected = true;
          });
        }
        Fluttertoast.showToast(
          msg: "Connected to Server successfully!",
          backgroundColor: Colors.green,
        );
        await BackendOrderService.getSession();
        await _fetchLiveSettings();
      } else {
        Fluttertoast.showToast(
          msg: "Failed to save session on backend.",
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Connection error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _maxTradeAmountIntradayController.dispose();
    _maxTradePerDayController.dispose();
    _maxTradeAmountSwingController.dispose();
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
        _maxTradeAmountIntradayController.text =
            settings.maxTradeAmountIntraday.toStringAsFixed(2);
        _maxTradePerDayController.text =
            settings.maxTradePerDay.toString();
        _maxTradeAmountSwingController.text =
            settings.maxTradeAmountSwing.toStringAsFixed(2);
        _squareOffTime = _parseTimeString(settings.squareOffTime);
        _enableTelegramAlert = settings.enableTelegramAlert;
        _enableAutoTradingIntraday = settings.enableAutoTradingIntraday;
        _enableAutoTradingSwing = settings.enableAutoTradingSwing;
        _swingProduct = settings.swingProduct;
        _enableScreenerSync = settings.enableScreenerSync;
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

    final maxAmountIntraday =
        double.tryParse(_maxTradeAmountIntradayController.text.trim());
    if (maxAmountIntraday == null || maxAmountIntraday <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid intraday trade amount");
      return;
    }

    final maxTradesPerDay =
        int.tryParse(_maxTradePerDayController.text.trim());
    if (maxTradesPerDay == null || maxTradesPerDay <= 0) {
      Fluttertoast.showToast(
          msg: "Please enter valid trades per day (min 1)");
      return;
    }

    final maxAmountSwing =
        double.tryParse(_maxTradeAmountSwingController.text.trim());
    if (maxAmountSwing == null || maxAmountSwing <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid swing trade amount");
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final newSettings = ServerSettings(
      maxTradeAmountIntraday: maxAmountIntraday,
      enableAutoTradingIntraday: _enableAutoTradingIntraday,
      maxTradePerDay: maxTradesPerDay,
      maxTradeAmountSwing: maxAmountSwing,
      enableAutoTradingSwing: _enableAutoTradingSwing,
      swingProduct: _swingProduct,
      squareOffTime: _formatTimeOfDay(_squareOffTime),
      enableTelegramAlert: _enableTelegramAlert,
      enableScreenerSync: _enableScreenerSync,
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
            : "Server settings saved successfully!",
        backgroundColor: Colors.green,
      );

      if (response.data != null) {
        setState(() {
          _maxTradeAmountIntradayController.text =
              response.data!.maxTradeAmountIntraday.toStringAsFixed(2);
          _maxTradePerDayController.text =
              response.data!.maxTradePerDay.toString();
          _maxTradeAmountSwingController.text =
              response.data!.maxTradeAmountSwing.toStringAsFixed(2);
          _squareOffTime = _parseTimeString(response.data!.squareOffTime);
          _enableTelegramAlert = response.data!.enableTelegramAlert;
          _enableAutoTradingIntraday = response.data!.enableAutoTradingIntraday;
          _enableAutoTradingSwing = response.data!.enableAutoTradingSwing;
          _swingProduct = response.data!.swingProduct;
          _enableScreenerSync = response.data!.enableScreenerSync;
          _updatedAt =
              response.data!.updatedAt ?? DateTime.now().toIso8601String();
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
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return rawDateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Server Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Live Settings',
            onPressed: _isLoading || _isSaving
                ? null
                : () async {
                    await _checkConnectionStatus();
                    await _fetchLiveSettings();
                  },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar:
          _isLoading || _errorMessage != null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              "Fetching live server settings...",
              style: TextStyle(color: Colors.grey, fontSize: 13),
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
              const Icon(Icons.cloud_off, size: 56, color: Colors.redAccent),
              const SizedBox(height: 14),
              Text(
                "Unable to Load Settings",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _fetchLiveSettings,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Retry Connection"),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _checkConnectionStatus();
        await _fetchLiveSettings();
      },
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Server Connection Banner with Connect / Reconnect button
              _buildConnectionBanner(),

              // Intraday Card
              _buildIntradayCard(),
              const SizedBox(height: 10),

              // Swing Card
              _buildSwingCard(),
              const SizedBox(height: 10),

              // Global Automation & Alerts (Screener Sync + Telegram Alert)
              _buildAlertsBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isBackendConnected
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isBackendConnected
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.amberAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isBackendConnected
                  ? Colors.greenAccent.withValues(alpha: 0.18)
                  : Colors.amberAccent.withValues(alpha: 0.18),
            ),
            child: Icon(
              _isBackendConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isBackendConnected
                  ? Colors.greenAccent
                  : Colors.amberAccent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isBackendConnected
                      ? "Server Connected"
                      : "Server Disconnected",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _isBackendConnected
                        ? Colors.greenAccent
                        : Colors.amberAccent,
                  ),
                ),
                Text(
                  _isBackendConnected
                      ? "Zerodha session active & token synced"
                      : "Sync Zerodha token for live execution",
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connectBackend,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isBackendConnected
                          ? Icons.sync_rounded
                          : Icons.link_rounded,
                      size: 14,
                    ),
              label: Text(
                _isConnecting
                    ? "Connecting..."
                    : _isBackendConnected
                        ? "Reconnect"
                        : "Connect Server",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBackendConnected
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.blueAccent,
                foregroundColor:
                    _isBackendConnected ? Colors.greenAccent : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: _isBackendConnected
                        ? Colors.greenAccent.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntradayCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2232),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _enableAutoTradingIntraday
              ? Colors.blueAccent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          if (_enableAutoTradingIntraday)
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child:
                    const Icon(Icons.bolt, size: 15, color: Colors.blueAccent),
              ),
              const SizedBox(width: 8),
              const Text(
                "INTRADAY",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "MIS",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              const Spacer(),
              _buildAutoTradePill(
                isActive: _enableAutoTradingIntraday,
                onChanged: (val) {
                  setState(() => _enableAutoTradingIntraday = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Inputs Row: Max Capital & Trades/Day
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Max Capital (₹)
              Expanded(
                flex: 3,
                child: _buildInputField(
                  controller: _maxTradeAmountIntradayController,
                  label: 'Max Capital (₹)',
                  hint: '20000',
                  icon: Icons.currency_rupee,
                  isDecimal: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return '> 0';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Trades / Day
              Expanded(
                flex: 2,
                child: _buildInputField(
                  controller: _maxTradePerDayController,
                  label: 'Trades/Day',
                  hint: '1',
                  icon: Icons.tag,
                  isDecimal: false,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return '>= 1';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Square-Off Time Row
          _buildSquareOffRow(),
        ],
      ),
    );
  }

  Widget _buildSquareOffRow() {
    final currentFormatted = _formatTimeOfDay(_squareOffTime);
    return InkWell(
      onTap: () => _selectSquareOffTime(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded,
                size: 16, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            const Text(
              "Square Off Time",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentFormatted,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 11, color: Colors.orangeAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF221B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _enableAutoTradingSwing
              ? Colors.purpleAccent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          if (_enableAutoTradingSwing)
            BoxShadow(
              color: Colors.purpleAccent.withValues(alpha: 0.12),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.auto_graph,
                    size: 15, color: Colors.purpleAccent),
              ),
              const SizedBox(width: 8),
              const Text(
                "SWING",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _swingProduct,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.purpleAccent,
                  ),
                ),
              ),
              const Spacer(),
              _buildAutoTradePill(
                isActive: _enableAutoTradingSwing,
                onChanged: (val) {
                  setState(() => _enableAutoTradingSwing = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Inputs Row: Max Capital & Product Selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Max Capital (₹)
              Expanded(
                flex: 3,
                child: _buildInputField(
                  controller: _maxTradeAmountSwingController,
                  label: 'Max Capital (₹)',
                  hint: '8000',
                  icon: Icons.currency_rupee,
                  isDecimal: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return '> 0';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Product Type: CNC / MTF Segmented Pills
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildProductTogglePill(
                            type: "CNC",
                            subtitle: "Delivery",
                          ),
                          const SizedBox(width: 3),
                          _buildProductTogglePill(
                            type: "MTF",
                            subtitle: "Margin",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Subtle hint
          Row(
            children: [
              const Icon(Icons.info_outline, size: 11, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _swingProduct == "MTF"
                    ? "MTF: Margin trading facility with leverage"
                    : "CNC: Standard delivery holdings",
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductTogglePill({
    required String type,
    required String subtitle,
  }) {
    final isSelected = _swingProduct == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _swingProduct = type;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.purpleAccent.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? Colors.purpleAccent.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                type,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.purpleAccent : Colors.grey,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 8.5,
                  color: isSelected ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoTradePill({
    required bool isActive,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? Colors.greenAccent.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.greenAccent : Colors.grey,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? "Auto: ON" : "Auto: OFF",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.greenAccent : Colors.grey,
            ),
          ),
          Transform.scale(
            scale: 0.65,
            child: Switch(
              value: isActive,
              activeThumbColor: Colors.greenAccent,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          // Screener Sync
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.sync,
                  size: 15,
                  color: _enableScreenerSync ? Colors.amberAccent : Colors.grey,
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    "Screener Sync",
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: _enableScreenerSync,
                    activeThumbColor: Colors.amberAccent,
                    onChanged: (val) {
                      setState(() => _enableScreenerSync = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: Colors.white.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),
          // Telegram Alert
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.send_rounded,
                  size: 14,
                  color: _enableTelegramAlert
                      ? Colors.lightBlueAccent
                      : Colors.grey,
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    "Telegram Alert",
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: _enableTelegramAlert,
                    activeThumbColor: Colors.lightBlueAccent,
                    onChanged: (val) {
                      setState(() => _enableTelegramAlert = val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDecimal,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      inputFormatters: [
        if (isDecimal)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11.5),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, size: 14),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_updatedAt != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 11, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    "Synced: ${_formatUpdatedAt(_updatedAt)}",
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 5),
            ],
            SizedBox(
              height: 44,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveServerSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Saving Settings...",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 16),
                          SizedBox(width: 6),
                          Text(
                            "Save Server Settings",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
