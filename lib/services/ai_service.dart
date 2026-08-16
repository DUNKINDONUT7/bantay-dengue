import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Bounded dengue education assistant.
///
/// When deployed, `ai-guidance` runs provider calls inside a Supabase Edge
/// Function so no private API key is shipped to the app. A conservative local
/// fallback keeps safety guidance available during a network outage.
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

  static Future<String> getResponse(String question) => instance.ask(question);

  Future<String> ask(String question) async {
    final query = question.trim();
    if (query.isEmpty) return 'Please enter a dengue-related question.';
    if (query.length > 600) {
      return 'Please shorten the question to 600 characters or fewer. $_disclaimer';
    }

    final lower = query.toLowerCase();
    if (_hasDangerSigns(lower)) return '$_emergency\n\n$_disclaimer';

    if (SupabaseConfig.isConfigured &&
        Supabase.instance.client.auth.currentSession != null) {
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'assistant-guidance',
          body: {'message': query},
        );
        final data = response.data;
        if (data is Map && data['reply'] is String) {
          return '${data['reply']}\n\n$_disclaimer';
        }
      } catch (_) {
        // Fall through to bounded offline guidance.
      }
    }

    return '${_offlineGuidance(lower)}\n\n$_disclaimer';
  }

  bool _hasDangerSigns(String q) => [
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
