import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Bounded dengue education assistant.
///
/// Real replies come from the `assistant-guidance` Supabase Edge Function,
/// which forwards to any OpenAI-compatible chat-completions API (provider
/// chosen via the AI_BASE_URL/AI_API_KEY/AI_MODEL secrets — see
/// supabase/functions/assistant-guidance/index.ts). No private API key is
/// ever shipped to the app. [live] on the result tells the caller whether
/// that function actually answered, or the query fell back to the
/// conservative local guidance below (used if the function isn't deployed,
/// AI_API_KEY isn't set, or the network is unavailable).
class AiReply {
  final String text;
  final bool live;
  const AiReply(this.text, {required this.live});
}

class AiService {
  AiService._();

  static final AiService instance = AiService._();

  static const _emergency =
      'Seek urgent medical care now for severe abdominal pain, persistent '
      'vomiting, bleeding, difficulty breathing, extreme weakness, confusion, '
      'cold/clammy skin, or very little urine. In the Philippines, call 911 or '
      'go to the nearest emergency department. Do not wait for an AI response.';

  static const _disclaimer =
      'This is general dengue education—not a diagnosis or replacement for a '
      'licensed clinician. A blood test and professional assessment may be needed.';

  Future<AiReply> ask(String question) async {
    final query = question.trim();
    if (query.isEmpty) {
      return const AiReply(
        'Please enter a dengue-related question.',
        live: false,
      );
    }
    if (query.length > 600) {
      return AiReply(
        'Please shorten the question to 600 characters or fewer. $_disclaimer',
        live: false,
      );
    }

    final lower = query.toLowerCase();
    if (hasDangerSigns(lower)) {
      return AiReply('$_emergency\n\n$_disclaimer', live: false);
    }

    if (SupabaseConfig.isConfigured &&
        Supabase.instance.client.auth.currentSession != null) {
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'assistant-guidance',
          body: {'message': query},
        );
        final data = response.data;
        if (data is Map && data['reply'] is String) {
          return AiReply('${data['reply']}\n\n$_disclaimer', live: true);
        }
      } on FunctionException catch (error) {
        // The server-side rate limit (supabase/RATE_LIMIT_ADDITIONS.sql)
        // rejected this — say so plainly instead of silently pretending the
        // AI is offline, which would be misleading.
        if (error.status == 429) {
          return const AiReply(
            "You're asking questions faster than the assistant can safely "
            'answer. Please wait a moment before trying again.',
            live: false,
          );
        }
        // Any other failure falls through to bounded offline guidance, but
        // log the real reason in debug builds — this is the one call in the
        // app backed by an external provider outside our control, so silent
        // failure here is genuinely hard to diagnose otherwise.
        debugPrint(
          'assistant-guidance call failed: status=${error.status} '
          'details=${error.details}',
        );
      } catch (error) {
        debugPrint('assistant-guidance call failed: $error');
      }
    }

    return AiReply('${_offlineGuidance(lower)}\n\n$_disclaimer', live: false);
  }

  /// Same phrase list the AI chat uses to short-circuit straight to the
  /// emergency message instead of waiting on a model call. Exposed so
  /// report_form.dart can reuse it verbatim on the case-details field —
  /// one danger-sign list for the whole app, not two that could drift.
  bool hasDangerSigns(String q) => [
    'bleeding',
    'blood in vomit',
    'black stool',
    'severe abdominal',
    'persistent vomiting',
    'difficulty breathing',
    'confusion',
    'fainting',
    'cold clammy',
    'no urine',
  ].any(q.contains);

  String _offlineGuidance(String q) {
    if (q.contains('symptom') || q.contains('fever')) {
      return 'Common dengue symptoms include sudden high fever, headache, pain '
          'behind the eyes, muscle or joint pain, nausea, and rash. Symptoms can '
          'overlap with other illnesses. Contact your barangay health center, '
          'especially when fever lasts two days or you are pregnant, elderly, or '
          'caring for a young child. $_emergency';
    }
    if (q.contains('medicine') ||
        q.contains('aspirin') ||
        q.contains('ibuprofen') ||
        q.contains('paracetamol')) {
      return 'Use only medicines advised by a clinician. Paracetamol is commonly '
          'used for fever when safe for the person. Avoid aspirin, ibuprofen, and '
          'other NSAIDs unless a clinician specifically directs you because they '
          'may increase bleeding risk. Drink fluids and monitor urine output.';
    }
    if (q.contains('prevent') ||
        q.contains('mosquito') ||
        q.contains('breeding')) {
      return 'Apply the 4S approach: Search and destroy breeding places; use '
          'Self-protection such as repellent and long sleeves; Seek early '
          'consultation; and Support fogging only when health authorities advise '
          'it. Empty and scrub water containers weekly and cover stored water.';
    }
    if (q.contains('test') || q.contains('diagnos')) {
      return 'Dengue cannot be confirmed by symptoms alone. A clinician decides '
          'whether NS1, PCR, or antibody testing and blood counts are appropriate '
          'based on the illness day and examination. Visit your health center.';
    }
    return 'I can provide bounded guidance about dengue symptoms, warning signs, '
        'prevention, testing, hydration, and when to seek care. I cannot diagnose '
        'a condition or prescribe treatment. For personal medical advice, contact '
        'your barangay health center. $_emergency';
  }
}
