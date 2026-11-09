// ============================================================================
//  LOAN SUMMARY / CONFIRMATION SCREEN — បញ្ជាក់ការស្នើសុំឥណទាន
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../api_service.dart';
import '../loan_form_data.dart';
import 'loan_receipt_screen.dart';
import 'loan_privacy_screen.dart';

class LoanSummaryScreen extends StatefulWidget {
  final LoanFormData formData;
  const LoanSummaryScreen({super.key, required this.formData});
  @override
  State<LoanSummaryScreen> createState() => _LoanSummaryScreenState();
}

class _LoanSummaryScreenState extends State<LoanSummaryScreen> {
  bool _submitting = false;
  bool _agreed = false;
  late final String _refNumber;
  late final DateTime _createdAt;

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
    _refNumber = 'LN${_createdAt.millisecondsSinceEpoch % 1000000000}';
  }

  Future<void> _openPrivacy() async {
    final result = await push(context, const LoanPrivacyScreen());
    if (result == true && mounted) setState(() => _agreed = true);
  }

  Future<void> _onConfirm() async {
    if (!_agreed) {
      toast(context, 'សូមយល់ព្រមតាមលក្ខខណ្ឌជាមុនសិន', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.saveLoanKyc(widget.formData.toKycPayload(), submit: true);
      final response = await ApiService.applyLoan(
        principal: widget.formData.amount,
        months: widget.formData.durationMonths ?? 12,
        annualRate: 21.6,
        interestMethod: 'annuity',
        province: widget.formData.province ?? '',
        district: widget.formData.district ?? '',
        commune: widget.formData.commune ?? '',
        village: widget.formData.village ?? '',
        purpose: widget.formData.loanTarget ?? '',
      );
      widget.formData.referenceNumber = _refNumber;
      widget.formData.loanResponse = response;
      if (mounted) {
        Navigator.pop(context);
        push(context, LoanReceiptScreen(formData: widget.formData));
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, 'មានកំហុស: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.formData;
    final months = data.durationMonths ?? 12;
    final r = 21.6 / 100 / 12;
    final monthly =
        data.amount > 0 ? data.amount * r / (1 - math.pow(1 + r, -months)) : 0.0;
    final totalPayable = monthly * months;
    final totalInterest = totalPayable - data.amount;
    final amountStr = data.currency == 'KHR'
        ? '${_fmt(data.amount)} រៀល'
        : '\$${_fmt(data.amount)}';

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('បញ្ជាក់ការស្នើសុំ'),
        backgroundColor: context.bg,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'ចែករំលែក',
            icon: Icon(Icons.ios_share_rounded, color: context.muted),
            onPressed: _showShareSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildHero(amountStr, data.loanTarget),
          const SizedBox(height: 16),
          _buildLoanCard(data, months, monthly, totalInterest, totalPayable),
          const SizedBox(height: 12),
          _buildApplicantCard(data),
          const SizedBox(height: 12),
          _buildAddressCard(data),
          const SizedBox(height: 12),
          _buildReferenceCard(),
          const SizedBox(height: 16),
          _buildConsentCard(),
          const SizedBox(height: 12),
          _buildNote(),
        ],
      ),
      bottomNavigationBar: _buildConfirmBar(),
    );
  }

  // --------------------------------------------------------------------------
  Widget _buildHero(String amountStr, String? target) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        gradient: AuraGrad.button,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: C.accent.withValues(alpha: 0.4),
            blurRadius: 26,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.fact_check_rounded,
                size: 140, color: Colors.white.withValues(alpha: 0.10)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Text('ជំហានចុងក្រោយ · ផ្ទៀងផ្ទាត់',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              const Text('ពិនិត្យព័ត៌មានឥណទាន',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'សូមពិនិត្យព័ត៌មានខាងក្រោមឱ្យបានត្រឹមត្រូវ មុននឹងបញ្ជាក់ការស្នើសុំ',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ចំនួនឥណទាន',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(amountStr,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: C.accentGreen.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: C.accentGreen.withValues(alpha: 0.5)),
                      ),
                      child: Text(target ?? 'កម្ចី',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(String title, IconData icon, Widget child) {
    return NeuBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    C.accent.withValues(alpha: 0.22),
                    C.accent.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: C.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: C.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildLoanCard(LoanFormData data, int months, double monthly,
      double totalInterest, double totalPayable) {
    return _card('ព័ត៌មានឥណទាន', Icons.account_balance_wallet_rounded,
        Column(
      children: [
        _row('ចំនួនឥណទាន', '\$${_fmt(data.amount)}'),
        _row('រយៈពេល', '$months ខែ'),
        _row('គោលដៅឥណទាន', data.loanTarget ?? 'កម្ចី'),
        _row('អត្រាការប្រាក់', '21.6% / ឆ្នាំ'),
        _row('វិធីគិតការប្រាក់', 'បង់ស្មើគ្នា (Annuity)'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              C.accent.withValues(alpha: 0.16),
              C.accentPurple.withValues(alpha: 0.10),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: C.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('ការបង់ប្រចាំខែ',
                    style: TextStyle(
                        color: context.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
              ),
              Text('\$${_fmt(monthly)}',
                  style: const TextStyle(
                      color: C.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _row('ការប្រាក់សរុប', '\$${_fmt(totalInterest)}'),
        _row('ចំនួនសងសរុប', '\$${_fmt(totalPayable)}', bold: true),
      ],
    ));
  }

  Widget _buildApplicantCard(LoanFormData data) {
    final id = data.scannedId;
    final name = data.fullName ?? id?.fullName ?? '-';
    final nationalId = data.nationalId ?? id?.idNumber ?? '-';
    return _card('ព័ត៌មានអត្តសញ្ញាណ', Icons.badge_rounded, Column(
      children: [
        _row('ឈ្មោះពេញ', name),
        _row('លេខអត្តសញ្ញាណ', nationalId),
        if (id != null && id.gender.isNotEmpty) _row('ភេទ', id.gender),
        if (id?.dob != null) _row('ថ្ងៃខែឆ្នាំកំណើត', _fmtDate(id!.dob!)),
        if (id?.birthPlace != null && id!.birthPlace!.isNotEmpty)
          _row('ទីកន្លែងកំណើត', id.birthPlace!),
        if (data.phone != null && data.phone!.isNotEmpty)
          _row('លេខទូរស័ព្ទ', data.phone!),
      ],
    ));
  }

  Widget _buildAddressCard(LoanFormData data) {
    return _card('អាសយដ្ឋានបច្ចុប្បន្ន', Icons.location_on_rounded, Column(
      children: [
        _row('ខេត្ត/ក្រុង', data.province ?? '-'),
        _row('ស្រុក/ខណ្ឌ', data.district ?? '-'),
        _row('ឃុំ/សង្កាត់', data.commune ?? '-'),
        _row('ភូមិ', data.village ?? '-'),
      ],
    ));
  }

  Widget _buildReferenceCard() {
    return _card('ព័ត៌មានយោង', Icons.receipt_long_rounded, Column(
      children: [
        _row('លេខយោង', _refNumber),
        _row('កាលបរិច្ឆេទ',
            '${_fmtDate(_createdAt)} ${_fmtTime(_createdAt)}'),
        _row('សាខា', 'សាខាកណ្ដាល'),
        _row('ស្ថានភាព', 'រង់ចាំបញ្ជាក់'),
      ],
    ));
  }

  Widget _buildConsentCard() {
    return NeuBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          InkWell(
            onTap: _openPrivacy,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: C.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: C.accentGreen.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.privacy_tip_rounded,
                        color: C.accentGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'គោលការណ៍ឯកជនភាព និងលក្ខខណ្ឌសេវាកម្ម',
                      style: TextStyle(
                        color: C.accent,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: C.accent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.muted),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(height: 1, color: context.border),
          ),
          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 1, right: 12),
                  decoration: BoxDecoration(
                    gradient: _agreed ? AuraGrad.button : null,
                    color: _agreed ? null : context.surface,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: _agreed ? C.accent : context.border,
                      width: 1.4,
                    ),
                  ),
                  child: _agreed
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 17)
                      : null,
                ),
                Expanded(
                  child: Text(
                    'ខ្ញុំបានអាន និងយល់ព្រមតាម គោលការណ៍ឯកជនភាព និងលក្ខខណ្ឌសេវាកម្ម របស់ Aura Bank។',
                    style: TextStyle(
                        color: context.ink, fontSize: 12.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.accentGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.accentGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, color: C.accentGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ពាក្យស្នើសុំរបស់អ្នកនឹងត្រូវបានពិនិត្យ និងដំណើរការក្នុងរយៈពេល ១-២ ថ្ងៃការងារ។',
              style: TextStyle(color: context.ink, fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmBar() {
    final enabled = _agreed && !_submitting;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.bg,
        border: Border(top: BorderSide(color: context.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: enabled ? _onConfirm : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 54,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: enabled ? AuraGrad.button : null,
                color: enabled ? null : context.surface,
                borderRadius: BorderRadius.circular(14),
                border: enabled ? null : Border.all(color: context.border),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: C.accent.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -8,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded,
                              color: enabled ? Colors.white : context.muted,
                              size: 20),
                          const SizedBox(width: 8),
                          Text('បញ្ជាក់ការស្នើសុំ',
                              style: TextStyle(
                                color: enabled ? Colors.white : context.muted,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
              ),
            ),
          ),
          if (!_agreed) ...[
            const SizedBox(height: 8),
            Text('សូមធីកយល់ព្រមលក្ខខណ្ឌជាមុនសិន',
                style: TextStyle(color: context.muted, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label,
                style: TextStyle(color: context.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.ink,
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  void _showShareSheet() {
    final data = widget.formData;
    final amountStr =
        data.currency == 'KHR' ? '${_fmt(data.amount)} រៀល' : '\$${_fmt(data.amount)}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: context.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('ចែករំលែកព័ត៌មានកម្ចី',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.ink)),
            const SizedBox(height: 20),
            _shareOption(Icons.copy_rounded, 'ចម្លងលេខយោង', () {
              _copy(_refNumber);
              Navigator.pop(context);
            }),
            _shareOption(Icons.receipt_long_rounded, 'ចម្លងព័ត៌មានកម្ចី', () {
              final info =
                  'AURA Bank - ព័ត៌មានកម្ចី\nលេខយោង: $_refNumber\nចំនួន: $amountStr\nរយៈពេល: ${data.durationMonths ?? 0} ខែ\nគោលដៅឥណទាន: ${data.loanTarget ?? 'កម្ចី'}';
              _copy(info);
              Navigator.pop(context);
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: C.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: C.accent, size: 22),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: context.ink)),
      trailing: Icon(Icons.chevron_right, color: context.muted),
      onTap: onTap,
    );
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    toast(context, 'បានចម្លងទៅ clipboard');
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
