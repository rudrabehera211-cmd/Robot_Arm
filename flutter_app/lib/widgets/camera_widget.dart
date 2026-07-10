import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/camera_service.dart';

class CameraWidget extends StatefulWidget {
  final CameraService cameraService;
  final VoidCallback? onFullscreen;
  final VoidCallback? onRefresh;
  final VoidCallback? onRetry;

  const CameraWidget({
    super.key,
    required this.cameraService,
    this.onFullscreen,
    this.onRefresh,
    this.onRetry,
  });

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  StreamSubscription<Uint8List>? _frameSubscription;
  Uint8List? _currentFrame;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _frameSubscription?.cancel();
    _frameSubscription = widget.cameraService.frameStream.listen(
      (frame) {
        if (mounted) {
          setState(() {
            _currentFrame = frame;
            _isLoading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
    if (!widget.cameraService.isConnected && _currentFrame == null) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.cameraService.isConnected;
    final hasFrame = _currentFrame != null;
    final fps = widget.cameraService.fps;
    final cameraIp = widget.cameraService.cameraIp;
    final hasIp = cameraIp != null && cameraIp.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.videocam, size: 18, color: isOnline ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Camera Online' : 'Camera Offline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ),
                const Spacer(),
                if (isOnline && fps > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${fps.toStringAsFixed(0)} FPS',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                if (isOnline) ...[
                  const SizedBox(width: 8),
                  _iconButton(Icons.fullscreen, 'Fullscreen', widget.onFullscreen),
                ],
                _iconButton(Icons.refresh, 'Refresh', widget.onRefresh),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: SizedBox(
              height: 220,
              child: _buildCameraContent(hasIp, isOnline, hasFrame),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraContent(bool hasIp, bool isOnline, bool hasFrame) {
    if (_isLoading && hasIp) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 8),
            Text('Connecting...', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    if (!hasIp) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            const Text('No camera configured', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Go to Settings to add ESP32-CAM IP', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
      );
    }

    if (!isOnline && !hasFrame) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.orange.shade300),
            const SizedBox(height: 8),
            const Text('Camera Offline', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onFullscreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasFrame)
            Image.memory(
              _currentFrame!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            )
          else
            const Center(child: CircularProgressIndicator(strokeWidth: 3)),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Tap for fullscreen',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    return SizedBox(
      width: 32, height: 32,
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
