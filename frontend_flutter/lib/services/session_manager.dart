/// Session Manager
/// Manages user session and persistence using SharedPreferences

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _sessionKey = 'user_session';
  static Map<String, dynamic>? _userSession;

  /// Save user session (in memory and persistent storage)
  static Future<void> saveUserSession(Map<String, dynamic> user) async {
    _userSession = user;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(user));
      print('✓ Session saved for user: ${user['email']} (ID: ${user['id']})');
    } catch (e) {
      print('⚠️ Warning: Failed to persist session: $e');
    }
  }

  /// Get saved user session (from memory or persistent storage)
  static Future<Map<String, dynamic>?> getUserSession() async {
    // Return from memory if available
    if (_userSession != null) {
      print('📋 Getting session from memory - ID: ${_userSession?['id']}');
      return _userSession;
    }
    
    // Try to restore from persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionStr = prefs.getString(_sessionKey);
      
      if (sessionStr != null) {
        _userSession = jsonDecode(sessionStr) as Map<String, dynamic>;
        print('📋 Getting session from storage - ID: ${_userSession?['id']}');
        return _userSession;
      }
    } catch (e) {
      print('⚠️ Warning: Failed to restore session: $e');
    }
    
    return null;
  }
  
  /// Get user ID from session
  static Future<int?> getUserId() async {
    final session = await getUserSession();
    return session?['id'] as int?;
  }
  
  /// Get user email from session
  static Future<String?> getUserEmail() async {
    final session = await getUserSession();
    return session?['email'] as String?;
  }

  /// Clear user session (logout)
  static Future<void> clearUserSession() async {
    _userSession = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      print('✓ Session cleared');
    } catch (e) {
      print('⚠️ Warning: Failed to clear session: $e');
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final session = await getUserSession();
    return session != null;
  }
}

