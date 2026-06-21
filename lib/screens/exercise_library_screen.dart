import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/exercise_data.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_constants.dart';
import '../utils/exercise_icon_mapper.dart';
import '../widgets/planner/planner_video_widgets.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _search = '';
  String _filter = 'All';

  List<String> get _filterChips => const [
        'All', 'Favorites', 'Chest', 'Back', 'Legs',
        'Shoulders', 'Arms', 'Core', 'Cardio',
      ];

  List<Map<String, dynamic>> get _filteredExercises {
    final favs = context.read<FavoritesProvider>().favoriteIds;
    var list = ExerciseData.list;

    // Filter by muscle/favorites
    if (_filter == 'Favorites') {
      list = list.where((e) => favs.contains(e['id'])).toList();
    } else if (_filter != 'All') {
      list = list.where((e) =>
          (e['muscle'] ?? '').toString().toLowerCase() == _filter.toLowerCase()
      ).toList();
    }

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
          (e['name'] ?? '').toString().toLowerCase().contains(q) ||
          (e['muscle'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090909),
        elevation: 0,
        title: Text(
          'Exercise Library',
          style: GoogleFonts.rajdhani(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: Column(
        children: [
          // ── Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.inter(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search exercises...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // ── Filter Chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: _filterChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final chip = _filterChips[i];
                final selected = _filter == chip;
                return GestureDetector(
                  onTap: () => setState(() => _filter = chip),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFD4AF37)
                          : const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFC69C2D)
                            : Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Center(
                      child: chip == 'Favorites'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selected
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 13,
                                  color: selected
                                      ? Colors.black
                                      : AppColors.textPrimary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  chip,
                                  style: GoogleFonts.rajdhani(
                                    color: selected
                                        ? Colors.black
                                        : AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              chip,
                              style: GoogleFonts.rajdhani(
                                color: selected
                                    ? Colors.black
                                    : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // ── Exercise List
          Expanded(
            child: Consumer<FavoritesProvider>(
              builder: (_, favProvider, __) {
                final exercises = _filteredExercises;
                if (exercises.isEmpty) {
                  return _buildEmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 34),
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _ExerciseCard(
                    exercise: exercises[i],
                    isFavorite: favProvider.isFavorite(exercises[i]['id']),
                    onFavoriteTap: () => favProvider.toggle(exercises[i]['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFav = _filter == 'Favorites';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFav ? Icons.favorite_border : Icons.fitness_center,
              color: AppColors.goldMuted,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isFav ? 'No favorites yet' : 'No exercises found',
              style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFav
                  ? 'Tap the heart on any exercise to save it here'
                  : 'Try a different search or filter',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  const _ExerciseCard({
    required this.exercise,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF121212),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.055),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // SVG icon tile — muscle group tinted
            ExerciseIconBox(
              muscle: (exercise['muscle'] ?? 'general').toString().toLowerCase(),
              color: AppColors.categoryColors[
                      (exercise['muscle'] ?? '').toString()] ??
                  AppColors.gold,
              boxSize: 44,
              iconSize: 21,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 14),

            // Name + muscle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (exercise['name'] ?? '').toString(),
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Tag(text: (exercise['muscle'] ?? '').toString()),
                      const SizedBox(width: 6),
                      _Tag(text: (exercise['equipment'] ?? '').toString()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ExerciseDemoButton(
                    exerciseName: (exercise['name'] ?? '').toString(),
                  ),
                ],
              ),
            ),

            // Favorite button
            GestureDetector(
              onTap: onFavoriteTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFavorite
                      ? AppColors.goldGlow
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? AppColors.gold : AppColors.textMuted,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AppColors.gold.withValues(alpha: 0.78),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
