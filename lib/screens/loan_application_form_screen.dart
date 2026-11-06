// ============================================================================
//  LOAN APPLICATION FORM SCREEN — ទម្រង់ពាក្យស្នើសុំឥណទាន
//  ACLEDA Bank style
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../id_scan_screen.dart';
import '../loan_form_data.dart';
import 'loan_summary_screen.dart';

// Region models (copied from loan_module.dart)
class _RegionProvince {
  final String code, name;
  final List<_RegionDistrict> districts;
  _RegionProvince(this.code, this.name, this.districts);
  factory _RegionProvince.fromJson(Map<String, dynamic> j) => _RegionProvince(
      j['c'] as String,
      j['n'] as String,
      [
        for (final d in j['d'] as List)
          _RegionDistrict.fromJson(Map<String, dynamic>.from(d as Map))
      ]);
}

class _RegionDistrict {
  final String code, name;
  final List<_RegionCommune> communes;
  _RegionDistrict(this.code, this.name, this.communes);
  factory _RegionDistrict.fromJson(Map<String, dynamic> j) => _RegionDistrict(
      j['c'] as String,
      j['n'] as String,
      [
        for (final m in j['m'] as List)
          _RegionCommune.fromJson(Map<String, dynamic>.from(m as Map))
      ]);
}

class _RegionCommune {
  final String code, name;
  final List<String> villages;
  _RegionCommune(this.code, this.name, this.villages);
  factory _RegionCommune.fromJson(Map<String, dynamic> j) => _RegionCommune(
      j['c'] as String, j['n'] as String, List<String>.from(j['v'] as List));
}

Future<List<_RegionProvince>> _loadRegionData() async {
  final raw = await rootBundle.loadString('assets/data/cambodia_admin.json');
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final p in j['p'] as List)
      _RegionProvince.fromJson(Map<String, dynamic>.from(p as Map))
  ];
}

class LoanApplicationFormScreen extends StatefulWidget {
  const LoanApplicationFormScreen({super.key});
  @override
  State<LoanApplicationFormScreen> createState() =>
      _LoanApplicationFormScreenState();
}

class _LoanApplicationFormScreenState extends State<LoanApplicationFormScreen> {
  final _formData = LoanFormData();
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<_RegionProvince> _provinces = [];
  bool _loadingRegions = true;
  IdCardData? _scannedId;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await _loadRegionData();
      if (mounted) {
        setState(() {
          _provinces = regions;
          _loadingRegions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRegions = false);
        toast(context, 'មិនអាចផ្ទុកទិន្នន័យខេត្តបាន', error: true);
      }
    }
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

  List<_RegionDistrict> _getDistricts() {
    if (_formData.province == null) return [];
    try {
      return _provinces
          .firstWhere((p) => p.name == _formData.province)
          .districts;
    } catch (e) {
      return [];
    }
  }

  List<_RegionCommune> _getCommunes() {
    if (_formData.district == null) return [];
    try {
      return _getDistricts()
          .firstWhere((d) => d.name == _formData.district)
          .communes;
    } catch (e) {
      return [];
    }
  }

  List<String> _getVillages() {
    if (_formData.commune == null) return [];
    try {
      return _getCommunes()
          .firstWhere((c) => c.name == _formData.commune)
          .villages;
    } catch (e) {
      return [];
    }
  }

  void _onProvinceChanged(String? value) {
    setState(() {
      _formData.province = value;
      _formData.district = null;
      _formData.commune = null;
      _formData.village = null;
    });
  }

  void _onDistrictChanged(String? value) {
    setState(() {
      _formData.district = value;
      _formData.commune = null;
      _formData.village = null;
    });
  }

  void _onCommuneChanged(String? value) {
    setState(() {
      _formData.commune = value;
      _formData.village = null;
    });
  }

  void _onVillageChanged(String? value) {
    setState(() {
      _formData.village = value;
    });
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
            // Currency Toggle
            _buildCurrencyToggle(),
            const SizedBox(height: 20),

            // ID Scan
            _buildIdScanCard(),
            const SizedBox(height: 20),

            // Amount
            NeuField(
              controller: _amountController,
              label: 'ចំនួនសុំឥណទាន',
              prefixIcon: _formData.currency == 'KHR' 
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Image.asset(
                      'assets/icon/khr_icon.png',
                      width: 24,
                      height: 24,
                    ),
                  )
                : Padding(
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

            // Purpose
            NeuField(
              controller: _purposeController,
              label: 'គោលបំណង',
              icon: Icons.description,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'សូមបញ្ចូលគោលបំណង';
                return null;
              },
              onChanged: (v) {
                _formData.purpose = v;
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
            const SizedBox(height: 24),

            // Location Section
            Text(
              'ទីតាំង',
              style: TextStyle(
                color: context.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            if (_loadingRegions)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildDropdown(
                label: 'ខេត្ត/ក្រុង',
                value: _formData.province,
                items: _provinces.map((p) => p.name).toList(),
                labels: _provinces.map((p) => p.name).toList(),
                onChanged: _onProvinceChanged,
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                label: 'ស្រុក/ខណ្ឌ',
                value: _formData.district,
                items: _getDistricts().map((d) => d.name).toList(),
                labels: _getDistricts().map((d) => d.name).toList(),
                onChanged: _onDistrictChanged,
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                label: 'ឃុំ/សង្កាត់',
                value: _formData.commune,
                items: _getCommunes().map((c) => c.name).toList(),
                labels: _getCommunes().map((c) => c.name).toList(),
                onChanged: _onCommuneChanged,
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                label: 'ភូមិ',
                value: _formData.village,
                items: _getVillages(),
                labels: _getVillages(),
                onChanged: _onVillageChanged,
              ),
              const SizedBox(height: 16),

              NeuField(
                label: 'អាសយដ្ឋាន',
                icon: Icons.location_on,
                onChanged: (v) {
                  _formData.address = v;
                },
              ),
            ],
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

  Widget _buildCurrencyToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border, width: 1.2),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _formData.currency = 'KHR'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _formData.currency == 'KHR' ? C.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'រៀល',
                    style: TextStyle(
                      color: _formData.currency == 'KHR' ? Colors.white : context.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _formData.currency = 'USD'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _formData.currency == 'USD' ? C.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'ដុល្លារ',
                    style: TextStyle(
                      color: _formData.currency == 'USD' ? Colors.white : context.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
