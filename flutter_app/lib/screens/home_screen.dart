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
  bool _fetching = false;
  bool _guardMode = false;
  String _joystickMode = 'base_shoulder';
  List<dynamic> _waypoints = [];
  List<dynamic> _history = [];
  List<dynamic> _alerts = [];
  Timer? _statusTimer;
  Timer? _debounceTimer;
  Timer? _dataTimer;
  final TextEditingController _wpController = TextEditingController();

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
    _dataTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
    _fetchStatus();
    _fetchData();
  }

  Future<void> _fetchStatus() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final status = await ApiService.getStatus().timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _connected = status['connected'] == true;
          _guardMode = status['guard_mode'] == true;
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
    } catch (_) {
      if (mounted) setState(() => _connected = false);
    } finally {
      _fetching = false;
    }
  }

  Future<void> _fetchData() async {
    final results = await Future.wait([
      ApiService.getWaypoints(),
      ApiService.getHistory(),
      ApiService.getAlerts(),
    ]);
    if (mounted) {
      setState(() {
        _waypoints = results[0];
        _history = results[1];
        _alerts = results[2];
      });
    }
  }

  void _toggleGuard(bool val) {
    setState(() => _guardMode = val);
    ApiService.toggleGuard(val).catchError((_) {});
  }

  void _onSliderChanged(String servo, double value) {
    setState(() => _positions[servo] = value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      final channel = _servoChannels[servo]!;
      final angle = value.round();
      ApiService.setServo(channel, angle).catchError((_) {});
    });
  }

  static const Map<String, List<String>> _joystickModes = {
    'base_shoulder': ['base', 'shoulder'],
    'elbow_gripper': ['elbow', 'gripper'],
    'base_elbow': ['base', 'elbow'],
    'shoulder_gripper': ['shoulder', 'gripper'],
  };
  static const Map<String, String> _joystickModeLabels = {
    'base_shoulder': 'Base + Shoulder',
    'elbow_gripper': 'Elbow + Gripper',
    'base_elbow': 'Base + Elbow',
    'shoulder_gripper': 'Shoulder + Gripper',
  };

  void _onJoystickMoved(double dx, double dy) {
    final parts = _joystickModes[_joystickMode]!;
    final xServo = parts[0];
    final yServo = parts[1];
    final limits = _servoLimits;
    final mins = _servoMins;

    final newX = (_positions[xServo]! + dx * 0.5).clamp(mins[xServo]!, limits[xServo]!).toDouble();
    final newY = (_positions[yServo]! - dy * 0.5).clamp(mins[yServo]!, limits[yServo]!).toDouble();

    setState(() {
      _positions[xServo] = newX;
      _positions[yServo] = newY;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 30), () {
      ApiService.setServo(_servoChannels[xServo]!, newX.round()).catchError((_) {});
      ApiService.setServo(_servoChannels[yServo]!, newY.round()).catchError((_) {});
    });
  }

  void _onPreset(String name) {
    ApiService.setPreset(name).catchError((_) {});
  }

  void _addWaypoint() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Waypoint'),
        content: TextField(
          controller: _wpController,
          decoration: const InputDecoration(hintText: 'Waypoint name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = _wpController.text.trim();
              if (name.isNotEmpty) {
                ApiService.addWaypoint(name).then((_) => _fetchData());
              }
              _wpController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _playWaypoint(int index) {
    ApiService.playWaypoint(index).catchError((_) {});
  }

  Future<void> _deleteWaypoint(int index) async {
    await ApiService.deleteWaypoint(index);
    _fetchData();
  }

  void _clearAlerts() {
    ApiService.clearAlerts().then((_) => _fetchData());
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
    _dataTimer?.cancel();
    _wpController.dispose();
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
          await _fetchData();
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
            const SizedBox(height: 16),
            _guardCard(),
            const SizedBox(height: 16),
            _sectionHeader('Servo Controls'),
            const SizedBox(height: 8),
            for (final servo in ['base', 'shoulder', 'elbow', 'gripper'])
              _servoSlider(servo),
            const SizedBox(height: 16),
            _sectionHeader('Joystick'),
            const SizedBox(height: 8),
            _joystickModeSelector(),
            const SizedBox(height: 8),
            JoystickWidget(onMove: _onJoystickMoved),
            const SizedBox(height: 16),
            _sectionHeader('Presets'),
            const SizedBox(height: 8),
            _presetButtons(),
            const SizedBox(height: 16),
            _sectionHeader('Waypoints'),
            const SizedBox(height: 8),
            _waypointsSection(),
            const SizedBox(height: 16),
            _sectionHeader('Position History'),
            const SizedBox(height: 8),
            _historySection(),
            const SizedBox(height: 16),
            _sectionHeader('Alerts / Theft Protection'),
            const SizedBox(height: 8),
            _alertsSection(),
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

  Widget _guardCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(_guardMode ? Icons.shield : Icons.shield_outlined,
                 color: _guardMode ? Colors.orange : Colors.white38, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Guard Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                       color: _guardMode ? Colors.orange : Colors.white70)),
                  Text(_guardMode ? 'Theft protection active' : 'Tap to enable',
                       style: TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
            Switch(
              value: _guardMode,
              activeThumbColor: Colors.orange,
              onChanged: _toggleGuard,
            ),
          ],
        ),
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

  Widget _joystickModeSelector() {
    return Row(
      children: [
        Icon(Icons.tune, size: 16, color: Colors.cyan.shade300),
        const SizedBox(width: 8),
        Text('X/Y:', style: TextStyle(fontSize: 12, color: Colors.cyan.shade300)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String>(
            value: _joystickMode,
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1F35),
            style: const TextStyle(fontSize: 13, color: Colors.white),
            underline: const SizedBox(),
            items: _joystickModeLabels.entries.map((e) {
              return DropdownMenuItem(value: e.key, child: Text(e.value));
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _joystickMode = v);
            },
          ),
        ),
      ],
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

  Widget _waypointsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${_waypoints.length} saved',
                       style: TextStyle(fontSize: 12, color: Colors.white54)),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Add current position as waypoint',
                  onPressed: _addWaypoint,
                ),
              ],
            ),
            if (_waypoints.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No waypoints saved. Tap + to save current arm position.',
                     style: TextStyle(fontSize: 12, color: Colors.white38),
                     textAlign: TextAlign.center),
              )
            else
              ...List.generate(_waypoints.length, (i) {
                final wp = _waypoints[i];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: Icon(Icons.flag, size: 18, color: Colors.cyan.shade300),
                  title: Text(wp['name'] ?? 'Waypoint ${i+1}',
                       style: const TextStyle(fontSize: 13)),
                  subtitle: Text(wp['time']?.toString().substring(0, 19) ?? '',
                       style: TextStyle(fontSize: 10, color: Colors.white38)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow, size: 18),
                        tooltip: 'Play',
                        onPressed: () => _playWaypoint(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Delete',
                        onPressed: () => _deleteWaypoint(i),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _historySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recent movements', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),
            if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No history yet.',
                     style: TextStyle(fontSize: 12, color: Colors.white38),
                     textAlign: TextAlign.center),
              )
            else
              ...List.generate(_history.length > 5 ? 5 : _history.length, (i) {
                final entry = _history[_history.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('${entry['servo']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${entry['angle']}°', style: TextStyle(fontSize: 12, color: Colors.cyan.shade300)),
                      const SizedBox(width: 8),
                      Text(entry['time']?.toString().substring(11, 19) ?? '',
                           style: TextStyle(fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _alertsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${_alerts.length} alerts',
                       style: TextStyle(fontSize: 12, color: Colors.white54)),
                ),
                if (_alerts.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearAlerts,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
                  ),
              ],
            ),
            if (_alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No alerts. Guard mode will detect motion and trigger alerts.',
                     style: TextStyle(fontSize: 12, color: Colors.white38),
                     textAlign: TextAlign.center),
              )
            else
              ...List.generate(_alerts.length > 5 ? 5 : _alerts.length, (i) {
                final alert = _alerts[_alerts.length - 1 - i];
                final type = alert['type'] ?? '';
                final icon = type == 'motion' ? Icons.sensors : Icons.warning;
                final color = type == 'motion' ? Colors.orange : Colors.red;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: Icon(icon, size: 18, color: color),
                  title: Text('$type${alert['details']?.isNotEmpty == true ? ': ${alert['details']}' : ''}',
                       style: const TextStyle(fontSize: 12)),
                  trailing: Text(alert['time']?.toString().substring(11, 19) ?? '',
                       style: TextStyle(fontSize: 10, color: Colors.white38)),
                );
              }),
          ],
        ),
      ),
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