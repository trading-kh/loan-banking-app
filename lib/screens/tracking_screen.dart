// ============================================================================
//  តាមដាន — ដំណើរការឥណទានទាំងអស់ + Processing animation
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

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  List<LoanRecord> _loans = const [];
  LoanKyc? _kyc;
  LoanScheduleRow? _nextDue;
  bool _loading = true;
  Timer? _timer;

  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();
  late final AnimationController _pulse = AnimationController(
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
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    List<LoanRecord> loans = const [];
    LoanKyc? kyc;
    LoanScheduleRow? next;

    try {
      final raw = await ApiService.getLoans();
      loans = raw
          .whereType<Map>()
          .map((e) => LoanRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}

    try {
      final k = await ApiService.getLoanKyc();
      if (k != null) kyc = LoanKyc.fromJson(k);
    } catch (_) {}

    final lead = _leadOf(loans);
    if (lead != null && lead.canPay) {
      try {
        final s = await ApiService.getLoanSchedule();
        final rows = (s['rows'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) =>
                LoanScheduleRow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.installmentNo.compareTo(b.installmentNo));
        for (final r in rows) {
          if (!r.isPaid) {
            next = r;
            break;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _loans = loans;
      _kyc = kyc;
      _nextDue = next;
      _loading = false;
    });
  }

  LoanRecord? _leadOf(List<LoanRecord> loans) {
    for (final l in loans) {
      if (l.status == 'submitted' ||
          l.status == 'under_review' ||
          l.status == 'approved' ||
          l.status == 'disbursed' ||
          l.status == 'active') {
        return l;
      }
    }
    return loans.isEmpty ? null : loans.first;
  }

  double _progress(LoanRecord? l) {
    if (l == null) return 0;
    return switch (l.status) {
      'submitted' => 0.18,
      'under_review' => 0.42,
      'approved' => 0.66,
      'disbursed' => 0.8,
      'active' => (0.8 + (l.months == 0 ? 0 : l.paid / l.months) * 0.2)
          .clamp(0.8, 1.0),
      'closed' => 1.0,
      'rejected' => 0.42,
      _ => 0.0,
    };
  }

  String _title(LoanRecord? l) => switch (l?.status) {
        'submitted' => 'សំណើរត្រូវបានទទួល',
        'under_review' => 'កំពុងពិនិត្យ & វាយតម្លៃ',
        'approved' => 'សំណើរត្រូវបានអនុម័ត',
        'disbursed' => 'ប្រាក់ត្រូវបានបញ្ចេញ',
        'active' => 'កំពុងសងប្រាក់',
        'closed' => 'កម្ចីត្រូវបានបិទ',
        'rejected' => 'សំណើរត្រូវបានបដិសេធ',
        _ => 'មិនទាន់មានឥណទាន',
      };

  String _hint(LoanRecord? l) => switch (l?.status) {
        'submitted' => 'មន្ត្រីឥណទាននឹងចាប់ផ្ដើមពិនិត្យក្នុងពេលឆាប់ៗ',
        'under_review' => 'យើងកំពុងវាយតម្លៃពិន្ទុឥណទាន និង CBC',
        'approved' => 'រង់ចាំការបញ្ចេញប្រាក់ចូលគណនីរបស់អ្នក',
        'disbursed' => 'ប្រាក់បានចូលគណនី — សូមពិនិត្យតារាងសង',
        'active' =>
          'បានសង ${l!.paid}/${l.months} វីនុបទ · បន្តបង់ទាន់ពេល',
        'closed' => 'សូមអរគុណដែលបានប្រើសេវារបស់យើង',
        'rejected' => l!.rejectReason.trim().isNotEmpty
            ? l.rejectReason
            : 'អ្នកអាចកែព័ត៌មាន ហើយដាក់ពាក្យស្នើរម្ដងទៀត',
        _ => 'ចាប់ផ្ដើមដាក់ពាក្យស្នើរដើម្បីទទួលបានប្រាក់កម្ចី',
      };

  static IconData _statusIcon(String s) => switch (s) {
        'submitted' => Icons.description_rounded,
        'under_review' => Icons.hourglass_top_rounded,
        'approved' => Icons.verified_rounded,
        'rejected' => Icons.cancel_rounded,
        'disbursed' || 'active' => Icons.payments_rounded,
        'closed' => Icons.task_alt_rounded,
        _ => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final lead = _leadOf(_loans);
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            StaggeredItem(index: 0, child: _hero(context, lead)),
            if (_nextDue != null && lead != null && lead.canPay)
              StaggeredItem(index: 1, child: _nextDueCard(context, _nextDue!)),
            StaggeredItem(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('ដំណើរការឥណទាន'),
                  if (lead != null)
                    NeuBox(
                      radius: 20,
                      padding: const EdgeInsets.all(16),
                      child: LoanStageTimeline(loan: lead, kyc: _kyc),
                    )
                  else
                    _emptyPipeline(context),
                ],
              ),
            ),
            StaggeredItem(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle('ឥណទានទាំងអស់ (${_loans.length})'),
                  if (_loans.isEmpty)
                    _emptyLoans(context)
                  else
                    for (final l in _loans)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _loanTile(context, l),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  HERO — Processing
  // --------------------------------------------------------------------------
  Widget _hero(BuildContext context, LoanRecord? lead) {
    final status = lead?.status;
    final waiting = status == 'submitted' ||
        status == 'under_review' ||
        status == null;
    final color = status == 'rejected'
        ? const Color(0xFFFF9A9A)
        : Colors.white;
    final progress = _progress(lead);
    final canApply = lead == null || status == 'rejected' || status == 'closed';

    return Container(
      decoration: BoxDecoration(
        gradient: AuraGrad.brand,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              offset: const Offset(0, 14),
              blurRadius: 30,
              spreadRadius: -10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          Positioned(
              top: -70,
              right: -60,
              child: _halo(190, Colors.white.withValues(alpha: 0.05))),
          Positioned(
              bottom: -80,
              left: -50,
              child: _halo(170, Colors.white.withValues(alpha: 0.04))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(children: [
              Row(children: [
                Icon(Icons.track_changes_rounded,
                    color: Colors.white.withValues(alpha: 0.9), size: 18),
                const SizedBox(width: 8),
                Text('ស្ថានភាពឥណទាន',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                if (lead != null) _heroChip(context, lead.status),
              ]),
              const SizedBox(height: 14),
              _ring(progress, color, waiting,
                  rejected: status == 'rejected',
                  closed: status == 'closed',
                  empty: lead == null),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: Text(_title(lead),
                    key: ValueKey('t-${status ?? 'none'}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 5),
              Text(_hint(lead),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11.5,
                      height: 1.4)),
              if (lead != null) ...[
                const SizedBox(height: 18),
                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12)),
                const SizedBox(height: 14),
                Row(children: [
                  _metric('ចំនួនទឹកប្រាក់', money(lead.principal)),
                  _metric('រំលស់/ខែ', money(lead.monthlyPayment)),
                  _metric('រយៈពេល', '${lead.months} ខែ'),
                ]),
              ],
              if (canApply) ...[
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => push(context, const LoanModuleScreen()),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              color: C.bgDark, size: 19),
                          const SizedBox(width: 7),
                          Text(
                              lead == null
                                  ? 'ដាក់ពាក្យស្នើរឥណទាន'
                                  : 'ដាក់ពាក្យស្នើរម្ដងទៀត',
                              style: const TextStyle(
                                  color: C.bgDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ]),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _halo(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _heroChip(BuildContext context, String status) {
    final c = loanStatusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(loanStatusLabels[status] ?? status,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _ring(double progress, Color color, bool waiting,
      {required bool rejected,
      required bool closed,
      required bool empty}) {
    return TweenAnimationBuilder<double>(
      key: const ValueKey('ring'),
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (_, p, __) => AnimatedBuilder(
        animation: Listenable.merge([_spin, _pulse]),
        builder: (_, __) => SizedBox(
          width: 172,
          height: 172,
          child: CustomPaint(
            painter: _RingPainter(
              progress: p,
              spin: _spin.value,
              pulse: _pulse.value,
              waiting: waiting,
              accent: color,
            ),
            child: Center(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: closed
                      ? [
                          Icon(Icons.verified_rounded,
                              color: C.accentGreen, size: 46),
                          const SizedBox(height: 4),
                          const Text('100%',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ]
                      : rejected
                          ? [
                              Icon(Icons.cancel_rounded,
                                  color: color, size: 46),
                              const SizedBox(height: 4),
                              const Text('បដិសេធ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                            ]
                          : empty
                              ? [
                                  Icon(Icons.savings_outlined,
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      size: 44),
                                  const SizedBox(height: 6),
                                  Text('ចាប់ផ្ដើម',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.75),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ]
                              : [
                                  Text('${(p * 100).round()}%',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1)),
                                  const SizedBox(height: 2),
                                  Text(
                                      waiting
                                          ? 'កំពុងដំណើរការ'
                                          : 'ដំណើរការ',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700)),
                                ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
        ]),
      );

  // --------------------------------------------------------------------------
  //  NEXT DUE
  // --------------------------------------------------------------------------
  Widget _nextDueCard(BuildContext context, LoanScheduleRow row) {
    final overdue = row.isOverdue || row.isDue;
    final color = overdue ? C.accentRed : C.accentGold;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        onTap: () => push(context, const LoanModuleScreen()),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.16)),
                child: Icon(
                    overdue
                        ? Icons.error_outline_rounded
                        : Icons.event_note_rounded,
                    color: color,
                    size: 21)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      overdue
                          ? 'វីនុបទទី ${row.installmentNo} ហួសកំណត់'
                          : 'វីនុបទទី ${row.installmentNo} ត្រូវបង់',
                      style: TextStyle(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                      '${money(row.remaining)}${row.dueDate == null ? '' : ' · ${dayLabel(row.dueDate!)}'}',
                      style: TextStyle(
                          color: context.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ])),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ]),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  LISTS
  // --------------------------------------------------------------------------
  Widget _loanTile(BuildContext context, LoanRecord l) {
    final color = loanStatusColor(context, l.status);
    final ratio = l.months == 0
        ? 0.0
        : l.status == 'closed'
            ? 1.0
            : (l.paid / l.months).clamp(0.0, 1.0);
    return NeuBox(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: () =>
          push(context, LoanTrackingDetailScreen(loan: l, kyc: _kyc)),
      child: Row(children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
            child: Icon(_statusIcon(l.status), color: color, size: 21)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Expanded(
                    child: Text('ឥណទាន #${l.id}',
                        style: TextStyle(
                            color: context.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800))),
                loanStatusChip(context, l.status),
              ]),
              const SizedBox(height: 4),
              Text('${money(l.principal)} • ${l.months} ខែ',
                  style: TextStyle(color: context.muted, fontSize: 11.5)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: context.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )),
                const SizedBox(width: 8),
                Text('${l.paid}/${l.months}',
                    style: TextStyle(
                        color: context.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
            ])),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, color: context.muted, size: 18),
      ]),
    );
  }

  Widget _emptyPipeline(BuildContext context) => NeuBox(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AuraGrad.soft,
                  border: Border.all(color: context.border)),
              child: Icon(Icons.route_rounded, color: C.accent, size: 23)),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('មិនទាន់មានដំណើរការ',
                    style: TextStyle(
                        color: context.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    'ដំណើរការឥណទាន ៤ ជំហាននឹងបង្ហាញនៅទីនេះ បន្ទាប់ពីអ្នកដាក់ពាក្យស្នើរ',
                    style: TextStyle(
                        color: context.muted, fontSize: 11, height: 1.4)),
              ])),
        ]),
      );

  Widget _emptyLoans(BuildContext context) => NeuBox(
        radius: 18,
        padding: const EdgeInsets.all(18),
        child: Center(
            child: Text('មិនទាន់មានប្រវត្តិឥណទាន',
                style: TextStyle(color: context.muted, fontSize: 12))),
      );
}

// ============================================================================
//  RING PAINTER — Processing animation
// ============================================================================
class _RingPainter extends CustomPainter {
  final double progress, spin, pulse;
  final bool waiting;
  final Color accent;

  _RingPainter({
    required this.progress,
    required this.spin,
    required this.pulse,
    required this.waiting,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 15;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // pulse halo — ស្រាលៗពេលកំពុងដំណើរការ
    if (waiting) {
      for (var i = 0; i < 2; i++) {
        final t = (pulse + i * 0.5) % 1.0;
        canvas.drawCircle(
            center,
            radius + 5 + 16 * t,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = Colors.white.withValues(alpha: 0.20 * (1 - t)));
      }
    }

    // track
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = Colors.white.withValues(alpha: 0.13));

    // stage markers (៤ ដំណាក់កាល)
    const thresholds = [0.15, 0.40, 0.63, 0.78];
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + i * math.pi / 2;
      final done = progress >= thresholds[i];
      canvas.drawCircle(
          Offset(center.dx + radius * math.cos(a),
              center.dy + radius * math.sin(a)),
          done ? 3.6 : 2.6,
          Paint()
            ..color =
                Colors.white.withValues(alpha: done ? 0.95 : 0.28));
    }

    // progress arc
    if (progress > 0.002) {
      final shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.35),
          accent,
          accent,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
      canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * progress.clamp(0.0, 1.0),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..shader = shader);
    }

    // rotating shimmer head
    if (waiting) {
      final start = -math.pi / 2 + 2 * math.pi * spin;
      canvas.drawArc(
          rect,
          start,
          0.62,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.7)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 4));
      final head = Offset(center.dx + radius * math.cos(start + 0.62),
          center.dy + radius * math.sin(start + 0.62));
      canvas.drawCircle(head, 8,
          Paint()..color = Colors.white.withValues(alpha: 0.28));
      canvas.drawCircle(head, 3.8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.spin != spin ||
      old.pulse != pulse ||
      old.waiting != waiting ||
      old.accent != accent;
}
