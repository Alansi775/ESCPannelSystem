/// Session Manager
/// Manages user session and persistence

import 'dart:convert';

// Simple in-memory session manager for web
class SessionManager {
  static Map<String, dynamic>? _userSession;

  /// Save user session
  static Future<void> saveUserSession(Map<String, dynamic> user) async {
    _userSession = user;
  }

  /// Get saved user session
  static Future<Map<String, dynamic>?> getUserSession() async {
    return _userSession;
  }

  /// Clear user session (logout)
  static Future<void> clearUserSession() async {
    _userSession = null;
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    return _userSession != null;
  }
}
