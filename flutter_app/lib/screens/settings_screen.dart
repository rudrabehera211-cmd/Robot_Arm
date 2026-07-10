import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/camera_service.dart';

class SettingsScreen extends StatefulWidget {
  final CameraService cameraService;

  const SettingsScreen({super.key, required this.cameraService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController();
  bool _isTesting = false;
  bool? _testResult;
  bool _isSaving = false;
  String _previewUrl = '';

  @override
  void initState() {
    super.initState();
    _loadIp();
    _ipController.addListener(_updatePreview);
  }

  void _updatePreview() {
    final ip = _ipController.text;
    widget.cameraService.setCameraIp(ip);
    setState(() {
      _previewUrl = widget.cameraService.streamUrl;
    });
  }

  Future<void> _loadIp() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('camera_ip') ?? '';
    _ipController.text = saved;
    widget.cameraService.setCameraIp(saved);
    _updatePreview();
  }

  Future<void> _saveIp() async {
    final raw = _ipController.text;
    final ip = raw.trim().replaceAll(RegExp(r'^https?://'), '').replaceAll('/', '');
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('camera_ip', ip);
    widget.cameraService.setCameraIp(ip);
    _ipController.text = ip;
    _ipController.selection = TextSelection.fromPosition(TextPosition(offset: ip.length));
    setState(() => _isSaving = false);
    _updatePreview();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera IP saved'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _testCamera() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    widget.cameraService.setCameraIp(ip);
    final result = await widget.cameraService.testConnection();
    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result == 'ok';
      });
      if (result != 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera unreachable: $result'), duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  @override
  void dispose() {
    _ipController.removeListener(_updatePreview);
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('ESP32-CAM Configuration'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: 'Camera IP Address',
                      hintText: 'e.g. 10.252.205.88',
                      prefixIcon: const Icon(Icons.camera_alt_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Enter just the IP number, not the full URL',
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _previewUrl.isEmpty ? 'Stream URL: —' : _previewUrl,
                            style: TextStyle(
                              fontSize: 12,
                              color: _previewUrl.contains('http://http')
                                  ? Colors.red
                                  : Colors.grey.shade600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isTesting ? null : _testCamera,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: Text(_isTesting ? 'Testing...' : 'Test Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isSaving ? null : _saveIp,
                          icon: const Icon(Icons.save, size: 18),
                          label: Text(_isSaving ? 'Saving...' : 'Save IP'),
                        ),
                      ),
                    ],
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testResult!
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _testResult! ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testResult! ? Icons.check_circle : Icons.error,
                            color: _testResult! ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _testResult! ? 'Camera Connected' : 'Camera Not Reachable',
                            style: TextStyle(
                              color: _testResult! ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('Server Configuration'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Server URL', 'https://robot-arm-35np.onrender.com'),
                  const Divider(height: 20),
                  _infoRow('Status', 'Online'),
                ],
              ),
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

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
