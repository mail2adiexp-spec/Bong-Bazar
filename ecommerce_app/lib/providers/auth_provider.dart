import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUser {
  final String email;
  final String name;

  AppUser({required this.email, required this.name});

  Map<String, dynamic> toMap() => {'email': email, 'name': name};

  factory AppUser.fromMap(Map<String, dynamic> map) =>
      AppUser(email: map['email'] as String, name: map['name'] as String);
}

class AuthProvider extends ChangeNotifier {
  static const _usersKey = 'users_v1';
  static const _currentUserKey = 'current_user_email_v1';

  final Map<String, Map<String, dynamic>> _usersByEmail =
      {}; // email -> {name, passwordHash}
  AppUser? _currentUser;

  AuthProvider() {
    Future.microtask(_init);
  }

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final e = email.trim().toLowerCase();
    if (_usersByEmail.containsKey(e)) {
      throw Exception('An account with this email already exists');
    }
    final passwordHash = _hash(password);
    _usersByEmail[e] = {'name': name.trim(), 'passwordHash': passwordHash};
    _currentUser = AppUser(email: e, name: name.trim());
    await _persist();
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    final e = email.trim().toLowerCase();
    final record = _usersByEmail[e];
    if (record == null) {
      throw Exception('No account found for this email');
    }
    final passwordHash = _hash(password);
    if (record['passwordHash'] != passwordHash) {
      throw Exception('Invalid credentials');
    }
    _currentUser = AppUser(email: e, name: record['name'] as String);
    await _persist();
    notifyListeners();
  }

  Future<void> signOut() async {
    _currentUser = null;
    await _persist();
    notifyListeners();
  }

  String _hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersRaw = prefs.getString(_usersKey);
      final currentEmail = prefs.getString(_currentUserKey);
      if (usersRaw != null && usersRaw.isNotEmpty) {
        final decoded = jsonDecode(usersRaw) as Map<String, dynamic>;
        decoded.forEach((email, data) {
          _usersByEmail[email] = Map<String, dynamic>.from(data as Map);
        });
      }
      if (currentEmail != null && currentEmail.isNotEmpty) {
        final record = _usersByEmail[currentEmail];
        if (record != null) {
          _currentUser = AppUser(
            email: currentEmail,
            name: record['name'] as String,
          );
        }
      }
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usersKey, jsonEncode(_usersByEmail));
      await prefs.setString(_currentUserKey, _currentUser?.email ?? '');
    } catch (_) {
      // ignore
    }
  }
}
