// ============================================================================
//  LOAN APPLICATION FORM SCREEN — ទម្រង់ពាក្យស្នើសុំឥណទាន
//  ACLEDA Bank style
// ============================================================================
import 'package:flutter/material.dart';

import '../main.dart';
import '../id_scan_screen.dart';
import '../loan_form_data.dart';
import 'loan_summary_screen.dart';

class LoanApplicationFormScreen extends StatefulWidget {
  const LoanApplicationFormScreen({super.key});
  @override
  State<LoanApplicationFormScreen> createState() =>
      _LoanApplicationFormScreenState();
}

class _LoanApplicationFormScreenState extends State<LoanApplicationFormScreen> {
  final _formData = LoanFormData();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  IdCardData? _scannedId;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _scanId() async {
    final result = await push(context, const IdCardScanScreen());
    if (result is IdCardData) {
      setState(() {
        _scannedId = result;
        _formData.scannedId = result;
        _formData.fullName = result.fullName;
        _formData.nationalId = result.idNumber;
      });
      toast(context, 'បានស្កេនអត្តសញ្ញាបណ្ណដោយជោគជ័យ');
    }
  }

  void _onContinue() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    if (!_formData.isValid) {
      toast(context, 'សូមបំពេញព័ត៌មានឱ្យបានគ្រប់គ្រាន់', error: true);
      return;
    }

    push(
      context,
      LoanSummaryScreen(formData: _formData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('ពាក្យស្នើសុំឥណទាន'),
        backgroundColor: context.bg,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ID Scan
            _buildIdScanCard(),
            const SizedBox(height: 20),

            // Amount
            NeuField(
              controller: _amountController,
              label: 'ចំនួនសុំឥណទាន',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Image.asset(
                  'assets/icon/usd_icon.png',
                  width: 24,
                  height: 24,
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final amount = double.tryParse(v ?? '0') ?? 0;
                if (amount <= 0) return 'សូមបញ្ចូលចំនួន';
                return null;
              },
              onChanged: (v) {
                _formData.amount = double.tryParse(v) ?? 0;
              },
            ),
            const SizedBox(height: 16),

            // Duration
            _buildDropdown(
              label: 'រយៈពេល',
              value: _formData.durationMonths?.toString(),
              items: ['3', '6', '12', '24', '36', '48', '60'],
              labels: ['3 ខែ', '6 ខែ', '12 ខែ', '24 ខែ', '36 ខែ', '48 ខែ', '60 ខែ'],
              onChanged: (v) {
                setState(() {
                  _formData.durationMonths = int.tryParse(v ?? '0');
                });
              },
            ),
            const SizedBox(height: 16),

            // Loan Target
            _buildDropdown(
              label: 'គោលដៅឥណទាន',
              value: _formData.loanTarget,
              items: ['អាជីវកម្ម', 'អប់រំ', 'លំនៅដ្ឋាន', 'វេជ្ជសាស្ត្រ', 'ផ្សេងៗ'],
              labels: ['អាជីវកម្ម', 'អប់រំ', 'លំនៅដ្ឋាន', 'វេជ្ជសាស្ត្រ', 'ផ្សេងៗ'],
              onChanged: (v) {
                setState(() {
                  _formData.loanTarget = v;
                });
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NeuButton(
          label: 'បន្ត',
          icon: Icons.arrow_forward,
          accent: C.accent,
          onPressed: _onContinue,
        ),
      ),
    );
  }

  Widget _buildIdScanCard() {
    return NeuBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner, color: C.accent, size: 24),
              const SizedBox(width: 12),
              Text(
                'អត្តសញ្ញាបណ្ណ',
                style: TextStyle(
                  color: context.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_scannedId != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('ឈ្មោះ', _scannedId!.fullName),
                  const SizedBox(height: 6),
                  _infoRow('លេខអត្តសញ្ញាណ', _scannedId!.idNumber),
                ],
              ),
            )
          else
            NeuButton(
              label: 'ស្កេនអត្តសញ្ញាបណ្ណ',
              icon: Icons.document_scanner,
              accent: C.accent,
              onPressed: _scanId,
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.muted, fontSize: 13),
          floatingLabelStyle: const TextStyle(
            color: C.accent,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: InputBorder.none,
        ),
        items: [
          for (var i = 0; i < items.length; i++)
            DropdownMenuItem(
              value: items[i],
              child: Text(labels[i], style: TextStyle(color: context.ink, fontSize: 14)),
            ),
        ],
        onChanged: onChanged,
        dropdownColor: context.bg,
        style: TextStyle(color: context.ink, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.arrow_drop_down, color: context.muted),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(color: context.muted, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
