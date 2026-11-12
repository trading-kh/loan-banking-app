// ============================================================================
//  LOAN MODULE — ម៉ាស៊ីនកម្ចី
//  KYC/CRM → សាកលកម្ម → វាយតម្លៃ → អនុមត្ត (បង្កើតតារាងសងប្រាក់តាមខែ) → បញ្ចូល → បង់
// ============================================================================
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'main.dart';
import 'id_scan_screen.dart';
import 'screens/loan_application_form_screen.dart';

// ============================================================
//  HELPERS
// ============================================================
double _d(Object? v) => v is num
    ? v.toDouble()
    : (v is String ? double.tryParse(v) ?? 0 : 0);

int _i(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);

String _s(Object? v) => v?.toString() ?? '';

DateTime? _dt(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

// ============================================================
//  MODELS
// ============================================================
/// ព័ត៌មាន KYC — ទាក់ទងជាមុននៃកម្ចីវីក្រុយ
class LoanKyc {
  final int userId;
  final String status;
  final String fullName, nationalId, dob, gender, phone, address, occupation;
  final String businessName, businessType;
  final double businessYears, monthlyIncome, monthlyExpense, existingDebt;
  final String bankName, bankAccount;
  final String notes;

  LoanKyc({
    required this.userId,
    required this.status,
    required this.fullName,
    required this.nationalId,
    required this.dob,
    required this.gender,
    required this.phone,
    required this.address,
    required this.occupation,
    required this.businessName,
    required this.businessType,
    required this.businessYears,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.existingDebt,
    required this.bankName,
    required this.bankAccount,
    required this.notes,
  });

  factory LoanKyc.fromJson(Map<String, dynamic> j) => LoanKyc(
        userId: _i(j['user_id']),
        status: _s(j['status']),
        fullName: _s(j['full_name']),
        nationalId: _s(j['national_id']),
        dob: _s(j['dob']),
        gender: _s(j['gender']),
        phone: _s(j['phone']),
        address: _s(j['address']),
        occupation: _s(j['occupation']),
        businessName: _s(j['business_name']),
        businessType: _s(j['business_type']),
        businessYears: _d(j['business_years']),
        monthlyIncome: _d(j['monthly_income']),
        monthlyExpense: _d(j['monthly_expense']),
        existingDebt: _d(j['existing_debt']),
        bankName: _s(j['bank_name']),
        bankAccount: _s(j['bank_account']),
        notes: _s(j['notes']),
      );

  bool get submitted => status == 'submitted' || status == 'verified';
  bool get verified => status == 'verified';
  bool get rejected => status == 'rejected';

  /// ភាគរយៈព័ត៌មាន (0–100) — គណនាពីវាលដែលបានបំពេញ
  int get completeness {
    const required = [
      'full_name', 'national_id', 'phone', 'address',
      'occupation', 'bank_name', 'bank_account'
    ];
    final values = {
      'full_name': fullName,
      'national_id': nationalId,
      'phone': phone,
      'address': address,
      'occupation': occupation,
      'bank_name': bankName,
      'bank_account': bankAccount,
    };
    final filled =
        required.where((k) => values[k]!.trim().isNotEmpty).length;
    return (filled / required.length * 100).round();
  }

  Map<String, dynamic> toPayload() => {
        'full_name': fullName,
        'national_id': nationalId,
        'dob': dob,
        'gender': gender,
        'phone': phone,
        'address': address,
        'occupation': occupation,
        'business_name': businessName,
        'business_type': businessType,
        'business_years': businessYears,
        'monthly_income': monthlyIncome,
        'monthly_expense': monthlyExpense,
        'existing_debt': existingDebt,
        'bank_name': bankName,
        'bank_account': bankAccount,
      };
}

/// កម្ចីមួយសាកលកម្ម
class LoanRecord {
  final int id;
  final String status;
  final double principal, annualRate, monthlyPayment, totalInterest;
  final double totalPayable, outstanding, feeAmount;
  final int months, paid;
  final String interestMethod, province, district, commune, village;
  final String purpose, rejectReason, channel;
  final int? score;
  final String? scoreBand, cbcStatus;
  final DateTime? firstDueDate, approvedAt;
  final bool autoDebit;

  LoanRecord({
    required this.id,
    required this.status,
    required this.principal,
    required this.annualRate,
    required this.monthlyPayment,
    required this.totalInterest,
    required this.totalPayable,
    required this.outstanding,
    required this.feeAmount,
    required this.months,
    required this.paid,
    required this.interestMethod,
    required this.province,
    required this.district,
    required this.commune,
    required this.village,
    required this.purpose,
    required this.rejectReason,
    required this.channel,
    required this.score,
    required this.scoreBand,
    required this.cbcStatus,
    required this.firstDueDate,
    required this.approvedAt,
    required this.autoDebit,
  });

  factory LoanRecord.fromJson(Map<String, dynamic> j) => LoanRecord(
        id: _i(j['id']),
        status: _s(j['status']),
        principal: _d(j['principal']),
        annualRate: _d(j['annual_rate']),
        monthlyPayment: _d(j['monthly_payment']),
        totalInterest: _d(j['total_interest']),
        totalPayable: _d(j['total_payable']),
        outstanding: _d(j['outstanding']),
        feeAmount: _d(j['fee_amount']),
        months: _i(j['months']),
        paid: _i(j['paid']),
        interestMethod: _s(j['interest_method']),
        province: _s(j['province']),
        district: _s(j['district']),
        commune: _s(j['commune']),
        village: _s(j['village']),
        purpose: _s(j['purpose']),
        rejectReason: _s(j['reject_reason']),
        channel: _s(j['channel']),
        score: j['score'] == null ? null : _i(j['score']),
        scoreBand: j['score_band']?.toString(),
        cbcStatus: j['cbc_status']?.toString(),
        firstDueDate: _dt(j['first_due_date']),
        approvedAt: _dt(j['approved_at']),
        autoDebit: _i(j['auto_debit']) == 1,
      );

  String get address =>
      [village, commune, district, province].where((s) => s.isNotEmpty).join(' · ');

  bool get canPay => status == 'disbursed' || status == 'active';
  bool get waitingApproval =>
      status == 'submitted' || status == 'under_review';

  /// ដំណើរការក្នុង pipeline (0–4)
  int get stage => switch (status) {
        'submitted' => 0,
        'under_review' => 1,
        'approved' => 2,
        'disbursed' => 3,
        'active' => 3,
        'closed' => 4,
        _ => -1,
      };
}

/// វីនុបទក្នុងតារាងសងប្រាក់តាមខែ
class LoanScheduleRow {
  final int installmentNo;
  final DateTime? dueDate;
  final double principalPart, interestPart, feePart, totalDue, paidAmount;
  final String status;
  final int daysLate;

  LoanScheduleRow({
    required this.installmentNo,
    required this.dueDate,
    required this.principalPart,
    required this.interestPart,
    required this.feePart,
    required this.totalDue,
    required this.paidAmount,
    required this.status,
    required this.daysLate,
  });

  factory LoanScheduleRow.fromJson(Map<String, dynamic> j) => LoanScheduleRow(
        installmentNo: _i(j['installment_no']),
        dueDate: _dt(j['due_date']),
        principalPart: _d(j['principal_part']),
        interestPart: _d(j['interest_part']),
        feePart: _d(j['fee_part']),
        totalDue: _d(j['total_due']),
        paidAmount: _d(j['paid_amount']),
        status: _s(j['status']),
        daysLate: _i(j['days_late']),
      );

  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';
  double get remaining => totalDue - paidAmount;
  bool get isDue => status != 'paid' && dueDate != null &&
      dueDate!.isBefore(DateTime.now());
}

// ============================================================
//  LABELS
// ============================================================
const loanStatusLabels = {
  'submitted': 'បានដាក់ស្នើ',
  'under_review': 'កំពុងវាយតម្លៃ',
  'approved': 'បានអនុមត្ត',
  'rejected': 'បានបដិសេធ',
  'disbursed': 'បានបញ្ចូល',
  'active': 'កំពុងបង់',
  'closed': 'បានបិទ',
};

const loanMethodLabels = {
  'annuity': 'ស្មើគ្នា',
  'flat': 'កាន្លោះថេត',
  'reducing': 'កាន្លោះថយថយ',
};

/// ដំណើរការ 5 ដំណើរការស្រុកកម្ចី
const loanStages = [
  'សាកលកម្ម',
  'វាយតម្លៃ',
  'អនុមត្ត',
  'បញ្ចូល',
  'បង់',
];

// ============================================================
//  MAIN SCREEN — កម្ចីវីក្រុយ
// ============================================================
class LoanModuleScreen extends StatefulWidget {
  const LoanModuleScreen({super.key});
  @override
  State<LoanModuleScreen> createState() => _LoanModuleScreenState();
}

class _LoanModuleScreenState extends State<LoanModuleScreen> {
  bool _loading = true;
  LoanKyc? _kyc;
  LoanRecord? _loan;
  List<LoanScheduleRow> _schedule = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final kyc = await ApiService.getLoanKyc();
      _kyc = kyc == null ? null : LoanKyc.fromJson(kyc);

      final loans = await ApiService.getLoans();
      LoanRecord? open;
      for (final e in loans) {
        final l = LoanRecord.fromJson(Map<String, dynamic>.from(e as Map));
        if (l.status != 'rejected' && l.status != 'closed') {
          open = l;
          break;
        }
      }
      _loan = open;

      if (open != null) {
        final s = await ApiService.getLoanSchedule();
        _schedule = [
          for (final r in (s['rows'] as List? ?? []))
            LoanScheduleRow.fromJson(Map<String, dynamic>.from(r as Map))
        ];
      } else {
        _schedule = [];
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay(LoanScheduleRow next) async {
    final amount = next.remaining;
    final okPay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: c.card,
        title: const Text('បង់វីនុបទកម្ចី'),
        content: Text(
            'វីនុបទទី ${next.installmentNo}\nត្រូវបង់ ${money(amount)}\n'
            'កាលបរិច្ឆេទ ${dayLabel(next.dueDate ?? DateTime.now())}',
            style: TextStyle(color: c.muted, height: 1.6)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('បោះបង់', style: TextStyle(color: c.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('បង់', style: TextStyle(color: C.accent))),
        ],
      ),
    );
    if (okPay != true) return;

    try {
      final res = await ApiService.payLoanInstallment(amount: amount);
      if (!mounted) return;
      toast(context, 'បង់បាន ${money(_d(res['amount']))}');
      await bank.refreshAll();
      await _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _toggleAutoDebit(bool enabled) async {
    try {
      await ApiService.setLoanAutoDebit(enabled: enabled);
      if (!mounted) return;
      toast(context, enabled ? 'បានបើកស្វត្តកម្ម' : 'បានបិទស្វត្តកម្ម');
      await _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(
          title: const Text('កម្ចី'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            )
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: C.accent))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: _buildBody(context),
                ),
              ),
      ));

  List<Widget> _buildBody(BuildContext context) {
    final kyc = _kyc;
    if (kyc == null || !kyc.submitted) {
      return [_applyButton(context)];
    }
    if (kyc.rejected) {
      return [_applyButton(context), _kycCard(context, kyc)];
    }
    final loan = _loan;
    if (loan == null) {
      return [_applyButton(context)];
    }
    return [
      _loanCard(context, loan),
      if (loan.score != null) _scoreCard(context, loan),
      _scheduleCard(context, loan),
      if (loan.canPay && _nextDue != null) ...[
        const SizedBox(height: 14),
        NeuButton(
          label: 'បង់វីនុបទទី ${_nextDue!.installmentNo} · '
              '${money(_nextDue!.remaining)}',
          icon: Icons.payment,
          accent: C.accentGold,
          onPressed: () => _pay(_nextDue!),
        ),
      ],
    ];
  }

  Widget _applyButton(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NeuButton(
          label: 'ស្នើសុំកម្ចី',
          icon: Icons.add_circle_outline,
          accent: C.accent,
          onPressed: () async {
            final done = await push(context, const LoanApplicationFormScreen());
            if (done == true) await _load();
          },
        ),
      );

  LoanScheduleRow? get _nextDue {
    for (final r in _schedule) {
      if (!r.isPaid) return r;
    }
    return null;
  }

  // ---------- KYC ----------
  Widget _kycCard(BuildContext context, LoanKyc? kyc) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeuBox(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Icon(Icons.badge_outlined,
                        color: C.accent, size: 22),
                    const SizedBox(width: 8),
                    Text('បំពេញព័ត៌មាន KYC',
                        style: TextStyle(
                            color: context.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'កម្ចីវីក្រុយត្រូវមានព័ត៌មាន KYC ជាមុនស្នើ។'
                    'បំពេញព័ត៌មានផ្ទាល់ខ្លួន និងព័ត៌មានអាជីវណ៍ '
                    'ដើម្បីឱ្យផ្នែកវាយតម្លៃបានរហូតវិញ។',
                    style:
                        TextStyle(color: context.muted, fontSize: 13, height: 1.6),
                  ),
                  if (kyc != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: kyc.completeness / 100,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        valueColor: const AlwaysStoppedAnimation(C.accent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('ព័ត៌មានបានបំពេញ ${kyc.completeness}%',
                        style: TextStyle(color: context.muted, fontSize: 12)),
                    if (kyc.rejected) ...[
                      const SizedBox(height: 10),
                      Text('ព័ត៌មានត្រូវបានបដិសេធ — សូមកែហើយដាក់ស្នើម្តងទៀត',
                          style: TextStyle(color: C.accentRed, fontSize: 12.5)),
                    ],
                  ],
                  const SizedBox(height: 16),
                  NeuButton(
                    label: kyc == null ? 'បំពេញ KYC' : 'កែព័ត៌មាន KYC',
                    icon: Icons.edit_note,
                    onPressed: () async {
                      await push(context, const LoanKycScreen());
                      await _load();
                    },
                  ),
                ]),
          ),
          const SectionTitle('ដំណើរការស្នើកម្ចី'),
          NeuBox(
            inset: true,
            child: Column(
                children: [
                  for (final (i, s) in loanStages.indexed)
                    InfoRow('${i + 1}. $s', [
                      'បំពេញ KYC រួចចុចស្នើ',
                      'ក្រុមវាយតម្លៃពិនិត្យ',
                      'អនុមត្ត និងបង្កើតតារាងសងប្រាក់',
                      'បញ្ចូលប្រាក់ទៅកាត',
                      'បង់តាមតារាងរៀងរាល់ខែ',
                    ][i]),
                ]),
          ),
        ],
      );

  // ---------- កម្ចីកំពុងដំណើរការ ----------
  Widget _loanCard(BuildContext context, LoanRecord l) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeuBox(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          loanStatusLabels[l.status] ?? l.status,
                          style: TextStyle(
                              color: context.muted, fontSize: 12.5)),
                    ),
                    _statusPill(context, l.status),
                  ]),
                  const SizedBox(height: 6),
                  Text(money(l.principal),
                      style: TextStyle(
                          color: context.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                  Text(
                      '${l.months} ខែ · ${(l.annualRate / 12).toStringAsFixed(1)}% / ខែ · '
                      '${loanMethodLabels[l.interestMethod] ?? l.interestMethod}',
                      style: TextStyle(color: context.muted, fontSize: 12)),
                  const SizedBox(height: 16),
                  _stageBar(context, l),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: l.months == 0 ? 0 : l.paid / l.months,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      valueColor: const AlwaysStoppedAnimation(C.accent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('បង់បាន ${l.paid}/${l.months} វីនុបទ',
                      style: TextStyle(color: context.muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  InfoRow('ប្រាក់/ខែ', money(l.monthlyPayment)),
                  InfoRow('ត្រូវបង់សរុប', money(l.totalPayable)),
                  if (l.outstanding > 0)
                    InfoRow('នៅសល់ត្រូវបង់', money(l.outstanding)),
                  if (l.feeAmount > 0)
                    InfoRow('ថ្លៃសេវកម្ម', money(l.feeAmount)),
                  if (l.firstDueDate != null)
                    InfoRow('បង់ដំបូង', dayLabel(l.firstDueDate!)),
                  if (l.address.isNotEmpty)
                    InfoRow('ទីតាំង', l.address),
                  if (l.rejectReason.isNotEmpty)
                    InfoRow('មូលហេតុបដិសេធ', l.rejectReason),
                  if (l.canPay) ...[
                    const SizedBox(height: 12),
                    Divider(color: context.border, height: 1),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.autorenew,
                          size: 18, color: l.autoDebit ? C.accent : context.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('បង់ស្វត្តកម្ម',
                                  style: TextStyle(
                                      color: context.ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  l.autoDebit
                                      ? 'ដកចំនួនពេលវីនុបទដល់កាលពីកាត'
                                      : 'បើកដើម្បីដកចំនួនពេលវីនុបទដល់កាលពីកាត',
                                  style:
                                      TextStyle(color: context.muted, fontSize: 11.5)),
                            ]),
                      ),
                      Switch(
                        value: l.autoDebit,
                        activeThumbColor: C.accent,
                        inactiveThumbColor: C.accentGreen,
                        onChanged: _toggleAutoDebit,
                      ),
                    ]),
                  ],
                ]),
          ),
        ],
      );

  Widget _stageBar(BuildContext context, LoanRecord l) => Row(
        children: [
          for (final (i, s) in loanStages.indexed) ...[
            Expanded(
              child: Column(children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= l.stage ? C.accent : context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(s,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: i == l.stage
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: i <= l.stage ? context.ink : context.muted)),
              ]),
            ),
            if (i < loanStages.length - 1) const SizedBox(width: 4),
          ],
        ],
      );

  Widget _statusPill(BuildContext context, String status) {
    final color = switch (status) {
      'active' => C.accentGreen,
      'approved' || 'disbursed' => C.accent,
      'rejected' => C.accentRed,
      'submitted' || 'under_review' => C.accentGold,
      _ => context.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(loanStatusLabels[status] ?? status,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ---------- វាយតម្លៃ ----------
  Widget _scoreCard(BuildContext context, LoanRecord l) {
    final score = l.score ?? 0;
    final color = score >= 80
        ? C.accentGreen
        : score >= 65
            ? C.accent
            : score >= 50
                ? C.accentGold
                : C.accentRed;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('លទ្ធផលវាយតម្លៃឥណទិសជាតិ'),
          NeuBox(
            child: Column(children: [
              Row(children: [
                Text('$score',
                    style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(width: 10),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ក្រុម ${l.scoreBand ?? '—'}',
                          style: TextStyle(
                              color: context.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text('CBC: ${l.cbcStatus ?? '—'}',
                          style:
                              TextStyle(color: context.muted, fontSize: 11.5)),
                    ]),
              ]),
            ]),
          ),
        ]);
  }

  // ---------- តារាងសងប្រាក់តាមខែ ----------
  Widget _scheduleCard(BuildContext context, LoanRecord l) {
    final rows = _schedule;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('តារាងសងប្រាក់តាមខែ (${rows.length})'),
          if (rows.isEmpty)
            NeuBox(
              child: Text(
                l.waitingApproval
                    ? 'តារាងសងប្រាក់នឹងបង្កើតក្រង់ពេលកម្ចីត្រូវបានអនុមត្ត'
                    : 'មិនទាន់មានតារាងសងប្រាក់',
                style: TextStyle(color: context.muted, fontSize: 13),
              ),
            )
          else ...[
            NeuBox(
              child: Column(
                children: [
                  for (final r in rows.take(5)) _scheduleRow(context, r),
                  if (rows.length > 5)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => push(
                            context,
                            LoanScheduleScreen(
                                rows: rows, loan: l)),
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: Text('មើលទាំងអស់ ${rows.length} វីនុបទ',
                            style: const TextStyle(color: C.accent)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ]);
  }

  Widget _scheduleRow(BuildContext context, LoanScheduleRow r) {
    final color = r.isPaid
        ? C.accentGreen
        : r.isOverdue
            ? C.accentRed
            : r.isDue
                ? C.accentGold
                : context.muted;
    final label = r.isPaid
        ? 'បានបង់'
        : r.isOverdue
            ? 'ផុត ${r.daysLate} ថ្ងៃ'
            : r.status == 'partial'
                ? 'បានបង់ខ្លះ'
                : 'រង់ចាំ';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: context.border.withValues(alpha: 0.6)))),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: Text('${r.installmentNo}',
              style: TextStyle(
                  color: context.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.dueDate == null
                    ? '—'
                    : dayLabel(r.dueDate!),
                    style: TextStyle(color: context.ink, fontSize: 13)),
                Text(
                    'ប្រាក់ដាក់ ${money(r.principalPart)} · '
                    'កាន្លោះ ${money(r.interestPart)}',
                    style: TextStyle(color: context.muted, fontSize: 11)),
              ]),
        ),
        Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(r.totalDue),
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text(label, style: TextStyle(color: color, fontSize: 10.5)),
            ]),
      ]),
    );
  }

}

// ============================================================
//  LOAN TYPE SCREEN — ប្រភេទប្រាក់កម្ចី
// ============================================================
class _LoanTypeItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconBg;
  final bool enabled;
  const _LoanTypeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBg,
    this.enabled = false,
  });
}

const _loanTypes = [
  _LoanTypeItem(
    id: 'apply',
    title: 'ដាក់ពាក្យស្នើសុំឥណទាន',
    description: 'ប្រាក់កម្ចីសម្រាប់គោលបំណងផ្សេងៗ ដាក់ពាក្យឥឡូវនេះ',
    icon: Icons.handshake_outlined,
    iconBg: Color(0xFF3B9AD9),
    enabled: true,
  ),
  _LoanTypeItem(
    id: 'bnpl',
    title: 'ឥណទាន BNPL',
    description: 'ទិញឥឡូវ បង់ក្រោយ ដោយមិនគិតការប្រាក់ រហូតដល់ ៣ ខែ',
    icon: Icons.shopping_bag_outlined,
    iconBg: Color(0xFFC2185B),
  ),
  _LoanTypeItem(
    id: 'deposit_secured',
    title: 'កម្ចីធានាដោយប្រាក់បញ្ញើ',
    description: 'ប្រាក់បញ្ញើរបស់អ្នកជាធានា អត្រាការប្រាក់ទាប ៥%',
    icon: Icons.savings_outlined,
    iconBg: Color(0xFFF5B83D),
  ),
  _LoanTypeItem(
    id: 'salary',
    title: 'ឥណទានប្រាក់បៀវត្សរ៍',
    description: 'សម្រាប់បុគ្គលិកមានប្រាក់បៀវត្សរ៍ច្បាស់លាស់ រហូតដល់ ៥០ លាន',
    icon: Icons.account_balance_wallet_outlined,
    iconBg: Color(0xFF00897B),
  ),
  _LoanTypeItem(
    id: 'advance_salary',
    title: 'ឥណទានបើកប្រាក់បៀវត្សរ៍មុន',
    description: 'ទទួលប្រាក់បៀវត្សរ៍មុនកាលកំណត់ រហូតដល់ ៥០%',
    icon: Icons.payments_outlined,
    iconBg: Color(0xFF43A047),
  ),
];

class LoanTypeScreen extends StatelessWidget {
  const LoanTypeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('ប្រភេទប្រាក់កម្ចី'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'ព័ត៌មានកម្ចី',
                applicationVersion: '1.0.0',
                children: [
                  Text(
                    'ប្រភេទកម្ចីផ្សេងៗនឹងដាក់ឱ្យប្រើបន្ថែមនៅពេលខាងមុខ។',
                    style: TextStyle(color: context.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.account_balance,
                    size: 64, color: C.accent.withValues(alpha: 0.3)),
              ),
            ),
            const SectionTitle('ប្រភេទប្រាក់កម្ចី'),
            const SizedBox(height: 8),
            for (final t in _loanTypes) _typeCard(context, t),
          ],
        ),
      );

  Widget _typeCard(BuildContext context, _LoanTypeItem t) {
    final enabled = t.enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: enabled
            ? () => push(context, const LoanAmountScreen())
            : () => _showComingSoon(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: enabled ? context.border : context.border.withValues(alpha: 0.4)),
            boxShadow: enabled
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: t.iconBg.withValues(alpha: enabled ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(t.icon,
                  size: 24,
                  color: enabled ? t.iconBg : context.muted.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: enabled ? context.ink : context.muted.withValues(alpha: 0.6))),
                    const SizedBox(height: 3),
                    Text(t.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: enabled ? context.muted : context.muted.withValues(alpha: 0.4),
                            height: 1.4)),
                  ]),
            ),
            const SizedBox(width: 8),
            if (!enabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.muted.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('ឆាប់ៗ',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.muted.withValues(alpha: 0.6))),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: context.muted),
          ]),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.schedule, color: C.accentGold, size: 22),
          const SizedBox(width: 8),
          const Text('មកដល់ឆាប់ៗ', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'ប្រភេទកម្ចីនេះនឹងដាក់ឱ្យប្រើនៅពេលខាងមុខ។ សូមរង់ចាំ!',
          style: TextStyle(color: context.muted, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('យល់ព្រម', style: TextStyle(color: C.accent)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  AMOUNT SELECTOR SCREEN — ជ្រើសរើសចំនួនទឹកប្រាក់
// ============================================================
class LoanAmountScreen extends StatefulWidget {
  const LoanAmountScreen({super.key});
  @override
  State<LoanAmountScreen> createState() => _LoanAmountScreenState();
}

class _LoanAmountScreenState extends State<LoanAmountScreen> {
  double _amount = 3000;
  double _months = 12;
  double _rate = 18;
  String _method = 'annuity';

  bool _quoting = false;
  Map<String, dynamic>? _quote;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _scheduleQuote();
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  void _scheduleQuote() {
    _quoteTimer?.cancel();
    _quoteTimer = Timer(const Duration(milliseconds: 300), _fetchQuote);
  }

  Future<void> _fetchQuote() async {
    setState(() => _quoting = true);
    try {
      final q = await ApiService.loanQuote(
        principal: _amount,
        months: _months.round(),
        annualRate: _rate,
        interestMethod: _method,
      );
      if (mounted) setState(() => _quote = q);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ជ្រើសរើសចំនួនទឹកប្រាក់')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'ជ្រើសរើសចំនួនទឹកប្រាក់ដែលអ្នកចង់ខ្ចី រយៈពេល និងអត្រាការប្រាក់។',
              style: TextStyle(color: context.muted, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
            NeuBox(
              child: Column(children: [
                _slider(context, 'ចំនួនទឹកប្រាក់', money(_amount), _amount, 500,
                    50000, 99, (v) {
                  setState(() => _amount = (v / 500).round() * 500.0);
                  _scheduleQuote();
                }),
                _slider(context, 'រយៈពេល', '${_months.round()} ខែ', _months, 3,
                    60, 57, (v) {
                  setState(() => _months = v);
                  _scheduleQuote();
                }),
                _slider(context, 'អត្រាការប្រាក់', '${_rate.toStringAsFixed(1)}%',
                    _rate, 6, 21.6, 30, (v) {
                  setState(() => _rate = v);
                  _scheduleQuote();
                }),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Text('វិធីគណនា',
                        style: TextStyle(color: context.muted, fontSize: 12.5)),
                  ),
                  ...loanMethodLabels.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _chip(
                          context,
                          e.value,
                          _method == e.key,
                          () {
                            setState(() => _method = e.key);
                            _scheduleQuote();
                          },
                        ),
                      )),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            NeuBox(
              inset: true,
              child: Column(children: [
                Text('បង់ប្រចាំខែ',
                    style: TextStyle(color: context.muted, fontSize: 12)),
                const SizedBox(height: 4),
                if (_quoting && _quote == null)
                  const SizedBox(
                      height: 34,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: C.accent, strokeWidth: 2)))
                else
                  Text(money(_d(_quote?['monthly_payment'])),
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: C.accent)),
                if (_quote != null) ...[
                  const SizedBox(height: 10),
                  InfoRow('ត្រូវបង់សរុប', money(_d(_quote!['total_payable']))),
                  InfoRow('ការប្រាក់សរុប', money(_d(_quote!['total_interest']))),
                  InfoRow('វីនុបទសរុប', '${_i(_quote!['row_count'])} វីនុបទ'),
                ],
              ]),
            ),
            const SizedBox(height: 24),
            NeuButton(
              label: 'បន្ត',
              icon: Icons.arrow_forward,
              onPressed: () async {
                final done = await push(
                  context,
                  LoanKycScreen(
                    initialAmount: _amount,
                    initialMonths: _months.round(),
                    initialRate: _rate,
                    initialMethod: _method,
                  ),
                );
                if (done == true && mounted) Navigator.pop(context, true);
              },
            ),
          ],
        ),
      );

  Widget _chip(BuildContext context, String label, bool active,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? C.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? C.accent : context.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : context.muted)),
        ),
      );

  Widget _slider(BuildContext context, String l, String v, double val,
          double min, double max, int div, ValueChanged<double> on) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l,
                          style:
                              TextStyle(color: context.muted, fontSize: 12.5)),
                      Text(v,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.ink,
                              fontSize: 13)),
                    ]),
                Slider(
                    value: val.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: div,
                    activeColor: C.accent,
                    onChanged: on),
              ]));
}

// ============================================================
//  KYC SCREEN
// ============================================================
class LoanKycScreen extends StatefulWidget {
  const LoanKycScreen({
    super.key,
    this.initialAmount,
    this.initialMonths,
    this.initialRate,
    this.initialMethod,
  });

  final double? initialAmount;
  final int? initialMonths;
  final double? initialRate;
  final String? initialMethod;

  @override
  State<LoanKycScreen> createState() => _LoanKycScreenState();
}

class _LoanKycScreenState extends State<LoanKycScreen> {
  bool _loading = true;
  bool _saving = false;
  IdCardData? _scannedData;

  @override
  void initState() {
    super.initState();
    _load();
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await ApiService.getLoanKyc();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanIdCard() async {
    final result = await push(context, const IdCardScanScreen());
    if (result == null || result is! IdCardData) return;

    setState(() {
      _scannedData = result;
    });

    // ពិនិត្យមើលថាតើអត្តសញ្ញាបណ្ណផុតកំណត់ឬអត់
    if (result.isExpired) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: C.accentRed, size: 28),
                const SizedBox(width: 12),
                Text('អត្តសញ្ញាបណ្ណផុតកំណត់', style: TextStyle(color: context.ink, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              'អត្តសញ្ញាបណ្ណនេះផុតកំណត់ហើយមិនអាចប្រើការបានទេ!\n\nសូមស្កេនអត្តសញ្ញាបណ្ណថ្មី។',
              style: TextStyle(color: context.muted, fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('យល់ហើយ', style: TextStyle(color: C.accent, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      toast(context, 'បានស្កេនអត្តសញ្ញាបណ្ណដោយជោគជ័យ');
    }
  }

  Future<void> _goToContactInfo() async {
    final done = await push(
      context,
      LoanContactScreen(scannedData: _scannedData!, initialAmount: widget.initialAmount,
        initialMonths: widget.initialMonths, initialRate: widget.initialRate,
        initialMethod: widget.initialMethod),
    );
    if (done == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ព័ត៌មាន KYC')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: C.accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  Text(
                    'ស្កេនអត្តសញ្ញាបណ្ណដើម្បីបំពេញព័ត៌មានដោយស្វ័យប្រវត្តិ',
                    style: TextStyle(color: context.muted, fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  NeuBox(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.document_scanner,
                          size: 64,
                          color: _scannedData != null ? C.accentGreen : C.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ស្កេនអត្តសញ្ញាបណ្ណ',
                          style: TextStyle(
                            color: context.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _scannedData != null
                              ? 'បានស្កេនរួចរាល់'
                              : 'ចុចដើម្បីចាប់ផ្តើមស្កេន',
                          style: TextStyle(
                            color: _scannedData != null ? C.accentGreen : context.muted,
                            fontSize: 13,
                          ),
                        ),
                        if (_scannedData != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: C.accentGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _infoRow('ឈ្មោះ', _scannedData!.fullName),
                                const SizedBox(height: 6),
                                _infoRow('លេខអត្តសញ្ញាណ', _scannedData!.idNumber),
                                if (_scannedData!.dob != null)
                                  const SizedBox(height: 6),
                                if (_scannedData!.dob != null)
                                  _infoRow(
                                    'ថ្ងៃកំណើត',
                                    '${_scannedData!.dob!.year}-${_scannedData!.dob!.month.toString().padLeft(2, '0')}-${_scannedData!.dob!.day.toString().padLeft(2, '0')}',
                                  ),
                                if (_scannedData!.birthPlace != null && _scannedData!.birthPlace!.isNotEmpty)
                                  const SizedBox(height: 6),
                                if (_scannedData!.birthPlace != null && _scannedData!.birthPlace!.isNotEmpty)
                                  _infoRow('ទីកន្លែងកំណើត', _scannedData!.birthPlace!),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        NeuButton(
                          label: _scannedData != null ? 'ស្កេនឡើងវិញ' : 'ចាប់ផ្តើមស្កេន',
                          icon: _scannedData != null ? Icons.refresh : Icons.document_scanner,
                          accent: C.accent,
                          onPressed: _scanIdCard,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  NeuButton(
                    label: _scannedData == null
                        ? 'ស្កេនអត្តសញ្ញាបណ្ណជាមុន'
                        : (_scannedData!.isExpired ? 'អត្តសញ្ញាបណ្ណផុតកំណត់' : 'បន្ត'),
                    icon: _scannedData == null
                        ? Icons.document_scanner
                        : (_scannedData!.isExpired ? Icons.error_outline : Icons.arrow_forward),
                    accent: (_scannedData != null && !_scannedData!.isExpired) ? C.accentGreen : context.muted,
                    onPressed: (_scannedData == null || _saving || _scannedData!.isExpired) ? null : () => _goToContactInfo(),
                  ),
                ],
              ),
      );

  Widget _infoRow(String label, String value) => Row(
        children: [
          Text('$label: ', style: TextStyle(color: context.muted, fontSize: 12)),
          Expanded(
            child: Text(value, style: TextStyle(color: context.ink, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      );
}

// ============================================================
//  CONTACT INFO SCREEN — លេខទូរស័ព្ទ + អាសយដ្ឋាន
// ============================================================
class LoanContactScreen extends StatefulWidget {
  const LoanContactScreen({
    super.key,
    required this.scannedData,
    this.initialAmount,
    this.initialMonths,
    this.initialRate,
    this.initialMethod,
  });

  final IdCardData scannedData;
  final double? initialAmount;
  final int? initialMonths;
  final double? initialRate;
  final String? initialMethod;

  @override
  State<LoanContactScreen> createState() => _LoanContactScreenState();
}

class _LoanContactScreenState extends State<LoanContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _saving = false;
  List<RegionProvince> _provinces = [];
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedCommune;
  String? _selectedVillage;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await loadRegionData();
      if (mounted) setState(() => _provinces = regions);
    } catch (e) {
      // Silently fail
    }
  }

  List<RegionDistrict> _getDistricts() {
    if (_selectedProvince == null) return [];
    return _provinces.firstWhere((p) => p.name == _selectedProvince).districts;
  }

  List<RegionCommune> _getCommunes() {
    if (_selectedDistrict == null) return [];
    return _getDistricts().firstWhere((d) => d.name == _selectedDistrict).communes;
  }

  List<String> _getVillages() {
    if (_selectedCommune == null) return [];
    return _getCommunes().firstWhere((c) => c.name == _selectedCommune).villages;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null || _selectedDistrict == null ||
        _selectedCommune == null || _selectedVillage == null) {
      toast(context, 'សូមបំពេញអាសយដ្ឋានឱ្យបានគ្រប់គ្រាន់', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final dobStr = widget.scannedData.dob != null
          ? '${widget.scannedData.dob!.year}-${widget.scannedData.dob!.month.toString().padLeft(2, '0')}-${widget.scannedData.dob!.day.toString().padLeft(2, '0')}'
          : '';

      final payload = {
        'full_name': widget.scannedData.fullName,
        'national_id': widget.scannedData.idNumber,
        'dob': dobStr,
        'gender': widget.scannedData.gender,
        'phone': _phoneController.text.trim(),
        'province': _selectedProvince ?? '',
        'district': _selectedDistrict ?? '',
        'commune': _selectedCommune ?? '',
        'village': _selectedVillage ?? '',
        'birth_place': widget.scannedData.birthPlace ?? '',
        'occupation': '',
        'business_name': '',
        'business_type': '',
        'business_years': 0,
        'monthly_income': 0,
        'monthly_expense': 0,
        'existing_debt': 0,
        'bank_name': '',
        'bank_account': '',
      };
      await ApiService.saveLoanKyc(payload, submit: true);
      if (!mounted) return;

      if (widget.initialAmount != null) {
        await ApiService.applyLoan(
          principal: widget.initialAmount!,
          months: widget.initialMonths ?? 12,
          annualRate: widget.initialRate ?? 18,
          interestMethod: widget.initialMethod ?? 'annuity',
          province: _selectedProvince ?? '',
          district: _selectedDistrict ?? '',
          commune: _selectedCommune ?? '',
          village: _selectedVillage ?? '',
          purpose: '',
        );
        if (!mounted) return;
        toast(context, 'បានដាក់ស្នើសាកលកម្មកម្ចី');
        Navigator.pop(context, true);
      } else {
        toast(context, 'បានដាក់ស្នើព័ត៌មាន KYC');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ព័ត៌មានទំនាក់ទំនង')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // Scanned info summary
              NeuBox(
                inset: true,
                child: Column(
                  children: [
                    _infoRow('ឈ្មោះ', widget.scannedData.fullName),
                    const SizedBox(height: 6),
                    _infoRow('លេខអត្តសញ្ញាណ', widget.scannedData.idNumber),
                    if (widget.scannedData.dob != null) ...[
                      const SizedBox(height: 6),
                      _infoRow('ថ្ងៃកំណើត',
                          '${widget.scannedData.dob!.year}-${widget.scannedData.dob!.month.toString().padLeft(2, '0')}-${widget.scannedData.dob!.day.toString().padLeft(2, '0')}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Phone
              const SectionTitle('លេខទូរស័ព្ទ'),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeuField(
                  controller: _phoneController,
                  label: 'លេខទូរស័ព្ទ',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'ត្រូវបំពេញ' : null,
                ),
              ),

              // Address
              const SectionTitle('អាសយដ្ឋាន'),
              _regionDropdown(
                'ខេត្ត/ក្រុង',
                _provinces.map((p) => p.name).toList(),
                _selectedProvince,
                (val) => setState(() {
                  _selectedProvince = val;
                  _selectedDistrict = null;
                  _selectedCommune = null;
                  _selectedVillage = null;
                }),
              ),
              if (_selectedProvince != null)
                _regionDropdown(
                  'ស្រុក/ខណ្ឌ',
                  _getDistricts().map((d) => d.name).toList(),
                  _selectedDistrict,
                  (val) => setState(() {
                    _selectedDistrict = val;
                    _selectedCommune = null;
                    _selectedVillage = null;
                  }),
                ),
              if (_selectedDistrict != null)
                _regionDropdown(
                  'ឃុំ/សង្កាត់',
                  _getCommunes().map((c) => c.name).toList(),
                  _selectedCommune,
                  (val) => setState(() {
                    _selectedCommune = val;
                    _selectedVillage = null;
                  }),
                ),
              if (_selectedCommune != null)
                _regionDropdown(
                  'ភូមិ',
                  _getVillages(),
                  _selectedVillage,
                  (val) => setState(() => _selectedVillage = val),
                ),

              const SizedBox(height: 20),
              NeuButton(
                label: _saving ? 'កំពុងដាក់ស្នើ...' : 'ដាក់ស្នើកម្ចី',
                icon: Icons.verified_user,
                accent: C.accentGreen,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      );

  Widget _infoRow(String label, String value) => Row(
        children: [
          Text('$label: ', style: TextStyle(color: context.muted, fontSize: 12)),
          Expanded(child: Text(value, style: TextStyle(color: context.ink, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      );

  Widget _regionDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          suffix: Text('*', style: TextStyle(color: C.accentRed)),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        validator: (v) => v == null ? 'សូមជ្រើសរើស' : null,
      ),
    );
  }
}

// ============================================================
//  APPLICATION SCREEN — ទីតាំង + ប្រាក់ប្រាក់ → ដាក់ស្នើ
// ============================================================
class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({
    super.key,
    this.initialAmount = 3000,
    this.initialMonths = 12,
    this.initialRate = 18,
    this.initialMethod = 'annuity',
  });

  final double initialAmount;
  final int initialMonths;
  final double initialRate;
  final String initialMethod;

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  late Future<List<RegionProvince>> _regions = loadRegionData();
  int _step = 0;
  RegionProvince? _province;
  RegionDistrict? _district;
  RegionCommune? _commune;
  String? _village;
  String _query = '';
  final _purpose = TextEditingController();

  late double _amount = widget.initialAmount;
  late double _months = widget.initialMonths.toDouble();
  late double _rate = widget.initialRate;
  late String _method = widget.initialMethod;

  bool _submitting = false;
  Map<String, dynamic>? _quote;

  static const _labels = ['ខេត្ត', 'ស្រុក', 'ឃុឆ', 'ភូមិ', 'កម្ចី'];

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _fetchQuote() async {
    try {
      final q = await ApiService.loanQuote(
        principal: _amount,
        months: _months.round(),
        annualRate: _rate,
        interestMethod: _method,
      );
      if (mounted) setState(() => _quote = q);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _query = '';
      if (_step == 4) {
        _step = 3;
        _village = null;
      } else if (_step == 3) {
        _step = 2;
        _commune = null;
        _village = null;
      } else if (_step == 2) {
        _step = 1;
        _district = null;
        _commune = null;
        _village = null;
      } else {
        _step = 0;
        _province = null;
        _district = null;
        _commune = null;
        _village = null;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ApiService.applyLoan(
        principal: _amount,
        months: _months.round(),
        annualRate: _rate,
        interestMethod: _method,
        province: _province!.name,
        district: _district!.name,
        commune: _commune!.name,
        village: _village!,
        purpose: _purpose.text.trim(),
      );
      if (!mounted) return;
      toast(context, 'បានដាក់ស្នើសាកលកម្មកម្ចី');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _path => [_province?.name, _district?.name, _commune?.name]
      .whereType<String>().join(' › ');

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            leading:
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
            title: const Text('ស្នើសុំកម្ចី'),
          ),
          body: FutureBuilder<List<RegionProvince>>(
            future: _regions,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('មិនអាចអានទិន្នន័យទីតាំង',
                      style: TextStyle(color: context.muted)),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: () =>
                          setState(() => _regions = loadRegionData()),
                      child: const Text('ព្យាយាមម្តងទៀត',
                          style: TextStyle(color: C.accent))),
                ]));
              }
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: C.accent));
              }
              return Column(children: [
                _progress(context),
                Expanded(child: _step < 4
                    ? _currentStep(snap.data!)
                    : _amountStep(context)),
              ]);
            },
          ),
        ),
      );

  Widget _progress(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Column(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: (_step + 1) / 5,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation(C.accent))),
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                  child: Column(children: [
                Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= _step ? C.accent : Colors.transparent,
                        border: Border.all(
                            color: i <= _step ? C.accent : context.border)),
                    child: i < _step
                        ? const Icon(Icons.check,
                            size: 13, color: Colors.white)
                        : Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: i == _step
                                        ? Colors.white
                                        : context.muted)))),
                const SizedBox(height: 4),
                Text(_labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: i == _step
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: i <= _step ? context.ink : context.muted)),
              ])),
          ]),
        ]),
      );

  Widget _currentStep(List<RegionProvince> data) {
    switch (_step) {
      case 0:
        return _stepList(context, 'ជ្រើសរើសខេត្ត/ក្រុង',
            [for (final p in data) p.name], (i) {
          setState(() {
            _province = data[i];
            _step = 1;
            _query = '';
          });
        });
      case 1:
        final list = _province!.districts;
        return _stepList(context, 'ជ្រើសរើសស្រុក/ខណ្ឌ',
            [for (final d in list) d.name], (i) {
          setState(() {
            _district = list[i];
            _step = 2;
            _query = '';
          });
        });
      case 2:
        final list = _district!.communes;
        return _stepList(context, 'ជ្រើសរើសឃុឆ/សង្កាត់',
            [for (final c in list) c.name], (i) {
          setState(() {
            _commune = list[i];
            _step = 3;
            _query = '';
          });
        });
      default:
        final list = _commune!.villages;
        return _stepList(context, 'ជ្រើសរើសភូមិ', list, (i) {
          setState(() {
            _village = list[i];
            _step = 4;
            _query = '';
          });
        });
    }
  }

  Widget _stepList(BuildContext context, String title, List<String> names,
      ValueChanged<int> onPick) {
    final q = _query.trim();
    final hits = [
      for (var i = 0; i < names.length; i++)
        if (q.isEmpty || names[i].contains(q)) i
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: context.ink)),
          const SizedBox(height: 3),
          Text(
              _path.isEmpty
                  ? 'ជំហាន ${_step + 1} ក្នុង 5'
                  : 'ជំហាន ${_step + 1} ក្នុង 5 · $_path',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.muted, fontSize: 11.5)),
          if (names.length > 4) ...[
            const SizedBox(height: 12),
            NeuField(
                key: ValueKey('search-$_step'),
                label: 'ស្វែងរក',
                icon: Icons.search,
                onChanged: (v) => setState(() => _query = v)),
          ],
        ]),
      ),
      Expanded(
          child: hits.isEmpty
              ? Center(
                  child: Text('រកមិនឃើញ',
                      style: TextStyle(color: context.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: hits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, k) {
                    final name = names[hits[k]];
                    return NeuBox(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        onTap: () => onPick(hits[k]),
                        child: Row(children: [
                          Expanded(
                              child: Text(name,
                                  style: TextStyle(
                                      color: context.ink,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500))),
                          Icon(Icons.chevron_right,
                              size: 18, color: context.muted),
                        ]));
                  })),
    ]);
  }

  Widget _amountStep(BuildContext context) {
    final q = _quote;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SectionTitle('ទីតាំងរបស់អ្នក'),
          NeuBox(
              inset: true,
              child: Column(children: [
                InfoRow('ខេត្ត/ក្រុង', _province!.name),
                InfoRow('ស្រុក/ខណ្ឌ', _district!.name),
                InfoRow('ឃុឆ/សង្កាត់', _commune!.name),
                InfoRow('ភូមិ', _village!),
              ])),
          const SectionTitle('ចំនួនទឹកប្រាក់'),
          NeuBox(
              child: Column(children: [
                _slider(context, 'ចំនួន', money(_amount), _amount, 500, 50000,
                    99, (v) {
                  setState(() => _amount = (v / 500).round() * 500.0);
                  _fetchQuote();
                }),
                _slider(context, 'រយៈពេល', '${_months.round()} ខែ', _months, 3,
                    60, 57, (v) {
                  setState(() => _months = v);
                  _fetchQuote();
                }),
                _slider(context, 'អត្រា', '${_rate.toStringAsFixed(1)}%', _rate, 6,
                    21.6, 30, (v) {
                  setState(() => _rate = v);
                  _fetchQuote();
                }),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: Text('វិធីគណនា',
                          style:
                              TextStyle(color: context.muted, fontSize: 12.5))),
                  ...loanMethodLabels.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _method = e.key);
                            _fetchQuote();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: _method == e.key
                                  ? C.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: _method == e.key
                                      ? C.accent
                                      : context.border),
                            ),
                            child: Text(e.value,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _method == e.key
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _method == e.key
                                        ? Colors.white
                                        : context.muted)),
                          ),
                        ),
                      )),
                ]),
              ])),
          const SectionTitle('គងសេចក្តីប្រើ'),
          NeuField(
            controller: _purpose,
            label: 'គងសេចក្តីប្រើទឹកប្រាក់',
            icon: Icons.savings_outlined,
          ),
          const SizedBox(height: 14),
          NeuBox(
              inset: true,
              child: Column(children: [
                Text('បង់ប្រចាំខែ',
                    style: TextStyle(color: context.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(money(_d(q?['monthly_payment'])),
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800, color: C.accent)),
                if (q != null) ...[
                  const SizedBox(height: 8),
                  InfoRow('ត្រូវបង់សរុប', money(_d(q['total_payable']))),
                  InfoRow('វីនុបទ', '${_i(q['row_count'])} វីនុបទ'),
                ],
              ])),
          const SizedBox(height: 20),
          NeuButton(
              label: _submitting ? 'កំពុងផ្ញើ...' : 'ផ្ញើសំណើ',
              icon: Icons.request_quote,
              onPressed: _submitting ? null : _submit),
        ]);
  }

  Widget _slider(BuildContext context, String l, String v, double val,
          double min, double max, int div, ValueChanged<double> on) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l,
                          style:
                              TextStyle(color: context.muted, fontSize: 12.5)),
                      Text(v,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.ink,
                              fontSize: 13)),
                    ]),
                Slider(
                    value: val.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: div,
                    activeColor: C.accent,
                    onChanged: on),
              ]));
}

// ============================================================
//  SCHEDULE SCREEN — តារាងសងប្រាក់ទាំងអស់
// ============================================================
class LoanScheduleScreen extends StatelessWidget {
  const LoanScheduleScreen({super.key, required this.rows, required this.loan});

  final List<LoanScheduleRow> rows;
  final LoanRecord loan;

  @override
  Widget build(BuildContext context) {
    final paid = rows.where((r) => r.isPaid).length;
    return Scaffold(
      appBar: AppBar(title: const Text('តារាងសងប្រាក់តាមខែ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          NeuBox(
            inset: true,
            child: Column(children: [
              InfoRow('ចំនួនប្រាក់', money(loan.principal)),
              InfoRow('ប្រាក់/ខែ', money(loan.monthlyPayment)),
              InfoRow('ត្រូវបង់សរុប', money(loan.totalPayable)),
              InfoRow('បានបង់', '$paid/${loan.months} វីនុបទ'),
              if (loan.outstanding > 0)
                InfoRow('នៅសល់', money(loan.outstanding)),
            ]),
          ),
          const SizedBox(height: 14),
          NeuBox(
            child: Column(
              children: [
                for (final r in rows) _row(context, r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, LoanScheduleRow r) {
    final color = r.isPaid
        ? C.accentGreen
        : r.isOverdue
            ? C.accentRed
            : r.isDue
                ? C.accentGold
                : context.muted;
    final label = r.isPaid
        ? 'បានបង់'
        : r.isOverdue
            ? 'ផុត ${r.daysLate} ថ្ងៃ'
            : r.status == 'partial'
                ? 'បានបង់ខ្លះ'
                : 'រង់ចាំ';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
          border: Border(
              bottom:
                  BorderSide(color: context.border.withValues(alpha: 0.6)))),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: Text('${r.installmentNo}',
              style: TextStyle(
                  color: context.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.dueDate == null ? '—' : dayLabel(r.dueDate!),
                    style: TextStyle(color: context.ink, fontSize: 13)),
                Text(
                    'ប្រាក់ដាក់ ${money(r.principalPart)} · '
                    'កាន្លោះ ${money(r.interestPart)}',
                    style: TextStyle(color: context.muted, fontSize: 11)),
              ]),
        ),
        Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(r.totalDue),
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text(label, style: TextStyle(color: color, fontSize: 10.5)),
            ]),
      ]),
    );
  }
}

// ============================================================
//  REGION DATA — ខេត្ត → ស្រុក → ឃុឆ → ភូមិ
// ============================================================
class RegionProvince {
  final String code, name;
  final List<RegionDistrict> districts;
  RegionProvince(this.code, this.name, this.districts);
  factory RegionProvince.fromJson(Map<String, dynamic> j) => RegionProvince(
      j['c'] as String,
      j['n'] as String,
      [
        for (final d in j['d'] as List)
          RegionDistrict.fromJson(Map<String, dynamic>.from(d as Map))
      ]);
}

class RegionDistrict {
  final String code, name;
  final List<RegionCommune> communes;
  RegionDistrict(this.code, this.name, this.communes);
  factory RegionDistrict.fromJson(Map<String, dynamic> j) => RegionDistrict(
      j['c'] as String,
      j['n'] as String,
      [
        for (final m in j['m'] as List)
          RegionCommune.fromJson(Map<String, dynamic>.from(m as Map))
      ]);
}

class RegionCommune {
  final String code, name;
  final List<String> villages;
  RegionCommune(this.code, this.name, this.villages);
  factory RegionCommune.fromJson(Map<String, dynamic> j) => RegionCommune(
      j['c'] as String, j['n'] as String, List<String>.from(j['v'] as List));
}

Future<List<RegionProvince>> loadRegionData() async {
  final raw = await rootBundle.loadString('assets/data/cambodia_admin.json');
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final p in j['p'] as List)
      RegionProvince.fromJson(Map<String, dynamic>.from(p as Map))
  ];
}
