/// Backend API Service
/// Communicates with Node.js server at localhost:7070

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/esc_models.dart';

class BackendAPI {
  static const String baseUrl = 'http://localhost:7070';
  static const Duration timeout = Duration(seconds: 30);

  /// Get server status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting status: $e');
    }
  }

  /// List available serial ports
  static Future<List<SerialPort>> getAvailablePorts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ports'),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ports = (data['ports'] as List)
            .map((p) => SerialPort.fromJson(p as Map<String, dynamic>))
            .toList();
        return ports;
      } else {
        throw Exception('Failed to get ports: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting ports: $e');
    }
  }

  /// Connect to ESC
  static Future<bool> connectESC(String portPath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'portPath': portPath}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to connect');
      }
    } catch (e) {
      throw Exception('Error connecting: $e');
    }
  }

  /// Disconnect from ESC
  static Future<bool> disconnectESC() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/disconnect'),
      ).timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error disconnecting: $e');
    }
  }

  /// Get current config from ESC
  static Future<ESCConfig> getConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/config'),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ESCConfig.fromJson(data['config'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting config: $e');
    }
  }

  /// Apply config to ESC
  static Future<bool> applyConfig(ESCConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/apply'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config.toJson()),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to apply config');
      }
    } catch (e) {
      throw Exception('Error applying config: $e');
    }
  }

  /// Generate auto config
  static Future<ESCConfig> generateAutoConfig(int cells, String mode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/autoConfig'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cells': cells, 'mode': mode}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ESCConfig.fromJson(data['config'] as Map<String, dynamic>);
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to generate config');
      }
    } catch (e) {
      throw Exception('Error generating config: $e');
    }
  }

  /// Save profile
  static Future<int> saveProfile(String profileName, ESCConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/saveProfile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'profileName': profileName,
          'config': config.toJson(),
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['profile']['id'] as int;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to save profile');
      }
    } catch (e) {
      throw Exception('Error saving profile: $e');
    }
  }

  /// Get all profiles
  static Future<List<ESCProfile>> getProfiles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profiles'),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profiles = (data['profiles'] as List)
            .map((p) => ESCProfile.fromJson(p as Map<String, dynamic>))
            .toList();
        return profiles;
      } else {
        throw Exception('Failed to get profiles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting profiles: $e');
    }
  }

  /// Get profile by ID
  static Future<ESCProfile> getProfileById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profiles/$id'),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ESCProfile.fromJson(data['profile'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting profile: $e');
    }
  }
}
