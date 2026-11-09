// ============================================================================
//  តាមដាន — ៣ ជំហាននៃដំណើរការឥណទាន (animated stepper)
// ============================================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../loan_module.dart';
import '../main.dart';
import 'loan_processing_card.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

enum _K { done, active, pending, failed }

class _Step {
  final String title, subtitle, chip;
  final IconData icon;
  final _K state;
  const _Step(this.title, this.subtitle, this.chip, this.icon, this.state);
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  List<LoanRecord> _loans = const [];
  bool _loading = true;
  Timer? _timer;

  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800))
    ..repeat();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700))
    ..repeat();
  late final AnimationController _flow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1900))
    ..repeat();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
        const Duration(seconds: 25), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spin.dispose();
    _pulse.dispose();
    _flow.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    List<LoanRecord> loans = const [];
    try {
      final raw = await ApiService.getLoans();
      loans = raw
          .whereType<Map>()
          .map((e) => LoanRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loans = loans;
      _loading = false;
    });
  }

  LoanRecord? get _lead {
    for (final l in _loans) {
      if (l.status == 'submitted' ||
          l.status == 'under_review' ||
          l.status == 'approved' ||
          l.status == 'disbursed' ||
          l.status == 'active') {
        return l;
      }
    }
    return _loans.isEmpty ? null : _loans.first;
  }

  List<_Step> _steps(LoanRecord l) {
    final rejected = l.status == 'rejected';
    final reviewed = rejected || l.stage >= 2;
    final received = l.stage >= 3;
    return [
      const _Step('ពាក្យស្នើសុំ',
          'បានដាក់ស្នើរ · KYC និងព័ត៌មានកម្ចី', 'រួចរាល់',
          Icons.description_rounded, _K.done),
      _Step(
          'ពិនិត្យ និងវាយតម្លៃ',
          rejected
              ? 'សំណើរត្រូវបានវាយតម្លៃរួចរាល់'
              : reviewed
                  ? 'បានឆ្លងកាត់ការវាយតម្លៃ'
                  : 'មន្ត្រីឥណទានកំពុងពិនិត្យពិន្ទុឥណទាន',
          reviewed ? 'រួចរាល់' : 'កំពុងដំណើរការ',
          Icons.fact_check_rounded,
          reviewed ? _K.done : _K.active),
      rejected
          ? const _Step(
              'បរាជ័យ',
              'លោកអ្នកមិនទាន់មានលក្ខណៈគ្រប់គ្រាន់សម្រាប់ទទួលកម្ចីនេះទេ',
              'មិនជោគជ័យ',
              Icons.close_rounded,
              _K.failed)
          : _Step(
              'ជោគជ័យទទួលបានប្រាក់',
              received
                  ? 'ប្រាក់បានចូលគណនីរបស់អ្នក'
                  : 'រង់ចាំការបញ្ចេញប្រាក់ចូលគណនី',
              received ? 'ជោគជ័យ' : 'រង់ចាំ',
              Icons.savings_rounded,
              received ? _K.done : _K.active),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lead = _lead;
    if (_loading && _loans.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('តាមដាន')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('តាមដាន')),
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        color: C.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: lead == null
              ? [_empty(context)]
              : [
                  StaggeredItem(index: 0, child: _head(context, lead)),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    child: Column(
                      key: ValueKey(lead.status),
                      children: _timeline(context, _steps(lead)),
                    ),
                  ),
                  if (lead.status == 'rejected' ||
                      lead.status == 'closed') ...[
                    const SizedBox(height: 26),
                    NeuButton(
                        label: 'ដាក់ពាក្យស្នើរម្ដងទៀត',
                        icon: Icons.add_circle_outline_rounded,
                        onPressed: () =>
                            push(context, const LoanModuleScreen())),
                  ],
                ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  HEADER
  // --------------------------------------------------------------------------
  Widget _head(BuildContext context, LoanRecord l) => Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AuraGrad.soft,
                border: Border.all(color: context.border)),
            child: const Icon(Icons.track_changes_rounded,
                color: C.accent, size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('ឥណទាន #${l.id}',
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${money(l.principal)} · ${l.months} ខែ',
                  style: TextStyle(color: context.muted, fontSize: 11.5)),
            ])),
        loanStatusChip(context, l.status),
      ]);

  // --------------------------------------------------------------------------
  //  TIMELINE — ៣ ជំហាន
  // --------------------------------------------------------------------------
  List<Widget> _timeline(BuildContext context, List<_Step> steps) {
    final out = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      out.add(StaggeredItem(index: i + 1, child: _card(context, i, steps[i])));
      if (i < steps.length - 1) {
        out.add(_connector(context, steps[i]));
      }
    }
    return out;
  }

  Color _stateColor(BuildContext context, _K s) => switch (s) {
        _K.done => C.accentGreen,
        _K.active => C.accent,
        _K.failed => C.accentRed,
        _K.pending => context.muted,
      };

  Widget _card(BuildContext context, int i, _Step s) {
    final success = s.state == _K.done && i == 2;
    final color = success ? C.accentGold : _stateColor(context, s.state);
    final active = s.state == _K.active;
    final pending = s.state == _K.pending;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active || success ? null : context.card,
        gradient: active || success
            ? LinearGradient(
                colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: pending ? context.border : color.withValues(alpha: 0.32)),
        boxShadow: active
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.16),
                    blurRadius: 22,
                    spreadRadius: -6)
              ]
            : null,
      ),
      child: Stack(children: [
        if (active)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedBuilder(
                  animation: _flow,
                  builder: (_, __) =>
                      CustomPaint(painter: _SweepPainter(_flow.value, color)),
                ),
              ),
            ),
          ),
        Row(children: [
          _orb(context, i, s, color, success),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(s.title,
                            style: TextStyle(
                                color: pending ? context.muted : context.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800))),
                    const SizedBox(width: 8),
                    _chip(context, s, color, success),
                  ]),
                  const SizedBox(height: 4),
                  Text(s.subtitle,
                      style: TextStyle(
                          color: context.muted, fontSize: 11.5, height: 1.45)),
                ]),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(BuildContext context, _Step s, Color color, bool success) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(20)),
        child: Text(s.chip,
            style: TextStyle(
                color: success ? C.accentGold : color,
                fontSize: 9,
                fontWeight: FontWeight.w800)),
      );

  // --------------------------------------------------------------------------
  //  ORB — icon + animations
  // --------------------------------------------------------------------------
  Widget _orb(
      BuildContext context, int i, _Step s, Color color, bool success) {
    final active = s.state == _K.active;
    final failed = s.state == _K.failed;
    final pending = s.state == _K.pending;
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(alignment: Alignment.center, children: [
        if (active)
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = _pulse.value;
              return Container(
                width: 52 + 16 * t,
                height: 52 + 16 * t,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withValues(alpha: 0.30 * (1 - t)),
                        width: 1.6)),
              );
            },
          ),
        if (failed)
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 56 + 6 * _pulse.value,
              height: 56 + 6 * _pulse.value,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.10)),
            ),
          ),
        if (active)
          AnimatedBuilder(
            animation: _spin,
            builder: (_, __) =>
                CustomPaint(size: const Size(70, 70), painter: _ArcPainter(_spin.value, color)),
          ),
        if (success)
          AnimatedBuilder(
            animation: Listenable.merge([_spin, _pulse]),
            builder: (_, __) => CustomPaint(
                size: const Size(70, 70),
                painter: _SparklePainter(_spin.value, _pulse.value)),
          ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pending ? context.bg : color.withValues(alpha: 0.16),
            gradient: pending
                ? null
                : LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.28),
                      color.withValues(alpha: 0.10)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
            border: Border.all(
                color: pending
                    ? context.border
                    : color.withValues(alpha: 0.30)),
          ),
          child: Icon(s.icon,
              color: pending ? context.muted : color, size: 25),
        ),
        if (s.state == _K.done)
          Positioned(
            right: 4,
            bottom: 4,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('check-$i'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: success ? C.accentGold : C.accentGreen,
                      border: Border.all(color: context.card, width: 2)),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 11),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  // --------------------------------------------------------------------------
  //  CONNECTOR
  // --------------------------------------------------------------------------
  Widget _connector(BuildContext context, _Step from) {
    final color = _stateColor(context, from.state);
    final flowing = from.state == _K.active;
    return Padding(
      padding: const EdgeInsets.only(left: 49.5, top: 6, bottom: 6),
      child: Container(
        width: 3,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: flowing ? null : color.withValues(alpha: 0.35),
          gradient: flowing
              ? _flowGradient(color)
              : null,
        ),
        child: flowing
            ? AnimatedBuilder(
                animation: _flow,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: _flowGradient(color),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  LinearGradient _flowGradient(Color color) {
    final t = _flow.value;
    final lo = (t - 0.35).clamp(0.0, 1.0);
    final hi = (t + 0.35).clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.12),
        color,
        color.withValues(alpha: 0.12),
      ],
      stops: [lo, t.clamp(lo, hi), hi],
    );
  }

  // --------------------------------------------------------------------------
  //  EMPTY
  // --------------------------------------------------------------------------
  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 70),
        child: Column(children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = _pulse.value;
              return SizedBox(
                width: 140,
                height: 140,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 86 + 34 * t,
                    height: 86 + 34 * t,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: C.accent.withValues(alpha: 0.22 * (1 - t)),
                            width: 1.4)),
                  ),
                  Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AuraGrad.soft,
                          border: Border.all(color: context.border)),
                      child: const Icon(Icons.route_rounded,
                          color: C.accent, size: 38)),
                ]),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('មិនទាន់មានការតាមដាន',
              style: TextStyle(
                  color: context.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('ដាក់ពាក្យស្នើរឥណទាន ដើម្បីតាមដានដំណើរការ ៣ ជំហាននៅទីនេះ',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.muted, fontSize: 12, height: 1.5)),
          const SizedBox(height: 24),
          NeuButton(
              label: 'ដាក់ពាក្យស្នើរឥណទាន',
              icon: Icons.add_circle_outline_rounded,
              onPressed: () => push(context, const LoanModuleScreen())),
        ]),
      );
}

// ============================================================================
//  PAINTERS
// ============================================================================
class _ArcPainter extends CustomPainter {
  final double t;
  final Color color;
  _ArcPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: 31);
    final start = -math.pi / 2 + 2 * math.pi * t;
    canvas.drawArc(
        rect,
        start,
        1.15,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.t != t || old.color != color;
}

class _SparklePainter extends CustomPainter {
  final double spin, pulse;
  _SparklePainter(this.spin, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const count = 7;
    for (var i = 0; i < count; i++) {
      final a = 2 * math.pi * (i / count) + spin * 1.2;
      final twinkle =
          0.35 + 0.65 * ((math.sin(pulse * 2 * math.pi + i) + 1) / 2);
      final r = 28.0 + (i.isEven ? 3 : 0);
      final p = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      canvas.drawCircle(
          p,
          1.7,
          Paint()
            ..color = C.accentGold.withValues(alpha: 0.85 * twinkle));
      canvas.drawCircle(
          p,
          4,
          Paint()
            ..color = C.accentGold.withValues(alpha: 0.18 * twinkle)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.spin != spin || old.pulse != pulse;
}

/// ពន្លឺរអិលកាត់កាតដែលកំពុងដំណើរការ
class _SweepPainter extends CustomPainter {
  final double t;
  final Color color;
  _SweepPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width * 0.4 + t * size.width * 1.8;
    final shader = LinearGradient(
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.10),
        color.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(x - 60, 0, 120, size.height));
    canvas.drawRect(
        Rect.fromLTWH(x - 60, 0, 120, size.height), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _SweepPainter old) =>
      old.t != t || old.color != color;
}
