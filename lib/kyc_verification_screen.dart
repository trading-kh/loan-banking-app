// ============================================================================
//  KYC — 3-step identity verification (dark violet / frosted glass)
//  Step 1: National ID front + back · Step 2: selfie with ID · Step 3: review
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

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

/// បង្រួមរូបភាពសម្រាប់ផ្ញើទៅ server (អតិបរមា 1600px · JPEG 82%)
String _encodeUploadBytes(Uint8List bytes) {
  var im = img.decodeImage(bytes);
  if (im == null) return '';
  im = img.bakeOrientation(im);
  const maxSide = 1600;
  if (im.width > maxSide || im.height > maxSide) {
    im = im.width >= im.height
        ? img.copyResize(im,
            width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(im,
            height: maxSide, interpolation: img.Interpolation.average);
  }
  return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(im, quality: 82))}';
}

class KycVerificationScreen extends StatefulWidget {
  /// លេខយោងប្រតិបត្តិការ (បើបើកចេញពីបង្កាន់ដៃ)
  final String? ref;
  const KycVerificationScreen({super.key, this.ref});
  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  late String _ref = widget.ref ??
      'KYC${DateTime.now().millisecondsSinceEpoch % 1000000000}';
  DateTime _submittedAt = DateTime.now();

  /// pending | approved | rejected (មកពី server)
  String _status = 'pending';
  String? _rejectReason;
  DateTime? _decidedAt;
  bool _submitting = false;
  bool _refreshingStatus = false;
  bool _syncing = false;
  bool _resultOpen = false;

  /// ពិនិត្យស្ថានភាពដោយស្វ័យប្រវត្តិ — ពេល admin អនុម័ត/បដិសេធ កម្មវិធីលោតទៅទំព័រលទ្ធផលភ្លាម
  Timer? _statusTimer;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) => _syncStatus());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncStatus();
  }

  Future<void> _restore() async {
    // Server ជាអ្នកកាន់ស្ថានភាពពិត — prefs គ្រាន់តែជា fallback ពេលគ្មានបណ្តាញ
    Map<String, dynamic>? remote;
    try {
      remote = await ApiService.kycStatus();
    } catch (_) {
      remote = null;
    }
    final sp = await SharedPreferences.getInstance();
    final at = DateTime.tryParse(sp.getString('kyc_at') ?? '');
    if (!mounted) return;
    if (remote != null) {
      final r = remote;
      final nextStatus = (r['status'] ?? 'pending').toString();
      final nextRef = (r['ref'] ?? _ref).toString();
      setState(() {
        _loadingSaved = false;
        _status = nextStatus;
        _ref = nextRef;
        _rejectReason = r['reason']?.toString();
        _submittedAt =
            DateTime.tryParse(r['submitted_at']?.toString() ?? '') ??
                at ??
                DateTime.now();
        _decidedAt = DateTime.tryParse(r['decided_at']?.toString() ?? '');
        _step = 2;
        _dir = 1;
      });
      // លទ្ធផលថ្មីដែលមិនទាន់បានបង្ហាញ → លោតទៅទំព័រលទ្ធផលដោយស្វ័យប្រវត្តិ
      if ((nextStatus == 'approved' || nextStatus == 'rejected') &&
          sp.getString('kyc_result_seen') != '$nextRef|$nextStatus') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openResult();
        });
      }
      return;
    }
    final pending = sp.getBool('kyc_pending') ?? false;
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
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
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
    if (_selfie == null || _front == null || _back == null) {
      _toast('សូមបញ្ចូលឯកសារអត្តសញ្ញាណប័ណ្ណ និងរូប Selfie ជាមុន');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final front = await compute(_encodeUploadBytes, _front!.bytes);
      final back = await compute(_encodeUploadBytes, _back!.bytes);
      final selfie = await compute(_encodeUploadBytes, _selfie!.bytes);
      if (front.isEmpty || back.isEmpty || selfie.isEmpty) {
        throw ApiException('រូបភាពមិនអាចអានបាន — សូមជ្រើសរើសម្តងទៀត');
      }
      final r = await ApiService.submitKyc(
          front: front, back: back, selfie: selfie);
      _ref = (r['ref'] ?? _ref).toString();
      _status = (r['status'] ?? 'pending').toString();
      _rejectReason = null;
      _decidedAt = null;

      final sp = await SharedPreferences.getInstance();
      await sp.setBool('kyc_pending', true);
      await sp.setString('kyc_at', DateTime.now().toIso8601String());
      await sp.setString('kyc_ref', _ref);
      if (!mounted) return;
      setState(() {
        _submittedAt = DateTime.now();
        _submitting = false;
      });
      _go(2);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('ដាក់ស្នើមិនបាន — ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('ដាក់ស្នើមិនបាន — សូមព្យាយាមម្តងទៀត');
    }
  }

  /// ទាញស្ថានភាពពី server — manual=true បង្ហាញ spinner/toast, auto=ស្ងាត់ៗ
  Future<void> _syncStatus({bool manual = false}) async {
    if (_syncing || _loadingSaved || _submitting || _resultOpen) return;
    if (_step != 2 || _status != 'pending') return;
    _syncing = true;
    if (manual && mounted) setState(() => _refreshingStatus = true);
    try {
      final r = await ApiService.kycStatus();
      if (!mounted || r == null) return;
      final next = (r['status'] ?? _status).toString();
      final decided = next == 'approved' || next == 'rejected';
      setState(() {
        _status = next;
        _rejectReason = r['reason']?.toString();
        _ref = (r['ref'] ?? _ref).toString();
        _decidedAt = DateTime.tryParse(r['decided_at']?.toString() ?? '');
      });
      if (decided) {
        final sp = await SharedPreferences.getInstance();
        await sp.setBool('kyc_pending', false);
        if (!mounted) return;
        _openResult();
      } else if (manual) {
        _toast('នៅរង់ចាំក្រុមការងារពិនិត្យ', error: false);
      }
    } catch (_) {
      if (manual && mounted) {
        _toast('មិនអាចពិនិត្យស្ថានភាពបាន — សូមព្យាយាមម្តងទៀត');
      }
    } finally {
      _syncing = false;
      if (mounted && manual) setState(() => _refreshingStatus = false);
    }
  }

  Future<void> _refreshStatus() => _syncStatus(manual: true);

  /// បើកទំព័រលទ្ធផល (ជោគជ័យ/បរាជ័យ ទំព័រតែមួយ) ដោយស្វ័យប្រវត្តិ
  Future<void> _openResult() async {
    if (_resultOpen || !mounted) return;
    if (_status != 'approved' && _status != 'rejected') return;
    _resultOpen = true;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        'kyc_result_seen', '$_ref|$_status');
    if (!mounted) {
      _resultOpen = false;
      return;
    }
    final action = await Navigator.of(context).push<String>(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 560),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (_, __, ___) => KycResultScreen(
        approved: _status == 'approved',
        ref: _ref,
        reason: _rejectReason,
        decidedAt: _decidedAt,
      ),
      transitionsBuilder: (_, a, __, child) {
        final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: t,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(t),
            child: child,
          ),
        );
      },
    ));
    _resultOpen = false;
    if (!mounted) return;
    if (action == 'resubmit') await _reset();
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
      _status = 'pending';
      _rejectReason = null;
      _decidedAt = null;
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
                label: _submitting
                    ? 'កំពុងបញ្ជូន…'
                    : 'បញ្ជូនការផ្ទៀងផ្ទាត់',
                caption:
                    _submitting ? 'UPLOADING…' : 'SUBMIT FOR VERIFICATION',
                icon: _submitting
                    ? Icons.cloud_upload_rounded
                    : Icons.verified_rounded,
                onTap: _submitting ? null : _submit,
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

  Widget _stepReview() {
    final approved = _status == 'approved';
    final rejected = _status == 'rejected';
    final title = approved
        ? 'អត្តសញ្ញាណបានផ្ទៀងផ្ទាត់'
        : rejected
            ? 'សំណើត្រូវបានបដិសេធ'
            : 'កំពុងពិនិត្យទិន្នន័យ';
    final english = approved
        ? 'IDENTITY VERIFIED'
        : rejected
            ? 'VERIFICATION REJECTED'
            : 'UNDER REVIEW';
    final desc = approved
        ? 'ឯកសាររបស់អ្នកឆ្លងកាត់ការផ្ទៀងផ្ទាត់ដោយជោគជ័យ។ ឥឡូវលោកអ្នកអាចប្រើសេវាធនាគារបានពេញលេញ។'
        : rejected
            ? 'ឯកសាររបស់អ្នកមិនត្រូវបានអនុម័តទេ។ សូមពិនិត្យមូលហេតុខាងក្រោម ហើយដាក់ឯកសារឡើងវិញ។'
            : 'ក្រុមការងាររបស់យើងកំពុងពិនិត្យផ្ទៀងផ្ទាត់ឯកសាររបស់អ្នក។ (បន្តិចទៀតនេះ) សូមមេត្តារង់ចាំមួយភ្លេត។';
    final titleColors = approved
        ? const [Color(0xFF7CF5C0), Color(0xFF34D399), Color(0xFF22D3EE)]
        : rejected
            ? const [Color(0xFFFFB199), Color(0xFFFF6B6B), Color(0xFFDD2476)]
            : const [Color(0xFFFFB199), Color(0xFFFF8A3D), Color(0xFFFF5A8A)];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
      child: Column(children: [
        const SizedBox(height: 6),
        if (approved)
          _statusEmblem(Icons.verified_rounded, Kyc.ok,
              const [Color(0xFF10B981), Color(0xFF34D399)], Kyc.ok)
        else if (rejected)
          _statusEmblem(Icons.close_rounded, Kyc.bad,
              const [Color(0xFFFF6B6B), Color(0xFFDD2476)], Kyc.bad)
        else
          _clock(),
        const SizedBox(height: 20),
        ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
                  colors: titleColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight)
              .createShader(r),
          child: Text(title,
              textAlign: TextAlign.center,
              style: _s(21, w: FontWeight.w900, c: Colors.white)),
        ),
        const SizedBox(height: 3),
        Text(english,
            style: _s(11, c: Kyc.muted.withValues(alpha: 0.8), ls: 1.6)),
        const SizedBox(height: 12),
        Text(desc,
            textAlign: TextAlign.center, style: _s(12, c: Kyc.muted, h: 1.7)),
        if (rejected && (_rejectReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          _reasonCard(),
        ],
        const SizedBox(height: 20),
        _summaryCard(),
        const SizedBox(height: 18),
        if (rejected) ...[
          _GradientButton(
            label: 'ដាក់ឯកសារឡើងវិញ',
            caption: 'RESUBMIT DOCUMENTS',
            icon: Icons.refresh_rounded,
            onTap: _reset,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
            child: Text('ត្រឡប់ទៅទំព័រដើម',
                style: _s(11.5, c: Kyc.muted.withValues(alpha: 0.85))),
          ),
        ] else
          _GradientButton(
            label: 'ត្រឡប់ទៅទំព័រដើម',
            caption: 'BACK TO HOME',
            icon: Icons.home_rounded,
            onTap: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        if (!approved && !rejected) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _refreshingStatus ? null : _refreshStatus,
            icon: _refreshingStatus
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.8, color: Kyc.muted))
                : const Icon(Icons.sync_rounded, size: 15, color: Kyc.muted),
            label: Text('ពិនិត្យស្ថានភាពឡើងវិញ',
                style: _s(11, c: Kyc.muted.withValues(alpha: 0.85))),
          ),
        ],
      ]),
    );
  }

  Widget _statusEmblem(
          IconData icon, Color glow, List<Color> colors, Color ring) =>
      SizedBox(
        width: 168,
        height: 168,
        child: AnimatedBuilder(
          animation: _pulse,
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
                      glow.withValues(
                          alpha: 0.20 + 0.10 * (1 - (p - 0.5).abs() * 2)),
                      Colors.transparent,
                    ],
                    stops: const [0.32, 1.0],
                  ),
                ),
              ),
              for (var i = 0; i < 2; i++) _ring((p + i * 0.5) % 1.0, ring),
              Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: glow.withValues(alpha: 0.55),
                        blurRadius: 30,
                        spreadRadius: 2),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 44),
              ),
            ]);
          },
        ),
      );

  Widget _reasonCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Kyc.bad.withValues(alpha: 0.10),
          border: Border.all(color: Kyc.bad.withValues(alpha: 0.45)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: Kyc.bad, size: 17),
            const SizedBox(width: 7),
            Text('មូលហេតុបដិសេធ',
                style: _s(12, w: FontWeight.w800, c: Kyc.bad)),
          ]),
          const SizedBox(height: 8),
          Text(_rejectReason!, style: _s(12, c: Kyc.text, h: 1.6)),
          if (_decidedAt != null) ...[
            const SizedBox(height: 6),
            Text('បដិសេធ ${_fmtWhen(_decidedAt!)}',
                style: _s(10, c: Kyc.muted)),
          ],
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

  Widget _ring(double p, [Color color = Kyc.accentStart]) => Opacity(
        opacity: (1 - p) * 0.5,
        child: Transform.scale(
          scale: 0.72 + p * 0.62,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withValues(alpha: 0.75), width: 1.6),
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
            Builder(builder: (_) {
              final approved = _status == 'approved';
              final rejected = _status == 'rejected';
              final color = approved
                  ? Kyc.ok
                  : rejected
                      ? Kyc.bad
                      : Kyc.gold;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: color.withValues(alpha: 0.14),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_status == 'pending')
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Opacity(
                        opacity: 0.45 +
                            0.55 *
                                (0.5 +
                                    0.5 *
                                        math.sin(
                                            _pulse.value * 2 * math.pi)),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, color: color),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                  const SizedBox(width: 5),
                  Text(
                      approved
                          ? 'បានអនុម័ត'
                          : rejected
                              ? 'បានបដិសេធ'
                              : 'រង់ចាំពិនិត្យ',
                      style: _s(9.5, w: FontWeight.w800, c: color)),
                ]),
              );
            }),
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
          if (_status == 'pending')
            _row('រយៈពេលពិនិត្យ',
                '(បន្តិចទៀតនេះ) សូមមេត្តារង់ចាំមួយភ្លេត',
                maxLines: 2)
          else
            _row('សម្រេចនៅ', _fmtWhen(_decidedAt ?? _submittedAt)),
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

  Widget _row(String k, String v, {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(k, style: _s(11.5, c: Kyc.muted)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  maxLines: maxLines,
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

// ============================================================================
//  ទំព័រលទ្ធផល — ជោគជ័យ / បរាជ័យ (ទំព័រតែមួយ · អត្ថបទខុសគ្នា)
// ============================================================================
class KycResultScreen extends StatefulWidget {
  final bool approved;
  final String ref;
  final String? reason;
  final DateTime? decidedAt;
  const KycResultScreen({
    super.key,
    required this.approved,
    required this.ref,
    this.reason,
    this.decidedAt,
  });
  @override
  State<KycResultScreen> createState() => _KycResultScreenState();
}

class _KycResultScreenState extends State<KycResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  bool get _ok => widget.approved;
  Color get _tone => _ok ? Kyc.ok : Kyc.bad;
  List<Color> get _tint => _ok
      ? const [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF22D3EE)]
      : const [Color(0xFFFF6B6B), Color(0xFFDD2476), Color(0xFFFF512F)];

  String get _title => _ok
      ? 'អបអរសាទរ លោកអ្នកទទួលបានជោគជ័យសម្រាប់ការដាក់ប្រាក់ហើយ'
      : 'សូមទោស លោកអ្នកមិនទទួលបានជោគជ័យសម្រាប់ការដាក់ប្រាក់ទេ';

  String get _desc => _ok
      ? 'ការផ្ទៀងផ្ទាត់អត្តសញ្ញាណរបស់លោកអ្នកត្រូវបានអនុម័តដោយជោគជ័យ។ ឥឡូវលោកអ្នកអាចប្រើសេវាធនាគារបានពេញលេញ។'
      : 'ការផ្ទៀងផ្ទាត់អត្តសញ្ញាណរបស់លោកអ្នកមិនត្រូវបានអនុម័តទេ។ សូមពិនិត្យមូលហេតុខាងក្រោម ហើយដាក់ឯកសារឡើងវិញ។';

  @override
  void dispose() {
    _pulse.dispose();
    _enter.dispose();
    super.dispose();
  }

  String _fmtWhen(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} · $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Kyc.bgBottom,
        body: Container(
          decoration: const BoxDecoration(gradient: Kyc.bgGrad),
          child: SafeArea(
            child: Stack(children: [
              _blob(Alignment.topRight, _ok ? Kyc.ok : Kyc.accentEnd),
              _blob(Alignment.bottomLeft,
                  _ok ? const Color(0xFF22D3EE) : Kyc.accentStart),
              Column(children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
                    child: Column(children: [
                      const SizedBox(height: 10),
                      _in(_emblem(), 0.0),
                      const SizedBox(height: 22),
                      _in(
                        ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (r) => LinearGradient(
                            colors: _ok
                                ? const [
                                    Color(0xFF7CF5C0),
                                    Color(0xFF34D399),
                                    Color(0xFF22D3EE),
                                  ]
                                : const [
                                    Color(0xFFFFB199),
                                    Color(0xFFFF6B6B),
                                    Color(0xFFDD2476),
                                  ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(r),
                          child: Text(_title,
                              textAlign: TextAlign.center,
                              style: _s(20,
                                  w: FontWeight.w900, c: Colors.white, h: 1.55)),
                        ),
                        0.10,
                      ),
                      const SizedBox(height: 6),
                      _in(
                        Text(_ok ? 'DEPOSIT APPROVED' : 'DEPOSIT REJECTED',
                            style: _s(11,
                                c: Kyc.muted.withValues(alpha: 0.8),
                                ls: 1.8)),
                        0.16,
                      ),
                      const SizedBox(height: 14),
                      _in(
                        Text(_desc,
                            textAlign: TextAlign.center,
                            style: _s(12, c: Kyc.muted, h: 1.7)),
                        0.22,
                      ),
                      if (!_ok && (widget.reason ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _in(_reasonCard(), 0.28),
                      ],
                      const SizedBox(height: 20),
                      _in(_infoCard(), 0.34),
                      const SizedBox(height: 20),
                      _in(_actions(), 0.42),
                      const SizedBox(height: 10),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _blob(Alignment align, Color color) => Align(
        alignment: align,
        child: FractionalTranslation(
          translation: Offset(align.x * 0.55, align.y * 0.55),
          child: Container(
            width: 280,
            height: 280,
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

  Widget _in(Widget child, double start) {
    final a = CurvedAnimation(
        parent: _enter,
        curve: Interval(start, 1.0, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.10), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Kyc.card.withValues(alpha: 0.8),
                border: Border.all(color: Kyc.line),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('លទ្ធផលផ្ទៀងផ្ទាត់អត្តសញ្ញាណ',
                      style: _s(15, w: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Identity Verification · Result',
                      style: _s(10.5,
                          c: Kyc.muted.withValues(alpha: 0.85), ls: 0.4)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: _tone.withValues(alpha: 0.16),
              border: Border.all(color: _tone.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 12, color: _tone),
              const SizedBox(width: 4),
              Text(_ok ? 'ជោគជ័យ' : 'បរាជ័យ',
                  style: _s(9.5, w: FontWeight.w800, c: _tone, ls: 0.6)),
            ]),
          ),
        ]),
      );

  Widget _emblem() => SizedBox(
        width: 178,
        height: 178,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _enter]),
          builder: (_, __) {
            final p = _pulse.value;
            final shake = _ok
                ? 0.0
                : math.sin(_enter.value * math.pi * 7) *
                    7 *
                    (1 - _enter.value);
            return Transform.translate(
              offset: Offset(shake, 0),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 178,
                  height: 178,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _tone.withValues(
                            alpha: 0.22 +
                                0.10 * (1 - (p - 0.5).abs() * 2)),
                        Colors.transparent,
                      ],
                      stops: const [0.32, 1.0],
                    ),
                  ),
                ),
                for (var i = 0; i < 2; i++) _ring((p + i * 0.5) % 1.0),
                if (_ok)
                  CustomPaint(
                    size: const Size(178, 178),
                    painter: _BurstPainter(
                      progress: Curves.easeOutCubic.transform(_enter.value),
                      color: Kyc.ok,
                    ),
                  ),
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: _tint,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: _tone.withValues(alpha: 0.55),
                          blurRadius: 34,
                          spreadRadius: 2),
                    ],
                  ),
                  child: Icon(_ok ? Icons.check_rounded : Icons.close_rounded,
                      color: Colors.white, size: 50),
                ),
              ]),
            );
          },
        ),
      );

  Widget _ring(double p) => Opacity(
        opacity: (1 - p) * 0.5,
        child: Transform.scale(
          scale: 0.72 + p * 0.62,
          child: Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: _tone.withValues(alpha: 0.75), width: 1.6),
            ),
          ),
        ),
      );

  Widget _reasonCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Kyc.bad.withValues(alpha: 0.10),
          border: Border.all(color: Kyc.bad.withValues(alpha: 0.45)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: Kyc.bad, size: 17),
            const SizedBox(width: 7),
            Text('មូលហេតុបដិសេធ',
                style: _s(12, w: FontWeight.w800, c: Kyc.bad)),
          ]),
          const SizedBox(height: 8),
          Text(widget.reason!, style: _s(12, c: Kyc.text, h: 1.6)),
        ]),
      );

  Widget _infoCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
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
          _row('លេខយោង', widget.ref),
          Divider(color: Kyc.line.withValues(alpha: 0.65), height: 1),
          _row('ស្ថានភាព', _ok ? 'បានអនុម័ត' : 'បានបដិសេធ', valueColor: _tone),
          Divider(color: Kyc.line.withValues(alpha: 0.65), height: 1),
          _row('សម្រេចនៅ', _fmtWhen(widget.decidedAt ?? DateTime.now())),
        ]),
      );

  Widget _row(String k, String v, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(k, style: _s(11.5, c: Kyc.muted)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _s(11.5,
                      w: FontWeight.w700, c: valueColor ?? Kyc.text))),
        ]),
      );

  Widget _actions() => _ok
      ? _GradientButton(
          label: 'ត្រឡប់ទៅទំព័រដើម',
          caption: 'BACK TO HOME',
          icon: Icons.home_rounded,
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
        )
      : Column(children: [
          _GradientButton(
            label: 'ដាក់ឯកសារឡើងវិញ',
            caption: 'RESUBMIT DOCUMENTS',
            icon: Icons.refresh_rounded,
            onTap: () => Navigator.of(context).pop('resubmit'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: Text('ត្រឡប់ទៅទំព័រដើម',
                style: _s(11.5, c: Kyc.muted.withValues(alpha: 0.85))),
          ),
        ]);
}

/// ចំណុចពន្លឺហោះចេញពីរង្វង់ (ជោគជ័យ)
class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n + 0.32;
      final r = 58 + 52 * progress;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      final op = ((1 - progress).clamp(0.0, 1.0)) * 0.9;
      canvas.drawCircle(
          p,
          i.isEven ? 3.2 : 2.0,
          Paint()
            ..color = (i % 3 == 0 ? Kyc.gold : color).withValues(alpha: op));
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.progress != progress || old.color != color;
}
