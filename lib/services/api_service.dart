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
  bool get isPro => tier == 'pro' || tier == 'premium' || tier == 'unlimited';

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id:             m['id']             as String,
        email:          m['email']          as String? ?? '',
        tier:           m['tier']           as String? ?? 'free',
        signaturesUsed: m['signaturesUsed'] as int?    ?? 0,
      );
}

// ── Request models ─────────────────────────────────────────────────────────────

class SigningSlotInfo {
  final int slot;
  final String label;
  final String email;
  final DateTime? signedAt;

  const SigningSlotInfo({
    required this.slot,
    required this.label,
    required this.email,
    this.signedAt,
  });

  factory SigningSlotInfo.fromMap(Map<String, dynamic> m) => SigningSlotInfo(
        slot:     m['slot']     as int,
        label:    m['label']    as String? ?? 'Person ${m['slot']}',
        email:    m['email']    as String? ?? '',
        signedAt: m['signed_at'] != null
            ? DateTime.tryParse(m['signed_at'] as String)
            : null,
      );
}

class SigningRequestInfo {
  final String id;
  final String documentName;
  final String status;
  final int currentSlot;
  final int totalSlots;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? reminderInterval;
  final List<SigningSlotInfo> slots;

  const SigningRequestInfo({
    required this.id,
    required this.documentName,
    required this.status,
    required this.currentSlot,
    required this.totalSlots,
    required this.createdAt,
    this.expiresAt,
    this.reminderInterval,
    required this.slots,
  });

  int get signedCount => slots.where((s) => s.signedAt != null).length;
  bool get isCompleted => status == 'completed';
  bool get isExpired   => status == 'expired';
  bool get isPending   => status == 'pending';

  factory SigningRequestInfo.fromMap(Map<String, dynamic> m) {
    final slotsList = (m['slots'] as List<dynamic>? ?? [])
        .map((s) => SigningSlotInfo.fromMap(s as Map<String, dynamic>))
        .toList();
    return SigningRequestInfo(
      id:               m['id']           as String,
      documentName:     m['documentName'] as String? ?? '',
      status:           m['status']       as String? ?? 'pending',
      currentSlot:      m['currentSlot']  as int?    ?? 1,
      totalSlots:       m['totalSlots']   as int?    ?? 1,
      createdAt:        m['createdAt'] != null
          ? DateTime.tryParse(m['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt:        m['expiresAt'] != null
          ? DateTime.tryParse(m['expiresAt'] as String)
          : null,
      reminderInterval: m['reminderInterval'] as int?,
      slots: slotsList,
    );
  }
}

// ── Audit model ────────────────────────────────────────────────────────────────

class AuditEvent {
  final String eventType;
  final int? slot;
  final String? actorEmail;
  final String? ipAddress;
  final String? userAgent;
  final String? sigHash;
  final DateTime createdAt;

  const AuditEvent({
    required this.eventType,
    this.slot,
    this.actorEmail,
    this.ipAddress,
    this.userAgent,
    this.sigHash,
    required this.createdAt,
  });

  factory AuditEvent.fromMap(Map<String, dynamic> m) => AuditEvent(
        eventType:   m['event_type']  as String,
        slot:        m['slot']        as int?,
        actorEmail:  m['actor_email'] as String?,
        ipAddress:   m['ip_address']  as String?,
        userAgent:   m['user_agent']  as String?,
        sigHash:     m['sig_hash']    as String?,
        createdAt:   DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  String get label => switch (eventType) {
        'request_created' => 'Request created',
        'slot_viewed'     => 'Link opened',
        'slot_signed'     => 'Signed',
        'completed'       => 'All complete',
        _                 => eventType,
      };
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

  // ── Billing ────────────────────────────────────────────────────────────────

  // ── Requests ───────────────────────────────────────────────────────────────

  /// Create a multi-signer signing request. Returns the new request ID.
  Future<String> createRequest({
    required String documentName,
    required String documentData,
    String documentType = 'pdf',
    String? message,
    int? expiresInDays,
    int? reminderInterval,
    required List<Map<String, dynamic>> placements,
    required List<Map<String, dynamic>> signers,
  }) async {
    final res = await http.post(
      _uri('/api/requests'),
      headers: await _headers(auth: true),
      body: json.encode({
        'documentName': documentName,
        'documentData': documentData,
        'documentType': documentType,
        if (message != null) 'message': message,
        if (expiresInDays != null && expiresInDays > 0) 'expiresInDays': expiresInDays,
        if (reminderInterval != null && reminderInterval > 0) 'reminderInterval': reminderInterval,
        'placements': placements,
        'signers': signers,
      }),
    );
    final data = await _handleResponse(res);
    return data['id'] as String;
  }

  Future<List<SigningRequestInfo>> listRequests() async {
    final res = await http.get(
      _uri('/api/requests'),
      headers: await _headers(auth: true),
    );
    final data = await _handleResponse(res);
    final list = data['requests'] as List<dynamic>;
    return list.map((m) => SigningRequestInfo.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SigningRequestInfo> getRequest(String id) async {
    final res = await http.get(
      _uri('/api/requests/$id'),
      headers: await _headers(auth: true),
    );
    final data = await _handleResponse(res);
    return SigningRequestInfo.fromMap(data);
  }

  Future<List<AuditEvent>> getAuditTrail(String requestId) async {
    final res = await http.get(
      _uri('/api/requests/$requestId/audit'),
      headers: await _headers(auth: true),
    );
    final data = await _handleResponse(res);
    final list = data['events'] as List<dynamic>;
    return list.map((m) => AuditEvent.fromMap(m as Map<String, dynamic>)).toList();
  }

  /// Downloads the certificate PDF bytes for a completed request.
  Future<Uint8List> downloadCertificate(String requestId) async {
    final token = await getToken();
    final res = await http.get(
      _uri('/api/requests/$requestId/certificate'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 403) {
      throw ApiException('Certificate requires a Premium plan.', 403);
    }
    if (res.statusCode == 404) {
      throw ApiException('Certificate not ready yet.', 404);
    }
    if (res.statusCode != 200) {
      throw ApiException('Failed to download certificate', res.statusCode);
    }
    return res.bodyBytes;
  }

  // ── Billing ────────────────────────────────────────────────────────────────

  /// Returns the Stripe Checkout URL for the given plan.
  Future<String> createCheckoutSession(String plan) async {
    final res = await http.post(
      _uri('/api/billing/checkout'),
      headers: await _headers(auth: true),
      body: json.encode({'plan': plan}),
    );
    final data = await _handleResponse(res);
    return data['url'] as String;
  }
}