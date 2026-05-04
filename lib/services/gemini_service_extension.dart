// lib/services/gemini_service_extension.dart
// ══════════════════════════════════════════════════════════
// Extends GeminiService with generateCoachMessage()
// Used by CoachProvider to get daily AI coaching insight
// (replaces fake AITrainer string matching)
// ══════════════════════════════════════════════════════════
// Add this method inside your existing GeminiService class:

/*
  Future<String> generateCoachMessage({required String prompt}) async {
    if (apiKey.isEmpty) return '';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature':     0.6,
            'maxOutputTokens': 400, // Short response for daily message
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return '';

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String? ?? '';
    } catch (_) {
      return '';
    }
  }
*/

// ══════════════════════════════════════════════════════════
// ADD TO pubspec.yaml:
// ══════════════════════════════════════════════════════════
/*
dependencies:
  # Billing
  in_app_purchase: ^3.1.13

  # Notifications
  flutter_local_notifications: ^17.2.3
  timezone: ^0.9.4

  # (already have these)
  http: ^1.2.0
  shared_preferences: ^2.2.2
  uuid: ^4.4.0
  provider: ^6.1.2
*/

// ══════════════════════════════════════════════════════════
// FILE DELETIONS — remove these files:
// ══════════════════════════════════════════════════════════
/*
DELETE: lib/ai/ai_trainer.dart            ← fake string matching
DELETE: lib/engines/ai_coach_engine.dart  ← empty file
DELETE: lib/engines/gamification_engine.dart ← empty file
DELETE: lib/engines/workout_engine.dart   ← empty file
DELETE: lib/engines/recovery_engine.dart  ← 4 lines, logic moved to analytics_provider
*/

// ══════════════════════════════════════════════════════════
// FIX: Remove duplicate PROutcome from these files:
// ══════════════════════════════════════════════════════════
/*
IN: lib/providers/app_provider.dart
  REMOVE lines 79-117 (entire PRResult class + PROutcome enum)
  ADD at top: import '../core/enums/pr_outcome.dart';
  KEEP: PRResult class BUT change PROutcome. references to use unified enum

IN: lib/services/pr_service.dart
  REMOVE lines 99-100 (duplicate enum PROutcome)
  ADD at top: import '../core/enums/pr_outcome.dart';
  NOTE: pr_service.dart has PROutcome.volumePR and PROutcome.repPR
        These are NOW in the unified enum — no behavior change

IN: lib/engines/pr_engine.dart
  REMOVE lines 49-57 (duplicate enum PROutcome)
  ADD at top: import '../../core/enums/pr_outcome.dart';
*/

// ══════════════════════════════════════════════════════════
// FIX: weekPlan unsafe indexing in app_provider.dart
// ══════════════════════════════════════════════════════════
/*
FIND:  return _weekPlan[today];
REPLACE WITH:
  final idx = today.clamp(0, _weekPlan.length - 1);
  return _weekPlan.elementAtOrNull(idx) ?? _buildDefaultDay(idx);

FIND:  _weekPlan[i].
REPLACE ALL with guard (add at top of method):
  if (i < 0 || i >= _weekPlan.length) return;
  _weekPlan[i].
*/
