// lib/utils/submit_throttle.dart
//
// Client-side cooldown mixin for submit buttons — deters accidental
// double-taps and simple scripted retry loops. NOT real rate limiting; a
// determined attacker can bypass any client-side check trivially. Real
// abuse protection is server-side: reports, appointments, and waste_requests
// all have DB-level rate-limit triggers (see supabase/RATE_LIMIT_ADDITIONS.sql
// and APPLY_THIS_NOW.sql), and the AI assistant has its own server-side
// check via the assistant-guidance Edge Function. This mixin is a UX nicety
// on top of that, not a substitute for it.
//
// Used by report_form.dart (case + breeding-site reports, and the
// appointment created alongside a case report), request_waste_screen.dart,
// and ai_chat_screen.dart — consolidated here so the cooldown window only
// needs to be tuned in one place. appointments_screen.dart's edit sheet does
// NOT use this (its writes are backstopped by the same DB-level triggers,
// same as everywhere else — this mixin just hasn't been added there).
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
