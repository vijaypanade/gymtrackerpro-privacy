// lib/services/training_intent_parser.dart

class TrainingIntent {
  final int trainingDays;       // 0 = unspecified
  final String splitType;       // '', 'ppl', 'bro', 'upper_lower', 'arnold', 'full_body', 'strength', 'calisthenics'
  final List<String> musclePriority;
  final String goalType;        // '', 'muscle', 'fat_loss', 'strength', 'recomp', 'endurance'
  final String gymType;         // '', 'full_gym', 'home', 'dumbbells', 'bodyweight', 'bands'
  final int timeLimitMin;       // 0 = unspecified
  final String experienceHint;  // '', 'beginner', 'intermediate', 'advanced', 'returning'
  final List<String> injuries;
  final bool isFullPlanRequest;
  final bool isSingleWorkoutRequest;

  const TrainingIntent({
    this.trainingDays = 0,
    this.splitType = '',
    this.musclePriority = const [],
    this.goalType = '',
    this.gymType = '',
    this.timeLimitMin = 0,
    this.experienceHint = '',
    this.injuries = const [],
    this.isFullPlanRequest = false,
    this.isSingleWorkoutRequest = false,
  });

  bool get hasConstraints =>
      trainingDays > 0 ||
      splitType.isNotEmpty ||
      musclePriority.isNotEmpty ||
      goalType.isNotEmpty ||
      gymType.isNotEmpty ||
      timeLimitMin > 0 ||
      experienceHint.isNotEmpty;

  String get engineSplit {
    switch (splitType) {
      case 'ppl':
        return trainingDays == 6 ? 'PPLPPL' : 'PPL';
      case 'upper_lower':
        return trainingDays <= 3 && trainingDays > 0 ? 'UpperLower2' : 'UpperLower4';
      case 'arnold':
        return 'ArnoldSplit';
      case 'full_body':
        return trainingDays == 4 ? 'FullBody4' : 'FullBody';
      case 'bro':
        return trainingDays == 6 ? 'BroSplit6' : 'BroSplit5';
      case 'strength':
        return 'Strength3';
      default:
        return '';
    }
  }
}

class TrainingIntentParser {
  TrainingIntentParser._();

  static TrainingIntent parse(String raw) {
    final t = raw.toLowerCase();
    final days   = _days(t);
    final split  = _split(t);
    final muscles = _muscles(t);
    final goal   = _goal(t);
    final gym    = _gym(t);
    final time   = _time(t);
    final exp    = _experience(t);
    final inj    = _injuries(t);
    final full   = _isFullPlan(t);
    final single = _isSingleWorkout(t);

    return TrainingIntent(
      trainingDays: days,
      splitType: split,
      musclePriority: muscles,
      goalType: goal,
      gymType: gym,
      timeLimitMin: time,
      experienceHint: exp,
      injuries: inj,
      isFullPlanRequest: full,
      isSingleWorkoutRequest: single,
    );
  }

  static int _days(String t) {
    if (RegExp(r'\b(7|seven)\s*day').hasMatch(t)) return 7;
    if (RegExp(r'\b(6|six)\s*day').hasMatch(t)) return 6;
    if (RegExp(r'\b(5|five)\s*day').hasMatch(t)) return 5;
    if (RegExp(r'\b(4|four)\s*day').hasMatch(t)) return 4;
    if (RegExp(r'\b(3|three)\s*day').hasMatch(t)) return 3;
    if (RegExp(r'\b(2|two)\s*day').hasMatch(t)) return 2;
    if (RegExp(r'\bpplppl\b').hasMatch(t)) return 6;
    if (RegExp(r'\bppl\b').hasMatch(t)) return 3;
    if (RegExp(r'\balternate\s*day').hasMatch(t)) return 3;
    if (RegExp(r'\bweekend').hasMatch(t)) return 2;
    if (RegExp(r'\beveryday\b').hasMatch(t)) return 6;
    return 0;
  }

  static String _split(String t) {
    if (RegExp(r'\bpplppl\b').hasMatch(t)) return 'ppl';
    if (RegExp(r'push\s*pull\s*legs|\bppl\b').hasMatch(t)) return 'ppl';
    if (RegExp(r'\barnold\s*split').hasMatch(t)) return 'arnold';
    if (RegExp(r'upper\s*lower\b|upper[/\-]lower').hasMatch(t)) return 'upper_lower';
    if (RegExp(r'\bfull\s*body\b|\bfullbody\b').hasMatch(t)) return 'full_body';
    if (RegExp(r'\bbro\s*split|body\s*part\s*split').hasMatch(t)) return 'bro';
    if (RegExp(r'\bstrength\s*training|powerlifting|stronglift').hasMatch(t)) return 'strength';
    if (RegExp(r'\bcalisthenics|bodyweight\s*training').hasMatch(t)) return 'calisthenics';

    // Bro split from muscle pairs
    final muscleWords = ['chest', 'back', 'shoulder', 'bicep', 'tricep', 'legs'];
    int muscleCount = 0;
    for (final m in muscleWords) {
      if (t.contains(m)) muscleCount++;
    }
    if (muscleCount >= 2 &&
        (t.contains('split') || t.contains('routine') || t.contains('plan'))) {
      return 'bro';
    }

    return '';
  }

  static List<String> _muscles(String t) {
    final result = <String>[];

    final checks = <String, List<String>>{
      'chest':     ['chest', 'pec', 'incline', 'bench press'],
      'back':      ['back', 'lat ', 'wide back', 'v-taper', 'v taper', 'lats'],
      'shoulders': ['shoulder', 'delt', 'capped', 'boulder', 'rear delt'],
      'arms':      ['arms', 'bicep', 'tricep', 'forearm', 'arm size', 'arm growth'],
      'legs':      ['legs', 'quad', 'hamstring', 'glute', 'calf', 'squat focus'],
      'abs':       ['abs', 'core', 'midsection'],
    };

    for (final entry in checks.entries) {
      for (final kw in entry.value) {
        if (t.contains(kw)) {
          if (!result.contains(entry.key)) result.add(entry.key);
          break;
        }
      }
    }

    return result;
  }

  static String _goal(String t) {
    if (RegExp(r'fat\s*loss|lose\s*fat|lose\s*weight|\bcut\b|\bcutting\b|shred').hasMatch(t)) return 'fat_loss';
    if (RegExp(r'\brecomp|body\s*recomp').hasMatch(t)) return 'recomp';
    if (RegExp(r'\bstrength\b|\bstrong\b|powerlifting|\b1rm\b|max\s*lift').hasMatch(t)) return 'strength';
    if (RegExp(r'\bendurance\b|stamina|cardio\s*fit').hasMatch(t)) return 'endurance';
    if (RegExp(r'\bbulk\b|mass\b|muscle\b|hypertrophy|physique|aesthetic').hasMatch(t)) return 'muscle';
    return '';
  }

  static String _gym(String t) {
    if (RegExp(r'no\s*equipment|no\s*gym|without\s*gym|bodyweight\s*only|home\s*workout').hasMatch(t)) return 'bodyweight';
    if (RegExp(r'dumbbell\s*only|only\s*dumbbell').hasMatch(t)) return 'dumbbells';
    if (RegExp(r'resistance\s*band').hasMatch(t)) return 'bands';
    if (RegExp(r'full\s*gym|commercial\s*gym').hasMatch(t)) return 'full_gym';
    if (RegExp(r'\bhome\b|village|no\s*barbell').hasMatch(t)) return 'home';
    return '';
  }

  static int _time(String t) {
    final match = RegExp(r'(\d+)\s*(min|minute)').firstMatch(t);
    if (match != null) {
      final val = int.tryParse(match.group(1) ?? '') ?? 0;
      if (val >= 15 && val <= 120) return val;
    }
    if (t.contains('quick workout') || t.contains('short workout')) return 30;
    if (t.contains('office') || t.contains('lunch break')) return 45;
    return 0;
  }

  static String _experience(String t) {
    if (RegExp(r'\bbeginner\b|newbie|starting out|first\s*time|gym\s*noob|naya\b').hasMatch(t)) return 'beginner';
    if (RegExp(r'\badvanced\b|experienced|veteran|\belite\b').hasMatch(t)) return 'advanced';
    if (RegExp(r'\bintermediate\b|mid\s*level').hasMatch(t)) return 'intermediate';
    if (RegExp(r'\breturning\b|coming\s*back|after\s*break|after.*gap|gap.*baad').hasMatch(t)) return 'returning';
    return '';
  }

  static List<String> _injuries(String t) {
    final result = <String>[];
    if (RegExp(r'knee\s*pain|knee\s*injur|bad\s*knee').hasMatch(t)) result.add('knee');
    if (RegExp(r'shoulder\s*pain|shoulder\s*injur|rotator\s*cuff').hasMatch(t)) result.add('shoulder');
    if (RegExp(r'lower\s*back|back\s*pain|lumbar').hasMatch(t)) result.add('lower_back');
    if (RegExp(r'elbow\s*pain|tennis\s*elbow').hasMatch(t)) result.add('elbow');
    if (RegExp(r'wrist\s*pain|wrist\s*injur').hasMatch(t)) result.add('wrist');
    if (RegExp(r'neck\s*pain|neck\s*injur').hasMatch(t)) result.add('neck');
    return result;
  }

  static bool _isFullPlan(String t) {
    if (RegExp(
      r'(create|generate|make|build|give)\s*(me\s*)?(a\s*)?(weekly|full|complete|\d+\s*day)?\s*(workout\s*)?(plan|program|routine|schedule)',
    ).hasMatch(t)) return true;
    if (RegExp(r'weekly\s*plan|week\s*plan|training\s*plan').hasMatch(t)) return true;
    if (RegExp(r'(ppl|push pull legs|bro split|upper lower|arnold split)\b').hasMatch(t) &&
        RegExp(r'(create|make|build|generate|give)').hasMatch(t)) return true;
    return false;
  }

  static bool _isSingleWorkout(String t) {
    if (RegExp(r'(today|aaj)\b.*workout|workout.*today').hasMatch(t)) return true;
    if (RegExp(r'(chest|back|legs?|shoulder|arm|bicep|tricep)\s*workout').hasMatch(t)) return true;
    if (RegExp(r'give.*today|today.*exercise').hasMatch(t)) return true;
    return false;
  }

  static const _splitLabels = <String, String>{
    'ppl':         'Push Pull Legs',
    'upper_lower': 'Upper / Lower',
    'arnold':      'Arnold Split',
    'full_body':   'Full Body',
    'bro':         'Bro Split',
    'strength':    'Strength / Powerlifting',
    'calisthenics':'Calisthenics',
  };

  static const _goalLabels = <String, String>{
    'muscle':    'Muscle Gain / Hypertrophy',
    'fat_loss':  'Fat Loss / Cutting',
    'strength':  'Strength / Powerlifting',
    'recomp':    'Body Recomposition',
    'endurance': 'Endurance / Cardio Fitness',
  };

  static const _gymLabels = <String, String>{
    'full_gym':   'Full Commercial Gym',
    'home':       'Home Gym',
    'dumbbells':  'Dumbbells Only',
    'bodyweight': 'Bodyweight / No Equipment',
    'bands':      'Resistance Bands',
  };

  static const _injuryNotes = <String, String>{
    'knee':       'No deep squats, no lunges, replace with leg extension + hip thrust',
    'shoulder':   'No overhead press, no upright row, use cable laterals + chest-supported rows',
    'lower_back': 'No barbell deadlift, no barbell squat, use goblet squat + belt squat',
    'elbow':      'No skull crushers, use cable pushdowns + neutral grip',
    'wrist':      'No wrist-loaded barbell moves, use EZ bar + neutral grip',
    'neck':       'No heavy shrugs or overhead loading, use light cable work only',
  };

  static String buildConstraintBlock(TrainingIntent intent) {
    if (!intent.hasConstraints && intent.injuries.isEmpty) return '';

    final lines = <String>[];
    lines.add('═══════════════════════════════════════');
    lines.add('HARD TRAINING CONSTRAINTS — FOLLOW EXACTLY. NEVER DEVIATE:');

    if (intent.trainingDays > 0) {
      lines.add('• Training Days: ${intent.trainingDays} days per week');
    }
    if (intent.splitType.isNotEmpty) {
      final label = _splitLabels[intent.splitType] ?? intent.splitType;
      lines.add('• Split Structure: $label');
    }
    if (intent.musclePriority.isNotEmpty) {
      lines.add('• Muscle Priority: ${intent.musclePriority.join(', ')}');
    }
    if (intent.goalType.isNotEmpty) {
      final label = _goalLabels[intent.goalType] ?? intent.goalType;
      lines.add('• Goal: $label');
    }
    if (intent.gymType.isNotEmpty) {
      final label = _gymLabels[intent.gymType] ?? intent.gymType;
      lines.add('• Equipment: $label');
    }
    if (intent.timeLimitMin > 0) {
      lines.add('• Max Session Duration: ${intent.timeLimitMin} minutes');
    }
    if (intent.experienceHint.isNotEmpty) {
      lines.add('• Experience Level: ${intent.experienceHint}');
    }
    if (intent.injuries.isNotEmpty) {
      lines.add('• INJURY AVOIDANCE (CRITICAL):');
      for (final inj in intent.injuries) {
        final note = _injuryNotes[inj] ?? 'Avoid aggravating $inj';
        lines.add('  → $inj: $note');
      }
    }
    lines.add('═══════════════════════════════════════');

    return lines.join('\n');
  }
}
