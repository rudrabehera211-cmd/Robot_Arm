import 'dart:async';
import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final CameraService cameraService;

  const SplashScreen({super.key, required this.cameraService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScale;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _taglineOpacity;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _iconScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.35, curve: Curves.elasticOut)),
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.55, curve: Curves.easeIn)),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.55, curve: Curves.easeOutCubic)),
    );

    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.55, 0.75, curve: Curves.easeIn)),
    );

    _controller.forward();

    _navTimer = Timer(const Duration(seconds: 3), _navigateToHome);
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => HomeScreen(cameraService: widget.cameraService),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: _iconScale.value,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.cyan.withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 8),
                      ],
                    ),
                    child: Icon(Icons.precision_manufacturing, size: 56, color: Colors.cyan.shade300),
                  ),
                ),
                const SizedBox(height: 32),
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Text(
                      'RoboArm',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.cyan.shade200,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    'Precision Control',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: Colors.cyan.withValues(alpha: 0.5),
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
