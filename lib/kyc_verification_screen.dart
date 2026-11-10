// ============================================================================
//  KYC — 3-step identity verification (dark violet / frosted glass)
//  Step 1: National ID front + back · Step 2: selfie with ID · Step 3: review
// ============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ពណ៌ និង gradient របស់ flow KYC (dark violet + red-orange accent)
class Kyc {
  static const bgTop = Color(0xFF1E1035);
  static const bgBottom = Color(0xFF0F081D);
  static const card = Color(0xFF2C1B4E);
  static const cardHi = Color(0xFF3A2664);
  static const accentStart = Color(0xFFFF512F);
  static const accentEnd = Color(0xFFDD2476);
  static const gold = Color(0xFFFF8A3D);
  static const text = Color(0xFFF6F1FF);
  static const muted = Color(0xFFB6A6D8);
  static const line = Color(0xFF47326F);
  static const ok = Color(0xFF34D399);
  static const bad = Color(0xFFFF6B6B);

  static const bgGrad = LinearGradient(
    colors: [bgTop, bgBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const accentGrad = LinearGradient(
    colors: [accentStart, accentEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

TextStyle _s(double size,
        {FontWeight w = FontWeight.w500,
        Color c = Kyc.text,
        double? h,
        double ls = 0}) =>
    TextStyle(
        fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

/// ឯកសារដែលបានជ្រើស — bytes ដើម្បីបង្ហាញបានទាំង mobile និង web
class _Doc {
  final Uint8List bytes;
  final String name;
  final int size;
  const _Doc(this.bytes, this.name, this.size);
}

/// រង្វាស់ភាពច្បាស់ (Laplacian variance) — តូច = រូបថតព្រិល
double _sharpnessOf(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return -1;
  final im = img.copyResize(decoded, width: 220);
  final w = im.width, h = im.height;
  if (w < 5 || h < 5) return -1;
  final lum = Float64List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      lum[y * w + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }
  }
  var sum = 0.0, sum2 = 0.0;
  var n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final v = 4 * lum[i] - lum[i - 1] - lum[i + 1] - lum[i - w] - lum[i + w];
      sum += v;
      sum2 += v * v;
      n++;
    }
  }
  if (n == 0) return -1;
  final mean = sum / n;
  return sum2 / n - mean * mean;
}

class KycVerificationScreen extends StatefulWidget {
  /// លេខយោងប្រតិបត្តិការ (បើបើកចេញពីបង្កាន់ដៃ)
  final String? ref;
  const KycVerificationScreen({super.key, this.ref});
  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();

  int _step = 0;
  int _dir = 1;
  bool _loadingSaved = true;

  _Doc? _front, _back, _selfie;

  bool _uploading = false;
  double _progress = 0;
  Timer? _uploadTimer;

  String? _toastMsg;
  bool _toastError = true;
  Timer? _toastTimer;

  late final String _ref = widget.ref ??
      'KYC${DateTime.now().millisecondsSinceEpoch % 1000000000}';
  DateTime _submittedAt = DateTime.now();

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final sp = await SharedPreferences.getInstance();
    final pending = sp.getBool('kyc_pending') ?? false;
    final at = DateTime.tryParse(sp.getString('kyc_at') ?? '');
    if (!mounted) return;
    setState(() {
      _loadingSaved = false;
      if (pending) {
        _submittedAt = at ?? DateTime.now();
        _step = 2;
        _dir = 1;
      }
    });
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    _toastTimer?.cancel();
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  // ───────────────────────── helpers ─────────────────────────

  void _go(int s) {
    if (s == _step) return;
    setState(() {
      _dir = s > _step ? 1 : -1;
      _step = s;
    });
  }

  void _goBack() {
    if (_step == 1) {
      _go(0);
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _toast(String msg, {bool error = true}) {
    _toastTimer?.cancel();
    setState(() {
      _toastMsg = msg;
      _toastError = error;
    });
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMsg = null);
    });
  }

  String _fmtSize(int b) => b < 1024 * 1024
      ? '${(b / 1024).toStringAsFixed(0)} KB'
      : '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';

  String _fmtWhen(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} · $hh:$mi';
  }

  Future<bool?> _confirmBlurry() => showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Kyc.cardHi, Kyc.card],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Kyc.line),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 14)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Kyc.accentStart.withValues(alpha: 0.16)),
                child: const Icon(Icons.blur_on_rounded,
                    color: Kyc.gold, size: 26),
              ),
              const SizedBox(height: 14),
              Text('រូបថតហាក់មិនច្បាស់', style: _s(15.5, w: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  'រូបថតនេះអាចព្រិល ឬខ្លីពន្លឺ។ ធនាគារអាចបដិសេធឯកសារមិនច្បាស់។ សូមប្តូររូបថតថ្មី ឬបន្តបើអ្នកប្រាកដថាច្បាស់។',
                  textAlign: TextAlign.center,
                  style: _s(12, c: Kyc.muted, h: 1.6)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: _OutlineButton(
                      label: 'ជ្រើសរើសម្តងទៀត',
                      icon: Icons.refresh_rounded,
                      onTap: () => Navigator.of(ctx).pop(false)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GradientButton(
                      label: 'បន្ត',
                      onTap: () => Navigator.of(ctx).pop(true)),
                ),
              ]),
            ]),
          ),
        ),
      );

  Future<_Doc?> _validate(XFile x, {required bool checkBlur}) async {
    final name = x.name.isEmpty ? 'image.jpg' : x.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!const ['png', 'jpg', 'jpeg'].contains(ext)) {
      _toast('ទម្រង់មិនត្រឹមត្រូវ — សូមជ្រើសរើស PNG, JPG ឬ JPEG');
      return null;
    }
    final size = await x.length();
    if (size > 10 * 1024 * 1024) {
      _toast('ទំហំឯកសារលើស 10MB — សូមជ្រើសរើសរូបតូចជាង');
      return null;
    }
    if (size < 10 * 1024) {
      _toast('ឯកសារតូចពេក ឬខូច — សូមជ្រើសរើសម្តងទៀត');
      return null;
    }
    final bytes = await x.readAsBytes();
    if (checkBlur) {
      final sharp = await compute(_sharpnessOf, bytes);
      if (sharp >= 0 && sharp < 45) {
        if (!mounted) return null;
        final cont = await _confirmBlurry();
        if (cont != true) return null;
      }
    }
    return _Doc(bytes, name, size);
  }

  Future<void> _pickId({required bool front}) async {
    try {
      final x = await _picker.pickImage(
          source: ImageSource.gallery, maxWidth: 2000, imageQuality: 90);
      if (x == null) return;
      final doc = await _validate(x, checkBlur: true);
      if (doc == null || !mounted) return;
      setState(() {
        if (front) {
          _front = doc;
        } else {
          _back = doc;
        }
      });
    } catch (_) {
      if (mounted) _toast('មិនអាចបើករូបថតបានទេ — សូមព្យាយាមម្តងទៀត');
    }
  }

  Future<void> _pickSelfie(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
          source: source,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 1600,
          imageQuality: 88);
      if (x == null) return;
      final doc = await _validate(x, checkBlur: false);
      if (doc == null || !mounted) return;
      setState(() => _selfie = doc);
    } catch (_) {
      if (source == ImageSource.camera) {
        _toast('កាមេរ៉ាមិនអាចប្រើបាន — សូមជ្រើសរើសពីវិចិត្រសាល');
      } else {
        _toast('មិនអាចបើកវិចិត្រសាលបានទេ');
      }
    }
  }

  void _startUpload() {
    if (_front == null || _back == null) {
      _toast('សូមជ្រើសរើសរូបថតអត្តសញ្ញាណប័ណ្ណទាំងសងខាងជាមុន');
      return;
    }
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(
          () => _progress = math.min(1, _progress + 0.023 + math.Random().nextDouble() * 0.012));
      if (_progress >= 1) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 280), () {
          if (!mounted) return;
          setState(() => _uploading = false);
          _go(1);
        });
      }
    });
  }

  Future<void> _submit() async {
    if (_selfie == null) {
      _toast('សូមថតរូបផ្ទាល់ខ្លួនជាមួយអត្តសញ្ញាណបណ្ណជាមុន');
      return;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('kyc_pending', true);
    await sp.setString('kyc_at', DateTime.now().toIso8601String());
    await sp.setString('kyc_ref', _ref);
    if (!mounted) return;
    setState(() => _submittedAt = DateTime.now());
    _go(2);
  }

  Future<void> _reset() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('kyc_pending');
    await sp.remove('kyc_at');
    await sp.remove('kyc_ref');
    if (!mounted) return;
    setState(() {
      _front = null;
      _back = null;
      _selfie = null;
      _submittedAt = DateTime.now();
    });
    _go(0);
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final canPop = _step != 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _step == 1) _go(0);
        },
        child: Scaffold(
          backgroundColor: Kyc.bgBottom,
          body: Container(
            decoration: const BoxDecoration(gradient: Kyc.bgGrad),
            child: SafeArea(
              child: Stack(children: [
                _glow(Alignment.topRight, Kyc.accentEnd),
                _glow(Alignment.bottomLeft, Kyc.accentStart),
                Column(children: [
                  _header(),
                  _progressBar(),
                  const SizedBox(height: 10),
                  Expanded(child: _stage()),
                ]),
                _toastLayer(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glow(Alignment align, Color color) => Align(
        alignment: align,
        child: FractionalTranslation(
          translation: Offset(align.x * 0.55, align.y * 0.55),
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withValues(alpha: 0.26), Colors.transparent],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          GestureDetector(
            onTap: _goBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Kyc.card.withValues(alpha: 0.8),
                border: Border.all(color: Kyc.line),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ការផ្ទៀងផ្ទាត់អត្តសញ្ញាណ',
                      style: _s(15, w: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Identity Verification · ជំហាន ${_step + 1} / 3',
                      style: _s(10.5,
                          c: Kyc.muted.withValues(alpha: 0.85), ls: 0.4)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: Kyc.accentEnd.withValues(alpha: 0.16),
              border: Border.all(color: Kyc.accentEnd.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_rounded, size: 12, color: Kyc.gold),
              const SizedBox(width: 4),
              Text('KYC',
                  style: _s(9.5,
                      w: FontWeight.w800, c: Kyc.text, ls: 1.1)),
            ]),
          ),
        ]),
      );

  Widget _progressBar() {
    const labels = ['ឯកសារ', 'Selfie', 'ពិនិត្យ'];
    final target = (_step + 1) / 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(children: [
        LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 1 / 3, end: target),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Stack(clipBehavior: Clip.none, children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                    color: Kyc.line.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(99)),
              ),
              FractionallySizedBox(
                widthFactor: v.clamp(0.02, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: Kyc.accentGrad,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                          color: Kyc.accentEnd.withValues(alpha: 0.55),
                          blurRadius: 14,
                          spreadRadius: 1),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: (w * v - 8).clamp(0.0, w - 16),
                top: -5,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Kyc.accentEnd.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 1),
                    ],
                  ),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 9),
        Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Text('${i + 1} · ${labels[i]}',
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == 1
                          ? TextAlign.center
                          : TextAlign.right,
                  style: _s(10.5,
                      w: i <= _step ? FontWeight.w800 : FontWeight.w500,
                      c: i <= _step
                          ? Kyc.text
                          : Kyc.muted.withValues(alpha: 0.55))),
            ),
        ]),
      ]),
    );
  }

  Widget _stage() {
    if (_loadingSaved) {
      return const Center(
          child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Kyc.accentStart))));
    }
    final child = switch (_step) {
      0 => _stepDocuments(),
      1 => _stepSelfie(),
      _ => _stepReview(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 460),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, if (current != null) current]),
      transitionBuilder: (c, a) {
        final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: t,
          child: SlideTransition(
            position: Tween(
                    begin: Offset(0.18 * _dir, 0), end: Offset.zero)
                .animate(t),
            child: c,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey<int>(_step), child: child),
    );
  }

  // ───────────────────────── STEP 1 ─────────────────────────

  Widget _stepDocuments() {
    final ready = _front != null && _back != null && !_uploading;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titleBlock('ទាមទារការផ្ទៀងផ្ទាត់អត្តសញ្ញាណ',
            'Identity Verification Required'),
        const SizedBox(height: 16),
        _notice(),
        const SizedBox(height: 18),
        _uploadCard(
          title: 'អត្តសញ្ញាណប័ណ្ណខាងមុខ',
          en: 'National ID — Front side',
          icon: Icons.badge_outlined,
          doc: _front,
          onPick: () => _pickId(front: true),
          onRemove: () => setState(() => _front = null),
        ),
        const SizedBox(height: 12),
        _uploadCard(
          title: 'អត្តសញ្ញាណប័ណ្ណខាងខ្នង',
          en: 'National ID — Back side',
          icon: Icons.flip_to_back_rounded,
          doc: _back,
          onPick: () => _pickId(front: false),
          onRemove: () => setState(() => _back = null),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          alignment: Alignment.topCenter,
          child: _uploading
              ? _uploadProgress()
              : const SizedBox(width: double.infinity),
        ),
        if (!_uploading) ...[
          _GradientButton(
            label: 'ផ្ទុកឯកសារ និងបន្ត',
            caption: 'UPLOAD & CONTINUE',
            icon: Icons.cloud_upload_rounded,
            onTap: ready ? _startUpload : null,
          ),
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Text('សូមជ្រើសរើសរូបថតទាំងសងខាងជាមុន',
                    style: _s(10.5,
                        c: Kyc.muted.withValues(alpha: 0.75))),
              ),
            ),
        ],
      ]),
    );
  }

  Widget _titleBlock(String kh, String en) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kh, style: _s(20, w: FontWeight.w800, h: 1.35)),
          const SizedBox(height: 3),
          Text(en,
              style: _s(11, c: Kyc.muted.withValues(alpha: 0.8), ls: 0.6)),
        ],
      );

  Widget _notice() => Container(
        padding: const EdgeInsets.fromLTRB(13, 13, 14, 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Kyc.card.withValues(alpha: 0.92),
              Kyc.card.withValues(alpha: 0.55),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: Kyc.accentStart.withValues(alpha: 0.38), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 20,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: Kyc.accentGrad,
              boxShadow: [
                BoxShadow(
                    color: Kyc.accentEnd.withValues(alpha: 0.42),
                    blurRadius: 14,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: const Icon(Icons.gpp_maybe_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('សូមអានឲ្យបានច្បាស់',
                  style: _s(12.5, w: FontWeight.w800, c: Kyc.gold)),
              const SizedBox(height: 5),
              Text(
                  'លោកអ្នកមិនទាន់បានបំពេញលក្ខខណ្ឌដែលធនាគារត្រូវការនៅឡើយទេ។ សូមធ្វើតាមការណែនាំ ៣ ជំហានខាងក្រោម។ រូបថតត្រូវតែច្បាស់ មិនព្រិល មិនចាំងពន្លឺ បើមិនច្បាស់ធនាគារនឹងបដិសេធដាច់ខាតដើម្បីការពារការក្លែងបន្លំ។',
                  style: _s(11.5, c: Kyc.muted, h: 1.65)),
            ]),
          ),
        ]),
      );

  Widget _uploadCard({
    required String title,
    required String en,
    required IconData icon,
    required _Doc? doc,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final filled = doc != null;
    return GestureDetector(
      onTap: filled ? null : onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: filled
              ? Kyc.card.withValues(alpha: 0.92)
              : Kyc.card.withValues(alpha: 0.42),
          border: Border.all(
              color: filled
                  ? Kyc.accentStart.withValues(alpha: 0.55)
                  : Kyc.line,
              width: 1.2),
          boxShadow: [
            if (filled)
              BoxShadow(
                  color: Kyc.accentEnd.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10)),
          ],
        ),
        child: doc == null
            ? _emptyDoc(title, en, icon)
            : _filledDoc(doc, title, onRemove),
      ),
    );
  }

  Widget _filledDoc(_Doc doc, String title, VoidCallback onRemove) =>
      Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 84,
            height: 58,
            child: Image.memory(doc.bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: Kyc.ok),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _s(12.5, w: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('${doc.name} · ${_fmtSize(doc.size)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _s(10.5, c: Kyc.muted)),
              ]),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline_rounded,
              size: 19, color: Kyc.muted),
          tooltip: 'លុប',
        ),
      ]);

  Widget _emptyDoc(String title, String en, IconData icon) => Column(children: [
        CustomPaint(
          painter: _DashedRRectPainter(
              color: Kyc.accentStart.withValues(alpha: 0.5), radius: 15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: Kyc.accentGrad,
                  boxShadow: [
                    BoxShadow(
                        color: Kyc.accentEnd.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.file_upload_outlined,
                    size: 13, color: Kyc.gold),
                const SizedBox(width: 5),
                Text('ជ្រើសរើស ឬអូសទម្លាក់ឯកសារ',
                    style: _s(11.5, w: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              Text('PNG · JPG · JPEG · អតិបរមា 10MB',
                  style: _s(9.5, c: Kyc.muted.withValues(alpha: 0.85))),
            ]),
          ),
        ),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(child: Text(title, style: _s(12.5, w: FontWeight.w800))),
          Text(en, style: _s(9.5, c: Kyc.muted.withValues(alpha: 0.75))),
        ]),
      ]);

  Widget _uploadProgress() {
    final pct = (_progress * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Kyc.card.withValues(alpha: 0.85),
        border: Border.all(color: Kyc.line),
      ),
      child: Column(children: [
        Row(children: [
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Kyc.gold))),
          const SizedBox(width: 9),
          Expanded(
              child: Text('កំពុងផ្ទុកឯកសារ…',
                  style: _s(12, w: FontWeight.w700))),
          ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (r) => Kyc.accentGrad.createShader(r),
            child: Text('$pct%',
                style: _s(15, w: FontWeight.w900, c: Colors.white)),
          ),
        ]),
        const SizedBox(height: 11),
        LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth;
          return SizedBox(
            height: 10,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: BoxDecoration(
                    color: Kyc.line, borderRadius: BorderRadius.circular(99)),
              ),
              FractionallySizedBox(
                widthFactor: _progress.clamp(0.01, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: Kyc.accentGrad,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                          color: Kyc.accentEnd.withValues(alpha: 0.55),
                          blurRadius: 12),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: (w * _progress - 7).clamp(0.0, w - 14),
                top: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.white),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ───────────────────────── STEP 2 ─────────────────────────

  Widget _stepSelfie() {
    final has = _selfie != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titleBlock('ថតរូបផ្ទាល់ខ្លួនជាមួយអត្តសញ្ញាណប័ណ្ណ',
            'Selfie with National ID'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Kyc.card.withValues(alpha: 0.62),
            border: Border.all(color: Kyc.line),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: Kyc.gold),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                  'តម្រូវឲ្យលោកអ្នកថតរូបកាន់អត្តសញ្ញាណប័ណ្ណរបស់ខ្លួនឯង ដោយបង្ហាញឲ្យឃើញច្បាស់ទាំងផ្ទៃមុខរបស់អ្នក និងព័ត៌មានលើអត្តសញ្ញាណប័ណ្ណ។',
                  style: _s(11.5, c: Kyc.muted, h: 1.6)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _selfieViewport(has),
        const SizedBox(height: 16),
        if (!has) ...[
          _GradientButton(
            label: 'បើកកាមេរ៉ា',
            caption: 'OPEN CAMERA',
            icon: Icons.photo_camera_rounded,
            onTap: () => _pickSelfie(ImageSource.camera),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () => _pickSelfie(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined,
                  size: 15, color: Kyc.muted),
              label: Text('ជ្រើសរើសពីវិចិត្រសាល',
                  style: _s(11.5, c: Kyc.muted, w: FontWeight.w600)),
            ),
          ),
        ] else
          Row(children: [
            Expanded(
              child: _OutlineButton(
                  label: 'ថតឡើងវិញ',
                  icon: Icons.refresh_rounded,
                  onTap: () => _pickSelfie(ImageSource.camera)),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _GradientButton(
                label: 'បញ្ជូនការផ្ទៀងផ្ទាត់',
                caption: 'SUBMIT FOR VERIFICATION',
                icon: Icons.verified_rounded,
                onTap: _submit,
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _selfieViewport(bool has) => AspectRatio(
        aspectRatio: 0.82,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
                colors: [Color(0xFF3A2664), Color(0xFF170D2B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            border: Border.all(
                color: has
                    ? Kyc.ok.withValues(alpha: 0.6)
                    : Kyc.accentStart.withValues(alpha: 0.45),
                width: 1.4),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 26,
                  offset: const Offset(0, 14)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(fit: StackFit.expand, children: [
              if (has)
                Image.memory(_selfie!.bytes, fit: BoxFit.cover)
              else
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.25),
                        radius: 0.95,
                        colors: [
                          Kyc.accentEnd.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: CustomPaint(
                        painter: _GuidePainter(phase: _pulse.value * 16)),
                  ),
                ),
              if (!has) ...[
                Align(
                  alignment: const Alignment(0, -0.66),
                  child: _hintChip(Icons.face_retouching_natural, 'ផ្ទៃមុខ'),
                ),
                Align(
                  alignment: const Alignment(0, 0.72),
                  child: _hintChip(Icons.badge_outlined, 'អត្តសញ្ញាណប័ណ្ណ'),
                ),
              ],
              if (has)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(99),
                      border:
                          Border.all(color: Kyc.ok.withValues(alpha: 0.7)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 12, color: Kyc.ok),
                      const SizedBox(width: 4),
                      Text('រួចរាល់',
                          style: _s(9.5,
                              w: FontWeight.w800, c: Colors.white)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      );

  Widget _hintChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Kyc.gold),
          const SizedBox(width: 5),
          Text(label,
              style: _s(9.5, w: FontWeight.w700, c: Colors.white)),
        ]),
      );

  // ───────────────────────── STEP 3 ─────────────────────────

  Widget _stepReview() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: Column(children: [
          const SizedBox(height: 6),
          _clock(),
          const SizedBox(height: 20),
          ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFFFFB199), Color(0xFFFF8A3D), Color(0xFFFF5A8A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight)
                .createShader(r),
            child: Text('កំពុងពិនិត្យទិន្នន័យ',
                textAlign: TextAlign.center,
                style: _s(21, w: FontWeight.w900, c: Colors.white)),
          ),
          const SizedBox(height: 3),
          Text('Under Review',
              style: _s(11,
                  c: Kyc.muted.withValues(alpha: 0.8), ls: 1.6)),
          const SizedBox(height: 12),
          Text(
              'ក្រុមការងាររបស់យើងកំពុងពិនិត្យផ្ទៀងផ្ទាត់ឯកសាររបស់អ្នក។ លទ្ធផលនឹងជូនដំណឹងក្នុងរយៈពេលប្រហែល ១ ម៉ោង (អនុម័ត ឬ បដិសេធ)។',
              textAlign: TextAlign.center,
              style: _s(12, c: Kyc.muted, h: 1.7)),
          const SizedBox(height: 20),
          _summaryCard(),
          const SizedBox(height: 18),
          _GradientButton(
            label: 'ត្រឡប់ទៅទំព័រដើម',
            caption: 'BACK TO HOME',
            icon: Icons.home_rounded,
            onTap: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _reset,
            child: Text('ដាក់ឯកសារឡើងវិញ',
                style: _s(11, c: Kyc.muted.withValues(alpha: 0.8))),
          ),
        ]),
      );

  Widget _clock() => SizedBox(
        width: 168,
        height: 168,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _spin]),
          builder: (_, __) {
            final p = _pulse.value;
            return Stack(alignment: Alignment.center, children: [
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Kyc.accentEnd.withValues(alpha: 0.22 + 0.10 * (1 - (p - 0.5).abs() * 2)),
                      Colors.transparent,
                    ],
                    stops: const [0.32, 1.0],
                  ),
                ),
              ),
              for (var i = 0; i < 2; i++) _ring((p + i * 0.5) % 1.0),
              CustomPaint(
                size: const Size(168, 168),
                painter: _SweepRingPainter(
                    angle: _spin.value * 2 * math.pi),
              ),
              Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Kyc.accentGrad,
                  boxShadow: [
                    BoxShadow(
                        color: Kyc.accentEnd.withValues(alpha: 0.55),
                        blurRadius: 30,
                        spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    color: Colors.white, size: 40),
              ),
            ]);
          },
        ),
      );

  Widget _ring(double p) => Opacity(
        opacity: (1 - p) * 0.5,
        child: Transform.scale(
          scale: 0.72 + p * 0.62,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Kyc.accentStart.withValues(alpha: 0.75), width: 1.6),
            ),
          ),
        ),
      );

  Widget _summaryCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              Kyc.card.withValues(alpha: 0.95),
              Kyc.card.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Kyc.line),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 22,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Column(children: [
          Row(children: [
            Text('ឯកសារបានផ្ទុក', style: _s(12.5, w: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Kyc.accentStart.withValues(alpha: 0.16),
                border:
                    Border.all(color: Kyc.accentStart.withValues(alpha: 0.45)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Opacity(
                    opacity: 0.45 + 0.55 * (0.5 + 0.5 * math.sin(_pulse.value * 2 * math.pi)),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Kyc.gold),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text('រង់ចាំពិនិត្យ',
                    style: _s(9.5, w: FontWeight.w800, c: Kyc.gold)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _thumb(_front, Icons.badge_outlined, 'មុខ')),
            const SizedBox(width: 8),
            Expanded(
                child: _thumb(_back, Icons.flip_to_back_rounded, 'ខ្នង')),
            const SizedBox(width: 8),
            Expanded(
                child: _thumb(_selfie, Icons.face_rounded, 'Selfie')),
          ]),
          const SizedBox(height: 14),
          Divider(color: Kyc.line.withValues(alpha: 0.8), height: 1),
          _row('លេខយោង', _ref),
          _row('កាលបរិច្ឆេទ', _fmtWhen(_submittedAt)),
          _row('រយៈពេលពិនិត្យ', '≈ ១ ម៉ោង'),
          const SizedBox(height: 4),
        ]),
      );

  Widget _thumb(_Doc? doc, IconData icon, String label) => Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 62,
            width: double.infinity,
            color: Kyc.cardHi,
            alignment: Alignment.center,
            child: doc == null
                ? Icon(icon, size: 22, color: Kyc.muted.withValues(alpha: 0.7))
                : Image.memory(doc.bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: _s(9.5, c: Kyc.muted, w: FontWeight.w600)),
      ]);

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(k, style: _s(11.5, c: Kyc.muted)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _s(11.5, w: FontWeight.w700))),
        ]),
      );

  // ───────────────────────── toast ─────────────────────────

  Widget _toastLayer() => Positioned(
        left: 16,
        right: 16,
        bottom: 18,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) {
            final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: t,
              child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.5), end: Offset.zero)
                      .animate(t),
                  child: c),
            );
          },
          child: _toastMsg == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey<String>(_toastMsg!),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Kyc.cardHi.withValues(alpha: 0.97),
                    border: Border.all(
                        color: (_toastError ? Kyc.bad : Kyc.ok)
                            .withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 22,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(children: [
                    Icon(
                        _toastError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: _toastError ? Kyc.bad : Kyc.ok),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(_toastMsg!,
                            style: _s(11.5, w: FontWeight.w600, h: 1.4))),
                  ]),
                ),
        ),
      );
}

// ============================================================================
//  ចំណុចចូល (entry card) — ជំនួស «បើមិនឃើញប្រាក់ទេ ចុចទីនេះ» ដោយ flow KYC
// ============================================================================
class KycEntryCard extends StatefulWidget {
  final bool prominent;
  const KycEntryCard({super.key, this.prominent = false});
  @override
  State<KycEntryCard> createState() => _KycEntryCardState();
}

class _KycEntryCardState extends State<KycEntryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _open() => Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 460),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const KycVerificationScreen(),
        transitionsBuilder: (_, a, __, child) {
          final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: t,
            child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(t),
                child: child),
          );
        },
      ));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final wave = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
          final glow = (widget.prominent ? 0.22 : 0.14) + 0.14 * wave;
          return Transform.scale(
            scale: 1 + 0.012 * wave,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Kyc.card.withValues(alpha: 0.92),
                    Kyc.cardHi.withValues(alpha: 0.55 + 0.2 * wave),
                  ],
                ),
                border: Border.all(
                    color: Kyc.accentStart.withValues(alpha: 0.32 + 0.26 * wave),
                    width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: Kyc.accentEnd.withValues(alpha: glow),
                      blurRadius: 18 + 12 * wave,
                      spreadRadius: 1),
                ],
              ),
              child: Row(children: [
                _halo(t),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ផ្ទៀងផ្ទាត់អត្តសញ្ញាណ',
                            style: _s(11.5,
                                w: FontWeight.w600,
                                c: Kyc.muted.withValues(alpha: 0.95))),
                        const SizedBox(height: 6),
                        _pill(t),
                      ]),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: Kyc.muted.withValues(alpha: 0.75)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _halo(double t) => SizedBox(
        width: 58,
        height: 58,
        child: Stack(alignment: Alignment.center, children: [
          for (var i = 0; i < 2; i++) _ripple((t + i * 0.5) % 1.0),
          Transform.rotate(
            angle: t * 2 * math.pi,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Kyc.accentStart.withValues(alpha: 0.0),
                    Kyc.accentStart.withValues(alpha: 0.0),
                    Kyc.accentStart.withValues(alpha: 0.55),
                    Kyc.gold.withValues(alpha: 0.95),
                    Kyc.accentStart.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.70, 0.86, 0.94, 1.0],
                ),
              ),
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Kyc.accentGrad,
              boxShadow: [
                BoxShadow(
                    color: Kyc.accentEnd.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: const Icon(Icons.verified_user_rounded,
                size: 21, color: Colors.white),
          ),
        ]),
      );

  Widget _ripple(double p) => Opacity(
        opacity: (1 - p) * 0.5,
        child: Transform.scale(
          scale: 0.9 + p * 0.5,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Kyc.accentStart, width: 1.4),
            ),
          ),
        ),
      );

  Widget _pill(double t) {
    final slide = math.sin(t * 2 * math.pi);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment(-1.2 + slide, -1),
          end: Alignment(0.8 + slide, 1),
          colors: const [Kyc.accentStart, Kyc.accentEnd, Kyc.gold],
        ),
        boxShadow: [
          BoxShadow(
              color: Kyc.accentEnd.withValues(alpha: 0.38),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.touch_app_rounded, size: 13, color: Colors.white),
        SizedBox(width: 5),
        Text('ចុចទីនេះ',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2)),
      ]),
    );
  }
}

// ============================================================================
//  Widgets តូចៗ + painters
// ============================================================================
class _GradientButton extends StatelessWidget {
  final String label;
  final String? caption;
  final IconData? icon;
  final VoidCallback? onTap;
  const _GradientButton(
      {required this.label, this.caption, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.42,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          gradient: Kyc.accentGrad,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (enabled)
              BoxShadow(
                  color: Kyc.accentEnd.withValues(alpha: 0.42),
                  blurRadius: 22,
                  offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 19),
                    const SizedBox(width: 8),
                  ],
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    if (caption != null)
                      Text(caption!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _OutlineButton(
      {required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        height: 55,
        decoration: BoxDecoration(
          color: Kyc.card.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Kyc.line, width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 17, color: Kyc.gold),
                  const SizedBox(width: 6),
                  Text(label,
                      style: _s(12, w: FontWeight.w700, c: Kyc.text)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// ស៊ុមដាច់ៗ (dashed) សម្រាប់ប្រអប់ផ្ទុកឯកសារ
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    const dash = 7.0, gap = 6.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(
            m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

/// ស៊ុមណែនាំថតរូប — មុខ (oval) + អត្តសញ្ញាណប័ណ្ណ (rect) + ជ្រុង
class _GuidePainter extends CustomPainter {
  final double phase;
  const _GuidePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF512F), Color(0xFFDD2476), Color(0xFFFF8A3D)],
      ).createShader(rect);

    final oval = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.355),
        width: w * 0.52,
        height: h * 0.40);
    final idRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.765),
            width: w * 0.70,
            height: h * 0.235),
        const Radius.circular(13));

    _dashed(canvas, Path()..addOval(oval), paint);
    _dashed(canvas, Path()..addRRect(idRect), paint);

    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.85);
    const m = 13.0, len = 26.0;
    _corner(canvas, const Offset(m, m), 1, 1, corner, len);
    _corner(canvas, Offset(w - m, m), -1, 1, corner, len);
    _corner(canvas, Offset(m, h - m), 1, -1, corner, len);
    _corner(canvas, Offset(w - m, h - m), -1, -1, corner, len);
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    const dash = 8.0, gap = 7.0;
    final offset = phase % (dash + gap);
    for (final m in path.computeMetrics()) {
      var d = -offset;
      while (d < m.length) {
        final s = math.max(0.0, d);
        final e = math.min(d + dash, m.length);
        if (e > s) canvas.drawPath(m.extractPath(s, e), paint);
        d += dash + gap;
      }
    }
  }

  void _corner(Canvas canvas, Offset p, double sx, double sy, Paint paint,
      double len) {
    canvas.drawLine(p, p + Offset(len * sx, 0), paint);
    canvas.drawLine(p, p + Offset(0, len * sy), paint);
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.phase != phase;
}

/// រង្វង់ពន្លឺរត់ជុំវិញនាឡិកា (រង់ចាំពិនិត្យ)
class _SweepRingPainter extends CustomPainter {
  final double angle;
  const _SweepRingPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.08));
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [
              Kyc.accentStart.withValues(alpha: 0.0),
              Kyc.accentStart.withValues(alpha: 0.45),
              Kyc.accentEnd,
              Kyc.gold,
              Kyc.accentStart.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.18, 0.42, 0.55, 0.72],
            transform: GradientRotation(angle),
          ).createShader(rect));
    final head = c + Offset(math.cos(angle) * r, math.sin(angle) * r);
    canvas.drawCircle(head, 8, Paint()..color = Kyc.gold.withValues(alpha: 0.3));
    canvas.drawCircle(head, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SweepRingPainter old) => old.angle != angle;
}
