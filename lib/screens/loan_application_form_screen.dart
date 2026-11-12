// ============================================================================
//  LOAN APPLICATION FORM SCREEN — ទម្រង់ពាក្យស្នើសុំឥណទាន (៤ ជំហាន)
//  ជំហាន៖ ឥណទាន → អត្តសញ្ញាបណ្ណ → ទីតាំង → ផ្ទៀងផ្ទាត់
// ============================================================================
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../id_scan_screen.dart';
import '../loan_form_data.dart';
import 'loan_summary_screen.dart';

// ----------------------------------------------------------------------------
//  Region models
// ----------------------------------------------------------------------------
class _RegionProvince {
  final String code, name;
  final List<_RegionDistrict> districts;
  _RegionProvince(this.code, this.name, this.districts);
  factory _RegionProvince.fromJson(Map<String, dynamic> j) => _RegionProvince(
      j['c'] as String, j['n'] as String, [
        for (final d in j['d'] as List)
          _RegionDistrict.fromJson(Map<String, dynamic>.from(d as Map))
      ]);
}

class _RegionDistrict {
  final String code, name;
  final List<_RegionCommune> communes;
  _RegionDistrict(this.code, this.name, this.communes);
  factory _RegionDistrict.fromJson(Map<String, dynamic> j) => _RegionDistrict(
      j['c'] as String, j['n'] as String, [
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

class _StepMeta {
  final String short, title, subtitle;
  final IconData icon;
  const _StepMeta(this.short, this.title, this.subtitle, this.icon);
}

const _steps = [
  _StepMeta('ឥណទាន', 'ព័ត៌មានឥណទាន', 'បំពេញចំនួន រយៈពេល និងគោលដៅឥណទាន',
      Icons.account_balance_wallet_rounded),
  _StepMeta('អត្តសញ្ញាបណ្ណ', 'ផ្ទៀងផ្ទាត់អត្តសញ្ញាណ', 'ស្កេនអត្តសញ្ញាបណ្ណរបស់អ្នក',
      Icons.badge_rounded),
  _StepMeta('ទីតាំង', 'អាសយដ្ឋានបច្ចុប្បន្ន', 'ជ្រើសរើស ខេត្ត ស្រុក ឃុំ ភូមិ',
      Icons.location_on_rounded),
  _StepMeta('ផ្ទៀងផ្ទាត់', 'ពិនិត្យ និងដាក់ស្នើ', 'ពិនិត្យព័ត៌មានមុននឹងបញ្ជាក់',
      Icons.verified_user_rounded),
];

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
  int _step = 0;
  bool _forward = true;

  List<_RegionProvince> _provinces = [];
  bool _loadingRegions = true;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _amountController.dispose();
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

  // --- region helpers ---
  List<_RegionDistrict> _getDistricts() {
    if (_formData.province == null) return [];
    try {
      return _provinces.firstWhere((p) => p.name == _formData.province).districts;
    } catch (e) {
      return [];
    }
  }

  List<_RegionCommune> _getCommunes() {
    if (_formData.district == null) return [];
    try {
      return _getDistricts().firstWhere((d) => d.name == _formData.district).communes;
    } catch (e) {
      return [];
    }
  }

  List<String> _getVillages() {
    if (_formData.commune == null) return [];
    try {
      return _getCommunes().firstWhere((c) => c.name == _formData.commune).villages;
    } catch (e) {
      return [];
    }
  }

  void _onProvinceChanged(String? v) => setState(() {
        _formData.province = v;
        _formData.district = null;
        _formData.commune = null;
        _formData.village = null;
      });
  void _onDistrictChanged(String? v) => setState(() {
        _formData.district = v;
        _formData.commune = null;
        _formData.village = null;
      });
  void _onCommuneChanged(String? v) => setState(() {
        _formData.commune = v;
        _formData.village = null;
      });
  void _onVillageChanged(String? v) => setState(() => _formData.village = v);

  // --- live monthly estimate (annuity, 21.6%/yr) ---
  double? get _monthlyEstimate {
    final p = _formData.amount;
    final n = _formData.durationMonths;
    if (p <= 0 || n == null || n <= 0) return null;
    final r = 21.6 / 100 / 12;
    return p * r / (1 - math.pow(1 + r, -n));
  }

  void _goTo(int step) {
    if (step == _step) return;
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _back() {
    if (_step > 0) _goTo(_step - 1);
  }

  void _next() {
    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_formData.durationMonths == null) {
        toast(context, 'សូមជ្រើសរើសរយៈពេលឥណទាន', error: true);
        return;
      }
      if (_formData.loanTarget == null) {
        toast(context, 'សូមជ្រើសរើសគោលដៅឥណទាន', error: true);
        return;
      }
      _goTo(1);
    } else if (_step == 1) {
      if (_scannedId == null) {
        toast(context, 'សូមស្កេនអត្តសញ្ញាបណ្ណជាមុនសិន', error: true);
        return;
      }
      _goTo(2);
    } else if (_step == 2) {
      if (_formData.province == null ||
          _formData.district == null ||
          _formData.commune == null ||
          _formData.village == null) {
        toast(context, 'សូមជ្រើសរើស ខេត្ត ស្រុក ឃុំ ភូមិ ឱ្យបានគ្រប់', error: true);
        return;
      }
      push(context, LoanSummaryScreen(formData: _formData));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _steps[_step];
    final isLast = _step == 2;
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildHero(meta),
            const SizedBox(height: 16),
            _buildStepper(),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                final offset = Tween(
                  begin: Offset(_forward ? 0.08 : -0.08, 0),
                  end: Offset.zero,
                ).animate(anim);
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_step),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildNavBar(isLast),
    );
  }

  // --------------------------------------------------------------------------
  //  Hero header
  // --------------------------------------------------------------------------
  Widget _buildHero(_StepMeta meta) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: AuraGrad.button,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: C.accent.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Icon(meta.icon,
                size: 120, color: Colors.white.withValues(alpha: 0.10)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'ជំហានទី ${_step + 1} / ${_steps.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Text(
                  meta.title,
                  key: ValueKey<String>(meta.title),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meta.subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  Stepper
  // --------------------------------------------------------------------------
  Widget _buildStepper() {
    return NeuBox(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 22, left: 2, right: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: i <= _step
                        ? const LinearGradient(
                            colors: [C.accentGreen, C.accent])
                        : null,
                    color: i <= _step ? null : context.border,
                  ),
                ),
              ),
            _buildStepNode(i),
          ],
        ],
      ),
    );
  }

  Widget _buildStepNode(int i) {
    final done = i < _step;
    final active = i == _step;
    final Color fg = done || active ? Colors.white : context.muted;
    return SizedBox(
      width: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done
                  ? const LinearGradient(
                      colors: [C.accentGreen, Color(0xFF1FA97C)])
                  : active
                      ? AuraGrad.button
                      : null,
              color: done || active ? null : context.surface,
              border: Border.all(
                color: active ? C.accent : context.border,
                width: active ? 2 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: C.accent.withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              done ? Icons.check_rounded : _steps[i].icon,
              color: fg,
              size: 20,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _steps[i].short,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? context.ink : context.muted,
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  Step content
  // --------------------------------------------------------------------------
  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildLoanStep();
      case 1:
        return _buildIdStep();
      default:
        return _buildLocationStep();
    }
  }

  Widget _buildLoanStep() {
    final est = _monthlyEstimate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeuBox(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(Icons.payments_rounded, 'ចំនួនឥណទាន'),
              const SizedBox(height: 14),
              NeuField(
                controller: _amountController,
                label: 'ចំនួនសុំឥណទាន (USD)',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Image.asset('assets/icon/usd_icon.png',
                      width: 24, height: 24),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final amount = double.tryParse(v ?? '0') ?? 0;
                  if (amount <= 0) return 'សូមបញ្ចូលចំនួនឥណទាន';
                  return null;
                },
                onChanged: (v) =>
                    setState(() => _formData.amount = double.tryParse(v) ?? 0),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'រយៈពេល',
                value: _formData.durationMonths?.toString(),
                items: const ['3', '6', '12', '24', '36', '48', '60'],
                labels: const ['3 ខែ', '6 ខែ', '12 ខែ', '24 ខែ', '36 ខែ', '48 ខែ', '60 ខែ'],
                onChanged: (v) => setState(
                    () => _formData.durationMonths = int.tryParse(v ?? '0')),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'គោលដៅឥណទាន',
                value: _formData.loanTarget,
                items: const ['អាជីវកម្ម', 'អប់រំ', 'លំនៅដ្ឋាន', 'វេជ្ជសាស្ត្រ', 'ផ្សេងៗ'],
                labels: const ['អាជីវកម្ម', 'អប់រំ', 'លំនៅដ្ឋាន', 'វេជ្ជសាស្ត្រ', 'ផ្សេងៗ'],
                onChanged: (v) => setState(() => _formData.loanTarget = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: est == null ? 0 : 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                C.accent.withValues(alpha: 0.14),
                C.accentPurple.withValues(alpha: 0.10),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: C.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calculate_rounded,
                      color: C.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ការបង់ប្រចាំខែប៉ាន់ស្មាន',
                          style: TextStyle(
                              color: context.muted, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        est == null ? '\$0.00' : '\$${_fmt(est)}',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'អត្រា 1.8% / ខែ',
                  style: TextStyle(color: context.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdStep() {
    final id = _scannedId;
    return NeuBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.badge_rounded, 'អត្តសញ្ញាបណ្ណជាតិ'),
          const SizedBox(height: 16),
          if (id == null)
            _buildScanZone()
          else
            _buildScannedCard(id),
        ],
      ),
    );
  }

  Widget _buildScanZone() {
    return GestureDetector(
      onTap: _scanId,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
        decoration: BoxDecoration(
          color: C.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: C.accent.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AuraGrad.button,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: C.accent.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(Icons.document_scanner_rounded,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              'ស្កេនអត្តសញ្ញាបណ្ណ',
              style: TextStyle(
                color: context.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ចុចទីនេះ ដើម្បីថត និងអានព័ត៌មានពីអត្តសញ្ញាបណ្ណរបស់អ្នក',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.muted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                gradient: AuraGrad.button,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('ចាប់ផ្តើមស្កេន',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedCard(IdCardData id) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A5A87), Color(0xFF033553)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: C.brandStart.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -8,
              ),
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
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(id.fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('អត្តសញ្ញាបណ្ណជាតិខ្មែរ',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: C.accentGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: C.accentGreen.withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: C.accentGreen, size: 14),
                        SizedBox(width: 4),
                        Text('បានស្កេន',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _idRow('លេខអត្តសញ្ញាណ', id.idNumber),
                    if (id.gender.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _idRow('ភេទ', id.gender),
                    ],
                    if (id.dob != null) ...[
                      const SizedBox(height: 8),
                      _idRow('ថ្ងៃខែឆ្នាំកំណើត', _fmtDate(id.dob!)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _scanId,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('ស្កេនម្តងទៀត'),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.accent,
              side: BorderSide(color: C.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return NeuBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.location_on_rounded, 'អាសយដ្ឋានបច្ចុប្បន្ន'),
          const SizedBox(height: 6),
          Text(
            'ជ្រើសរើសទីតាំងរបស់អ្នក ដើម្បីងាយស្រួលក្នុងការទំនាក់ទំនង',
            style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (_loadingRegions)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
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
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  Bottom navigation
  // --------------------------------------------------------------------------
  Widget _buildNavBar(bool isLast) {
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
      child: Row(
        children: [
          if (_step > 0) ...[
            SizedBox(
              width: 116,
              child: NeuButton(
                label: 'ថយក្រោយ',
                icon: Icons.arrow_back_rounded,
                accent: context.muted,
                onPressed: _back,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: NeuButton(
              label: isLast ? 'ផ្ទៀងផ្ទាត់' : 'បន្ត',
              icon: isLast
                  ? Icons.verified_user_rounded
                  : Icons.arrow_forward_rounded,
              accent: C.accent,
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  Shared bits
  // --------------------------------------------------------------------------
  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: C.accent, size: 20),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                color: context.ink, fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _idRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ),
      ],
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
        color: context.isDark
            ? Colors.black.withValues(alpha: 0.18)
            : context.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
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
              child: Text(labels[i],
                  style: TextStyle(color: context.ink, fontSize: 14)),
            ),
        ],
        onChanged: onChanged,
        dropdownColor: context.card,
        style: TextStyle(
            color: context.ink, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.arrow_drop_down_rounded, color: context.muted),
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
