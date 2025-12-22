import 'package:flutter/material.dart';
import '../services/device_manager.dart';
import '../services/realtime_db_service.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late DeviceManagerService _deviceManager;

  // Simplified: single light toggle + latency
  bool _lightOn = false;
  int? _latencyMicros;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _deviceManager = DeviceManagerService();
    _deviceManager.addListener(_updateUI);
    _syncWithDeviceManager();
  }

  @override
  void dispose() {
    _deviceManager.removeListener(_updateUI);
    super.dispose();
  }

  void _updateUI() {
    setState(() {});
  }

  void _syncWithDeviceManager() {
    // Sync current light state from DeviceManager into _lightOn
    final isOn = _deviceManager.getLightState('Office Lights');
    setState(() {
      _lightOn = isOn;
    });
  }

  int _getLightBrightnessFromLevel(String level) {
    switch (level) {
      case 'Off':
        return 0;
      case 'Level 1':
        return 30;
      case 'Level 2':
        return 70;
      case 'Level 3':
        return 100;
      default:
        return 70;
    }
  }

  String _getLevelFromBrightness(int brightness) {
    if (brightness == 0) return 'Off';
    if (brightness <= 30) return 'Level 1';
    if (brightness <= 70) return 'Level 2';
    return 'Level 3';
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebDemo = screenWidth > 800; // Web demo mode
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWebDemo ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isWebDemo, isMobile),
              SizedBox(height: isWebDemo ? 32 : 24),
              _buildSingleLightSection(isWebDemo),
              SizedBox(height: isWebDemo ? 32 : 80), // Extra space for mobile
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWebDemo, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isWebDemo ? 24 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isWebDemo ? 12 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.settings,
              color: Colors.white,
              size: isWebDemo ? 28 : 24,
            ),
          ),
          SizedBox(width: isWebDemo ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Control',
                  style: TextStyle(
                    fontSize: isWebDemo ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isWebDemo ? 8 : 4),
                Text(
                  'Manage your office devices',
                  style: TextStyle(
                    fontSize: isWebDemo ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLightSection(bool isWebDemo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb,
                color: const Color(0xFF8B5CF6), size: isWebDemo ? 28 : 24),
            SizedBox(width: isWebDemo ? 12 : 8),
            Text('Light Control',
                style: TextStyle(
                    fontSize: isWebDemo ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937))),
          ],
        ),
        SizedBox(height: isWebDemo ? 16 : 12),
        Container(
          padding: EdgeInsets.all(isWebDemo ? 20 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _lightOn ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_lightOn ? 'On' : 'Off',
                      style: TextStyle(
                          fontSize: isWebDemo ? 18 : 16,
                          fontWeight: FontWeight.w600)),
                  Switch(
                    value: _lightOn,
                    onChanged: _sending ? null : (v) => _toggleLightAndSend(v),
                    activeColor: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Text(
              //     'Latency: ${_latencyMicros != null ? '${_latencyMicros} μs' : '—'}'),
            ],
          ),
        ),
      ],
    );
  }

  

  // Single light control: toggle and send to RTDB with latency measurement
  Future<void> _toggleLightAndSend(bool isOn) async {
    setState(() {
      _lightOn = isOn;
      _sending = true;
    });

    try {
      final baseUrl = RealtimeDbService.defaultBaseUrl;
      final int start = DateTime.now().microsecondsSinceEpoch;
      await RealtimeDbService.put(
        baseUrl: baseUrl,
        path: '/light',
        data: {
          'state': _lightOn ? 'on' : 'off',
          'ts': DateTime.now().millisecondsSinceEpoch, // epoch ms
          'datetime': DateTime.now().toIso8601String(), // human-readable
        },
      );
      final int end = DateTime.now().microsecondsSinceEpoch;
      final int latency = end - start;

      await RealtimeDbService.patch(
        baseUrl: baseUrl,
        path: '/',
        data: {
          'latency': latency, // kept for compatibility (microseconds)
          'latency_us': latency,
          'latency_ms': latency ~/ 1000,
        },
      );

      setState(() {
        _latencyMicros = latency;
      });

      // sync simple state back to DeviceManager
      _deviceManager.updateLightState('Office Lights', _lightOn);
      if (!_lightOn) _deviceManager.updateLightLevel('Office Lights', 'Off');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('RTDB error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  // Removed AC control methods
}

// Removed Firebase Test navigation helpers

// Light device model
class LightDevice {
  final String id;
  final String name;
  final String location;
  final bool isOn;
  final int brightness;
  final Color color;

  LightDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.isOn,
    required this.brightness,
    required this.color,
  });

  LightDevice copyWith({
    String? id,
    String? name,
    String? location,
    bool? isOn,
    int? brightness,
    Color? color,
  }) {
    return LightDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      color: color ?? this.color,
    );
  }
}

// Air conditioner device model
// Removed AirConditionerDevice model since AC UI is removed
