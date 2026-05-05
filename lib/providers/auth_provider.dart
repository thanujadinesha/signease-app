import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _profile;
  String? _error;
  bool _loading = false;

  AuthStatus get status  => _status;
  UserProfile? get profile => _profile;
  String? get error    => _error;
  bool get loading     => _loading;
  bool get isLoggedIn  => _status == AuthStatus.authenticated;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final token = await ApiService.instance.getToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    // Token exists — try to load profile to verify it's still valid
    try {
      _profile = await ApiService.instance.getProfile();
      _status  = AuthStatus.authenticated;
    } catch (_) {
      await ApiService.instance.clearToken();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _profile = await ApiService.instance.signIn(email, password);
      _status  = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Sign in failed. Please try again.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> signUp(String email, String password) async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _profile = await ApiService.instance.signUp(email, password);
      _status  = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Registration failed. Please try again.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    await ApiService.instance.signOut();
    _profile = null;
    _status  = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      _profile = await ApiService.instance.getProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('Profile refresh error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
