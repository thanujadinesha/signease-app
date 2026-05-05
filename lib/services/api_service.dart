import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

// ── Tier limits ────────────────────────────────────────────────────────────────

const Map<String, int> kTierLimits = {
  'free': 3,
  'pro': 50,
  'unlimited': -1,
};
const int kDefaultLimit = 3;

// ── User model ─────────────────────────────────────────────────────────────────

class UserProfile {
  final String id;
  final String email;
  final String tier;
  final int signaturesUsed;

  const UserProfile({
    required this.id,
    required this.email,
    required this.tier,
    required this.signaturesUsed,
  });

  int get limit     => kTierLimits[tier] ?? kDefaultLimit;
  int get remaining => limit < 0 ? 999999 : (limit - signaturesUsed).clamp(0, limit);
  bool get canSign  => limit < 0 || signaturesUsed < limit;
  bool get isUnlimited => limit < 0;

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id:             m['id']             as String,
        email:          m['email']          as String? ?? '',
        tier:           m['tier']           as String? ?? 'free',
        signaturesUsed: m['signaturesUsed'] as int?    ?? 0,
      );
}

// ── Exceptions ─────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class LimitReachedException implements Exception {
  @override
  String toString() => 'Signature limit reached for your current plan.';
}

// ── Service ────────────────────────────────────────────────────────────────────

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _tokenKey = 'se_token';

  // ── Token storage ──────────────────────────────────────────────────────────

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(
      body['error'] as String? ?? 'Request failed',
      res.statusCode,
    );
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Returns the logged-in [UserProfile] or throws [ApiException].
  Future<UserProfile> signIn(String email, String password) async {
    final res = await http.post(
      _uri('/api/auth/login'),
      headers: await _headers(),
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res);
    await saveToken(data['token'] as String);
    return UserProfile.fromMap(data['user'] as Map<String, dynamic>);
  }

  Future<UserProfile> signUp(String email, String password) async {
    final res = await http.post(
      _uri('/api/auth/register'),
      headers: await _headers(),
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res);
    await saveToken(data['token'] as String);
    return UserProfile.fromMap(data['user'] as Map<String, dynamic>);
  }

  Future<void> signOut() async {
    await clearToken();
  }

  bool get isLoggedIn => false; // checked via token presence; see AuthProvider

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<UserProfile> getProfile() async {
    final res = await http.get(
      _uri('/api/profile'),
      headers: await _headers(auth: true),
    );
    final data = await _handleResponse(res);
    return UserProfile.fromMap(data);
  }

  // ── Signatures ─────────────────────────────────────────────────────────────

  Future<bool> canSign() async {
    try {
      final res = await http.get(
        _uri('/api/signatures/can-sign'),
        headers: await _headers(auth: true),
      );
      final data = await _handleResponse(res);
      return data['allowed'] as bool? ?? false;
    } catch (e) {
      debugPrint('canSign error: $e');
      return false;
    }
  }

  Future<void> recordSignature(String documentName) async {
    final res = await http.post(
      _uri('/api/signatures/record'),
      headers: await _headers(auth: true),
      body: json.encode({'documentName': documentName}),
    );
    if (res.statusCode == 403) throw LimitReachedException();
    await _handleResponse(res);
  }
}
