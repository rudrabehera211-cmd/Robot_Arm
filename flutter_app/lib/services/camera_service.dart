import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CameraService {
  String? _cameraIp;
  bool _isConnected = false;
  bool _isDisposed = false;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  int _frameCount = 0;
  int _lastFpsTime = 0;
  double _fps = 0;
  final int _reconnectInterval = 5;
  final int _pollIntervalMs = 150;
  bool _streamStarted = false;

  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  String? get cameraIp => _cameraIp;
  bool get isConnected => _isConnected;
  double get fps => _fps;
  bool get isDisposed => _isDisposed;

  String get _baseUrl {
    if (_cameraIp == null || _cameraIp!.isEmpty) return '';
    final ip = _sanitizeIp(_cameraIp!);
    return 'http://$ip';
  }

  String get streamUrl => '$_baseUrl:81/stream';
  String get snapshotUrl => '$_baseUrl/capture';

  Stream<Uint8List> get frameStream => _frameController.stream;

  String _sanitizeIp(String ip) {
    return ip
        .trim()
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r':\d+$'), '')
        .replaceAll('/', '');
  }

  void setCameraIp(String ip) {
    _cameraIp = _sanitizeIp(ip);
  }

  Future<String> testConnection() async {
    final ip = _sanitizeIp(_cameraIp ?? '');
    if (ip.isEmpty) return 'No IP configured';
    final url = 'http://$ip';
    try {
      final resp = await http.get(Uri.parse('$url/'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return 'ok';
      return 'Port 80 returned status ${resp.statusCode}';
    } catch (e) {
      return 'Port 80: ${e.toString()}';
    }
  }

  void startStream() {
    if (_isDisposed || _streamStarted) return;
    _streamStarted = true;
    _reconnectTimer?.cancel();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _lastFpsTime = DateTime.now().millisecondsSinceEpoch;
    _frameCount = 0;
    _pollFrame();
  }

  void _pollFrame() async {
    if (_isDisposed) return;
    final url = snapshotUrl;
    if (url.isEmpty) {
      _isConnected = false;
      _scheduleReconnect();
      return;
    }
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _isConnected = true;
        _frameCount++;
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = now - _lastFpsTime;
        if (elapsed >= 1000) {
          _fps = _frameCount / (elapsed / 1000);
          _frameCount = 0;
          _lastFpsTime = now;
        }
        _frameController.add(Uint8List.fromList(response.bodyBytes));
      } else {
        _isConnected = false;
      }
    } catch (_) {
      _isConnected = false;
    }
    if (!_isDisposed) {
      _pollTimer = Timer(Duration(milliseconds: _pollIntervalMs), _pollFrame);
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_isDisposed) return;
    _reconnectTimer = Timer.periodic(
      Duration(seconds: _reconnectInterval),
      (_) async {
        if (!_isConnected && !_isDisposed) {
          _startPolling();
        }
      },
    );
  }

  void stopStream() {
    _streamStarted = false;
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _isConnected = false;
  }

  void dispose() {
    _isDisposed = true;
    stopStream();
    _frameController.close();
  }
}
