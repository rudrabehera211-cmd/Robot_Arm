import 'package:flutter/material.dart';
import 'services/camera_service.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoboArmApp());
}

class RoboArmApp extends StatefulWidget {
  const RoboArmApp({super.key});

  @override
  State<RoboArmApp> createState() => _RoboArmAppState();
}

class _RoboArmAppState extends State<RoboArmApp> {
  final CameraService _cameraService = CameraService();

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoboArm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0D47A1),
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1F35),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: SplashScreen(cameraService: _cameraService),
    );
  }
}
