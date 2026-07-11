import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/rest_timer_service.dart';
import '../utils/app_constants.dart';

// ── Compact top banner (inline — sits above day strip, no floating) ──────────
class RestTimerBanner extends StatefulWidget {
  const RestTimerBanner({super.key});
  @override
  State<RestTimerBanner> createState() => _RestTimerBannerState();
}

class _RestTimerBannerState extends State<RestTimerBanner> {
  final _timer = RestTimerService();

  @override
  void initState() { super.initState(); _timer.addListener(_rebuild); }
  @override
  void dispose()   { _timer.removeListener(_rebuild); super.dispose(); }
  void _rebuild()  { if (mounted) setState(() {}); }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_timer.active) return const SizedBox.shrink();

    final remaining = _timer.remaining;
    final progress  = _timer.progress;
    final urgent    = remaining <= 10;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent
              ? AppColors.gold.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.07),
          width: 0.8,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Progress bar — thin top line
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(
              urgent
                  ? AppColors.gold
                  : AppColors.gold.withValues(alpha: 0.55),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(children: [
            // Icon
            Icon(
              urgent ? Icons.flash_on_rounded : Icons.timer_outlined,
              color: AppColors.gold.withValues(alpha: 0.85),
              size: 15,
            ),
            const SizedBox(width: 8),
            // Label
            Text(
              'REST',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            // Countdown
            Text(
              _fmt(remaining),
              style: GoogleFonts.rajdhani(
                color: urgent ? AppColors.gold : AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            // Next exercise name
            if (_timer.nextName != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '→ ${_timer.nextName!}',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            // +30s — visuals unchanged; outer padding grows the hit area
            // to ~44px for sweaty mid-workout thumbs.
            GestureDetector(
              onTap: () => _timer.addTime(30),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+30s',
                    style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            // Skip — same treatment; this is tapped after every set.
            GestureDetector(
              onTap: () => _timer.skip(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                child: Text(
                  'Skip',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Legacy floating overlay (kept for any other screen that uses it) ─────────
/// Floating bottom rest timer that appears during rest periods
class RestTimerOverlay extends StatefulWidget {
  const RestTimerOverlay({super.key});

  @override
  State<RestTimerOverlay> createState() => _RestTimerOverlayState();
}

class _RestTimerOverlayState extends State<RestTimerOverlay> {
  final _timer = RestTimerService();

  @override
  void initState() {
    super.initState();
    _timer.addListener(_onChange);
  }

  @override
  void dispose() {
    _timer.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _timer,
      builder: (context, _) => _buildContent(),
    );
  }

  Widget _buildContent() {
    if (!_timer.active) return const SizedBox.shrink();
    return _buildTimer();
  }

  String _format(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildTimer() {
    final remaining = _timer.remaining;
    final progress = _timer.progress;

    final kb = MediaQuery.of(context).viewInsets.bottom;

    return Positioned(
      left: AppSpacing.sm,
      right: AppSpacing.sm,
      top: kb > 0 ? 180 : null,
      bottom: kb > 0 ? null : 82,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101010), Color(0xFF171717)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 1.2,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(
                  AppColors.gold.withValues(alpha: 0.65),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
              child: Row(
                children: [
                  // Timer icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      remaining <= 5
                          ? Icons.flash_on_rounded
                          : Icons.timer_outlined,
                      color: AppColors.gold.withValues(alpha: 0.9),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REST TIMER',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                        Text(
                          _format(remaining),
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // +30 sec button
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _timer.addTime(30),
                      icon: const Icon(
                        Icons.add_rounded,
                        color: AppColors.gold,
                        size: 18,
                      ),
                      tooltip: 'Add 30 sec',
                    ),
                  ),

                  // Skip button
                  TextButton(
                    onPressed: () => _timer.skip(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Up Next ─────────────────────────────────
            if (_timer.nextName != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 0.5),
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.textMuted, size: 11),
                  const SizedBox(width: 6),
                  Text('NEXT',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 9, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _timer.nextName!,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
                  if (_timer.nextContext != null)
                    Text(_timer.nextContext!,
                      style: GoogleFonts.rajdhani(
                        color: AppColors.gold.withValues(alpha: 0.75),
                        fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],

          ],
        ),
      ),
    );
  }
}
