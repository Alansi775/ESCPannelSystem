/// Authentication Service for Flutter
/// Handles signup, login, verification

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/esc_models.dart';
import 'session_manager.dart';

class AuthenticationService {
  static const String baseUrl = 'http://192.168.3.241:7070';
  static const Duration timeout = Duration(seconds: 30);

  /// Sign up new user
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? name,
    String language = 'tr',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'name': name ?? '',
              'language': language,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['error'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save user session
        final userData = data['user'] ?? {
          'id': data['userId'],
          'email': data['email'],
          'name': data['name'] ?? '',
        };
        await SessionManager.saveUserSession(userData);

        return {
          'success': true,
          'verified': true,
          'data': data,
        };
      } else if (response.statusCode == 403 && data['code'] == 'NOT_VERIFIED') {
        // Email not verified
        return {
          'success': false,
          'verified': false,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'verified': null,
          'error': data['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'verified': null,
        'error': 'Network error: $e',
      };
    }
  }

  /// Resend verification email
  static Future<Map<String, dynamic>> resendVerification({
    required String email,
    required int userId,
    String language = 'tr',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/resend-verification'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'userId': userId,
              'language': language,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['error'] ?? 'Resend failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Change password
  static Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/change-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'oldPassword': oldPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['error'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Request password reset
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'language': 'en',
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['error'] ?? 'Failed to send reset link',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}

