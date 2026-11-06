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
                  _detailRow(context, 'គោលបំណង', formData.purpose),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notification
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: C.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: C.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ពាក្យស្នើសុំរបស់អ្នកត្រូវបានទទួល ហើយនឹងត្រូវពិនិត្យក្នុងរយៈពេល ៣-៥ ថ្ងៃធ្វើការ',
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
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
