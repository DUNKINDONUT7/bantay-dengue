// lib/services/auth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';

/// Central authentication + role gateway for the whole app.
///
/// Wraps Supabase Auth and the `profiles` table, where the user's role lives.
/// Extends ChangeNotifier so GoRouter can re-run redirects whenever the live
/// session or profile changes.
class AuthService extends ChangeNotifier {
  AuthService() {
    if (!SupabaseConfig.isConfigured) {
      _authSub = null;
      return;
    }

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _loadProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _profile = null;
        _loadingProfile = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    });
    if (currentSession != null) {
      _loadProfile();
    }
  }

  StreamSubscription<AuthState>? _authSub;

  bool get hasSupabase => SupabaseConfig.isConfigured;

  SupabaseClient get _client {
    if (!hasSupabase) {
      throw StateError('Supabase is not configured.');
    }
    return Supabase.instance.client;
  }

  UserModel? _profile;
  UserModel? get profile => _profile;
  UserModel? get currentUser => _profile;

  bool _loadingProfile = false;
  Future<void>? _profileLoad;
  String? _profileLoadUserId;
  bool get loadingProfile => _loadingProfile;

  Session? get currentSession =>
      hasSupabase ? _client.auth.currentSession : null;
  bool get isAuthenticated => currentSession != null;
  UserRole? get role => _profile?.role;

  /// Reuses an in-flight profile request. Supabase emits `signedIn` while the
  /// explicit sign-in future is also completing; without this guard both paths
  /// fetched the same profile and made entry feel slower on mobile networks.
  Future<void> _loadProfile() {
    final userId = currentSession?.user.id;
    final active = _profileLoad;
    if (active != null && _profileLoadUserId == userId) return active;

    _profileLoadUserId = userId;
    _loadingProfile = userId != null;
    notifyListeners();

    late final Future<void> operation;
    operation = _performProfileLoad(userId).whenComplete(() {
      // A different account may have started loading while this request was
      // in flight. Only the newest operation may clear the shared state.
      if (identical(_profileLoad, operation)) {
        _profileLoad = null;
        _profileLoadUserId = null;
        _loadingProfile = false;
        notifyListeners();
      }
    });
    _profileLoad = operation;
    return operation;
  }

  Future<void> _performProfileLoad(String? userId) async {
    if (!hasSupabase || userId == null) {
      _profile = null;
      return;
    }

    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      if (currentSession?.user.id == userId) {
        _profile = UserModel.fromProfile(row);
      }
    } catch (error) {
      final repaired = await _createMissingProfile(userId);
      if (currentSession?.user.id == userId) _profile = repaired;
      if (repaired == null) {
        debugPrint('Unable to load or repair profile for $userId: $error');
      }
    }
  }

  Future<UserModel?> _createMissingProfile(String userId) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != userId) return null;

    final fullName = (user.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final email = user.email ?? '';

    try {
      final row = await _client
          .from('profiles')
          .upsert({
            'id': userId,
            'full_name': fullName.isEmpty ? email.split('@').first : fullName,
            'email': email,
            'role': userRoleToString(UserRole.civilian),
          })
          .select()
          .single();
      return UserModel.fromProfile(row);
    } catch (repairError) {
      debugPrint('Profile repair failed for $userId: $repairError');
      return null;
    }
  }

  /// Re-fetches the profile after role or profile changes.
  Future<void> refreshProfile() => _loadProfile();

  Future<void> signIn({required String email, required String password}) async {
    if (!hasSupabase) {
      throw StateError('Supabase is not configured.');
    }
    await _client.auth.signInWithPassword(email: email, password: password);
    await _loadProfile();
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (!hasSupabase) {
      throw StateError('Supabase is not configured.');
    }
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    final userId = res.user?.id;
    if (userId != null) {
      await _client.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'email': email,
        'role': userRoleToString(UserRole.civilian),
      });
    }

    if (_client.auth.currentSession != null) {
      await _loadProfile();
    }
  }

  Future<void> resetPassword(String email) async {
    if (!hasSupabase) {
      throw StateError('Supabase is not configured.');
    }
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    if (!hasSupabase) {
      _profile = null;
      _loadingProfile = false;
      notifyListeners();
      return;
    }
    await _client.auth.signOut();
    _profile = null;
    _loadingProfile = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

AuthService? _authService;

/// Initializes the global AuthService instance once Supabase is ready.
void initializeAuthService() {
  _authService ??= AuthService();
}

/// The global AuthService instance. Must be initialized after Supabase.
AuthService get authService {
  if (_authService == null) {
    throw StateError(
      'AuthService was accessed before initialization. Call initializeAuthService() after Supabase.initialize().',
    );
  }
  return _authService!;
}
