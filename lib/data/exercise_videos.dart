// AUTO-GENERATED — Curated embeddable YouTube videos (verified)
class ExerciseVideos {
  static const Map<String, String> _videos = {
    // CHEST
    'bench press': 'rT7DgCr-3pg',
    'barbell bench press': 'rT7DgCr-3pg',
    'incline bench press': 'jPLdzuHckI8',
    'incline barbell press': 'jPLdzuHckI8',
    'dumbbell bench press': 'QsYre__-aro',
    'incline dumbbell press': '8iPEnn-ltC8',
    'dumbbell fly': 'QENKPHhQVi4',
    'cable fly': 'Iwe6AmxVf7o',
    'push up': 'IODxDxX7oi4',
    'push-up': 'IODxDxX7oi4',
    'push ups': 'IODxDxX7oi4',
    'push-ups': 'IODxDxX7oi4',
    'chest dip': 'wjUmnZH528Y',
    'dips': 'wjUmnZH528Y',

    // BACK
    'pull up': 'eGo4IYlbE5g',
    'pull-up': 'eGo4IYlbE5g',
    'pull ups': 'eGo4IYlbE5g',
    'chin up': 'brhRXlOhsAM',
    'lat pulldown': 'CAwf7n6Luuc',
    'barbell row': 'kBWAon7ItDw',
    'bent over row': 'kBWAon7ItDw',
    'dumbbell row': 'roCP6wCXPqo',
    'seated cable row': 'GZbfZ033f74',
    'deadlift': 'r4MzxtBKyNE',
    'romanian deadlift': '7AsYNBlOZKk',
    'face pull': 'rep-qVOkqgk',

    // SHOULDERS
    'overhead press': '2yjwXTZQDDI',
    'shoulder press': 'qEwKCR5JCog',
    'military press': '2yjwXTZQDDI',
    'dumbbell shoulder press': 'qEwKCR5JCog',
    'lateral raise': '3VcKaXpzqRo',
    'side lateral raise': '3VcKaXpzqRo',
    'rear delt fly': 'EA7u4Q_8HQ0',
    'arnold press': '6Z15_WdXmVw',

    // BICEPS
    'barbell curl': 'kwG2ipFRgfo',
    'bicep curl': 'ykJmrZ5v0Oo',
    'dumbbell curl': 'ykJmrZ5v0Oo',
    'hammer curl': 'zC3nLlEvin4',
    'preacher curl': 'fIWP-FRFNU0',

    // TRICEPS
    'tricep pushdown': '2-LAMcpzODU',
    'cable pushdown': '2-LAMcpzODU',
    'skull crusher': 'd_KZxkY_0cM',
    'overhead tricep extension': '_gsUck-7M74',
    'close grip bench press': 'nEF0bv2FW94',
    'tricep dip': '6kALZikXxLc',

    // LEGS
    'squat': 'ultWZbUMPL8',
    'barbell squat': 'ultWZbUMPL8',
    'back squat': 'ultWZbUMPL8',
    'front squat': 'uYumuL_G_V0',
    'goblet squat': 'MeIiIdhvXT4',
    'leg press': 'IZxyjW7MPJQ',
    'lunge': 'QOVaHwm-Q6U',
    'walking lunge': 'L8fvypPrzzs',
    'bulgarian split squat': '2C-uNgKwPLE',
    'leg extension': 'YyvSfVjQeL0',
    'leg curl': '1Tq3QdYUuHs',
    'hamstring curl': '1Tq3QdYUuHs',
    'calf raise': 'gwLzBJYoWlI',
    'hip thrust': 'LM8XHLYJoYs',

    // CORE
    'plank': 'ASdvN_XEl_c',
    'crunch': 'Xyd_fa5zoEU',
    'sit up': 'jDwoBqPH0jk',
    'leg raise': 'JB2oyawG9KI',
    'hanging leg raise': 'Pr1ieGZ5atk',
    'russian twist': 'wkD8rjkodUI',
    'mountain climber': 'nmwgirgXLYM',

    // FULL BODY
    'burpee': 'auBLPXO8Fww',
    'kettlebell swing': 'YSxHifyI6s8',
  };

  static String? getVideoId(String exerciseName) {
    // Exact match only — fuzzy matching caused wrong demos for unrelated exercises
    return _videos[exerciseName.toLowerCase().trim()];
  }
}
