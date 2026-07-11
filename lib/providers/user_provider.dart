// lib/providers/user_provider.dart
//
// RESPONSIBILITY:
//   - User profile (name, weight, height, age, gender, goal, level, trainer style)
//   - Daily water tracking (goal + current intake, auto-resets daily)
//   - Today's mood
//   - Body measurements history
//   - Favorite exercises
//   - Onboarding completion flag
//
// NOT RESPONSIBLE FOR:
//   - Workout plans, logs, streak (WorkoutProvider)
//   - Analytics or AI insights (AnalyticsProvider / AIProvider)
//   - Premium state (MonetizationService)
//
// PERSISTENCE: SharedPreferences via StorageService.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile           _profile      = UserProfile();
  MoodType              _todayMood    = MoodType.normal;
  List<BodyMeasurement> _measurements = [];
  Set<String>           _favorites    = {};
  bool                  _loaded       = false;

  // ── Public state ─────────────────────────────────────────
  bool get isLoaded => _loaded;
  UserProfile get profile => _profile;
  MoodType get todayMood => _todayMood;
  List<BodyMeasurement> get measurements => List.unmodifiable(_measurements);
  Set<String> get favorites => Set.unmodifiable(_favorites);

  // Convenience getters — mirror old AppProvider surface so UI screens that
  // read `appProvider.goal`, `appProvider.weightKg` etc. can be migrated
  // by simply swapping the provider reference.
  String get name           => _profile.name;
  String get goal           => _profile.goal;
  String get level          => _profile.level;
  String get trainerType    => _profile.trainerType;
  String get fitnessGoal    => _profile.goal;
  String get fitnessLevel   => _profile.level;
  String get gender         => _profile.gender;
  String get activityLevel  => _profile.activityLevel;
  double get weightKg       => _profile.weightKg;
  double get heightCm       => _profile.heightCm;
  int    get age            => _profile.age;

  // ═════════════════════════════════════════════════════════
  // INIT / LOAD
  // ═════════════════════════════════════════════════════════
  Future<void> load() async {
    if (_loaded) return;
    try {
      final storage = StorageService.instance;

      // Profile
      final loadedProfile = await storage.loadObject<UserProfile>(
        StorageKeys.profile,
        UserProfile.fromJson,
      );
      if (loadedProfile != null) _profile = loadedProfile;

      // Measurements
      _measurements = await storage.loadList<BodyMeasurement>(
        StorageKeys.measurements,
        BodyMeasurement.fromJson,
      );

      // Favorites — stored as JSON array of strings
      final favRaw = await storage.getString(StorageKeys.favorites);
      if (favRaw != null) {
        try {
          final decoded = jsonDecode(favRaw);
          if (decoded is List) {
            _favorites = decoded.whereType<String>().toSet();
          }
        } catch (e) {
          debugPrint('UserProvider favorites decode error: $e');
        }
      }

      // Mood
      final moodStr = await storage.getString(StorageKeys.mood) ?? 'normal';
      _todayMood = MoodType.values.firstWhere(
        (m) => m.name == moodStr,
        orElse: () => MoodType.normal,
      );

    } catch (e, s) {
      debugPrint('UserProvider.load error: $e\n$s');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  // ═════════════════════════════════════════════════════════
  // PROFILE
  // ═════════════════════════════════════════════════════════
  Future<void> updateProfile(UserProfile updated) async {
    _profile = updated;
    notifyListeners();
    await _saveProfile();
  }

  // ═════════════════════════════════════════════════════════
  // MOOD
  // ═════════════════════════════════════════════════════════
  Future<void> setMood(MoodType mood) async {
    if (_todayMood == mood) return;
    _todayMood = mood;
    notifyListeners();
    await StorageService.instance.setString(StorageKeys.mood, mood.name);
  }

  // ═════════════════════════════════════════════════════════
  // FAVORITES
  // ═════════════════════════════════════════════════════════
  bool isFavorite(String name) => _favorites.contains(name);

  Future<void> toggleFavorite(String name) async {
    if (name.isEmpty) return;
    if (_favorites.contains(name)) {
      _favorites.remove(name);
    } else {
      _favorites.add(name);
    }
    notifyListeners();
    await StorageService.instance
        .setJson(StorageKeys.favorites, _favorites.toList());
  }

  // ═════════════════════════════════════════════════════════
  // BODY MEASUREMENTS
  // ═════════════════════════════════════════════════════════
  Future<void> addMeasurement(BodyMeasurement m) async {
    _measurements.insert(0, m);
    notifyListeners();
    await _saveMeasurements();
  }

  Future<void> deleteMeasurement(String id) async {
    final before = _measurements.length;
    _measurements.removeWhere((m) => m.id == id);
    if (_measurements.length != before) {
      notifyListeners();
      await _saveMeasurements();
    }
  }

  // ═════════════════════════════════════════════════════════
  // ONBOARDING
  // ═════════════════════════════════════════════════════════
  Future<void> completeOnboarding() async {
    await StorageService.instance.setBool(StorageKeys.onboardingDone, true);
  }

  Future<bool> isOnboardingComplete() async {
    return (await StorageService.instance.getBool(StorageKeys.onboardingDone))
        ?? false;
  }

  // ═════════════════════════════════════════════════════════
  // RESET
  // ═════════════════════════════════════════════════════════
  Future<void> resetToDefaults() async {
    _profile      = UserProfile();
    _todayMood    = MoodType.normal;
    _measurements = [];
    _favorites    = {};
    notifyListeners();
    await _saveProfile();
    await _saveMeasurements();
    await StorageService.instance
        .setJson(StorageKeys.favorites, <String>[]);
  }

  // ═════════════════════════════════════════════════════════
  // PERSISTENCE HELPERS
  // ═════════════════════════════════════════════════════════
  Future<void> _saveProfile() async {
    await StorageService.instance
        .setJson(StorageKeys.profile, _profile.toJson());

    // ── Firestore backup (cloud sync) ──
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
              'profile': _profile.toJson(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Firestore profile save failed: \$e');
      // Silent fail - local save already done
    }
  }

  /// Fetch profile from Firestore on login.
  /// Returns true if cloud profile was found and applied.
  Future<bool> tryRestoreFromCloud() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null || data['profile'] == null) return false;

      final cloudProfile = UserProfile.fromJson(
          Map<String, dynamic>.from(data['profile'] as Map));
      _profile = cloudProfile;

      // Save locally too
      await StorageService.instance
          .setJson(StorageKeys.profile, _profile.toJson());
      await StorageService.instance
          .setBool(StorageKeys.onboardingDone, true);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Firestore profile restore failed: \$e');
      return false;
    }
  }

  Future<void> _saveMeasurements() async {
    await StorageService.instance.setJson(
      StorageKeys.measurements,
      _measurements.map((m) => m.toJson()).toList(),
    );
  }

}
