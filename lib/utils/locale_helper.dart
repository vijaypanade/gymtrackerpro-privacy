// lib/utils/locale_helper.dart
// Detects country and preferred weight unit from device locale.
// No external packages — uses Flutter's built-in platformDispatcher.

import 'package:flutter/widgets.dart';

class LocaleHelper {
  LocaleHelper._();

  /// 2-letter ISO country code from device locale ('US', 'IN', 'GB', etc.)
  static String get countryCode {
    try {
      return WidgetsBinding
              .instance.platformDispatcher.locale.countryCode
              ?.toUpperCase() ??
          'IN';
    } catch (_) {
      return 'IN';
    }
  }

  /// Full country name for AI prompts and profile display.
  static String get countryName => _nameFromCode(countryCode);

  /// 'lbs' only for the United States. All other countries default to 'kg'.
  static String get defaultWeightUnit =>
      countryCode == 'US' ? 'lbs' : 'kg';

  /// BCP-47 locale string for TTS — maps country to the right English accent.
  static String get ttsLocale => const {
        'IN': 'en-IN',
        'US': 'en-US',
        'GB': 'en-GB',
        'AU': 'en-AU',
        'NZ': 'en-NZ',
        'IE': 'en-IE',
        'SG': 'en-SG',
        'ZA': 'en-ZA',
        'CA': 'en-CA',
      }[countryCode] ??
      'en-US';

  /// Default cuisine preference based on country code.
  static String get defaultCuisine => _cuisineFromCode(countryCode);

  static String _nameFromCode(String code) => const {
        'IN': 'India',
        'US': 'United States',
        'CA': 'Canada',
        'GB': 'United Kingdom',
        'AU': 'Australia',
        'NZ': 'New Zealand',
        'IE': 'Ireland',
        'SG': 'Singapore',
        'AE': 'United Arab Emirates',
        'ZA': 'South Africa',
        'DE': 'Germany',
        'FR': 'France',
        'IT': 'Italy',
        'ES': 'Spain',
        'PT': 'Portugal',
        'NL': 'Netherlands',
        'BE': 'Belgium',
        'CH': 'Switzerland',
        'AT': 'Austria',
        'SE': 'Sweden',
        'NO': 'Norway',
        'DK': 'Denmark',
        'FI': 'Finland',
        'PL': 'Poland',
        'MY': 'Malaysia',
        'PH': 'Philippines',
        'TH': 'Thailand',
        'ID': 'Indonesia',
        'PK': 'Pakistan',
        'BD': 'Bangladesh',
        'LK': 'Sri Lanka',
        'NP': 'Nepal',
        'NG': 'Nigeria',
        'KE': 'Kenya',
        'GH': 'Ghana',
        'JP': 'Japan',
        'KR': 'South Korea',
        'CN': 'China',
        'BR': 'Brazil',
        'MX': 'Mexico',
        'AR': 'Argentina',
        'SA': 'Saudi Arabia',
        'QA': 'Qatar',
        'KW': 'Kuwait',
        'BH': 'Bahrain',
        'OM': 'Oman',
      }[code] ??
      code;

  static String _cuisineFromCode(String code) => const {
        'IN': 'indian',
        'US': 'american',
        'CA': 'american',
        'GB': 'british',
        'AU': 'no_preference',
        'NZ': 'no_preference',
        'IE': 'british',
        'SG': 'southeast_asian',
        'AE': 'middle_eastern',
        'ZA': 'no_preference',
        'MY': 'southeast_asian',
        'PH': 'southeast_asian',
        'TH': 'east_asian',
        'ID': 'southeast_asian',
        'JP': 'east_asian',
        'KR': 'east_asian',
        'CN': 'east_asian',
        'MX': 'mexican',
        'SA': 'middle_eastern',
        'QA': 'middle_eastern',
        'KW': 'middle_eastern',
        'DE': 'mediterranean',
        'FR': 'mediterranean',
        'IT': 'mediterranean',
        'ES': 'mediterranean',
        'GR': 'mediterranean',
      }[code] ??
      'no_preference';
}

/// Global cuisine options — used in onboarding and profile.
const kCuisineOptions = <String, String>{
  'no_preference': 'No Preference',
  'indian':        'Indian',
  'american':      'American',
  'british':       'British',
  'mediterranean': 'Mediterranean',
  'east_asian':    'East Asian',
  'southeast_asian': 'Southeast Asian',
  'middle_eastern': 'Middle Eastern',
  'mexican':       'Mexican',
  'vegetarian':    'Vegetarian (Any)',
  'vegan':         'Vegan',
  'high_protein':  'High Protein',
};

/// Migrate legacy Indian cuisine values to the global schema.
String migrateCuisinePreference(String old) => switch (old) {
      'maharashtrian' => 'indian',
      'north_indian'  => 'indian',
      'south_indian'  => 'indian',
      'mixed'         => 'no_preference',
      _               => old, // already valid or a new value
    };
