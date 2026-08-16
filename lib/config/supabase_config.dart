// lib/config/supabase_config.dart
import 'dart:convert';

//
// Supabase client configuration.
//
// Dart defines override the original repository's browser-safe project URL and
// public anon key fallback. The fallback preserves the existing connected login
// when this integrated project is opened without a local env.json. Supabase
// anon/publishable keys are intentionally public identifiers; authorization is
// enforced by JWTs and RLS. Secret/service-role/provider keys must never appear
// here or in any Flutter build.
//
// Run the app locally with:
//   flutter run --dart-define-from-file=env.json
//
// Build with:
//   flutter build apk --dart-define-from-file=env.json
//
// See env.json.example for the expected format. Copy it to env.json
// (which is already listed in .gitignore) and fill in your real values
// from Supabase → Project Settings → API.
class SupabaseConfig {
  static const String _fallbackUrl = 'https://vyhypddwnsybquzhkcmx.supabase.co';
  static const String _fallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ5aHlwZGR3bnN5YnF1emhrY214Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxMzExMzQsImV4cCI6MjEwMTcwNzEzNH0.stICbeWQW0RWALsldRF8Mxo01YCF7h8mXH_QC3YBiEM';

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _fallbackUrl,
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _fallbackAnonKey,
  );

  static String get publishableKey => anonKey;

  static bool _looksLikePlaceholder(String value) {
    return value.contains('YOUR-PROJECT-REF') ||
        value.contains('YOUR-ANON-PUBLIC-KEY');
  }

  static bool _isSecretKey(String value) {
    return value.startsWith('sb_secret_') ||
        value.startsWith('service_role') ||
        value.startsWith('service-role');
  }

  static bool _isJwtValue(String value) {
    return value.startsWith('eyJ') || value.split('.').length == 3;
  }

  static bool _isLegacyAnonJwt(String value) {
    if (!_isJwtValue(value)) return false;
    final parts = value.split('.');
    if (parts.length != 3) return false;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      return claims['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  static bool _isValidAnonKey(String value) {
    return value.startsWith('sb_publishable_') ||
        value.startsWith('sb_anon_') ||
        _isLegacyAnonJwt(value);
  }

  /// True once real credentials have been supplied and the key is the
  /// expected Supabase browser API key format.
  static bool get isConfigured {
    if (url.isEmpty || publishableKey.isEmpty) {
      return false;
    }
    if (_looksLikePlaceholder(url) || _looksLikePlaceholder(publishableKey)) {
      return false;
    }
    if (_isSecretKey(publishableKey)) {
      return false;
    }
    return _isValidAnonKey(publishableKey);
  }

  static String? get invalidReason {
    if (url.isEmpty || publishableKey.isEmpty) {
      return 'Missing Supabase URL or key.';
    }
    if (_looksLikePlaceholder(url)) {
      return 'Supabase URL still contains placeholder text.';
    }
    if (_looksLikePlaceholder(publishableKey)) {
      return 'Supabase key still contains placeholder text.';
    }
    if (_isSecretKey(publishableKey)) {
      return 'Supabase key is secret-only. Use the browser-safe publishable/anon key from Supabase API settings.';
    }
    if (!_isValidAnonKey(publishableKey)) {
      return 'Supabase key is not in the expected browser-safe format. Use the publishable/anon key from API settings.';
    }
    return null;
  }
}
