import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://robot-arm-35np.onrender.com';

  static Future<void> setServo(int channel, int angle) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/set'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'channel': channel, 'angle': angle}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<void> setPreset(String name) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/preset/$name'),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<void> toggleGuard(bool enable) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/guard/${enable ? "enable" : "disable"}'),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/status'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'connected': false, 'positions': {}, 'guard_mode': false};
  }

  static Future<Map<String, dynamic>> getPositions() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/positions'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  static Future<List<dynamic>> getWaypoints() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/waypoints'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> addWaypoint(String name) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/waypoints/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<void> playWaypoint(int index) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/waypoints/$index/play'),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<void> deleteWaypoint(int index) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/waypoints/$index'),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<List<dynamic>> getAlerts() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/alerts'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> clearAlerts() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/alerts/clear'),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<List<dynamic>> getHistory() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/history'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }
}
