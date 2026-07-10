import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/camera_service.dart';
import '../services/api_service.dart';
import '../widgets/camera_widget.dart';
import '../widgets/joystick_widget.dart';
import 'camera_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final CameraService cameraService;

  const HomeScreen({super.key, required this.cameraService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, double> _positions = {
    'base': 90, 'shoulder': 90, 'elbow': 0, 'gripper': 90,
  };
  bool _connected = false;
  Timer? _statusTimer;
  Timer? _debounceTimer;

  static const Map<String, int> _servoChannels = {
    'base': 0, 'shoulder': 1, 'elbow': 2, 'gripper': 3,
  };
  static const Map<String, double> _servoLimits = {
    'base': 180, 'shoulder': 180, 'elbow': 90, 'gripper': 130,
  };
  static const Map<String, double> _servoMins = {
    'base': 0, 'shoulder': 90, 'elbow': 0, 'gripper': 90,
  };

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startPolling();
  }

  Future<void> _initCamera() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('camera_ip') ?? '';
    if (ip.isNotEmpty) {
      widget.cameraService.setCameraIp(ip);
      widget.cameraService.startStream();
    }
  }

  void _startPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchStatus());
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final status = await ApiService.getStatus();
    if (mounted) {
      setState(() {
        _connected = status['connected'] == true;
        final pos = status['positions'] as Map<String, dynamic>?;
        if (pos != null) {
          for (final key in _positions.keys) {
            if (pos.containsKey(key)) {
              _positions[key] = (pos[key] as num).toDouble();
            }
          }
        }
      });
    }
  }

  void _onSliderChanged(String servo, double value) {
    setState(() => _positions[servo] = value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      final channel = _servoChannels[servo]!;
      final angle = value.round();
      ApiService.setServo(channel, angle);
    });
  }

  void _onJoystickMoved(double dx, double dy) {
    final base = (_positions['base']! + dx * 0.5).clamp(0, 180).toDouble();
    final shoulder = (_positions['shoulder']! - dy * 0.5).clamp(90, 180).toDouble();
    setState(() {
      _positions['base'] = base;
      _positions['shoulder'] = shoulder;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 30), () {
      ApiService.setServo(0, base.round());
      ApiService.setServo(1, shoulder.round());
    });
  }

  void _onPreset(String name) {
    ApiService.setPreset(name);
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraScreen(cameraService: widget.cameraService),
      ),
    );
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(cameraService: widget.cameraService),
      ),
    );
    widget.cameraService.startStream();
    if (mounted) setState(() {});
  }

  void _retryCamera() {
    widget.cameraService.stopStream();
    widget.cameraService.startStream();
  }

  void _refreshCamera() {
    widget.cameraService.stopStream();
    widget.cameraService.startStream();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RoboArm'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          widget.cameraService.stopStream();
          widget.cameraService.startStream();
          await _fetchStatus();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CameraWidget(
              cameraService: widget.cameraService,
              onFullscreen: _openFullscreen,
              onRefresh: _refreshCamera,
              onRetry: _retryCamera,
            ),
            const SizedBox(height: 16),
            _connectionBadge(),
            const SizedBox(height: 12),
            _sectionHeader('Servo Controls'),
            const SizedBox(height: 8),
            for (final servo in ['base', 'shoulder', 'elbow', 'gripper'])
              _servoSlider(servo),
            const SizedBox(height: 16),
            _sectionHeader('Joystick'),
            const SizedBox(height: 8),
            JoystickWidget(onMove: _onJoystickMoved),
            const SizedBox(height: 16),
            _sectionHeader('Presets'),
            const SizedBox(height: 8),
            _presetButtons(),
            const SizedBox(height: 16),
            _sectionHeader('Voice Control'),
            const SizedBox(height: 8),
            _voiceControlCard(),
          ],
        ),
      ),
    );
  }

  Widget _connectionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _connected ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _connected ? Colors.green : Colors.red, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: _connected ? Colors.green : Colors.red),
          const SizedBox(width: 6),
          Text(
            _connected ? 'Arm Connected' : 'Arm Disconnected',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _connected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _servoSlider(String servo) {
    final value = _positions[servo]!;
    final min = _servoMins[servo]!;
    final max = _servoLimits[servo]!;
    final labels = {
      'base': 'Base', 'shoulder': 'Shoulder', 'elbow': 'Elbow', 'gripper': 'Gripper',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(labels[servo]!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${value.round()}°', style: TextStyle(color: Colors.cyan.shade300, fontSize: 13)),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              activeColor: Colors.cyan,
              onChanged: (v) => _onSliderChanged(servo, v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetButtons() {
    final presets = ['home', 'grab', 'reach', 'rest', 'wave'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((name) {
        return ElevatedButton(
          onPressed: () => _onPreset(name),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.cyan.withValues(alpha: 0.15),
            foregroundColor: Colors.cyan.shade200,
          ),
          child: Text(name[0].toUpperCase() + name.substring(1)),
        );
      }).toList(),
    );
  }

  Widget _voiceControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Say: "base 90", "home", "grab", etc.', style: TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _startListening(),
              icon: const Icon(Icons.mic, size: 18),
              label: const Text('Push to Talk'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                foregroundColor: Colors.cyan.shade200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startListening() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice control: say a command'), duration: Duration(seconds: 2)),
    );
  }
}
