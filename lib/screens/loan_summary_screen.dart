// ============================================================================
//  LOAN SUMMARY SCREEN
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../api_service.dart';
import '../loan_form_data.dart';
import 'loan_receipt_screen.dart';

class LoanSummaryScreen extends StatefulWidget {
  final LoanFormData formData;
  const LoanSummaryScreen({super.key, required this.formData});
  @override
  State<LoanSummaryScreen> createState() => _LoanSummaryScreenState();
}

class _LoanSummaryScreenState extends State<LoanSummaryScreen> {
  bool _submitting = false;

  Future<void> _onConfirm() async {
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
      final ref = 'LN${DateTime.now().millisecondsSinceEpoch % 1000000000}';
      widget.formData.referenceNumber = ref;
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
    final amountStr = data.currency == 'KHR'
        ? '${_formatMoney(data.amount)} រៀល'
        : '\$${_formatMoney(data.amount)}';
    final refNumber = 'LN${DateTime.now().millisecondsSinceEpoch % 1000000000}';
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066CC),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF0066CC).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.handshake, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('បានស្នើឥណទាន', style: TextStyle(color: Color(0xFF333333), fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                Text(amountStr, style: const TextStyle(color: Color(0xFF00AA44), fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                  child: Text(data.loanTarget ?? 'កម្ចី', style: const TextStyle(color: Color(0xFF00AA44), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('សាខា', 'សាខាកណ្ដាល'),
                _divider(),
                _detailRow('លេខយោង', refNumber),
                _divider(),
                _detailRow('កាលបរិច្ឆេទ', '$dateStr $timeStr'),
                _divider(),
                _detailRow('រយៈពេល', '${data.durationMonths ?? 0} ខែ'),
                _divider(),
                _detailRow('គោលដៅឥណទាន', data.loanTarget ?? 'កម្ចី'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFE066), width: 1.5)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFFA000), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('សូមពិនិត្យព័ត៌មានឱ្យបានត្រឹមត្រូវ មុននឹងបញ្ជាក់ការស្នើសុំ', style: TextStyle(color: const Color(0xFF666666), fontSize: 13, height: 1.5))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•', style: TextStyle(color: Color(0xFF999999), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(child: Text('ប្រាក់កម្ចីនេះនឹងត្រូវបានដំណើរការក្នុងរយៈពេល ១-២ ថ្ងៃការងារ', style: TextStyle(color: const Color(0xFF666666), fontSize: 13, height: 1.5))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0066CC), Color(0xFF0088FF)]),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [BoxShadow(color: const Color(0xFF0066CC).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _onConfirm,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                    child: _submitting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('បញ្ជាក់ការស្នើសុំ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navButton(Icons.home_outlined, 'ទំព័រដើម', () { Navigator.of(context).popUntil((route) => route.isFirst); tabIndex.value = 0; }),
                    _navButton(Icons.account_balance_wallet_outlined, 'គណនី', () { Navigator.of(context).popUntil((route) => route.isFirst); tabIndex.value = 1; }),
                    _navButton(Icons.share_outlined, 'ចែករំលែក', () => _showShareSheet(context)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Color(0xFF999999), fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF333333), fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 1, color: const Color(0xFFF0F0F0));
  }

  Widget _navButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF999999), size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF999999), fontSize: 11)),
        ],
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    final data = widget.formData;
    final amountStr = data.currency == 'KHR' ? '${_formatMoney(data.amount)} រៀល' : '\$${_formatMoney(data.amount)}';
    final refNumber = 'LN${DateTime.now().millisecondsSinceEpoch % 1000000000}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('ចែករំលែកព័ត៌មានកម្ចី', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 20),
            _shareOption(Icons.copy, 'ចម្លងលេខយោង', () { _copyToClipboard(context, refNumber); Navigator.pop(context); }),
            _shareOption(Icons.receipt_long, 'ចម្លងព័ត៌មានកម្ចី', () {
              final info = 'AURA Bank - ព័ត៌មានកម្ចី\nលេខយោង: $refNumber\nចំនួន: $amountStr\nរយៈពេល: ${data.durationMonths ?? 0} ខែ\nគោលដៅឥណទាន: ${data.loanTarget ?? 'កម្ចី'}';
              _copyToClipboard(context, info);
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
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF0066CC), size: 22)),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
      onTap: onTap,
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('បានចម្លងទៅ clipboard'), duration: Duration(seconds: 2), backgroundColor: Color(0xFF00AA44)));
  }

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
