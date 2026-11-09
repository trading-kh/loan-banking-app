// ============================================================================
//  LOAN RECEIPT SCREEN — បង្កាន់ដៃឥណទាន
//  ACLEDA Bank style
// ============================================================================
import 'package:flutter/material.dart';

import '../main.dart';
import '../loan_form_data.dart';

class LoanReceiptScreen extends StatelessWidget {
  final LoanFormData formData;
  const LoanReceiptScreen({super.key, required this.formData});
  @override
  Widget build(BuildContext context) {
    final amountStr = formData.currency == 'KHR'
        ? '${_formatMoney(formData.amount)} រៀល'
        : '\$${_formatMoney(formData.amount)}';

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),

            // Success Icon
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: C.accentGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: C.accentGreen,
                    size: 48,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Center(
              child: Text(
                'បានដាក់ស្នើជោគជ័យ',
                style: TextStyle(
                  color: context.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'ពាក្យស្នើសុំរបស់អ្នកត្រូវបានទទួល',
                style: TextStyle(
                  color: context.muted,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Amount Card
            NeuBox(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'ចំនួនឥណទាន',
                    style: TextStyle(
                      color: context.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amountStr,
                    style: TextStyle(
                      color: C.accentGreen,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formData.loanTarget ?? 'ឥណទានគោលដៅ',
                    style: TextStyle(
                      color: context.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Details Card
            NeuBox(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _detailRow(context, 'លេខយោង', formData.referenceNumber ?? '-'),
                  const Divider(height: 24),
                  _detailRow(context, 'កាលបរិច្ឆេទ', dateStr),
                  const Divider(height: 24),
                  _detailRow(context, 'រយៈពេល', '${formData.durationMonths ?? 0} ខែ'),
                  const Divider(height: 24),
                  _detailRow(context, 'គោលដៅឥណទាន', formData.loanTarget ?? 'កម្ចី'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tracking link
            GestureDetector(
              onTap: () {
                Navigator.popUntil(context, (route) => route.isFirst);
                tabIndex.value = 3;
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      C.accent.withValues(alpha: 0.16),
                      C.accentGreen.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: C.accent.withValues(alpha: 0.32)),
                  boxShadow: [
                    BoxShadow(
                        color: C.accent.withValues(alpha: 0.14),
                        offset: const Offset(0, 8),
                        blurRadius: 22,
                        spreadRadius: -6),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AuraGrad.button,
                            boxShadow: [
                              BoxShadow(
                                  color: C.accent.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  spreadRadius: -4),
                            ],
                          ),
                          child: const Icon(Icons.track_changes_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ការស្នើសុំរបស់លោកអ្នកជោគជ័យហើយ',
                            style: TextStyle(
                              color: context.ink,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: C.accent, size: 22),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ចុចដើម្បីមើលដំណើរការ និងជំហាននីមួយៗរបស់ឥណទាន',
                      style: TextStyle(
                          color: context.muted, fontSize: 11.5, height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: C.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.route_rounded,
                              color: C.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'តាមដាន',
                            style: TextStyle(
                              color: C.accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_forward_rounded,
                              color: C.accent, size: 17),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Done Button
            NeuButton(
              label: 'រួចរាល់',
              icon: Icons.home,
              accent: C.accent,
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(color: context.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
