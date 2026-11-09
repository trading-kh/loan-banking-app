// ============================================================================
//  LOAN STAGE TIMELINE — ដំណាក់កាលឥណទាន (រួមប្រើដោយ តាមដាន + លម្អិត)
// ============================================================================
import 'package:flutter/material.dart';

import '../loan_module.dart';
import '../main.dart';

enum _S { done, active, pending, failed }

class _Step {
  final String label;
  final bool done;
  const _Step(this.label, this.done);
}

class _Stage {
  final String title, subtitle;
  final IconData icon;
  final _S state;
  final List<_Step> steps;
  const _Stage(this.title, this.subtitle, this.icon, this.state, this.steps);
}

Color loanStatusColor(BuildContext context, String status) => switch (status) {
      'submitted' => C.accent,
      'under_review' => C.accentGold,
      'approved' => C.accentTeal,
      'rejected' => C.accentRed,
      'disbursed' || 'active' => C.accentGreen,
      'closed' => C.accentGreen,
      _ => context.muted,
    };

Widget loanStatusChip(BuildContext context, String status) {
  final color = loanStatusColor(context, status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20)),
    child: Text(loanStatusLabels[status] ?? status,
        style: TextStyle(
            color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
  );
}

Widget loanRejectBanner(BuildContext context, LoanRecord l) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: C.accentRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.accentRed.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.error_outline_rounded, color: C.accentRed, size: 18),
          SizedBox(width: 8),
          Expanded(
              child: Text('សំណើរត្រូវបានបដិសេធ',
                  style: TextStyle(
                      color: C.accentRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w800))),
        ]),
        if (l.rejectReason.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(l.rejectReason,
              style: TextStyle(color: context.muted, fontSize: 11.5)),
        ],
        const SizedBox(height: 6),
        Text('អ្នកអាចកែព័ត៌មាន ហើយដាក់ពាក្យស្នើរម្ដងទៀតបាន។',
            style: TextStyle(color: context.muted, fontSize: 11)),
      ]),
    );

// ============================================================================
//  TIMELINE
// ============================================================================
class LoanStageTimeline extends StatefulWidget {
  final LoanRecord loan;
  final LoanKyc? kyc;
  const LoanStageTimeline(
      {super.key, required this.loan, required this.kyc});
  @override
  State<LoanStageTimeline> createState() => _LoanStageTimelineState();
}

class _LoanStageTimelineState extends State<LoanStageTimeline> {
  final Set<int> _open = {};

  @override
  void initState() {
    super.initState();
    _open.add(_activeOrFirst());
  }

  @override
  void didUpdateWidget(covariant LoanStageTimeline old) {
    super.didUpdateWidget(old);
    if (old.loan.id != widget.loan.id) {
      _open
        ..clear()
        ..add(_activeOrFirst());
    }
  }

  int _activeOrFirst() {
    final l = widget.loan;
    if (l.status == 'rejected') return 1;
    final i = _activeIndex(l);
    return i >= 0 ? i : 3;
  }

  int _activeIndex(LoanRecord l) {
    switch (l.status) {
      case 'submitted':
      case 'under_review':
        return 1;
      case 'approved':
        return 2;
      case 'disbursed':
      case 'active':
        return 3;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages(widget.loan);
    return Column(children: [
      for (var i = 0; i < stages.length; i++)
        _stageTile(context, i, stages[i], last: i == stages.length - 1),
    ]);
  }

  List<_Stage> _stages(LoanRecord l) {
    final rejected = l.status == 'rejected';
    final kyc = widget.kyc;
    final kycDone = kyc != null && kyc.submitted;
    final bankDone = kyc != null &&
        kyc.bankName.trim().isNotEmpty &&
        kyc.bankAccount.trim().isNotEmpty;
    final approvedOrMore = l.stage >= 2 && !rejected;
    final disbursed = l.stage >= 3;
    final paidDone = l.months > 0 && l.paid >= l.months;

    final review = rejected
        ? _S.failed
        : (l.status == 'submitted' || l.status == 'under_review')
            ? _S.active
            : _S.done;
    final contract = rejected || l.stage < 2 || l.status == 'approved'
        ? (l.status == 'approved' ? _S.active : _S.pending)
        : _S.done;
    final repay = rejected || !disbursed
        ? _S.pending
        : (l.status == 'closed' ? _S.done : _S.active);

    return [
      _Stage(
        'ដំណាក់កាលដាក់ពាក្យស្នើសុំ',
        kycDone ? 'ផ្ទៀងផ្ទាត់អត្តសញ្ញាណរួចរាល់' : 'KYC និងព័ត៌មានកម្ចី',
        Icons.description_outlined,
        _S.done,
        [
          _Step('KYC — អត្តសញ្ញាណប័ណ្ណ & លេខទូរសព្ទ', kycDone),
          _Step('ព័ត៌មានប្រាក់កម្ចី & គោលបំណង', true),
          _Step('ឯកសារ & គណនីធនាគារ', bankDone),
          _Step('ពិនិត្យសិទ្ធិបឋម (Pre-qualification)', true),
        ],
      ),
      _Stage(
        'ពិនិត្យ និងវាយតម្លៃ',
        rejected
            ? 'សំណើរត្រូវបានបដិសេធ'
            : l.waitingApproval
                ? 'កំពុងរង់ចាំមន្ត្រីឥណទានពិនិត្យ'
                : 'បានឆ្លងកាត់ការវាយតម្លៃ',
        Icons.fact_check_outlined,
        review,
        [
          _Step('ចូលជួររង់ចាំមន្ត្រីឥណទាន', true),
          _Step('ពិន្ទុឥណទាន & CBC',
              l.score != null || approvedOrMore || rejected),
          _Step('អនុម័តតាមកម្រិតអំណាច', approvedOrMore),
        ],
      ),
      _Stage(
        'ចុះកិច្ចសន្យា',
        l.status == 'approved'
            ? 'រង់ចាំការបញ្ចេញប្រាក់'
            : disbursed
                ? 'កិច្ចសន្យាត្រូវបានអនុវត្ត'
                : 'បង្កើតកិច្ចសន្យា & ហត្ថលេខាឌីជីថល',
        Icons.history_edu_outlined,
        contract,
        [
          _Step('បង្កើតកិច្ចសន្យាឥណទាន', l.approvedAt != null),
          _Step('ចុះហត្ថលេខាឌីជីថល / OTP', disbursed),
        ],
      ),
      _Stage(
        'បញ្ចេញប្រាក់ & សង',
        l.status == 'closed'
            ? 'កម្ចីត្រូវបានបិទ'
            : disbursed
                ? 'បានបញ្ចេញប្រាក់ — ${l.paid}/${l.months} វីនុបទ'
                : 'រង់ចាំការបញ្ចេញប្រាក់',
        Icons.payments_outlined,
        repay,
        [
          _Step('បញ្ចេញប្រាក់ចូលគណនី/កាត', disbursed),
          _Step('តារាងសងប្រចាំខែ', disbursed),
          _Step('ជូនដំណឹងរំលឹកមុនកំណត់', disbursed),
          _Step('ទូទាត់សង & កត់ត្រា (${l.paid}/${l.months})', paidDone),
        ],
      ),
    ];
  }

  Widget _stageTile(BuildContext context, int index, _Stage stage,
      {required bool last}) {
    final open = _open.contains(index);
    final color = switch (stage.state) {
      _S.done => C.accentGreen,
      _S.active => C.accent,
      _S.failed => C.accentRed,
      _S.pending => context.muted,
    };
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stage.state == _S.pending ? context.bg : null,
              gradient: stage.state == _S.pending
                  ? null
                  : LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
              border: stage.state == _S.pending
                  ? Border.all(color: context.border)
                  : null,
              boxShadow: stage.state == _S.active
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: -2)
                    ]
                  : null,
            ),
            child: Icon(
              stage.state == _S.done
                  ? Icons.check_rounded
                  : stage.state == _S.failed
                      ? Icons.close_rounded
                      : stage.icon,
              color: stage.state == _S.pending ? context.muted : Colors.white,
              size: 17,
            ),
          ),
          if (!last)
            Expanded(
              child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: stage.state == _S.done
                      ? C.accentGreen.withValues(alpha: 0.45)
                      : context.border),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(
                        () => open ? _open.remove(index) : _open.add(index)),
                    child: Row(children: [
                      Expanded(
                          child: Text(stage.title,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: context.ink))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            switch (stage.state) {
                              _S.done => 'បានបញ្ចប់',
                              _S.active => 'កំពុងដំណើរការ',
                              _S.failed => 'បរាជ័យ',
                              _S.pending => 'រង់ចាំ',
                            },
                            style: TextStyle(
                                color: color,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800)),
                      ),
                      Icon(
                          open
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: context.muted,
                          size: 18),
                    ]),
                  ),
                  const SizedBox(height: 2),
                  Text(stage.subtitle,
                      style:
                          TextStyle(color: context.muted, fontSize: 11)),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: open
                        ? Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final s in stage.steps)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: Row(children: [
                                        Icon(
                                            s.done
                                                ? Icons.check_circle_rounded
                                                : Icons
                                                    .radio_button_unchecked,
                                            size: 15,
                                            color: s.done
                                                ? C.accentGreen
                                                : context.muted),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(s.label,
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: s.done
                                                        ? context.ink
                                                        : context.muted))),
                                      ]),
                                    ),
                                ]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ]),
          ),
        ),
      ]),
    );
  }
}

// ============================================================================
//  DETAIL — ឥណទានមួយជាក់លាក់
// ============================================================================
class LoanTrackingDetailScreen extends StatelessWidget {
  final LoanRecord loan;
  final LoanKyc? kyc;
  const LoanTrackingDetailScreen(
      {super.key, required this.loan, required this.kyc});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('ឥណទាន #${loan.id}')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AuraGrad.brand,
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('ចំនួនប្រាក់កម្ចី',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12)),
                      const Spacer(),
                      loanStatusChip(context, loan.status),
                    ]),
                    const SizedBox(height: 6),
                    Text(money(loan.principal),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 14),
                    Row(children: [
                      _w(context, 'រំលស់/ខែ', money(loan.monthlyPayment)),
                      _w(context, 'រយៈពេល', '${loan.months} ខែ'),
                      _w(context, 'បានសង',
                          '${loan.paid}/${loan.months}'),
                    ]),
                    if (loan.score != null) ...[
                      const SizedBox(height: 12),
                      Text(
                          'ពិន្ទុឥណទាន ${loan.score}${loan.scoreBand == null ? '' : ' · ${loan.scoreBand}'}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ]),
            ),
            if (loan.status == 'rejected') ...[
              const SizedBox(height: 14),
              loanRejectBanner(context, loan),
            ],
            const SectionTitle('ដំណើរការឥណទាន'),
            NeuBox(
              radius: 20,
              padding: const EdgeInsets.all(16),
              child: LoanStageTimeline(loan: loan, kyc: kyc),
            ),
            const SizedBox(height: 16),
            NeuButton(
                label: 'មើលក្នុងផ្នែកឥណទាន',
                icon: Icons.open_in_new_rounded,
                onPressed: () => push(context, const LoanModuleScreen())),
          ],
        ),
      );

  Widget _w(BuildContext context, String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}
