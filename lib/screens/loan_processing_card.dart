// ============================================================================
//  LOAN PROCESSING CARD — ដំណើរការឥណទាន (តាមដានផ្ទាល់)
//  បង្ហាញ ៤ ដំណាក់កាល + ជំហានរង ហើយធ្វើបច្ចុប្បន្នភាពស្វ័យប្រវត្តិ
//  ពេល admin approve/disburse នៅ Backend
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
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

class LoanProcessingCard extends StatefulWidget {
  const LoanProcessingCard({super.key});
  @override
  State<LoanProcessingCard> createState() => _LoanProcessingCardState();
}

class _LoanProcessingCardState extends State<LoanProcessingCard> {
  LoanRecord? _loan;
  LoanKyc? _kyc;
  LoanScheduleRow? _nextDue;
  bool _loading = true;
  bool _failed = false;
  Timer? _timer;
  final Set<int> _open = {};

  @override
  void initState() {
    super.initState();
    _load();
    // live: Backend approve → user ឃើញភ្លាម (auto refresh)
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final raw = await ApiService.getLoans();
      final loans = raw
          .map((e) => LoanRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      LoanRecord? loan;
      final open = loans
          .where((l) => l.status != 'closed' && l.status != 'rejected')
          .toList();
      if (open.isNotEmpty) loan = open.first;
      else if (loans.isNotEmpty) loan = loans.first;

      LoanKyc? kyc;
      final k = await ApiService.getLoanKyc();
      if (k != null) kyc = LoanKyc.fromJson(k);

      LoanScheduleRow? next;
      if (loan != null && loan.canPay) {
        try {
          final sch = await ApiService.getLoanSchedule();
          final rows = (sch['rows'] as List<dynamic>? ?? [])
              .map((e) =>
                  LoanScheduleRow.fromJson(Map<String, dynamic>.from(e as Map)))
              .where((r) => !r.isPaid)
              .toList()
            ..sort((a, b) => a.installmentNo.compareTo(b.installmentNo));
          if (rows.isNotEmpty) next = rows.first;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _loan = loan;
        _kyc = kyc;
        _nextDue = next;
        _loading = false;
        _failed = false;
        if (_open.isEmpty && loan != null) {
          final idx = _activeStageIndex(loan);
          if (idx >= 0) _open.add(idx);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// សន្ទស្សន៍ដំណាក់កាលដែលកំពុងដំណើរការ (0–3)
  int _activeStageIndex(LoanRecord l) {
    switch (l.status) {
      case 'submitted':
        return 1; // រង់ចាំវាយតម្លៃ
      case 'under_review':
        return 1;
      case 'approved':
        return 2;
      case 'disbursed':
      case 'active':
        return 3;
      case 'closed':
        return -1;
      default:
        return 1;
    }
  }

  double _progress(LoanRecord l) => switch (l.status) {
        'submitted' => 0.30,
        'under_review' => 0.45,
        'approved' => 0.60,
        'disbursed' || 'active' => 0.82,
        'closed' => 1.0,
        'rejected' => 0.18,
        _ => 0.15,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return NeuBox(
        radius: 20,
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: const Center(
            child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: C.accent))),
      );
    }
    if (_failed) {
      return NeuBox(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Icon(Icons.cloud_off_rounded, color: context.muted, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text('មិនអាចទាញស្ថានភាពឥណទានបានទេ',
                  style: TextStyle(color: context.muted, fontSize: 12.5))),
          TextButton(
              onPressed: _load,
              child: const Text('ព្យាយាមម្ដងទៀត',
                  style: TextStyle(
                      color: C.accent, fontWeight: FontWeight.w700))),
        ]),
      );
    }
    final loan = _loan;
    return NeuBox(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _header(context, loan),
        if (loan == null) ...[
          const SizedBox(height: 14),
          _empty(context),
        ] else ...[
          const SizedBox(height: 14),
          _summary(context, loan),
          const SizedBox(height: 14),
          _progressBar(context, loan),
          const SizedBox(height: 16),
          for (var i = 0; i < _stages(loan).length; i++)
            _stageTile(
              context,
              index: i,
              stage: _stages(loan)[i],
              last: i == _stages(loan).length - 1,
            ),
          if (loan.status == 'rejected') ...[
            const SizedBox(height: 4),
            _rejectBanner(context, loan),
          ],
          if (_nextDue != null) ...[
            const SizedBox(height: 12),
            _nextDueRow(context),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: () => push(context, const LoanModuleScreen()),
                icon: const Icon(Icons.open_in_new_rounded,
                    size: 16, color: C.accent),
                label: const Text('មើលលម្អិត',
                    style: TextStyle(
                        color: C.accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700))),
          ),
        ],
      ]),
    );
  }

  Widget _header(BuildContext context, LoanRecord? loan) => Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              gradient: AuraGrad.button,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.sync_alt_rounded,
              color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ដំណើរការឥណទាន',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.ink)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: C.accentGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('ធ្វើបច្ចុប្បន្នភាពស្វ័យប្រវត្តិ',
                      style:
                          TextStyle(color: context.muted, fontSize: 10.5)),
                ]),
              ]),
        ),
        if (loan != null) _statusChip(context, loan.status),
      ]);

  Widget _statusChip(BuildContext context, String status) {
    final color = switch (status) {
      'submitted' => C.accent,
      'under_review' => C.accentGold,
      'approved' => C.accentTeal,
      'rejected' => C.accentRed,
      'disbursed' || 'active' => C.accentGreen,
      'closed' => C.accentGreen,
      _ => context.muted,
    };
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

  Widget _empty(BuildContext context) => Column(children: [
        Container(
          width: 60,
          height: 60,
          decoration:
              BoxDecoration(gradient: AuraGrad.soft, shape: BoxShape.circle),
          child: Icon(Icons.request_quote_outlined,
              color: context.muted, size: 26),
        ),
        const SizedBox(height: 10),
        Text('អ្នកមិនទាន់មានសំណើរឥណទានទេ',
            style: TextStyle(
                color: context.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('ដាក់ពាក្យស្នើរ ដើម្បីតាមដានដំណាក់កាលនៅទីនេះ',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.muted, fontSize: 11.5)),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: NeuButton(
              label: 'ដាក់ពាក្យស្នើរ',
              icon: Icons.add_rounded,
              height: 44,
              onPressed: () => push(context, const LoanModuleScreen())),
        ),
      ]);

  Widget _summary(BuildContext context, LoanRecord l) => Row(children: [
        _metric(context, 'ចំនួន', money(l.principal)),
        _divider(context),
        _metric(context, 'រំលស់/ខែ', money(l.monthlyPayment)),
        _divider(context),
        _metric(context, 'រយៈពេល', '${l.months} ខែ'),
      ]);

  Widget _metric(BuildContext context, String label, String value) => Expanded(
        child: Column(children: [
          Text(label,
              style: TextStyle(color: context.muted, fontSize: 10.5)),
          const SizedBox(height: 3),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _divider(BuildContext context) => Container(
      width: 1, height: 26, color: context.border);

  Widget _progressBar(BuildContext context, LoanRecord l) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 8,
          color: context.isDark
              ? Colors.black.withValues(alpha: 0.18)
              : context.bg,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progress(l),
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [C.accentTeal, C.accent, C.accentGreen])),
            ),
          ),
        ),
      );

  List<_Stage> _stages(LoanRecord l) {
    final rejected = l.status == 'rejected';
    final kyc = _kyc;
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

  Widget _stageTile(BuildContext context,
      {required int index,
      required _Stage stage,
      required bool last}) {
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
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
                  Icon(open ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                      color: context.muted, size: 18),
                ]),
              ),
              const SizedBox(height: 2),
              Text(stage.subtitle,
                  style: TextStyle(color: context.muted, fontSize: 11)),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
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
                                            : Icons.radio_button_unchecked,
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

  Widget _rejectBanner(BuildContext context, LoanRecord l) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: C.accentRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: C.accentRed.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: C.accentRed, size: 18),
            const SizedBox(width: 8),
            const Expanded(
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
          const SizedBox(height: 8),
          Text('អ្នកអាចកែព័ត៌មាន ហើយដាក់ពាក្យស្នើរម្ដងទៀតបាន។',
              style: TextStyle(color: context.muted, fontSize: 11)),
        ]),
      );

  Widget _nextDueRow(BuildContext context) {
    final due = _nextDue!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: C.accentGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: C.accentGold.withValues(alpha: 0.25))),
      child: Row(children: [
        const Icon(Icons.event_rounded, color: C.accentGold, size: 17),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                'ថ្ងៃបង់បន្ទាប់ • ${due.dueDate == null ? '-' : '${due.dueDate!.day}/${due.dueDate!.month}/${due.dueDate!.year}'}',
                style: TextStyle(
                    color: context.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700))),
        Text(money(due.remaining),
            style: const TextStyle(
                color: C.accentGold,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
