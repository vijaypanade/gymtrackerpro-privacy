// lib/widgets/home/coach_insight_block.dart
// RFC-HOME-004: Coach Insight — lightweight editorial annotation after Recovery.
// No container. No border. Typography and whitespace are the hierarchy.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../screens/ai_chat_screen.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';

// ── Data snapshot ─────────────────────────────────────────────────────────────
// Combined text = coachMessage.title + '\n' + coachMessage.subtitle.
// maxLines:2 in collapsed mode shows the headline and the first line of the
// one-sentence expansion — the "first two lines always visible" contract.

@immutable
class _InsightData {
  final String text;
  final bool   isCompleted;
  final bool   isRestDay;

  const _InsightData({
    required this.text,
    required this.isCompleted,
    required this.isRestDay,
  });

  String get ctaLabel {
    if (isCompleted) return 'Discuss today\'s session →';
    if (isRestDay)   return 'Ask about recovery →';
    return 'Continue with AI Coach →';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _InsightData) return false;
    return other.text        == text        &&
           other.isCompleted == isCompleted &&
           other.isRestDay   == isRestDay;
  }

  @override
  int get hashCode => Object.hash(text, isCompleted, isRestDay);
}

_InsightData _buildInsightData(AppProvider ap) {
  final msg  = ap.coachMessage;
  final plan = ap.todayPlan;
  return _InsightData(
    text:        '${msg.title}\n${msg.subtitle}',
    isCompleted: plan.isCompleted,
    isRestDay:   plan.isRestDay,
  );
}

// ── Seed context for AI chat ──────────────────────────────────────────────────
// Mirrors _AIVerdictCardState._buildSeedContext — opens the chat already
// briefed on today's training state so the first response is immediately useful.

String _buildSeedContext(AppProvider ap) {
  final recovery   = ap.getOverallRecovery();
  final readiness  = ap.weeklyReadinessScore;
  final trendDelta = ((readiness * 100 - recovery) * 0.14).round().clamp(-12, 12);
  final trend      = trendDelta > 2 ? 'Improving' : trendDelta < -2 ? 'Declining' : 'Stable';
  final readLabel  = readiness > 0.70 ? 'High' : readiness > 0.40 ? 'Moderate' : 'Low';
  final limiting   = ap.weakestMuscle.isNotEmpty
      ? '${ap.weakestMuscle[0].toUpperCase()}${ap.weakestMuscle.substring(1)}'
      : null;
  final trainFocus  = ap.topMuscleGroup.isNotEmpty ? ap.topMuscleGroup : null;
  final isCompleted = ap.todayPlan.isCompleted;

  if (isCompleted) {
    final planTitle   = ap.todayPlan.title;
    final session     = planTitle.isNotEmpty ? planTitle : (trainFocus ?? 'Today\'s session');
    final recoveryHrs = ((100 - recovery) * 0.28).toInt().clamp(4, 40);
    final buf = StringBuffer();
    buf.writeln('$session complete. Here is your recovery breakdown.');
    buf.writeln();
    buf.write('Recovery: $recovery%  ·  Readiness: $readLabel  ·  Trend: $trend');
    buf.write('\nRecovery window: ~${recoveryHrs}h');
    if (limiting != null) buf.write('\nMost fatigued: $limiting');
    buf.write('\nPrioritise sleep and protein intake to accelerate adaptation.');
    return buf.toString();
  }

  final insight = ap.coachInsight;
  final buf = StringBuffer();
  if (insight.title.isNotEmpty) {
    buf.writeln(insight.title);
    buf.writeln();
  }
  buf.write('Recovery: $recovery%  ·  Readiness: $readLabel  ·  Trend: $trend');
  if (limiting != null)   buf.write('\nLimiting Factor: $limiting');
  if (trainFocus != null) buf.write("\nToday's Focus: $trainFocus Training");
  return buf.toString();
}

// ── Public widget ─────────────────────────────────────────────────────────────

class CoachInsightBlock extends StatelessWidget {
  const CoachInsightBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _InsightData>(
      selector: (_, ap) => _buildInsightData(ap),
      builder:  (_, data, __) => RepaintBoundary(
        child: _InsightLayout(data: data),
      ),
    );
  }
}

// ── Layout ────────────────────────────────────────────────────────────────────

class _InsightLayout extends StatelessWidget {
  final _InsightData data;
  const _InsightLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 0.5, color: AppColors.borderSoft),
        const SizedBox(height: 14),
        // Eyebrow + CTA on same row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.record_voice_over_outlined,
              size: 14,
              color: AppColors.goldSoft,
            ),
            const SizedBox(width: 7),
            Text(
              'LiftOn Coach',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                final ap   = context.read<AppProvider>();
                final seed = _buildSeedContext(ap);
                Navigator.push(context, slideRoute(AIChatScreen(seedContext: seed)));
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  data.ctaLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.goldSoft,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Expandable insight — stateful, owns the typewriter
        _ExpandableInsight(data: data),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── Expandable insight ────────────────────────────────────────────────────────
// Owns the typewriter timer directly so the displayed characters survive
// expand/collapse toggles and Selector rebuilds with unchanged text.
// Restarts only when data.text actually changes.

class _ExpandableInsight extends StatefulWidget {
  final _InsightData data;
  const _ExpandableInsight({required this.data});

  @override
  State<_ExpandableInsight> createState() => _ExpandableInsightState();
}

class _ExpandableInsightState extends State<_ExpandableInsight> {
  bool   _expanded  = false;
  String _displayed = '';
  Timer? _timer;

  static const _style = TextStyle(
    fontFamily: 'Inter',
    fontSize:   14,
    fontWeight: FontWeight.w400,
    color:      AppColors.textSecondary,
    height:     1.5,
  );

  @override
  void initState() {
    super.initState();
    _startTyping(widget.data.text);
  }

  @override
  void didUpdateWidget(_ExpandableInsight old) {
    super.didUpdateWidget(old);
    // Restart only when the coaching message text itself changes.
    // Expand/collapse and unrelated Selector rebuilds are no-ops here.
    if (old.data.text != widget.data.text) {
      _timer?.cancel();
      setState(() { _displayed = ''; _expanded = false; });
      _startTyping(widget.data.text);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTyping(String text) {
    int idx = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) { t.cancel(); return; }
      if (idx >= text.length) { t.cancel(); return; }
      setState(() => _displayed = text.substring(0, ++idx));
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Measure whether the full text exceeds 4 lines at this width.
        final tp = TextPainter(
          text:      TextSpan(text: widget.data.text, style: _style),
          maxLines:  4,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        if (!tp.didExceedMaxLines) {
          // Fits in 4 lines — no collapse gesture needed.
          return Text(_displayed, style: _style);
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded ? _expandedContent() : _collapsedContent(),
          ),
        );
      },
    );
  }

  // Collapsed: first 4 lines, bottom fade via ShaderMask.
  Widget _collapsedContent() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin:  Alignment.topCenter,
        end:    Alignment.bottomCenter,
        stops:  [0.65, 1.0],
        colors: [Colors.white, Colors.transparent],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: Text(
        _displayed,
        style:    _style,
        maxLines: 4,
        overflow: TextOverflow.clip,
      ),
    );
  }

  // Expanded: full text, AnimatedSize handles the height transition.
  Widget _expandedContent() {
    return Text(_displayed, style: _style);
  }
}
