import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome, SystemUiMode;
import 'package:http/http.dart' as http;
import '../services/camera_service.dart';

class CameraScreen extends StatefulWidget {
  final CameraService cameraService;

  const CameraScreen({super.key, required this.cameraService});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  StreamSubscription<Uint8List>? _frameSubscription;
  Uint8List? _currentFrame;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _startListening();
    _enterFullscreen();
  }

  void _startListening() {
    _frameSubscription?.cancel();
    _frameSubscription = widget.cameraService.frameStream.listen(
      (frame) {
        if (mounted) setState(() => _currentFrame = frame);
      },
    );
  }

  void _enterFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _transformController.dispose();
    _exitFullscreen();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitFullscreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            GestureDetector(
              onDoubleTap: () {
                if (_transformController.value != Matrix4.identity()) {
                  _resetZoom();
                } else {
                  _transformController.value = Matrix4.diagonal3Values(2.5, 2.5, 1);
                }
              },
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,
                maxScale: 5.0,
                panEnabled: true,
                child: Center(
                  child: _currentFrame != null
                      ? Image.memory(
                          _currentFrame!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32, height: 32,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            ),
                            SizedBox(height: 16),
                            Text('Connecting...', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: _exitFullscreen,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _controlButton(Icons.refresh, 'Reset Zoom', _resetZoom),
                    const SizedBox(width: 16),
                    _controlButton(Icons.camera_alt, 'Snapshot', _takeSnapshot),
                    const SizedBox(width: 16),
                    _controlButton(Icons.screen_rotation, 'Rotate', _forceRotate),
                  ],
                ),
              ),
            ),
            if (_currentFrame != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${widget.cameraService.fps.toStringAsFixed(0)} FPS',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 24),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  void _forceRotate() {
    final current = MediaQuery.of(context).orientation;
    if (current == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  Future<void> _takeSnapshot() async {
    final url = widget.cameraService.snapshotUrl;
    if (url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Snapshot captured'), duration: Duration(seconds: 2)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture snapshot')),
        );
      }
    }
  }
}
