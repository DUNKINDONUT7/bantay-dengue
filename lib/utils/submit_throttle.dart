// lib/utils/submit_throttle.dart
//
// Client-side cooldown mixin for submit buttons — deters accidental
// double-taps and simple scripted retry loops. NOT real rate limiting; a
// determined attacker can bypass any client-side check trivially. Actual
// abuse protection has to live server-side (Supabase rate limits auth
// endpoints by default; other endpoints would need an Edge Function).
//
// Was hand-rolled identically in request_appointment_screen.dart and
// request_waste_screen.dart — consolidated so the cooldown window only needs
// to be tuned in one place.
mixin SubmitThrottle {
  DateTime? _lastSubmitAttempt;

  /// Returns null if a submit may proceed now, otherwise the number of whole
  /// seconds the caller should ask the user to wait.
  int? checkSubmitCooldown({Duration cooldown = const Duration(seconds: 10)}) {
    final now = DateTime.now();
    final last = _lastSubmitAttempt;
    if (last != null && now.difference(last) < cooldown) {
      return (cooldown - now.difference(last)).inSeconds;
    }
    _lastSubmitAttempt = now;
    return null;
  }
}
