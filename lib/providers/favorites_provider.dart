import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages user's favorite exercises.
/// Stores in Firestore: users/{uid}/favorites/list
class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};
  bool _loading = false;

  Set<String> get favoriteIds => _favoriteIds;
  List<String> get favoritesList => _favoriteIds.toList();
  int get count => _favoriteIds.length;
  bool get isLoading => _loading;

  bool isFavorite(String exerciseId) => _favoriteIds.contains(exerciseId);

  /// Load favorites from Firestore on app start
  Future<void> loadFavorites() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return; // Firebase not initialized yet
    }
    if (user == null) return;

    _loading = true;

    try {
      // Timeout guards splash navigation — this get() is awaited in the boot
      // Future.wait, so an unbounded server wait would hold the logo screen.
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc('list')
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final ids = List<String>.from(doc.data()!['exerciseIds'] ?? []);
        _favoriteIds
          ..clear()
          ..addAll(ids);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load favorites: $e');
    }

    _loading = false;
    notifyListeners();
  }

  /// Toggle favorite (add if missing, remove if present)
  Future<void> toggle(String exerciseId) async {
    if (_favoriteIds.contains(exerciseId)) {
      _favoriteIds.remove(exerciseId);
    } else {
      _favoriteIds.add(exerciseId);
    }
    notifyListeners();
    await _syncToFirestore();
  }

  /// Add to favorites
  Future<void> add(String exerciseId) async {
    if (_favoriteIds.add(exerciseId)) {
      notifyListeners();
      await _syncToFirestore();
    }
  }

  /// Remove from favorites
  Future<void> remove(String exerciseId) async {
    if (_favoriteIds.remove(exerciseId)) {
      notifyListeners();
      await _syncToFirestore();
    }
  }

  /// Clear all
  Future<void> clearAll() async {
    _favoriteIds.clear();
    notifyListeners();
    await _syncToFirestore();
  }

  /// Save to Firestore
  Future<void> _syncToFirestore() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return;
    }
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc('list')
          .set({
        'exerciseIds': _favoriteIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Failed to sync favorites: $e');
    }
  }
}
