import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/exercise_data.dart';
import '../../data/exercise_videos.dart';
import '../../models/workout_log.dart';
import '../../providers/app_provider.dart';
import '../../services/exercise_video_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/exercise_icon_mapper.dart';
import '../../utils/haptics.dart';
import '../home/muscle_overlay_painter.dart';

// ════════════════════════════════════════════════
// EXERCISE DEMO BUTTON — opens YouTube player
// ════════════════════════════════════════════════
class ExerciseDemoButton extends StatelessWidget {
  final String exerciseName;
  const ExerciseDemoButton({super.key, required this.exerciseName});

  List<String> _findVideoIds() {
    for (final ex in ExerciseData.list) {
      if ((ex['name'] as String?)?.toLowerCase() ==
          exerciseName.toLowerCase()) {
        final ids = ex['youtubeIds'];
        if (ids is List && ids.isNotEmpty) {
          return ids.cast<String>();
        }
        final single = ex['youtubeId'];
        if (single is String && single.isNotEmpty) return [single];
      }
    }
    final fb = ExerciseVideos.getVideoId(exerciseName);
    return fb != null ? [fb] : [];
  }

  @override
  Widget build(BuildContext context) {
    final videoIds = _findVideoIds();
    if (videoIds.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: InkWell(
        onTap: () => _showDemo(context, videoIds),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.8),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.gold, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Watch Form Demo',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      )),
                  Text('Pro trainer video',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 8.5,
                      )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.55), size: 10),
          ]),
        ),
      ),
    );
  }

  void _showDemo(BuildContext context, List<String> videoIds) {
    final videoSet = ExerciseVideoService.find(exerciseName);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VideoPickerSheet(
        videoSet: videoSet,
        fallbackIds: videoIds,
        exerciseName: exerciseName,
      ),
    );
  }
}

class _VideoPickerSheet extends StatelessWidget {
  final ExerciseVideoSet? videoSet;
  final List<String> fallbackIds;
  final String exerciseName;

  const _VideoPickerSheet({
    required this.videoSet,
    required this.fallbackIds,
    required this.exerciseName,
  });

  void _open(BuildContext context, String videoId, String trainer, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _InAppPlayerScreen(
          videoId: videoId,
          trainer: trainer,
          title: title,
          exerciseName: exerciseName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCurated = videoSet != null && videoSet!.hasAny;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E0E0E), Color(0xFF050505)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFFD4AF37), width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFA8892C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.black, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FORM TUTORIAL',
                          style: GoogleFonts.rajdhani(
                            color: const Color(0xFFD4AF37),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          )),
                      Text(exerciseName,
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          )),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              if (hasCurated) ...[
                if (videoSet!.english != null)
                  _trainerCard(
                    context: context,
                    video: videoSet!.english!,
                    flag: '🌍',
                    badge: 'EN',
                    badgeColor: const Color(0xFFD4AF37),
                    isPremium: true,
                  ),
                if (videoSet!.hindi != null) ...[
                  const SizedBox(height: 10),
                  _trainerCard(
                    context: context,
                    video: videoSet!.hindi!,
                    flag: '🇮🇳',
                    badge: 'HI',
                    badgeColor: const Color(0xFFFF6B35),
                    isPremium: false,
                  ),
                ],
              ] else if (fallbackIds.isNotEmpty)
                _fallbackCard(context, fallbackIds.first)
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No video available',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      )),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trainerCard({
    required BuildContext context,
    required TrainerVideo video,
    required String flag,
    required String badge,
    required Color badgeColor,
    required bool isPremium,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _open(context, video.youtubeId, video.trainer, video.title);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.4),
            width: 1.4,
          ),
          boxShadow: isPremium
              ? [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(child: Text(flag, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(video.trainer,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(badge,
                        style: GoogleFonts.rajdhani(
                          color: badgeColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        )),
                  ),
                  if (isPremium) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.workspace_premium,
                        color: Color(0xFFD4AF37), size: 14),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                if (video.whySelected.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(video.whySelected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.play_circle_filled, color: Color(0xFFFF0000), size: 32),
        ]),
      ),
    );
  }

  Widget _fallbackCard(BuildContext context, String videoId) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _open(context, videoId, 'YouTube', exerciseName);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderMedium, width: 1.2),
        ),
        child: Row(children: [
          const Icon(Icons.play_circle_outline, color: Color(0xFFFF0000), size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Open on YouTube',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
          ),
          const Icon(Icons.open_in_new, color: Color(0xFFD4AF37), size: 20),
        ]),
      ),
    );
  }
}


class _InAppPlayerScreen extends StatefulWidget {
  final String videoId;
  final String trainer;
  final String title;
  final String exerciseName;

  const _InAppPlayerScreen({
    required this.videoId,
    required this.trainer,
    required this.title,
    required this.exerciseName,
  });

  @override
  State<_InAppPlayerScreen> createState() => _InAppPlayerScreenState();
}

class _InAppPlayerScreenState extends State<_InAppPlayerScreen> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _hasError = false;
  bool _videoVerified = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          // DON'T reveal WebView yet - verify first
          await Future.delayed(const Duration(milliseconds: 1200));
          try {
            final result = await _ctrl.runJavaScriptReturningResult(
              "document.body.innerText.includes('Video unavailable') || "
              "document.body.innerText.includes('Error') || "
              "document.body.innerText.includes('not available') || "
              "document.body.innerText.includes('configuration error')"
            );
            if (result.toString() == 'true') {
              if (mounted) setState(() {
                _hasError = true;
                _loading = false;
              });
              await Future.delayed(const Duration(milliseconds: 800));
              if (mounted) _openInYouTube();
            } else {
              // Video is OK - reveal WebView
              if (mounted) setState(() {
                _videoVerified = true;
                _loading = false;
              });
            }
          } catch (_) {
            if (mounted) setState(() {
              _videoVerified = true;
              _loading = false;
            });
          }
        },
        onWebResourceError: (err) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _loading = false;
            });
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) _openInYouTube();
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(
        'https://www.youtube.com/embed/${widget.videoId}?autoplay=1&playsinline=1&rel=0&modestbranding=1&fs=1',
      ));

    // Auto-fallback timer: if not loaded in 8 sec, suggest YouTube app
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _loading) {
        setState(() => _hasError = true);
      }
    });
  }

  Future<void> _openInYouTube() async {
    final vid = widget.videoId;
    final ytApp = Uri.parse('vnd.youtube:$vid');
    final ytWeb = Uri.parse('https://www.youtube.com/watch?v=$vid');
    if (await canLaunchUrl(ytApp)) {
      await launchUrl(ytApp, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(ytWeb, mode: LaunchMode.externalApplication);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Premium header
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF050505),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFD4AF37), width: 1),
                ),
              ),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FORM TUTORIAL',
                          style: GoogleFonts.rajdhani(
                            color: const Color(0xFFD4AF37),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          )),
                      Text(widget.exerciseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          )),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new,
                      color: Color(0xFFD4AF37)),
                  tooltip: 'Open in YouTube',
                  onPressed: _openInYouTube,
                ),
              ]),
            ),

            // Video area
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  // WebView is always rendered (needs to load) but only VISIBLE when verified
                  Visibility(
                    visible: _videoVerified,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: WebViewWidget(controller: _ctrl),
                  ),
                  // Premium loading overlay - shown until video verified or error
                  if (!_videoVerified)
                    Positioned.fill(
                      child: _hasError ? _buildErrorState() : _buildLoadingState(),
                    ),
                ],
              ),
            ),

            // Trainer info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0E0E0E),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1A1A1A), width: 1),
                ),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.fitness_center,
                        color: Color(0xFFD4AF37), size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.trainer,
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          )),
                      Text(widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ]),
            ),

            // Tips section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡 PRO TIPS',
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFD4AF37),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        )),
                    const SizedBox(height: 12),
                    _tipCard(
                      Icons.straighten,
                      'Form > Weight',
                      'Always prioritize proper form over heavier weights to avoid injury.',
                    ),
                    _tipCard(
                      Icons.timer_outlined,
                      'Tempo Control',
                      'Slow eccentric (lowering) phase = more muscle growth. 2-3 sec down, 1 sec up.',
                    ),
                    _tipCard(
                      Icons.bolt,
                      'Progressive Overload',
                      'Add weight or reps each week to keep growing. Track in the app.',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openInYouTube,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text('Watch in YouTube App',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              letterSpacing: 1,
                            )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                const CircularProgressIndicator(
                  color: Color(0xFFD4AF37),
                  strokeWidth: 2.5,
                ),
                const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFFD4AF37), size: 30),
              ],
            ),
            const SizedBox(height: 22),
            Text('LOADING IN HD',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFD4AF37),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                )),
            const SizedBox(height: 10),
            Text('Preparing premium stream...',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated streaming icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                const CircularProgressIndicator(
                  color: Color(0xFFD4AF37),
                  strokeWidth: 2.5,
                ),
                const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFFD4AF37), size: 30),
              ],
            ),
            const SizedBox(height: 22),
            Text('STREAMING IN HD',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFD4AF37),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                )),
            const SizedBox(height: 10),
            Text('Loading premium video...',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 10),
            Text('Switching to high quality stream',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  Widget _tipCard(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderMedium, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFD4AF37), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 2),
                Text(desc,
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ════════════════════════════════════════════════
// EXERCISE PREVIEW SHEET
// ════════════════════════════════════════════════
class ExercisePreviewSheet extends StatefulWidget {
  final Map<String, dynamic> ex;
  final int dayIdx;
  const ExercisePreviewSheet({super.key, required this.ex, required this.dayIdx});
  @override
  State<ExercisePreviewSheet> createState() => _ExercisePreviewSheetState();
}

class _ExercisePreviewSheetState extends State<ExercisePreviewSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _thumbError = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade  = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  // ── Derived metadata ─────────────────────────────────────────────────────
  String get _muscle    => widget.ex['muscle']    as String? ?? 'General';
  String get _equipment => widget.ex['equipment'] as String? ?? 'bodyweight';
  String get _movement  => widget.ex['movement']  as String? ?? 'isolation';
  String get _name      => widget.ex['name']      as String? ?? '';
  String get _emoji     => widget.ex['emoji']     as String? ?? '💪';
  String get _type      => widget.ex['type']      as String? ?? '';

  List<String> get _secondaryMuscles {
    const map = <String, List<String>>{
      'Chest':     ['Front Delts', 'Triceps'],
      'Back':      ['Biceps', 'Rear Delts'],
      'Legs':      ['Glutes', 'Core'],
      'Shoulders': ['Upper Traps', 'Triceps'],
      'Arms':      ['Forearms'],
      'Core':      ['Hip Flexors'],
    };
    return map[_muscle] ?? [];
  }

  String get _difficulty {
    if (_movement == 'compound' && (_equipment == 'barbell' || _equipment == 'olympic')) return 'Advanced';
    if (_movement == 'compound') return 'Intermediate';
    return 'Beginner';
  }

  Color get _diffColor {
    switch (_difficulty) {
      case 'Advanced':     return const Color(0xFFFF5C5C);
      case 'Intermediate': return const Color(0xFFFFAA33);
      default:             return const Color(0xFF4CAF50);
    }
  }

  List<String> get _cues {
    final m = _muscle;
    final eq = _equipment;
    if (m == 'Chest') return [
      'Retract scapulae and maintain arch — protect your rotator cuffs',
      'Lower the bar with control; touch sternum not neck',
      'Drive feet into floor and press bar in a slight arc',
    ];
    if (m == 'Back') return [
      'Initiate the pull with elbow drive, not biceps',
      'Keep chest tall and avoid rounding the lower back',
      'Full stretch at the bottom; full contraction at the top',
    ];
    if (m == 'Legs') return [
      'Brace core before descent — treat it like a plank',
      'Track knees over toes; don\'t let them cave inward',
      'Drive through the whole foot, not just the heel',
    ];
    if (m == 'Shoulders') return [
      'Press in a straight line overhead — not forward',
      'Keep ribs down; avoid excessive lumbar extension',
      'Slow the eccentric — shoulders are injury prone',
    ];
    if (m == 'Arms') return [
      eq == 'cable'
          ? 'Keep upper arm fixed; only the forearm moves'
          : 'Squeeze at peak contraction — 1-second pause',
      'Control the negative; don\'t let gravity do the work',
      'Full range of motion beats partial reps every time',
    ];
    if (m == 'Core') return [
      'Exhale on the exertion phase to engage deep core',
      'Neutral spine — don\'t pull on your neck',
      'Slow and controlled beats fast and sloppy',
    ];
    return [
      'Focus on the target muscle with each rep',
      'Control the eccentric phase (lower slowly)',
      'Breathe out on effort, breathe in on return',
    ];
  }

  String? get _videoId {
    final ids = widget.ex['youtubeIds'];
    if (ids is List && ids.isNotEmpty) return ids.first as String?;
    final single = widget.ex['youtubeId'];
    if (single is String && single.isNotEmpty) return single;
    return ExerciseVideos.getVideoId(_name);
  }

  List<String> get _commonMistakes => switch (_muscle) {
    'Chest'     => ['Flaring elbows too wide', 'Bouncing bar off chest', 'Not retracting scapulae'],
    'Back'      => ['Pulling with biceps, not elbows', 'Rounding lower back under load', 'Losing chest tall posture'],
    'Legs'      => ['Knee cave on the ascent', 'Quarter-rep depth', 'Forgetting to brace before descent'],
    'Shoulders' => ['Pressing forward instead of straight up', 'Excessive lumbar arch', 'Too heavy — form breaks early'],
    'Arms'      => ['Moving upper arm during curls', 'Partial range of motion only', 'Using momentum to swing the weight'],
    'Core'      => ['Pulling on neck with hands', 'Holding breath throughout set', 'Rushing and losing tension'],
    _           => ['Sacrificing form for heavier weight', 'Neglecting the eccentric phase', 'Skipping warm-up sets'],
  };

  String? get _alternativeExercise => const {
    'Chest':     'Dumbbell Fly',
    'Back':      'Seated Cable Row',
    'Legs':      'Romanian Deadlift',
    'Shoulders': 'Lateral Raise',
    'Arms':      'Hammer Curl',
    'Core':      'Hanging Leg Raise',
    'Cardio':    'Jump Rope',
  }[_muscle];

  String _fmtLog(WorkoutLog log, String unit) {
    if (unit == 'reps') return '${log.reps} reps';
    if (unit == 'min') return '${log.weight.toInt()} min';
    if (log.weight > 0 && log.reps > 0) {
      return '${log.weight.toStringAsFixed(1)} kg × ${log.reps}';
    }
    return '${log.weight.toStringAsFixed(1)} kg';
  }

  String _fmtBest(double weight, int reps, String unit) {
    if (unit == 'reps') return '$reps reps';
    if (unit == 'min') return '${weight.toInt()} min';
    if (weight > 0 && reps > 0) {
      return '${weight.toStringAsFixed(1)} kg × $reps';
    }
    return '${weight.toStringAsFixed(1)} kg';
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _addAndClose() {
    H.medium();
    final ex = widget.ex;
    context.read<AppProvider>().addExercise(widget.dayIdx,
      name:         ex['name']       as String? ?? '',
      category:     ex['muscle']     as String? ?? '',
      emoji:        ex['emoji']      as String? ?? '💪',
      type:         ex['type']       as String? ?? '',
      unit:         ex['unit']       as String?
          ?? (ex['bodyweight'] == true ? 'reps' : 'kg'),
      baseId:       '${ex["name"]}_${ex["type"] ?? ""}',
      isBodyweight: ex['bodyweight'] as bool? ?? false,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ $_name added!',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _openVideo() async {
    final id = _videoId;
    if (id == null) return;
    final ytApp = Uri.parse('vnd.youtube:$id');
    final ytWeb = Uri.parse('https://www.youtube.com/watch?v=$id');
    if (await canLaunchUrl(ytApp)) {
      await launchUrl(ytApp, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(ytWeb, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openYouTubeSearch() async {
    final query = Uri.encodeComponent('$_name exercise form tutorial');
    final ytApp = Uri.parse('vnd.youtube://results?search_query=$query');
    final ytWeb = Uri.parse('https://www.youtube.com/results?search_query=$query');
    if (await canLaunchUrl(ytApp)) {
      await launchUrl(ytApp, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(ytWeb, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFFD4AF37), width: 1.2)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 44, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 14),
                        _buildBodyMap(),
                        const SizedBox(height: 22),
                        _buildVideoThumb(),
                        const SizedBox(height: 22),
                        _buildMeta(),
                        const SizedBox(height: 22),
                        _buildCues(),
                        const SizedBox(height: 24),
                        _buildScienceBlock(),
                        const SizedBox(height: 22),
                        _buildMistakes(),
                        if (_alternativeExercise != null) ...[
                          const SizedBox(height: 14),
                          _buildAlternative(),
                        ],
                        const SizedBox(height: 28),
                        _buildAddButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Target Muscle Body Map — premium dual PNG view ───────────────────────
  Widget _buildBodyMap() {
    final frontPrimary   = _ExerciseMuscleMap.frontZonesFor(_muscle);
    final backPrimary    = _ExerciseMuscleMap.backZonesFor(_muscle);
    final frontSecondary = _ExerciseMuscleMap.frontSecondaryFor(_secondaryMuscles);
    final backSecondary  = _ExerciseMuscleMap.backSecondaryFor(_secondaryMuscles);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.5), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TARGET MUSCLES',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 10),
          // Dual body views — FRONT + BACK
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [
                AspectRatio(
                  aspectRatio: 7.0 / 12.0,
                  child: _ExerciseMuscleMap(
                    isFront:        true,
                    primaryZones:   frontPrimary,
                    secondaryZones: frontSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text('FRONT',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted.withValues(alpha: 0.45),
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    )),
              ])),
              Expanded(child: Column(children: [
                AspectRatio(
                  aspectRatio: 7.0 / 12.0,
                  child: _ExerciseMuscleMap(
                    isFront:        false,
                    primaryZones:   backPrimary,
                    secondaryZones: backSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text('BACK',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted.withValues(alpha: 0.45),
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    )),
              ])),
            ],
          ),
          const SizedBox(height: 14),
          // Legend
          _legendRow(AppColors.goldSoft, 'Primary', _muscle),
          ..._secondaryMuscles
              .map((s) => _legendRow(const Color(0xFFB8860B), 'Secondary', s)),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String role, String name) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$role  ',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w400)),
            TextSpan(
                text: name,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                )),
          ]),
        ),
      ),
    ]),
  );

  // ── Upgrade #5 — Exercise Science Block ───────────────────────────────────
  Widget _buildScienceBlock() {
    final isCompound   = _movement == 'compound';
    final isBarbell    = _equipment == 'barbell';
    final isMachine    = _equipment == 'machine';
    final isCable      = _equipment == 'cable';
    final isBodyweight = _equipment == 'bodyweight';
    final nm           = _name.toLowerCase();

    // Movement pattern label
    String pattern;
    if (_muscle == 'Back' ||
        (_muscle == 'Arms' && nm.contains('curl'))) {
      pattern = 'Pull';
    } else if (_muscle == 'Legs') {
      pattern = (nm.contains('deadlift') || nm.contains('rdl') ||
              nm.contains('hip thrust'))
          ? 'Hinge'
          : 'Squat';
    } else if (_muscle == 'Core') {
      pattern = 'Brace';
    } else {
      pattern = 'Push';
    }

    // Deterministic ratings (1–6)
    int stability = isMachine
        ? 1
        : (isCable ? 2 : (isBodyweight ? 4 : (isBarbell ? 5 : 3)));
    if (isCompound) stability = (stability + 1).clamp(1, 6);

    int strength = isCompound
        ? (isBarbell ? 6 : (isBodyweight ? 5 : 4))
        : 2;

    int hypertrophy = (isMachine || isCable) ? 5 : (isCompound ? 4 : 5);
    if (isBarbell && isCompound) hypertrophy = 5;

    int fatigue =
        isBarbell ? (isCompound ? 5 : 3) : (isCompound ? 4 : 2);
    if (isMachine) fatigue = (fatigue - 1).clamp(1, 6);

    Widget bar(String label, int value) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(children: [
        SizedBox(
          width: 88,
          child: Text(label,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              )),
        ),
        const SizedBox(width: 8),
        ...List.generate(6, (i) => Container(
          width: 16, height: 4,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: i < value
                ? AppColors.goldSoft.withValues(alpha: 0.78)
                : AppColors.bgCard,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: i < value
                  ? AppColors.goldSoft.withValues(alpha: 0.30)
                  : AppColors.borderSoft,
              width: 0.5,
            ),
          ),
        )),
        const SizedBox(width: 7),
        Text('$value',
            style: GoogleFonts.inter(
              color: AppColors.textMuted.withValues(alpha: 0.55),
              fontSize: 9,
              fontWeight: FontWeight.w400,
            )),
      ]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('EXERCISE SCIENCE',
              style: GoogleFonts.rajdhani(
                color: AppColors.goldSoft.withValues(alpha: 0.70),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.goldAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: AppColors.goldAmber.withValues(alpha: 0.25),
                  width: 0.6),
            ),
            child: Text(pattern,
                style: GoogleFonts.inter(
                  color: AppColors.goldSoft.withValues(alpha: 0.60),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                )),
          ),
        ]),
        const SizedBox(height: 12),
        bar('Stability',       stability),
        bar('Str. Carryover',  strength),
        bar('Hypertrophy',     hypertrophy),
        bar('Fatigue Cost',    fatigue),
      ],
    );
  }

  Widget _buildHeader() {
    final col = AppColors.categoryColors[_muscle] ?? AppColors.gold;
    return Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: col.withValues(alpha: 0.3), width: 1),
        ),
        child: Center(
          child: ExerciseIconMapper.icon(
            _muscle, size: 28, color: col, fallbackEmoji: _emoji,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_name,
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            Text(_type,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11,
                )),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _diffColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _diffColor.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Text(_difficulty,
            style: GoogleFonts.rajdhani(
              color: _diffColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            )),
      ),
    ]);
  }

  Widget _buildVideoThumb() {
    final id = _videoId;
    return GestureDetector(
      onTap: id != null ? _openVideo : _openYouTubeSearch,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (id != null && !_thumbError)
                Image.network(
                  'https://img.youtube.com/vi/$id/mqdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _thumbError = true);
                    });
                    return _fallbackThumb();
                  },
                )
              else
                _fallbackThumb(),

              // dark scrim
              Container(color: Colors.black.withValues(alpha: 0.35)),

              // play button
              if (id != null)
                Center(
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Color(0xFFD4AF37), size: 32),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.3),
                              width: 1.2),
                        ),
                        child: Icon(Icons.play_circle_outline_rounded,
                            color: const Color(0xFFD4AF37)
                                .withValues(alpha: 0.5),
                            size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text('Search on YouTube',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          )),
                      const SizedBox(height: 4),
                      Text('Tap to watch form tutorial',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                          )),
                    ],
                  ),
                ),

              // YouTube badge — always visible
              Positioned(
                bottom: 8, right: 10,
                child: Row(children: [
                  const Icon(Icons.open_in_new,
                      color: Color(0xFFD4AF37), size: 12),
                  const SizedBox(width: 4),
                  Text(id != null ? 'Open in YouTube' : 'Search on YouTube',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD4AF37),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      )),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackThumb() => Container(
    color: const Color(0xFF111111),
    child: Center(
      child: ExerciseIconMapper.icon(
        _muscle,
        size: 64,
        color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
        fallbackEmoji: _emoji,
      ),
    ),
  );

  Widget _buildMeta() {
    final p       = context.read<AppProvider>();
    final logKey  = p.getKey('${_name}_$_type');
    final unit    = widget.ex['unit'] as String?
        ?? (widget.ex['bodyweight'] == true ? 'reps' : 'kg');
    final bestWt  = p.getPR(logKey, unit);
    final bestRps = p.getPRReps(logKey);
    final logs    = p.logs
        .where((l) => l.exercise == logKey)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final lastLog = logs.isNotEmpty ? logs.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaRow(Icons.fitness_center_rounded, 'Primary', _muscle),
        if (_secondaryMuscles.isNotEmpty)
          _metaRow(Icons.sync_alt_rounded, 'Secondary',
              _secondaryMuscles.join(', ')),
        _metaRow(Icons.build_rounded, 'Equipment',
            _equipment.isNotEmpty
                ? '${_equipment[0].toUpperCase()}${_equipment.substring(1)}'
                : '—'),
        _metaRow(Icons.swap_vert_rounded, 'Movement',
            _movement == 'compound'
                ? 'Compound (multi-joint)'
                : 'Isolation (single-joint)'),
        if (lastLog != null)
          _metaRow(Icons.history_rounded, 'Last', _fmtLog(lastLog, unit)),
        if (bestWt > 0)
          _metaRow(Icons.emoji_events_rounded, 'Best',
              _fmtBest(bestWt, bestRps, unit)),
      ],
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFD4AF37), size: 15),
        ),
        const SizedBox(width: 10),
        Text('$label  ',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 12,
            )),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
    );
  }

  Widget _buildCues() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COACHING CUES',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFD4AF37),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            )),
        const SizedBox(height: 8),
        ...List.generate(_cues.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFD4AF37),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_cues[i],
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    )),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildMistakes() {
    final mistakes = _commonMistakes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COMMON MISTAKES',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFFF453A).withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            )),
        const SizedBox(height: 8),
        ...mistakes.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF9F0A), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(m,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    )),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildAlternative() {
    final alt = _alternativeExercise;
    if (alt == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.5), width: 0.7),
      ),
      child: Row(children: [
        const Icon(Icons.swap_horiz_rounded,
            color: AppColors.gold, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Try instead',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 10)),
              Text(alt,
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFF5D060)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _addAndClose,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text('ADD TO WORKOUT',
              style: GoogleFonts.rajdhani(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              )),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// BODY MAP PAINTER (Upgrade #4)
// Draws a minimal front-view human silhouette.
// Primary muscle = gold, secondary = amber, rest = dim.
// ════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════════════
// PREMIUM EXERCISE MUSCLE MAP
// PNG anatomical body + animated gold/amber glow — same asset system as
// the Recovery Scan heatmap. Replaces the old geometric _BodyPainter.
// ════════════════════════════════════════════════════════════════════════════

class _ExerciseMuscleMap extends StatefulWidget {
  final bool isFront;
  final Set<String> primaryZones;   // zone keys from frontZones / backZones
  final Set<String> secondaryZones;

  const _ExerciseMuscleMap({
    required this.isFront,
    required this.primaryZones,
    required this.secondaryZones,
  });

  // ── Zone mapping helpers ─────────────────────────────────────────────────

  static Set<String> frontZonesFor(String muscle) => switch (muscle.toLowerCase()) {
    'chest'     => {'chest'},
    'shoulders' => {'shoulders'},
    'arms'      => {'biceps'},
    'biceps'    => {'biceps'},
    'core'      => {'core'},
    'legs'      => {'legs'},
    _           => {},
  };

  static Set<String> backZonesFor(String muscle) => switch (muscle.toLowerCase()) {
    'back'      => {'back'},
    'arms'      => {'triceps'},
    'triceps'   => {'triceps'},
    'legs'      => {'legs', 'glutes'},
    'shoulders' => {'shoulders'},
    'calves'    => {'calves'},
    _           => {},
  };

  static Set<String> frontSecondaryFor(List<String> list) {
    final out = <String>{};
    for (final s in list) {
      switch (s.toLowerCase()) {
        case 'front delts': case 'shoulders': out.add('shoulders');
        case 'chest':                         out.add('chest');
        case 'biceps':                        out.add('biceps');
        case 'core': case 'abs': case 'hip flexors': out.add('core');
        case 'legs': case 'quads':            out.add('legs');
      }
    }
    return out;
  }

  static Set<String> backSecondaryFor(List<String> list) {
    final out = <String>{};
    for (final s in list) {
      switch (s.toLowerCase()) {
        case 'triceps':                          out.add('triceps');
        case 'back': case 'upper traps': case 'traps': out.add('back');
        case 'rear delts':                       out.add('shoulders');
        case 'glutes':                           out.add('glutes');
        case 'hamstrings': case 'legs':          out.add('legs');
        case 'calves':                           out.add('calves');
      }
    }
    return out;
  }

  @override
  State<_ExerciseMuscleMap> createState() => _ExerciseMuscleMapState();
}

class _ExerciseMuscleMapState extends State<_ExerciseMuscleMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.isFront
        ? 'assets/body/body_front.png'
        : 'assets/body/body_back.png';

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          CustomPaint(
            painter: _ExerciseGlowPainter(
              isFront:        widget.isFront,
              primaryZones:   widget.primaryZones,
              secondaryZones: widget.secondaryZones,
              breathAnim:     _anim.value,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gold/amber glow painter — same coordinate space as MuscleGlowPainter ──

class _ExerciseGlowPainter extends CustomPainter {
  final bool isFront;
  final Set<String> primaryZones;
  final Set<String> secondaryZones;
  final double breathAnim; // 0–1

  const _ExerciseGlowPainter({
    required this.isFront,
    required this.primaryZones,
    required this.secondaryZones,
    required this.breathAnim,
  });

  static const _gold  = Color(0xFFD4AF37);
  static const _amber = Color(0xFFB8860B);

  // Anatomical shape multipliers (matches MuscleGlowPainter)
  static const Map<String, (double, double)> _frontShapes = {
    'chest':     (1.20, 0.72),
    'shoulders': (0.88, 0.78),
    'biceps':    (0.68, 1.05),
    'core':      (1.00, 0.82),
    'legs':      (0.68, 0.88),
  };
  static const Map<String, (double, double)> _backShapes = {
    'back':      (1.10, 0.80),
    'shoulders': (0.88, 0.78),
    'triceps':   (0.68, 1.05),
    'glutes':    (0.95, 0.75),
    'legs':      (0.68, 0.88),
    'calves':    (0.56, 0.80),
  };

  // With BoxFit.contain, PNG (ratio 2/3) inside AspectRatio(7/12) container
  // gets 6.25% letterbox top/bottom. The zone coords were tuned for the home
  // screen's 380dp-tall body. In this smaller container the image sits higher,
  // so subtract _kYUp to shift all glows upward to match anatomy.
  static const double _kYUp = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width  / 100.0;
    final sy = size.height / 175.0;

    final zones  = isFront ? frontZones : backZones;
    final shapes = isFront ? _frontShapes : _backShapes;

    for (final zone in zones) {
      final isPrimary   = primaryZones.contains(zone.key);
      final isSecondary = !isPrimary && secondaryZones.contains(zone.key);
      if (!isPrimary && !isSecondary) continue;

      final baseColor = isPrimary ? _gold : _amber;
      final pulse = isPrimary
          ? 0.80 + breathAnim * 0.20
          : 0.60 + breathAnim * 0.12;
      final (wm, hm) = shapes[zone.key] ?? (1.0, 1.0);

      final yShift = zone.key == 'calves' ? _kYUp - 16.0 : _kYUp;
      for (final r in zone.rects) {
        final px = Rect.fromLTWH(
          r.left * sx, (r.top - yShift) * sy,
          r.width * sx, r.height * sy,
        );
        final cx = px.center.dx;
        final cy = px.center.dy;
        final rw = px.width  * wm * 0.70;
        final rh = px.height * hm * 0.70;

        // Layer 1 — wide atmospheric haze
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: rw * 2.2, height: rh * 2.2),
          Paint()
            ..style = PaintingStyle.fill
            ..color = baseColor.withValues(alpha: 0.10 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
        // Layer 2 — mid bloom
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: rw * 1.5, height: rh * 1.5),
          Paint()
            ..style = PaintingStyle.fill
            ..color = baseColor.withValues(alpha: 0.28 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Layer 3 — tight surface
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: rw, height: rh),
          Paint()
            ..style = PaintingStyle.fill
            ..color = baseColor.withValues(alpha: 0.55 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        // Layer 4 — hot centre (primary only)
        if (isPrimary) {
          final hotColor = Color.lerp(baseColor, const Color(0xFFFFE08C), breathAnim * 0.38)!;
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy), width: rw * 0.45, height: rh * 0.45),
            Paint()
              ..style = PaintingStyle.fill
              ..color = hotColor.withValues(alpha: 0.82 * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ExerciseGlowPainter old) =>
      old.primaryZones   != primaryZones   ||
      old.secondaryZones != secondaryZones ||
      old.breathAnim     != breathAnim     ||
      old.isFront        != isFront;
}
