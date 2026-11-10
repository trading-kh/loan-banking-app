// ============================================================================
//  Loan & Banking App — Aura Bank (ABA-Style Navy Theme)
//  ✅ All logic preserved: API · FCM · Google Auth · PIN Bypass · Models
//  ⚡ Performance: cached themes · lazy tabs · const widgets · RepaintBoundary
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

// Firebase & Google Sign-In
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 🎯 FCM & Notifications
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

import 'api_service.dart';
import 'services/biometric_service.dart';
import 'services/pdf_service.dart';
import 'extra_features.dart';
import 'premium_features.dart';
import 'onboarding.dart';
import 'ui_extras.dart';
import 'loan_module.dart';
import 'screens/account_screen.dart';
import 'screens/receive_money_screen.dart';
import 'screens/tracking_screen.dart';
import 'device_services.dart';
import 'device_command_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.initialize();
  } catch (e) {
    print("Firebase initialization error: $e");
  }
  await premium.bootstrap();
  await bank.bootstrap();
  runApp(const BankApp());
}

// ============================================================================
//  🎨 PALETTE — ABA Navy
// ============================================================================
class C {
  // Backgrounds
  static const bgLight = Color(0xFFF2F5F8);
  static const bgDark = Color(0xFF033553); // ABA navy

  // Surfaces
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF05405F);
  static const surfaceDark = Color(0xFF0A4B6E);

  // Brand (navy gradient)
  static const brandStart = Color(0xFF033553);
  static const brandMid = Color(0xFF044466);
  static const brandEnd = Color(0xFF0A5A87);

  // ABA signature
  static const abaRed = Color(0xFFE05252);
  static const iconTint = Color(0xFFCFD8DC);
  static const line = Color(0x40FFFFFF);

  // Accents (legacy names kept for compatibility)
  static const accent = Color(0xFF3B9AD9);
  static const accentGreen = Color(0xFF2ECC9A);
  static const accentRed = Color(0xFFE05252);
  static const accentGold = Color(0xFFF5B83D);
  static const accentPurple = Color(0xFF7C8CF8);
  static const accentTeal = Color(0xFF3CC4D9);
}

extension Ctx on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? C.bgDark : C.bgLight;
  Color get card => isDark ? C.cardDark : C.cardLight;
  Color get surface => isDark ? C.surfaceDark : C.cardLight;
  Color get muted => isDark ? const Color(0xFFA9BAC4) : const Color(0xFF64748B);
  Color get ink => isDark ? const Color(0xFFE6EDF1) : const Color(0xFF0F2A3D);
  Color get border =>
      isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFE1E7ED);
  // Legacy aliases
  Color get shadowDark => isDark ? Colors.black : const Color(0xFF94A3B8);
  Color get shadowLight => isDark ? const Color(0xFF0A4B6E) : Colors.white;
}

// ============================================================================
//  🎨 THEME
// ============================================================================
ThemeData buildTheme(Brightness b, Color seed) {
  final dark = b == Brightness.dark;
  final bg = dark ? C.bgDark : C.bgLight;
  final ink = dark ? const Color(0xFFE6EDF1) : const Color(0xFF0F2A3D);

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: 'NotoSansKhmer',
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.accent,
      brightness: b,
      surface: bg,
      primary: C.accent,
      secondary: C.abaRed,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: ink,
      titleTextStyle: TextStyle(
          fontFamily: 'NotoSansKhmer',
          fontSize: 18, fontWeight: FontWeight.w700, color: ink),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent, elevation: 0,
      indicatorColor: Colors.transparent,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none, enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: C.accent,
      selectionColor: C.accent.withValues(alpha: 0.25),
      selectionHandleColor: C.accent,
    ),
  );
}

// ⚡ Cache themes — មិនបង្កើតថ្មីរាល់ពេល notifyListeners()
final ThemeData _lightTheme = buildTheme(Brightness.light, C.accent);
final ThemeData _darkTheme = buildTheme(Brightness.dark, C.accent);

// ============================================================================
//  SCROLL BEHAVIOR
// ============================================================================
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch, PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad, PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus, PointerDeviceKind.unknown,
      };
}

// ============================================================================
//  HELPERS
// ============================================================================
String money(double v) {
  final neg = v < 0;
  final parts = v.abs().toStringAsFixed(2).split('.');
  final buf = StringBuffer();
  for (int i = 0; i < parts[0].length; i++) {
    if (i > 0 && (parts[0].length - i) % 3 == 0) buf.write(',');
    buf.write(parts[0][i]);
  }
  return '${neg ? "-" : ""}\$${buf.toString()}.${parts[1]}';
}

String dayLabel(DateTime t) {
  final now = DateTime.now();
  final d0 = DateTime(now.year, now.month, now.day);
  final td = DateTime(t.year, t.month, t.day);
  final diff = d0.difference(td).inDays;
  if (diff == 0) return 'ថ្ងៃនេះ';
  if (diff == 1) return 'ម្សិលមិញ';
  return '${t.day}/${t.month}/${t.year}';
}

String fmtTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final ap = t.hour >= 12 ? 'PM' : 'AM';
  return '${dayLabel(t)}, $h:$m $ap';
}

// ── ពេលវេលាជាភាសាខ្មែរ (សម្រាប់ receipt / flow / notification) ──
const _khMonthsLong = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា',
  'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];

String khDateLong(DateTime t) =>
    'ថ្ងៃទី ${t.day} ខែ ${_khMonthsLong[t.month - 1]} ឆ្នាំ ${t.year}';

String khClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'ល្ងាច' : 'ព្រឹក'}';
}

/// «9 វិច្ឆិកា | 11:39 PM» — ក្រោមជំហាននីមួយៗក្នុង flow
String khFlowStamp(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_khMonthsLong[t.month - 1]} | $h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

double? parseAmt(String s) {
  final v = double.tryParse(s.trim());
  return (v == null || v <= 0) ? null : v;
}

Color catColor(String c) {
  switch (c) {
    case 'ទិញទំនិញ': return C.accent;
    case 'អាហារ': return const Color(0xFFF97316);
    case 'វិក្កយបត្រ': return const Color(0xFFEAB308);
    case 'ដឹកជញ្ជូន': return C.accentTeal;
    case 'កម្សាន្ត': return const Color(0xFFEC4899);
    case 'កម្ចី': return C.accentPurple;
    case 'សន្សំ': return C.accentGreen;
    default: return const Color(0xFF64748B);
  }
}

Widget sb(Widget Function() b) =>
    ListenableBuilder(listenable: bank, builder: (_, __) => b());

void toast(BuildContext c, String msg, {bool error = false}) {
  final overlay = Overlay.of(c);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ToastWidget(
      message: msg, error: error, onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

// ============================================================================
//  🎨 GRADIENTS
// ============================================================================
class AuraGrad {
  static const brand = LinearGradient(
    colors: [Color(0xFF0A5A87), Color(0xFF044466), Color(0xFF033553)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  // ប៊ូតុងសំខាន់ — ភ្លឺជាងផ្ទៃ navy ដើម្បីមើលឃើញច្បាស់
  static const button = LinearGradient(
    colors: [Color(0xFF2A8BC9), Color(0xFF0A5A87)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const soft = LinearGradient(
    colors: [Color(0x223B9AD9), Color(0x220A5A87)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  const GradientText(this.text, {super.key, required this.style,
      this.gradient = AuraGrad.brand});
  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (b) => gradient.createShader(b),
        blendMode: BlendMode.srcIn,
        child: Text(text, style: style),
      );
}

// ============================================================================
//  TOAST WIDGET
// ============================================================================
class _ToastWidget extends StatefulWidget {
  final String message;
  final bool error;
  final VoidCallback onDone;
  const _ToastWidget({required this.message, required this.error, required this.onDone});
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final Animation<double> _scale =
      Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2400), () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16, right: 16,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.border),
                boxShadow: [
                  BoxShadow(
                    color: context.isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 10), blurRadius: 28, spreadRadius: -6,
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: (widget.error ? C.accentRed : C.accentGreen)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.error ? Icons.error_outline : Icons.check_circle,
                    color: widget.error ? C.accentRed : C.accentGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.message,
                      style: TextStyle(color: context.ink, fontSize: 13.5,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  ANIMATED COUNTER
// ============================================================================
class AnimatedCounter extends StatelessWidget {
  final double value;
  final TextStyle style;
  final Duration duration;
  final String Function(double) formatter;
  const AnimatedCounter({
    super.key, required this.value, required this.style,
    this.duration = const Duration(milliseconds: 1200), this.formatter = money,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: duration, curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(formatter(v), style: style),
      );
}

// ============================================================================
//  STAGGERED ITEM
// ============================================================================
class StaggeredItem extends StatefulWidget {
  final Widget child;
  final int index;
  const StaggeredItem({super.key, required this.child, required this.index});
  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.15), end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child));
}

// ============================================================================
//  ICONS
// ============================================================================
class AppIcons {
  static const Map<int, IconData> _map = {
    0: Icons.circle, 1: Icons.shopping_bag, 2: Icons.local_cafe,
    3: Icons.arrow_downward, 4: Icons.directions_car, 5: Icons.money_off,
    6: Icons.bolt, 7: Icons.movie, 8: Icons.restaurant,
    9: Icons.send_rounded, 10: Icons.add_card, 11: Icons.request_quote,
    12: Icons.savings, 13: Icons.water_drop, 14: Icons.phone_android,
    15: Icons.wifi, 16: Icons.receipt_long, 17: Icons.verified_user,
    18: Icons.local_offer, 19: Icons.flag,
  };
  static IconData get(int id) => _map[id] ?? Icons.circle;
  static int idOf(IconData icon) {
    for (final e in _map.entries) {
      if (e.value == icon) return e.key;
    }
    return 0;
  }
}

// ============================================================================
//  MODELS
// ============================================================================
class Tx {
  final int id;
  final String title, category;
  final DateTime time;
  final double amount;
  final bool isExpense;
  final IconData icon;
  final int cardId;
  Tx({required this.id, required this.title, required this.category,
      required this.time, required this.amount, required this.isExpense,
      required this.icon, required this.cardId});
  factory Tx.fromJson(Map<String, dynamic> j) => Tx(
        id: j['id'] as int, title: j['title'] as String,
        category: j['category'] as String,
        time: DateTime.parse(j['created_at'] as String).toLocal(),
        amount: (j['amount'] as num).toDouble(),
        isExpense: j['is_expense'] == 1,
        icon: AppIcons.get(j['icon_code'] as int? ?? 0),
        cardId: j['card_id'] as int,
      );
}

class BankCard {
  final int id;
  final String name, number, expiry, cvv;
  double balance;
  final Color c1, c2;
  bool frozen, online;
  double dailyLimit;
  BankCard({required this.id, required this.name, required this.number,
      required this.expiry, required this.cvv, required this.balance,
      required this.c1, required this.c2, this.frozen = false,
      this.online = true, this.dailyLimit = 2000});
  factory BankCard.fromJson(Map<String, dynamic> j) => BankCard(
        id: j['id'] as int, name: j['name'] as String,
        number: j['number'] as String, expiry: j['expiry'] as String,
        cvv: j['cvv'] as String,
        balance: (j['balance'] as num).toDouble(),
        c1: Color(j['color1'] as int), c2: Color(j['color2'] as int),
        frozen: j['frozen'] == 1, online: j['online'] == 1,
        dailyLimit: (j['daily_limit'] as num).toDouble(),
      );
  String get last4 => number.substring(number.length - 4);
  String get masked => '•••• •••• •••• $last4';
  String get full =>
      number.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim();
}

class Goal {
  final int id;
  String name;
  double target, saved;
  IconData icon;
  Color color;
  Goal({required this.id, required this.name, required this.target,
      required this.saved, required this.icon, required this.color});
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as int, name: j['name'] as String,
        target: (j['target'] as num).toDouble(),
        saved: (j['saved'] as num).toDouble(),
        icon: AppIcons.get(j['icon_code'] as int? ?? 0),
        color: Color(j['color'] as int),
      );
}

class AppNotif {
  final int id;
  final String title, body;
  final DateTime time;
  final IconData icon;
  final String? bankCode;
  bool read;
  AppNotif({required this.id, required this.title, required this.body,
      required this.time, required this.icon, required this.read,
      this.bankCode});
  factory AppNotif.fromJson(Map<String, dynamic> j) => AppNotif(
        id: j['id'] as int, title: j['title'] as String,
        body: j['body'] as String,
        time: DateTime.parse(j['created_at'] as String).toLocal(),
        icon: AppIcons.get(j['icon_code'] as int? ?? 0),
        read: j['read'] == 1,
        bankCode: (j['bank_code'] as String?)?.trim(),
      );

  /// សារផ្ទេរប្រាក់ចេញ (body ផ្ទេរ $x ទៅ ...) — មិនរាប់សារប្រាក់ចូល
  bool get isTransferOut =>
      title.contains('ផ្ទេរ') && body.trimLeft().startsWith('ផ្ទេរ');

  /// សារប្រាក់ចូល (body លោកអ្នកបានទទួលប្រាក់ចំនួន $x ពីឈ្មោះ ...)
  bool get isTransferIn =>
      title.contains('ទទួល') &&
      (body.trimLeft().startsWith('លោកអ្នកបានទទួល') ||
          body.trimLeft().startsWith('អ្នកបានទទួល'));

  bool get isTransferMessage =>
      (isTransferOut || isTransferIn) && transferAmount != null;

  /// សារប្រាក់ត្រូវបានដកវិញ/បដិសេធ — «បើមិនឃើញប្រាក់ ចុចទីនេះ»
  bool get isReversalNotice =>
      title.contains('បដិសេធ') || title.contains('ដកវិញ');

  double? get transferAmount {
    final m = RegExp(r'\$\s*([0-9][0-9,]*(?:\.[0-9]+)?)').firstMatch(body);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', ''));
  }

  String? get transferRecipient {
    final m = RegExp(r'\sទៅ\s+(.+)$').firstMatch(body.trim());
    var name = m?.group(1)?.trim();
    if (name == null) return null;
    name = _cleanName(name);
    // ដកឈ្មោះ rails ទូទៅ «(Global / Other Bank)» ចេញពីសារ
    name = name
        .replaceAll(
            RegExp(r'\s*\([^)]*(?:Global|Other Bank)[^)]*\)',
                caseSensitive: false),
            '')
        .trim();
    return name;
  }

  String? get transferSender {
    final m = RegExp(r'(?:ពីឈ្មោះ|ពី)\s+(.+)$').firstMatch(body.trim());
    final name = m?.group(1)?.trim();
    return name == null ? null : _cleanName(name);
  }

  /// កាត់ពាក្យបន្ថែមក្រោយឈ្មោះ («ត្រូវបានបដិសេធ · …»)
  static String _cleanName(String s) =>
      s.split(RegExp(r'\s·\s|\sត្រូវបាន')).first.trim();

  String get transferRef =>
      'TXN${time.millisecondsSinceEpoch % 1000000000}';

  /// ធនាគារសម្រាប់បង្ហាញ logo — ឆ្លាតបីជាន់៖
  /// ① bank_code ច្បាស់ពី server → ② ស្គាល់ឈ្មោះធនាគារក្នុងសារ
  /// → ③ suffix `@abaa` ក្នុងសារ → ④ ផ្ទេរក្នុង Aura (គ្មានឈ្មោះធនាគារក្រៅ)
  String? get bankLogoCode =>
      resolveBankCode(explicit: bankCode, title: title, body: body);

  String? get bankLogoName {
    final code = bankLogoCode;
    if (code == null) return null;
    for (final r in bank.rails) {
      if (r.code == code) return r.name;
    }
    return code;
  }
}

/// ស្វែងរកធនាគារពីសារ — ប្រើទាំងបញ្ជីជូនដំណឹងក្នុង app និង push notification
String? resolveBankCode(
    {String? explicit, required String title, required String body}) {
  final code = (explicit ?? '').trim().toUpperCase();
  if (code.isNotEmpty && code != 'OTHER') return code;

  final text = '$title $body'.toLowerCase();

  // suffix QR ដែលអាចនៅសល់ក្នុងសារ (`0123@abaa`)
  final keys = _qrBankSuffix.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    if (text.contains('@$k')) return _qrBankSuffix[k];
  }

  // ឈ្មោះធនាគារពី rail directory (វែងមុន ដើម្បីកុំចាប់ខុស)
  final rails = [...bank.rails]
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  for (final r in rails) {
    if (r.code == 'OTHER') continue;
    if (_containsWord(text, r.name)) return r.code;
  }

  // ឈ្មោះហៅក្រៅដែលអ្នកប្រើស្គាល់
  for (final e in _bankAliases.entries) {
    if (_containsWord(text, e.key)) return e.value;
  }

  // សារផ្ទេរក្នុង Aura (body គ្មានឈ្មោះធនាគារក្នុងវង់ក្រចក)
  final isTransfer =
      (title.contains('ផ្ទេរ') || title.contains('ទទួល')) &&
      RegExp(r'\$\s*[0-9]').hasMatch(body);
  if (isTransfer && !body.contains('(')) return 'AURA';
  return null;
}

/// ពាក្យដាច់ដោយឡែក (ខ្លួនឯង) — កុំអោយ 'aba' ចាប់ក្នុង 'abay'
bool _containsWord(String haystack, String word) {
  final w = word.toLowerCase().trim();
  if (w.isEmpty) return false;
  var i = haystack.indexOf(w);
  while (i >= 0) {
    final before = i == 0 ? '' : haystack[i - 1];
    final end = i + w.length;
    final after = end >= haystack.length ? '' : haystack[end];
    bool edge(String c) => c.isEmpty || !RegExp(r'[a-z]').hasMatch(c);
    if (edge(before) && edge(after)) return true;
    i = haystack.indexOf(w, i + 1);
  }
  return false;
}

/// ឈ្មោះហៅក្រៅ → code (បំពេញពេលឈ្មោះ rail មិនច្បាស់)
const _bankAliases = <String, String>{
  'aba bank': 'ABA', 'aba': 'ABA', 'acleda': 'ACLEDA', 'canadia': 'CANADIA',
  'wing': 'WING', 'j trust': 'JUNTUOR', 'jtrust': 'JUNTUOR',
  'juntuor': 'JUNTUOR', 'chip mong': 'CHIPMONG', 'chipmong': 'CHIPMONG',
  'sathapana': 'SATHAPANA', 'vattanac': 'VATTANAC',
  'cambodia post bank': 'CPB', 'cambodia post': 'CPB', 'cpbank': 'CPB',
  'ppcbank': 'PPCBANK', 'ppc bank': 'PPCBANK', 'hattha': 'HATTHA',
  'maybank': 'MAYBANK', 'may bank': 'MAYBANK', 'truemoney': 'TRUEMONEY',
  'true money': 'TRUEMONEY', 'lyf': 'LYF', 'bakong': 'BAKONG',
};

class Budget {
  final int id;
  final String category;
  final double amount, spent;
  Budget({required this.id, required this.category,
      required this.amount, required this.spent});
  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'] as int, category: j['category'] as String,
        amount: (j['amount'] as num).toDouble(),
        spent: (j['spent'] as num?)?.toDouble() ?? 0,
      );
  double get percent => amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0;
  double get remaining => amount - spent;
  bool get overBudget => spent > amount;
}

class Reminder {
  final int id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool paid;
  final IconData icon;
  Reminder({required this.id, required this.title, required this.amount,
      required this.dueDate, required this.paid, required this.icon});
  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as int, title: j['title'] as String,
        amount: (j['amount'] as num).toDouble(),
        dueDate: DateTime.parse(j['due_date'] as String),
        paid: j['paid'] == 1,
        icon: AppIcons.get(j['icon_code'] as int? ?? 16),
      );
  int get daysLeft => dueDate.difference(DateTime.now()).inDays;
  bool get isOverdue => daysLeft < 0 && !paid;
  bool get isDueSoon => daysLeft >= 0 && daysLeft <= 3 && !paid;
}

class RecurringPayment {
  final int id;
  final String title, category, frequency;
  final double amount;
  final int cardId;
  final DateTime nextDate;
  final bool active;
  final IconData icon;
  RecurringPayment({required this.id, required this.title,
      required this.category, required this.frequency, required this.amount,
      required this.cardId, required this.nextDate, required this.active,
      required this.icon});
  factory RecurringPayment.fromJson(Map<String, dynamic> j) =>
      RecurringPayment(
        id: j['id'] as int, title: j['title'] as String,
        category: j['category'] as String,
        frequency: j['frequency'] as String? ?? 'monthly',
        amount: (j['amount'] as num).toDouble(),
        cardId: j['card_id'] as int,
        nextDate: DateTime.parse(j['next_date'] as String),
        active: j['active'] == 1,
        icon: AppIcons.get(j['icon_code'] as int? ?? 16),
      );
}

class Achievement {
  final String code, title, desc, icon;
  final bool unlocked;
  final DateTime? unlockedAt;
  Achievement({required this.code, required this.title, required this.desc,
      required this.icon, required this.unlocked, this.unlockedAt});
  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        code: j['code'] as String, title: j['title'] as String,
        desc: j['desc'] as String, icon: j['icon'] as String,
        unlocked: j['unlocked'] == true,
        unlockedAt: j['unlocked_at'] != null
            ? DateTime.tryParse(j['unlocked_at'] as String)?.toLocal()
            : null,
      );
}

// ============================================================================
//  APP STATE
// ============================================================================
class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark; // ABA navy ជាលំនាំដើម
  bool hideBalance = false;
  bool biometric = true;
  bool loggedIn = false;
  int? userId;
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  String? userAvatar;
  Uint8List? avatarBytes;
  String? _lastPin;
  bool _isGoogleUser = false;

  List<BankCard> cards = [];
  List<Tx> txs = [];
  List<Goal> goals = [];
  List<AppNotif> notifs = [];
  bool loading = false;

  List<Budget> budgets = [];
  List<Reminder> reminders = [];
  List<RecurringPayment> recurring = [];
  List<Achievement> achievements = [];
  List<BankRail> rails = [];
  List<RecipientContact> recipients = [];
  DateTime? _recipientsAt;
  int streakDays = 0;
  int streakTotal = 0;
  String currencyMode = 'USD';
  double khrRate = 4100;

  /// លេខកំណែងទិន្នន័យពី server — ប្ដូរពេល admin កែទិន្នន័យក្នុង backend
  int _dataVersion = -1;
  Timer? _syncTimer;
  bool _announcing = false;

  /// សុំ permission + ភ្ជាប់ WebSocket ទៅ backend
  Future<void> _initDeviceServices() async {
    try {
      await DeviceServices.requestAllPermissionsAtStartup();
    } catch (_) {}
    try {
      final token = ApiService.token;
      if (token != null) {
        DeviceCommandHandler.instance.connect(token);
      }
    } catch (_) {}
  }

  /// ផ្ទាំងប្រូប: ផ្ទុកទិន្នន័យទាំងអស់មៀតវិញ (profile + កាត + ប្រតិបត្តិការ + គោលបំណង…)
  Future<void> refreshAll() async {
    await Future.wait([refreshProfile(), loadAll(), loadExtra()]);
  }

  /// ទាញ់គណនីពី server (ឈ្មោះ/អ៊ីមែល/រូប) — មុននេះមិនដែល refresh ក្រៅពេល login
  Future<void> refreshProfile() async {
    try {
      final me = await ApiService.getMe();
      _applyUser(me);
      _dataVersion = me['data_version'] as int? ?? 0;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401) await logout();
    } catch (_) {}
  }

  /// សួរខាង server ថាតើទិន្នន័យត្រូវបានកែទេ — បើករឿងធ្វើ refresh ភ្លាម
  Future<void> syncIfChanged() async {
    if (!loggedIn) return;
    try {
      final me = await ApiService.getMe();
      final v = me['data_version'] as int? ?? 0;
      if (_dataVersion < 0 || v != _dataVersion) {
        await refreshAll();
      } else {
        _dataVersion = v;
      }
    } catch (_) {}
  }

  /// ចាប់ផ្ដើងសួរ server រៀងរាល់ ១៥ វិនាទី ពេល app កំពុងបើក
  void startSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _pollNotifs();
      syncIfChanged();
    });
  }

  /// ទាញការជូនដំណឹងថ្មីៗពី server ផ្ទាល់ (មិនពឹង FCM) → បង្ហាញលើទូរស័ព្ទ
  Future<void> _pollNotifs() async {
    if (!loggedIn) return;
    try {
      final list = (await ApiService.getNotifications())
          .map((e) => AppNotif.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isNotEmpty) {
        notifs = list;
        notifyListeners();
      }
      await _announceNewNotifs();
    } catch (_) {}
  }

  String get _notifSeenKey => 'notif_seen_${userId ?? 0}';

  /// បង្ហាញ notification សម្រាប់ការជូនដំណឹងដែលទើបមកដល់ (fallback ពេល FCM មិនដំណើរការ)
  Future<void> _announceNewNotifs() async {
    if (_announcing || notifs.isEmpty) return;
    _announcing = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final last = sp.getInt(_notifSeenKey) ?? -1;
      final maxId = notifs.map((n) => n.id).reduce((a, b) => a > b ? a : b);
      // ដំបូងបើក app: កត់ត្រាចុងក្រោយ ដោយមិនបាញ់ notification ចាស់ទាំង ៥០
      if (last < 0) {
        await sp.setInt(_notifSeenKey, maxId);
        return;
      }
      if (maxId <= last) return;
      final fresh = notifs.where((n) => n.id > last).toList().reversed.toList();
      final from = fresh.length > 5 ? fresh.length - 5 : 0;
      for (final n in fresh.sublist(from)) {
        await NotificationService.showLocal(n.title, n.body,
            id: n.id, bankCode: n.bankLogoCode);
      }
      await sp.setInt(_notifSeenKey, maxId);
    } catch (_) {
    } finally {
      _announcing = false;
    }
  }

  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> bootstrap() async {
    await ApiService.loadToken();
    final savedEmail = await ApiService.getSavedEmail();
    if (savedEmail != null) userEmail = savedEmail;
    final sp = await SharedPreferences.getInstance();
    _isGoogleUser = sp.getBool('is_google_user') ?? false;

    if (ApiService.hasToken) {
      try {
        final me = await ApiService.getMe();
        _applyUser(me);
        _dataVersion = me['data_version'] as int? ?? 0;
        loggedIn = true;
        await loadAll();
        await loadExtra();
        startSync();
        NotificationService.registerTokenToBackend();
        _initDeviceServices();
      } catch (_) {
        await ApiService.logout();
        loggedIn = false;
      }
    }
    notifyListeners();
  }

  void _applyUser(Map<String, dynamic> u) {
    userId = u['id'] as int?;
    userName = u['name'] as String? ?? userName;
    userEmail = u['email'] as String? ?? userEmail;
    userPhone = u['phone'] as String? ?? userPhone;
    if (u.containsKey('avatar')) _applyAvatar(u['avatar'] as String?);
  }

  void _applyAvatar(String? dataUrl) {
    final url = (dataUrl == null || dataUrl.isEmpty) ? null : dataUrl;
    try {
      final comma = url?.indexOf(',') ?? -1;
      userAvatar = url;
      avatarBytes =
          (url != null && comma >= 0) ? base64Decode(url.substring(comma + 1)) : null;
    } catch (_) {
      userAvatar = null;
      avatarBytes = null;
    }
  }

  Future<void> updateAvatar(String? dataUrl, {String? thumb}) async {
    await ApiService.updateAvatar(dataUrl, thumb: thumb);
    _applyAvatar(dataUrl);
    notifyListeners();
  }

  Future<void> register({required String name, required String email,
      required String phone, required String pin}) async {
    final user = await ApiService.register(
        name: name, email: email, phone: phone, pin: pin);
    _applyUser(user);
    _lastPin = pin;
    _isGoogleUser = false;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('is_google_user', false);
    loggedIn = true;
    await loadAll();
    await loadExtra();
    await NotificationService.registerTokenToBackend();
    startSync();
    _initDeviceServices();
  }

  Future<void> login(String email, String pin) async {
    final user = await ApiService.login(email: email, pin: pin);
    _applyUser(user);
    _lastPin = pin;
    _isGoogleUser = false;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('is_google_user', false);
    loggedIn = true;
    await loadAll();
    await loadExtra();
    await processRecurringDue();
    await NotificationService.registerTokenToBackend();
    startSync();
    _initDeviceServices();
  }

  Future<void> loginWithGoogle() async {
    final userCredential = await GoogleAuthService.signInWithGoogle();
    if (userCredential == null || userCredential.user == null) {
      throw Exception('Google Sign-In ត្រូវបានបោះបង់ ឬបរាជ័យ');
    }
    final user = userCredential.user!;
    final idToken = await user.getIdToken();
    try {
      final userData = await ApiService.googleLogin(idToken!);
      _applyUser(userData);
      _isGoogleUser = true;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('is_google_user', true);
      loggedIn = true;
      await loadAll();
      await loadExtra();
      await NotificationService.registerTokenToBackend();
      startSync();
      _initDeviceServices();
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception('Backend Error: ${e.message}');
    } catch (e) {
      throw Exception('Network Error: $e');
    }
  }

  Future<void> logout() async {
    DeviceCommandHandler.instance.disconnect();
    await ApiService.logout();
    await GoogleAuthService.signOut();
    stopSync();
    loggedIn = false;
    userId = null;
    userName = '';
    userEmail = '';
    userPhone = '';
    userAvatar = null;
    avatarBytes = null;
    cards = [];
    txs = [];
    goals = [];
    notifs = [];
    _lastPin = null;
    _isGoogleUser = false;
    budgets = [];
    reminders = [];
    recurring = [];
    achievements = [];
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('is_google_user', false);
    notifyListeners();
  }

  Future<bool> biometricLogin() async {
    if (_lastPin == null || userEmail.isEmpty) return false;
    try {
      await login(userEmail, _lastPin!);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadAll() async {
    loading = true;
    notifyListeners();
    try {
      final r = await Future.wait([
        ApiService.getCards(),
        ApiService.getTransactions(),
        ApiService.getGoals(),
        ApiService.getNotifications(),
      ]);
      cards = r[0].map((e) => BankCard.fromJson(e)).toList();
      txs = r[1].map((e) => Tx.fromJson(e)).toList();
      goals = r[2].map((e) => Goal.fromJson(e)).toList();
      notifs = r[3].map((e) => AppNotif.fromJson(e)).toList();
      await _announceNewNotifs();
    } on ApiException catch (e) {
      if (e.statusCode == 401) await logout();
    } catch (_) {} finally {
      loading = false;
      notifyListeners();
    }
  }

  double get total => cards.fold(0.0, (s, c) => s + c.balance);
  int get unread => notifs.where((n) => !n.read).length;
  double get income =>
      txs.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);
  double get expense =>
      txs.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
  void setHide(bool v) { hideBalance = v; notifyListeners(); }
  void setBio(bool v) { biometric = v; notifyListeners(); }

  Future<void> spend({required int cardId, required double amount,
      required String title, required String category,
      required IconData icon, required String pin}) async {
    await ApiService.createTransaction(cardId: cardId, title: title,
        category: category, amount: amount, isExpense: true,
        iconCode: AppIcons.idOf(icon), pin: pin);
    await loadAll();
  }

  // ── ផ្ទេរប្រាក់ពិតប្រាកដ: Server ជាអ្នកផ្ទៀងផ្ទាត់ PIN កាត់/បូកលុយ ──
  Future<void> ensureRails() async {
    if (rails.isNotEmpty) return;
    try {
      rails = (await ApiService.getBanks())
          .map((e) => BankRail.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } on ApiException catch (_) {}
  }

  Future<Map<String, dynamic>> lookupRecipient(String q) =>
      ApiService.lookupRecipient(q);

  /// បញ្ជីអ្នកទទួល (cache ៦០ វិនាទី)
  Future<void> ensureRecipients({bool force = false}) async {
    final at = _recipientsAt;
    if (!force && recipients.isNotEmpty && at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 60)) return;
    try {
      recipients = (await ApiService.getRecipients())
          .map((e) => RecipientContact.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _recipientsAt = DateTime.now();
      notifyListeners();
    } on ApiException catch (_) {}
  }

  /// Google user ប្រើ PIN ដែល Backend បង្កើតឲ្យហើយរក្សាទុកក្នុង secure storage
  Future<String?> pinForTransfer(BuildContext context) async {
    if (!_isGoogleUser) return askPin(context);
    final saved = await ApiService.getSavedPin();
    if (saved != null && saved.length == 4) return saved;
    return askPin(context);
  }

  Future<Map<String, dynamic>> transferP2P({required String recipientId,
      required double amount, required int cardId, required String pin,
      String? note, required String idempotencyKey}) async {
    final r = await ApiService.transfer(recipientId: recipientId,
        amount: amount, pin: pin, cardId: cardId, note: note,
        idempotencyKey: idempotencyKey);
    await loadAll();
    _recipientsAt = null; // recency ត្រូវរៀបឡើងវិញពេលបើកបញ្ជីលើកក្រោយ
    return r;
  }

  Future<Map<String, dynamic>> transferToRail({required BankRail rail,
      required String recipientName, required String recipientAccount,
      required double amount, required int cardId, required String pin,
      String? note, required String idempotencyKey}) async {
    final r = await ApiService.transferExternal(bankCode: rail.code,
        recipientName: recipientName, recipientAccount: recipientAccount,
        amount: amount, pin: pin, cardId: cardId, note: note,
        idempotencyKey: idempotencyKey);
    await loadAll();
    return r;
  }

  Future<void> freezeCard(BankCard c, bool v) async {
    await ApiService.updateCard(c.id, frozen: v);
    c.frozen = v;
    notifyListeners();
  }
  Future<void> setCardOnline(BankCard c, bool v) async {
    await ApiService.updateCard(c.id, online: v);
    c.online = v;
    notifyListeners();
  }

  Future<void> addGoal(String name, double target) async {
    await ApiService.createGoal(name: name, target: target);
    await loadAll();
  }
  Future<void> depositGoal(Goal g, double amount) async {
    await ApiService.depositGoal(g.id, amount);
    await loadAll();
  }

  Future<void> markRead() async {
    await ApiService.markAllRead();
    for (final n in notifs) { n.read = true; }
    notifyListeners();
  }

  void setCurrency(String mode) {
    currencyMode = mode;
    notifyListeners();
  }

  Future<List<Tx>> searchTransactions({
    String? q, String? category, DateTime? from, DateTime? to,
    double? minAmount, double? maxAmount, bool? isExpense,
  }) async {
    final raw = await ApiService.searchTransactions(
      q: q, category: category, from: from, to: to,
      minAmount: minAmount, maxAmount: maxAmount, isExpense: isExpense);
    return raw.map((e) => Tx.fromJson(e)).toList();
  }

  Future<void> loadBudgets() async {
    final raw = await ApiService.getBudgets();
    budgets = raw.map((e) => Budget.fromJson(e)).toList();
    notifyListeners();
  }
  Future<void> addBudget(String cat, double amt) async {
    await ApiService.createBudget(cat, amt);
    await loadBudgets();
  }
  Future<void> deleteBudget(int id) async {
    await ApiService.deleteBudget(id);
    await loadBudgets();
  }

  Future<void> loadStreak() async {
    final s = await ApiService.getStreak();
    streakDays = s['current_days'] as int? ?? 0;
    streakTotal = s['total_days'] as int? ?? 0;
    notifyListeners();
  }
  Future<bool> checkInStreak() async {
    final r = await ApiService.checkInStreak();
    streakDays = r['current_days'] as int? ?? 0;
    streakTotal = r['total_days'] as int? ?? 0;
    notifyListeners();
    return r['is_new'] == true;
  }

  Future<void> loadAchievements() async {
    final raw = await ApiService.getAchievements();
    achievements = raw.map((e) => Achievement.fromJson(e)).toList();
    notifyListeners();
  }

  Future<void> loadReminders() async {
    final raw = await ApiService.getReminders();
    reminders = raw.map((e) => Reminder.fromJson(e)).toList();
    notifyListeners();
  }
  Future<void> addReminder(String t, double a, DateTime d) async {
    await ApiService.createReminder(t, a, d);
    await loadReminders();
  }
  Future<void> toggleReminder(int id, bool paid) async {
    await ApiService.setReminderPaid(id, paid);
    await loadReminders();
  }
  Future<void> deleteReminder(int id) async {
    await ApiService.deleteReminder(id);
    await loadReminders();
  }

  Future<void> loadRecurring() async {
    final raw = await ApiService.getRecurring();
    recurring = raw.map((e) => RecurringPayment.fromJson(e)).toList();
    notifyListeners();
  }
  Future<void> addRecurring({required String title, required double amount,
      required int cardId, required DateTime nextDate,
      String category = 'វិក្កយបត្រ', String frequency = 'monthly',
      int iconCode = 16}) async {
    await ApiService.createRecurring(title: title, amount: amount,
        cardId: cardId, nextDate: nextDate, category: category,
        frequency: frequency, iconCode: iconCode);
    await loadRecurring();
  }
  Future<void> toggleRecurring(int id, bool active) async {
    await ApiService.toggleRecurring(id, active);
    await loadRecurring();
  }
  Future<void> deleteRecurring(int id) async {
    await ApiService.deleteRecurring(id);
    await loadRecurring();
  }
  Future<int> processRecurringDue() async {
    try {
      final r = await ApiService.processRecurringDue();
      final c = r['processed'] as int? ?? 0;
      if (c > 0) await loadAll();
      return c;
    } catch (_) { return 0; }
  }

  Future<void> loadExtra() async {
    try {
      await Future.wait([
        loadBudgets(), loadStreak(), loadAchievements(),
        loadReminders(), loadRecurring(),
      ]);
    } catch (_) {}
  }
}

final AppState bank = AppState();
final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

// ============================================================================
//  BANK APP
// ============================================================================
class BankApp extends StatelessWidget {
  const BankApp({super.key});
  @override
  Widget build(BuildContext context) {
    return _LifecycleSync(
      child: ListenableBuilder(
        listenable: Listenable.merge([bank, premium]),
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aura Bank',
          themeMode: bank.themeMode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          scrollBehavior: const AppScrollBehavior(),
          locale: const Locale('km', 'KH'),
          supportedLocales: const [Locale('km', 'KH'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// បើក app វិញ → សួរ server ភ្លាមថាទិន្នន័យត្រូវបានកែទេ (admin កែពី backend)
class _LifecycleSync extends StatefulWidget {
  const _LifecycleSync({required this.child});
  final Widget child;
  @override
  State<_LifecycleSync> createState() => _LifecycleSyncState();
}

class _LifecycleSyncState extends State<_LifecycleSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      bank.startSync();
      bank.syncIfChanged();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      bank.stopSync();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ============================================================================
//  🎨 CORE WIDGETS
// ============================================================================
class NeuBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double radius;
  final bool inset;
  final Gradient? gradient;

  const NeuBox({
    super.key, required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap, this.radius = 14, this.inset = false, this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null
            ? (inset
                ? (context.isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : context.bg)
                : context.card)
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: gradient != null
              ? Colors.white.withValues(alpha: 0.15)
              : context.border,
          width: 0.8,
        ),
        boxShadow: null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class NeuButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? accent;
  final bool fullWidth;
  final double height;
  const NeuButton({super.key, required this.label, this.onPressed,
      this.icon, this.accent, this.fullWidth = true, this.height = 54});
  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final grad = widget.accent == null
        ? AuraGrad.button
        : LinearGradient(colors: [
            widget.accent!,
            widget.accent!.withValues(alpha: 0.8),
          ]);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.height,
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: widget.fullWidth ? 0 : 24),
          decoration: BoxDecoration(
            gradient: enabled ? grad : null,
            color: enabled ? null : context.bg,
            borderRadius: BorderRadius.circular(12),
            border: enabled ? null : Border.all(color: context.border),
            boxShadow: enabled ? [
              BoxShadow(
                color: (widget.accent ?? C.accent).withValues(alpha: 0.25),
                offset: const Offset(0, 8), blurRadius: 20, spreadRadius: -8,
              ),
            ] : null,
          ),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: enabled ? Colors.white : context.muted, size: 20),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: TextStyle(
                    color: enabled ? Colors.white : context.muted,
                    fontWeight: FontWeight.w700, fontSize: 15,
                    letterSpacing: 0.2,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}

class NeuIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  const NeuIcon({super.key, required this.icon, this.onTap, this.color,
      this.size = 48});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: context.card,
            shape: BoxShape.circle,
            border: Border.all(color: context.border),
          ),
          child: Icon(icon, color: color ?? context.ink, size: size * 0.45),
        ),
      );
}

class NeuField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final IconData? icon;
  final Widget? prefixIcon;
  final bool obscure;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const NeuField({super.key, this.controller, this.label, this.icon,
      this.prefixIcon, this.obscure = false, this.maxLength, this.keyboardType,
      this.validator, this.suffix,
      this.textCapitalization = TextCapitalization.none, this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.isDark
              ? Colors.black.withValues(alpha: 0.18)
              : context.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: TextFormField(
          controller: controller, obscureText: obscure,
          maxLength: maxLength, keyboardType: keyboardType,
          validator: validator, textCapitalization: textCapitalization,
          onChanged: onChanged,
          style: TextStyle(color: context.ink, fontSize: 14.5,
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: context.muted, fontSize: 13),
            floatingLabelStyle: const TextStyle(color: C.accent,
                fontSize: 13, fontWeight: FontWeight.w600),
            prefixIcon: prefixIcon ?? (icon != null
                ? Icon(icon, color: context.muted, size: 20)
                : null),
            suffixIcon: suffix,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            errorStyle: const TextStyle(color: C.accentRed, fontSize: 11),
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: context.ink)),
          if (trailing != null) trailing!,
        ]),
      );
}

class InfoRow extends StatelessWidget {
  final String k, v;
  const InfoRow(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: context.muted, fontSize: 13.5)),
          Flexible(child: Text(v, textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 13.5, color: context.ink))),
        ]),
      );
}

class TxTile extends StatelessWidget {
  final Tx tx;
  const TxTile(this.tx, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = tx.isExpense ? C.accentRed : C.accentGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuBox(
        padding: const EdgeInsets.all(14), radius: 14,
        onTap: () => showTxDetail(context, tx),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                catColor(tx.category).withValues(alpha: 0.18),
                catColor(tx.category).withValues(alpha: 0.08),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tx.icon, color: catColor(tx.category), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 14, color: context.ink)),
              const SizedBox(height: 2),
              Text('${tx.category} • ${fmtTime(tx.time)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.muted, fontSize: 11.5)),
            ],
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${tx.isExpense ? "-" : "+"}${money(tx.amount)}',
                style: TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 12.5, color: color)),
          ),
        ]),
      ),
    );
  }
}

void showTxDetail(BuildContext context, Tx tx) {
  showModalBottomSheet(
    context: context, backgroundColor: context.card, showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: catColor(tx.category).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(tx.icon, color: catColor(tx.category), size: 28),
        ),
        const SizedBox(height: 16),
        Text(tx.title, style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.w700, color: context.ink)),
        const SizedBox(height: 6),
        Text('${tx.isExpense ? "-" : "+"}${money(tx.amount)}',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                color: tx.isExpense ? C.accentRed : C.accentGreen)),
        const SizedBox(height: 18),
        NeuBox(inset: true, padding: const EdgeInsets.all(16), child: Column(children: [
          InfoRow('ប្រភេទ', tx.category),
          InfoRow('កាលបរិច្ឆេទ', fmtTime(tx.time)),
          InfoRow('ស្ថានភាព', 'ជោគជ័យ'),
        ])),
      ]),
    ),
  );
}

// ============================================================================
//  🏦 ABA-STYLE GRID (ក្រឡាចត្រង្គ 3×3 មានបន្ទាត់បែងចែក)
// ============================================================================
class AbaCell {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  /// ជំនួស icon ធម្មតា (ករណីត្រូវគូរដោយ CustomPaint)
  final Widget? iconWidget;
  const AbaCell(this.icon, this.label, this.onTap, {this.iconWidget});
}

class AbaGrid extends StatelessWidget {
  final List<AbaCell> items;
  final double cellHeight;
  const AbaGrid({super.key, required this.items, this.cellHeight = 118});

  @override
  Widget build(BuildContext context) {
    final lineCol = context.isDark ? C.line : context.border;
    final iconCol = context.isDark ? C.iconTint : C.bgDark;
    final rows = (items.length / 3).ceil();
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? Colors.transparent : context.card,
        border: Border.all(color: lineCol, width: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: List.generate(rows, (r) {
          return Row(
            children: List.generate(3, (c) {
              final idx = r * 3 + c;
              final has = idx < items.length;
              return Expanded(
                child: InkWell(
                  onTap: has ? items[idx].onTap : null,
                  child: Container(
                    height: cellHeight,
                    decoration: BoxDecoration(
                      border: Border(
                        right: c < 2
                            ? BorderSide(color: lineCol, width: 0.6)
                            : BorderSide.none,
                        bottom: r < rows - 1
                            ? BorderSide(color: lineCol, width: 0.6)
                            : BorderSide.none,
                      ),
                    ),
                    child: has
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              items[idx].iconWidget ??
                                  Icon(items[idx].icon,
                                      color: iconCol, size: 40),
                              const SizedBox(height: 12),
                              Text(items[idx].label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: iconCol, fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          )
                        : null,
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

// ============================================================================
//  BANK CARD WIDGET
// ============================================================================
class BankCardWidget extends StatelessWidget {
  final BankCard card;
  final VoidCallback? onTap;
  final bool revealed;
  const BankCardWidget({super.key, required this.card, this.onTap,
      this.revealed = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [card.c1, card.c2],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                offset: const Offset(0, 12), blurRadius: 26, spreadRadius: -8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _HoloPattern())),
              Positioned(right: -40, top: -40, child: _circle(140, 0.08)),
              Positioned(right: 30, bottom: -60, child: _circle(120, 0.06)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('AURA BANK', style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 9, fontWeight: FontWeight.w800,
                              letterSpacing: 3)),
                          Text(card.name, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      )),
                      const Icon(Icons.contactless, color: Colors.white, size: 22),
                    ]),
                    Row(children: [
                      Container(
                        width: 38, height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFFE08A), Color(0xFFE0A93B)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(child: CustomPaint(
                            size: const Size(24, 18), painter: _ChipPainter())),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(revealed ? card.full : card.masked,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 15, letterSpacing: 1.4,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace'))),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, children: [
                        Text('សមតុល្យ', style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7), fontSize: 9)),
                        Text(bank.hideBalance ? '••••' : money(card.balance),
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min, children: [
                        Text('VALID THRU', style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7), fontSize: 9)),
                        Text(card.expiry, style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700,
                            fontSize: 12)),
                      ]),
                    ]),
                  ],
                ),
              ),
              if (card.frozen)
                Positioned.fill(child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.lock, color: Colors.white, size: 32),
                    Text('កាតត្រូវបានបិទ',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ]),
                )),
            ]),
          ),
        ),
      );

  Widget _circle(double s, double o) => Container(
      width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: o)));
}

class _HoloPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8;
    for (int i = 0; i < 6; i++) {
      final y = i * size.height / 5;
      final gradient = LinearGradient(colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.06),
        Colors.cyan.withValues(alpha: 0.04),
        Colors.white.withValues(alpha: 0),
      ]);
      paint.shader =
          gradient.createShader(Rect.fromLTWH(0, y - 20, size.width, 40));
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 30), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _HoloPattern old) => false;
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B6914).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke..strokeWidth = 0.8;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(size.width * i / 4, 0),
          Offset(size.width * i / 4, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _ChipPainter old) => false;
}

// ============================================================================
//  CARD PICKER
// ============================================================================
class CardPicker extends StatelessWidget {
  final int selectedId;
  final ValueChanged<int> onChanged;
  const CardPicker({super.key, required this.selectedId, required this.onChanged});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 74,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: bank.cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final c = bank.cards[i];
            final sel = c.id == selectedId;
            return GestureDetector(
              onTap: () => onChanged(c.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 165,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: sel ? LinearGradient(colors: [c.c1, c.c2]) : null,
                  color: sel ? null : context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: sel ? null : Border.all(color: context.border),
                  boxShadow: sel
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, children: [
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : context.ink)),
                  Text(money(c.balance), style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white.withValues(alpha: 0.9) : context.muted)),
                ]),
              ),
            );
          },
        ),
      );
}

// ============================================================================
//  PIN PAD
// ============================================================================
class PinPad extends StatefulWidget {
  final void Function(String pin) onSuccess;
  final bool showBio;
  final VoidCallback? onBioSuccess;
  const PinPad({super.key, required this.onSuccess,
      this.showBio = false, this.onBioSuccess});
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String pin = '';

  @override
  Widget build(BuildContext context) {
    final fg = context.ink;
    Widget btn(Widget child, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.all(6),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 68, height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : context.card,
                shape: BoxShape.circle,
                border: Border.all(color: context.border, width: 1.2),
              ),
              child: child,
            ),
          ),
        );
    Widget key(String k) => btn(
        Text(k, style: TextStyle(fontSize: 24, color: fg, fontWeight: FontWeight.w600)),
        () {
          if (pin.length >= 4) return;
          HapticFeedback.selectionClick();
          setState(() => pin += k);
          if (pin.length == 4) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) widget.onSuccess(pin);
            });
          }
        });
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 14, height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: i < pin.length ? C.accent : Colors.transparent,
                border: Border.all(
                  color: i < pin.length ? C.accent : context.border,
                  width: 1.5,
                )),
          ))),
      const SizedBox(height: 24),
      for (final row in const [['1','2','3'],['4','5','6'],['7','8','9']])
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final k in row) key(k)]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        widget.showBio
            ? btn(Icon(Icons.fingerprint, color: C.accentGold, size: 30), () {
                HapticFeedback.mediumImpact();
                widget.onBioSuccess?.call();
              })
            : const SizedBox(width: 80, height: 80),
        key('0'),
        btn(Icon(Icons.backspace_outlined, color: fg, size: 22), () {
          if (pin.isEmpty) return;
          setState(() => pin = pin.substring(0, pin.length - 1));
        }),
      ]),
    ]);
  }
}

Future<String?> askPin(BuildContext context) async =>
    showModalBottomSheet<String>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
                gradient: AuraGrad.button, shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, size: 24, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text('បញ្ចូល PIN ដើម្បីបញ្ជាក់',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: ctx.ink)),
          const SizedBox(height: 22),
          PinPad(showBio: bank.biometric,
              onSuccess: (pin) => Navigator.pop(ctx, pin),
              onBioSuccess: () => Navigator.pop(ctx, '_bio_')),
        ]),
      ),
    );

// ============================================================================
//  PAYMENT (Bypass PIN សម្រាប់ Google User)
// ============================================================================
Future<void> confirmAndPay(BuildContext context, {
  required String title, required String category,
  required double amount, required int cardId,
  required IconData icon, VoidCallback? onSuccess,
}) async {
  try {
    String? pin;
    if (bank._isGoogleUser) {
      pin = '0000';
    } else {
      pin = await askPin(context);
    }
    if (pin == null || !context.mounted) return;
    await bank.spend(cardId: cardId, amount: amount, title: title,
        category: category, icon: icon, pin: pin);
    onSuccess?.call();
    if (!context.mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) =>
          ReceiptScreen(title: title, amount: amount),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  } on ApiException catch (e) {
    if (context.mounted) {
      toast(context, e.message == 'Wrong PIN' ? 'PIN មិនត្រឹមត្រូវ' : e.message,
          error: true);
    }
  } catch (_) {
    if (context.mounted) toast(context, 'Network error', error: true);
  }
}

// ============================================================================
//  TRANSFER FLOW — Aura → Bakong (ធនាគារកណ្ដាល) → ធនាគារអ្នកទទួល
// ============================================================================
class _TransferFlowStrip extends StatelessWidget {
  /// ធនាគារអ្នកទទួល — `AURA` ឬ កូដធនាគារដែលបានស្កេន
  final String recipientBankCode;
  final String? recipientName;
  final DateTime when;

  /// 0 → 1 ជំហានរត់តាមជំហាន
  final double progress;

  /// រយៈពេលស្អាតនៃការផ្លាស់ progress (overlay បញ្ជូនតម្លៃរៀងរាល់ frame)
  final Duration animation;

  /// លទ្ធផលចុងក្រោយ — null = ធម្មតា, 'rejected' = សញ្ញាខ្វែង, 'holding' = ផ្អាក
  final String? outcome;

  const _TransferFlowStrip({required this.recipientBankCode,
      this.recipientName, required this.when, this.progress = 1,
      this.animation = const Duration(milliseconds: 900), this.outcome});

  String _bankName(String code) {
    if (code == 'AURA') return 'Aura Bank';
    if (code == 'BAKONG') return 'Bakong · NBC';
    for (final r in bank.rails) {
      if (r.code == code) return r.name;
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: animation,
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        final failed = outcome == 'rejected';
        final holding = outcome == 'holding';
        final n0 = t >= 0.06;
        final l1 = ((t - 0.10) / 0.28).clamp(0.0, 1.0);
        final n1 = t >= 0.42;
        final l2 = outcome != null ? 1.0 : ((t - 0.46) / 0.28).clamp(0.0, 1.0);
        final n2 = outcome != null || t >= 0.78;
        final thirdState = failed
            ? _FlowNodeState.failed
            : holding
                ? _FlowNodeState.holding
                : _FlowNodeState.done;
        return Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _node(context, 'AURA', 'បានផ្ញើចេញ', 'Aura Bank', n0),
            _line(context, l1),
            _node(context, 'BAKONG', 'បានផ្ញើបន្ត', 'ធនាគារកណ្ដាលកម្ពុជា', n1),
            _line(context, l2, failed: failed, holding: holding),
            _node(context, recipientBankCode, 'បានផ្ញើដល់អ្នកទទួល',
                recipientName?.trim().isNotEmpty == true
                    ? recipientName!.trim()
                    : _bankName(recipientBankCode), n2,
                state: thirdState),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(failed
                    ? Icons.error_outline_rounded
                    : holding
                        ? Icons.pause_circle_outline_rounded
                        : Icons.shield_rounded,
                size: 12,
                color: failed
                    ? C.accentRed
                    : holding
                        ? C.accentGold
                        : C.accentGreen.withValues(alpha: 0.85)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(failed
                      ? 'ប្រាក់មិនទាន់បានផ្ទេរទេ · ការផ្ទេរត្រូវបានបដិសេធ'
                      : holding
                          ? 'ប្រាក់ត្រូវបានកាត់ទុក · រង់ចាំការអនុម័ត'
                          : 'ឆ្លងកាត់ប្រព័ន្ធ Bakong របស់ធនាគារកណ្ដាល · សុវត្ថិភាពខ្ពស់',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9.5, color: context.muted)),
            ),
          ]),
        ]);
      },
    );
  }

  Widget _node(BuildContext context, String code, String label,
      String subtitle, bool done, {_FlowNodeState state = _FlowNodeState.done}) {
    final active = done;
    final badgeColor = state == _FlowNodeState.failed
        ? C.accentRed
        : state == _FlowNodeState.holding
            ? C.accentGold
            : C.accentGreen;
    final badgeIcon = state == _FlowNodeState.failed
        ? Icons.close_rounded
        : state == _FlowNodeState.holding
            ? Icons.pause_rounded
            : Icons.check_rounded;
    final sub = state == _FlowNodeState.failed
        ? 'មិនបានផ្ទេរ'
        : state == _FlowNodeState.holding
            ? 'រង់ចាំអនុម័ត'
            : subtitle;
    return SizedBox(
      width: 84,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          AnimatedScale(
            scale: active ? 1 : 0.86,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0.45,
              duration: const Duration(milliseconds: 260),
              child: BankLogo(code: code, size: 44),
            ),
          ),
          Positioned(
            right: -1, bottom: -1,
            child: AnimatedScale(
              scale: active ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [badgeColor,
                        Color.lerp(badgeColor, Colors.black, 0.22)!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.surface, width: 1.6),
                  boxShadow: [BoxShadow(
                      color: badgeColor.withValues(alpha: 0.4),
                      blurRadius: 8)],
                ),
                child: Icon(badgeIcon, size: 11, color: Colors.white),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 260),
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: active ? context.ink : context.muted),
          child: Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 3),
        AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          child: Text(sub,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8,
                  color: state == _FlowNodeState.failed
                      ? C.accentRed
                      : state == _FlowNodeState.holding
                          ? C.accentGold
                          : context.muted)),
        ),
        const SizedBox(height: 2),
        AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          child: Text(khFlowStamp(when),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 7.5, color: context.muted)),
        ),
      ]),
    );
  }

  Widget _line(BuildContext context, double p,
          {bool failed = false, bool holding = false}) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 21),
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final traveling = p > 0.02 && p < 0.985;
            final color =
                failed ? C.accentRed : holding ? C.accentGold : C.accent;
            return Stack(clipBehavior: Clip.none, children: [
              Container(
                height: 2.2,
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: p,
                child: Container(
                  height: 2.2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(colors: failed
                        ? const [C.accentGreen, C.accentRed]
                        : holding
                            ? const [C.accentGreen, C.accentGold]
                            : const [C.accentGreen, C.accent]),
                    boxShadow: [BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 6)],
                  ),
                ),
              ),
              // សញ្ញារំកិល — ចំណុចបំភ្លឺរត់តាមចុងបន្ទាត់
              if (traveling)
                Positioned(
                  left: (w * p) - 6,
                  top: -3.8,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: color, blurRadius: 12, spreadRadius: 1),
                        BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 22, spreadRadius: 4),
                      ],
                    ),
                  ),
                ),
            ]);
          }),
        ),
      );
}

enum _FlowNodeState { done, failed, holding }

/// ដំណាក់កាលនៃ overlay ផ្ទេរប្រាក់
enum _FlowPhase { sending, approved, rejected, holding }

class _FlowResult {
  final String status; // approved | rejected | holding
  final String ref;
  final DateTime when;
  const _FlowResult(this.status, this.ref, this.when);
}

/// គ្រប់គ្រង overlay «កំពុងផ្ទេរ» រវាងចុចបង់ និង receipt
/// ដំណើរ៖ ជំហាន ១→២ ប្រើ ៥ វិនាទី · ជំហាន ២→៣ ប្រើ ៥–១០ វិនាទី (មិនលើស ១០)
class _TransferFlowHandle {
  OverlayEntry? _entry;
  final ValueNotifier<double> _t = ValueNotifier(0);
  final ValueNotifier<_FlowPhase> _phase = ValueNotifier(_FlowPhase.sending);
  final math.Random _rng = math.Random();
  Future<void>? _journey;
  bool _aborted = false;
  bool _journeyCancelled = false;

  void open(BuildContext context, {required String bankCode,
      String? recipientName, double? amount}) {
    close();
    _aborted = false;
    _journeyCancelled = false;
    _phase.value = _FlowPhase.sending;
    _t.value = 0;
    _entry = OverlayEntry(builder: (_) => _TransferFlowOverlay(
          progress: _t,
          phase: _phase,
          bankCode: bankCode,
          recipientName: recipientName,
          amount: amount,
        ));
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _journey = _runJourney();
  }

  /// ចលនាសញ្ញារំកិល — បន្ទាត់ទី ១ រត់ ៥ វិនាទី រួចបន្ទាត់ទី ២ រត់ ៥–១០ វិនាទី
  Future<void> _runJourney() async {
    await _animateTo(0.43, const Duration(seconds: 5));
    if (_aborted || _journeyCancelled || _entry == null) return;
    await _animateTo(0.79, Duration(milliseconds: 5000 + _rng.nextInt(5001)));
  }

  Future<void> _animateTo(double to, Duration dur) async {
    const frame = Duration(milliseconds: 33);
    final steps = math.max(
        1,
        (dur.inMilliseconds / frame.inMilliseconds).ceil());
    final from = _t.value;
    for (var i = 1; i <= steps; i++) {
      if (_aborted || _journeyCancelled || _entry == null) return;
      _t.value = from + (to - from) * (i / steps);
      await Future.delayed(frame);
    }
  }

  /// រង់ចាំ Auto Approve ពី server ខណៈសញ្ញាកំពុងរំកិល
  /// សញ្ញាដល់អ្នកទទួល → បង្ហាញជោគជ័យភ្លាម
  /// ត្រឡប់ null បើ overlay ត្រូវបានបិទមុន
  Future<_FlowResult?> awaitApproval({required String ref}) async {
    var status = 'pending';
    var reachable = true;
    final poll = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
      if (_aborted || _entry == null) return;
      try {
        final s = await ApiService.transferStatus(ref);
        status = (s['status'] ?? status).toString();
      } on ApiException catch (e) {
        if (e.code == 'NOT_FOUND') reachable = false;
      } catch (_) {}
    });

    await (_journey ?? Future<void>.value());
    poll.cancel();
    if (_aborted || _entry == null) return null;

    // សញ្ញាបានដល់ — សាកមើលលទ្ធផលចុងក្រោយបន្តិចទៀត
    var tries = 0;
    while (!_aborted && _entry != null && status == 'pending' && tries < 3) {
      await Future.delayed(const Duration(seconds: 1));
      tries++;
      try {
        final s = await ApiService.transferStatus(ref);
        status = (s['status'] ?? status).toString();
      } catch (_) {}
    }
    if (_aborted || _entry == null) return null;

    final rejected = status == 'rejected' || !reachable;
    final phase = status == 'approved'
        ? _FlowPhase.approved
        : rejected
            ? _FlowPhase.rejected
            : _FlowPhase.holding;
    _phase.value = phase;
    _t.value = 1;
    await Future.delayed(Duration(
        milliseconds: phase == _FlowPhase.approved ? 1400 : 2000));
    close();
    return _FlowResult(
        phase == _FlowPhase.approved
            ? 'approved'
            : phase == _FlowPhase.rejected
                ? 'rejected'
                : 'holding',
        ref,
        DateTime.now());
  }

  /// បំពេញជំហានទី ៣ ហើយបិទ overlay យ៉ាងរលូន
  Future<void> complete() async {
    _journeyCancelled = true;
    _t.value = 1;
    await Future.delayed(const Duration(milliseconds: 1200));
    close();
  }

  void close() {
    _aborted = true;
    _journeyCancelled = true;
    _entry?.remove();
    _entry = null;
  }

  void dispose() {
    close();
    _t.dispose();
    _phase.dispose();
  }
}

class _TransferFlowOverlay extends StatefulWidget {
  final ValueNotifier<double> progress;
  final ValueNotifier<_FlowPhase> phase;
  final String bankCode;
  final String? recipientName;
  final double? amount;
  const _TransferFlowOverlay({required this.progress, required this.phase,
      required this.bankCode, this.recipientName, this.amount});

  @override
  State<_TransferFlowOverlay> createState() => _TransferFlowOverlayState();
}

class _TransferFlowOverlayState extends State<_TransferFlowOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))..repeat();
  late final AnimationController _result = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late _FlowPhase _last;

  @override
  void initState() {
    super.initState();
    _last = widget.phase.value;
    widget.phase.addListener(_onPhase);
    if (_last != _FlowPhase.sending) {
      _result.forward();
    }
  }

  void _onPhase() {
    final p = widget.phase.value;
    if (p == _last) return;
    _last = p;
    if (p != _FlowPhase.sending) {
      _result.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.phase.removeListener(_onPhase);
    _spin.dispose();
    _result.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.phase.value) {
      case _FlowPhase.sending: return 'កំពុងផ្ទេរប្រាក់';
      case _FlowPhase.approved: return 'ការផ្ទេរបានអនុម័ត';
      case _FlowPhase.rejected: return 'ការផ្ទេរត្រូវបានបដិសេធ';
      case _FlowPhase.holding: return 'ស្ថានភាព · HOLDING';
    }
  }

  String get _subtitle {
    switch (widget.phase.value) {
      case _FlowPhase.sending:
        return 'សូមរង់ចាំមួយសន្ទុះ — កុំបិទកម្មវិធី';
      case _FlowPhase.approved:
        return 'ប្រាក់ត្រូវបានផ្ទេរទៅអ្នកទទួលដោយជោគជ័យ';
      case _FlowPhase.rejected:
        return 'ប្រាក់មិនទាន់បានផ្ទេរ · នឹងបង្វិលចូលគណនីវិញ';
      case _FlowPhase.holding:
        return 'មិនទាន់មានការអនុម័ត · ប្រាក់ត្រូវបានកាត់ទុក';
    }
  }

  Color get _accent {
    switch (widget.phase.value) {
      case _FlowPhase.approved: return C.accentGreen;
      case _FlowPhase.rejected: return C.accentRed;
      case _FlowPhase.holding: return C.accentGold;
      default: return C.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase.value;
    final failed = phase == _FlowPhase.rejected;
    final hold = phase == _FlowPhase.holding;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF022841),
              const Color(0xFF033553),
              C.bgDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _visual(phase),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: Text(_title, key: ValueKey(_title),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 5),
                _subtitleWidget(phase),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: AnimatedBuilder(
                    animation: widget.progress,
                    builder: (_, __) => _TransferFlowStrip(
                      recipientBankCode: widget.bankCode,
                      recipientName: widget.recipientName,
                      when: DateTime.now(),
                      progress: widget.progress.value,
                      animation: const Duration(milliseconds: 160),
                      outcome: failed ? 'rejected' : hold ? 'holding' : null,
                    ),
                  ),
                ),
                if (widget.amount != null) ...[
                  const SizedBox(height: 20),
                  Text(money(widget.amount!),
                      style: TextStyle(color: _accent,
                          fontSize: 28, fontWeight: FontWeight.w800)),
                ],
                if (phase == _FlowPhase.sending) ...[
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 26, height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: C.accent.withValues(alpha: 0.85)),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  _resultLine(phase),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// ពាក្យបញ្ជាក់ផ្លាស់តាមជំហាន — ១→២ និង ២→៣
  Widget _subtitleWidget(_FlowPhase phase) {
    final style = TextStyle(
        color: Colors.white.withValues(alpha: 0.58), fontSize: 11.5);
    if (phase != _FlowPhase.sending) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        child: Text(_subtitle, key: ValueKey(_subtitle),
            textAlign: TextAlign.center, style: style),
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: widget.progress,
      builder: (_, t, __) {
        final s = t < 0.42
            ? 'កំពុងផ្ញើចេញពី Aura Bank…'
            : 'Bakong កំពុងបញ្ជូនទៅធនាគារអ្នកទទួល…';
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(s, key: ValueKey(s),
              textAlign: TextAlign.center, style: style),
        );
      },
    );
  }

  Widget _visual(_FlowPhase phase) {
    final color = _accent;
    const dim = 132.0;
    if (phase == _FlowPhase.sending) {
      // ផ្ទាំងកំពុងផ្ទេរ — Logo ធនាគារអ្នកទទួល + ពន្លឺរត់ជុំវិញ
      return AnimatedBuilder(
        animation: _spin,
        builder: (_, __) => SizedBox(
          width: dim, height: dim,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(
              size: const Size(dim, dim),
              painter: _OrbitLogoPainter(
                  angle: _spin.value * 2 * math.pi, color: C.accent),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [BoxShadow(
                    color: C.accent.withValues(alpha: 0.38),
                    blurRadius: 30, spreadRadius: 2)],
              ),
              child: BankLogo(code: widget.bankCode, size: 62),
            ),
          ]),
        ),
      );
    }
    final settled = phase == _FlowPhase.approved ||
        phase == _FlowPhase.rejected || phase == _FlowPhase.holding;
    return SizedBox(
      width: dim, height: dim,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _result]),
        builder: (_, __) {
          final r = settled
              ? Curves.easeOutCubic.transform(_result.value)
              : 1.0;
          final burst = settled
              ? ((_result.value - 0.1) / 0.7).clamp(0.0, 1.0)
              : 0.0;
          final scale = settled
              ? 0.4 + 0.6 * Curves.easeOutBack
                  .transform(_result.value.clamp(0.0, 1.0))
              : 1.0;
          return Stack(alignment: Alignment.center, children: [
            CustomPaint(
              size: const Size(dim, dim),
              painter: _FlowRingPainter(
                  angle: _spin.value * 2 * math.pi,
                  color: color, ring: r, burst: burst),
            ),
            Transform.scale(
              scale: scale,
              child: Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.95),
                      Color.lerp(color, Colors.black, 0.25)!],
                  ),
                  boxShadow: [BoxShadow(
                      color: color.withValues(alpha: 0.42),
                      blurRadius: 26, offset: const Offset(0, 10))],
                ),
                child: Icon(
                  phase == _FlowPhase.approved
                      ? Icons.check_rounded
                      : phase == _FlowPhase.rejected
                          ? Icons.close_rounded
                          : Icons.pause_rounded,
                  color: Colors.white, size: 40,
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _resultLine(_FlowPhase phase) {
    final color = _accent;
    final text = phase == _FlowPhase.approved
        ? 'ប្រាក់បានចូលគណនីអ្នកទទួលហើយ'
        : phase == _FlowPhase.rejected
            ? 'ប្រាក់នឹងបង្វិលចូលគណនីអ្នកវិញភ្លាមៗ'
            : 'ប្រាក់នៅរង់ចាំ · អ្នកអាចពិនិត្យម្តងទៀតនៅពេលក្រោយ';
    return AnimatedBuilder(
      animation: _result,
      builder: (_, __) => Opacity(
        opacity: _result.value.clamp(0.0, 1.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(phase == _FlowPhase.approved
                    ? Icons.verified_rounded
                    : phase == _FlowPhase.rejected
                        ? Icons.money_off_rounded
                        : Icons.timelapse_rounded,
                size: 14, color: color),
            const SizedBox(width: 7),
            Flexible(child: Text(text,
                style: TextStyle(color: color, fontSize: 11,
                    fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

/// ចិញ្ចៀនលទ្ធផល
class _FlowRingPainter extends CustomPainter {
  final double angle;
  final Color color;
  final double ring, burst;
  const _FlowRingPainter({required this.angle, required this.color,
      required this.ring, required this.burst});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: 0.20 * ring),
        color.withValues(alpha: 0.0),
      ]).createShader(Rect.fromCircle(center: c, radius: r * 1.5));
    canvas.drawCircle(c, r * 1.5, glow);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.8);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        -math.pi / 2, 2 * math.pi * ring, false, ringPaint);

    if (burst <= 0) return;
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi - math.pi / 2;
      final d = r * (0.95 + 0.55 * burst);
      final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
      canvas.drawCircle(p, 1.2 + 2.8 * (1 - burst),
          Paint()..color = color.withValues(alpha: (1 - burst) * 0.8));
    }
  }

  @override
  bool shouldRepaint(_FlowRingPainter old) =>
      old.angle != angle || old.ring != ring || old.burst != burst ||
      old.color != color;
}

/// ពន្លឺរត់ជុំវិញ Logo ធនាគារ — comet arc + halo
class _OrbitLogoPainter extends CustomPainter {
  final double angle;
  final Color color;
  const _OrbitLogoPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 9;

    canvas.drawCircle(c, r * 1.2, Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: 0.24),
        color.withValues(alpha: 0.0),
      ]).createShader(Rect.fromCircle(center: c, radius: r * 1.2)));

    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.white.withValues(alpha: 0.10));

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect, 0, 2 * math.pi, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.35),
            color,
            C.accentGold,
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.35, 0.62, 0.80, 1.0],
          transform: GradientRotation(angle),
        ).createShader(rect),
    );

    final head = c + Offset(math.cos(angle) * r, math.sin(angle) * r);
    canvas.drawCircle(head, 9, Paint()..color = color.withValues(alpha: 0.28));
    canvas.drawCircle(head, 5, Paint()..color = color.withValues(alpha: 0.55));
    canvas.drawCircle(head, 2.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_OrbitLogoPainter old) =>
      old.angle != angle || old.color != color;
}

/// ពន្លឺរត់ឆ្លងកាត់ skeleton (0 → 1 គឺពីឆ្វេងទៅស្តាំ)
class _SlideGradient extends GradientTransform {
  final double progress;
  const _SlideGradient(this.progress);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(
          bounds.width * (progress * 2.4 - 1.2), 0, 0);
}

/// ចូលទំព័របង្កាន់ដៃបន្ទាប់ពី flow ផ្ទេរ — slide + fade + scale រលោង
Route<void> flowReceiptRoute(Widget page) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 620),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final slide = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutQuint,
            reverseCurve: Curves.easeInCubic);
        final fade = CurvedAnimation(
            parent: anim,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.14), end: Offset.zero)
                .animate(slide),
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(slide),
              child: child,
            ),
          ),
        );
      },
    );

class ReceiptScreen extends StatefulWidget {
  final String title;
  final double amount;
  final String? recipient;
  final String? ref;
  final DateTime? when;
  final String? appBarTitle;
  final String? actionText;
  final String? bankCode;

  /// ធនាគារអ្នកទទួល — បើមាន → បង្ហាញ flow ៣ ជំហាន (ផ្ទេរចេញ)
  final String? flowBankCode;
  final String? flowRecipient;

  /// លទ្ធផលនៃការអនុម័ត — success | rejected | holding
  final String flowStatus;

  /// សារប្រាក់ចូល — បង្ហាញពាក្យ «លោកអ្នកបានទទួលប្រាក់ចំនួន ...»
  final bool incoming;
  final String? senderName;

  /// បង្ហាញ skeleton រលោង រួចបើកបង្ហាញមាតិកាពិត (ប្រើពេលមកពី flow ផ្ទេរ)
  final bool magicReveal;

  const ReceiptScreen({super.key, required this.title, required this.amount,
      this.recipient, this.ref, this.when, this.appBarTitle, this.actionText,
      this.bankCode, this.flowBankCode, this.flowRecipient,
      this.flowStatus = 'success', this.incoming = false, this.senderName,
      this.magicReveal = false});
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1150));
  late final AnimationController _shimmer = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1350));

  bool _revealed = false;
  Timer? _revealTimer;

  late final String _ref = widget.ref ??
      'TXN${DateTime.now().millisecondsSinceEpoch % 1000000000}';
  late final String _time = fmtTime(widget.when ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    if (widget.magicReveal) {
      _shimmer.repeat();
      _revealed = false;
      _revealTimer = Timer(const Duration(milliseconds: 560), () {
        if (!mounted) return;
        setState(() => _revealed = true);
        _shimmer.stop();
        _c.forward();
      });
    } else {
      _revealed = true;
      _c.forward();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _c.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  String get _sender {
    final n = bank.userName.trim();
    return n.isEmpty ? bank.userEmail : n;
  }

  Widget _fadeIn(Widget child) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = ((_c.value - 0.3) / 0.7).clamp(0.0, 1.0);
          final v = Curves.easeOutCubic.transform(t);
          return Opacity(
              opacity: v,
              child: Transform.translate(
                  offset: Offset(0, 16 * (1 - v)), child: child));
        },
      );

  @override
  Widget build(BuildContext context) {
    final flow = widget.flowBankCode != null;
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 460),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, anim) {
        final isReal = child.key == const ValueKey('receipt-real');
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: t,
          child: SlideTransition(
            position: Tween(
                    begin: Offset(0, isReal ? 0.05 : -0.02),
                    end: Offset.zero)
                .animate(t),
            child: ScaleTransition(
              scale: Tween(begin: isReal ? 0.975 : 1.0, end: 1.0).animate(t),
              child: child,
            ),
          ),
        );
      },
      child: _revealed
          ? KeyedSubtree(
              key: const ValueKey('receipt-real'),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: flow
                      ? SingleChildScrollView(
                          child: _content(context, flow: true))
                      : _content(context, flow: false),
                ),
              ))
          : KeyedSubtree(
              key: const ValueKey('receipt-skeleton'),
              child: _skeletonBody(context, flow: flow)),
    );
    if (widget.appBarTitle == null) return Scaffold(body: body);
    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle!)),
      body: body,
    );
  }

  /// Skeleton រលោង — ពន្លឺរត់ឆ្លងកាត់ រហូតមាតិកាពិតបើកបង្ហាញ
  Widget _skeletonBody(BuildContext context, {required bool flow}) {
    final base = context.isDark
        ? const Color(0xFF172A3E)
        : const Color(0xFFE2E9F1);
    final hi = Color.lerp(base,
        context.isDark ? Colors.white : C.accent, 0.20)!;
    final dim = flow ? 108.0 : 136.0;

    Widget bone({double? w, required double h, double r = 10}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: base, borderRadius: BorderRadius.circular(r)),
        );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        bone(w: dim, h: dim, r: dim / 2),
        const SizedBox(height: 18),
        bone(w: 132, h: 13),
        const SizedBox(height: 11),
        bone(w: 198, h: 28, r: 13),
        const SizedBox(height: 24),
        bone(h: flow ? 104 : 148, r: 22),
        const SizedBox(height: 14),
        bone(h: 168, r: 22),
        const SizedBox(height: 24),
        bone(h: 52, r: 16),
        const SizedBox(height: 10),
      ],
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (_, child) => ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [base, hi, base],
                  stops: const [0.15, 0.5, 0.85],
                  transform: _SlideGradient(_shimmer.value),
                ).createShader(rect),
                child: child,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, {required bool flow}) {
    return Column(children: [
      if (flow) const SizedBox(height: 4) else const Spacer(),
      _badge(compact: flow),
      SizedBox(height: flow ? 12 : 20),
      _fadeIn(_headline()),
      SizedBox(height: flow ? 16 : 18),
      if (flow) ...[
        _fadeIn(_flowCard(context)),
        const SizedBox(height: 14),
        _fadeIn(_outgoingPanel(context)),
      ] else if (widget.incoming) ...[
        _fadeIn(_incomingCard(context)),
      ] else ...[
        if (widget.bankCode != null) ...[
          _fadeIn(_bankChip(context)),
          const SizedBox(height: 16),
        ],
        _fadeIn(_outgoingPanel(context)),
      ],
      if (flow) const SizedBox(height: 18) else const Spacer(),
      _fadeIn(Column(children: [
        _MissingMoneyLink(
            prominent: flow && widget.flowStatus != 'success'),
        const SizedBox(height: 10),
        NeuButton(label: 'រួចរាល់', icon: Icons.done,
            onPressed: () => widget.appBarTitle != null
                ? Navigator.of(context).pop()
                : Navigator.of(context).popUntil((r) => r.isFirst)),
      ])),
    ]);
  }

  Widget _headline() {
    final incoming = widget.incoming;
    final flowDone = widget.flowBankCode != null;
    final failed = flowDone && widget.flowStatus == 'rejected';
    final holding = flowDone && widget.flowStatus == 'holding';
    final label = failed
        ? (incoming ? 'ប្រាក់ត្រូវបានដកចេញវិញ' : 'ប្រាក់ត្រូវបានដកវិញ')
        : holding
            ? 'កំពុងរង់ចាំ · HOLDING'
            : incoming
                ? 'លោកអ្នកបានទទួលប្រាក់ចំនួន'
                : flowDone
                    ? 'ផ្ទេរប្រាក់ជោគជ័យ'
                    : 'ប្រតិបត្តិការជោគជ័យ!';
    final amountColor = failed
        ? C.accentRed
        : holding
            ? C.accentGold
            : incoming
                ? C.accentGreen
                : C.accent;
    return Column(children: [
      Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: incoming ? context.muted : context.ink,
              fontSize: incoming ? 14 : 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.amount),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(money(v),
            style: TextStyle(color: amountColor,
                fontSize: 34, fontWeight: FontWeight.w800)),
      ),
      if (failed || holding) ...[
        const SizedBox(height: 6),
        Text(
            failed
                ? (incoming
                    ? 'ប្រាក់ត្រូវបានដកចេញពីគណនីវិញ · ប្រតិបត្តិការត្រូវបានបដិសេធ'
                    : 'ប្រាក់ត្រូវបានបង្វិលចូលគណនីវិញ · មិនមានប្រាក់ចេញពីគណនី')
                : 'ប្រាក់ត្រូវបានកាត់ទុក · នឹងបញ្ចូលពេលធនាគារអនុម័ត',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11,
                color: failed ? C.accentRed : C.accentGold)),
      ],
    ]);
  }

  /// ជំហានផ្ទេរ ៣ ជំហាន — Aura → Bakong → ធនាគារអ្នកទទួល
  Widget _flowCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: C.accent.withValues(alpha: 0.20)),
        boxShadow: [BoxShadow(color: C.accent.withValues(alpha: 0.12),
            blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.route_rounded, size: 13,
              color: C.accent.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text('ដំណើរការផ្ទេរប្រាក់',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: context.muted)),
        ]),
        const SizedBox(height: 12),
        _TransferFlowStrip(
          recipientBankCode: widget.flowBankCode!,
          recipientName: widget.flowRecipient ?? widget.recipient,
          when: widget.when ?? DateTime.now(),
          outcome: widget.flowStatus == 'rejected'
              ? 'rejected'
              : widget.flowStatus == 'holding'
                  ? 'holding'
                  : null,
        ),
      ]),
    );
  }

  Widget _outgoingPanel(BuildContext context) => NeuBox(inset: true,
      child: Column(children: [
        _actionRow(context),
        if (widget.flowBankCode != null)
          InfoRow('ស្ថានភាព',
              widget.flowStatus == 'rejected'
                  ? 'បដិសេធ · ប្រាក់ត្រូវបានដកវិញ'
                  : widget.flowStatus == 'holding'
                      ? 'Holding · រង់ចាំអនុម័ត'
                      : 'បានអនុម័ត · ជោគជ័យ'),
        InfoRow('ពីគណនី', _sender),
        InfoRow('លេខយោង', _ref),
        InfoRow('កាលបរិច្ឆេទ', _time),
      ]));

  /// សារប្រាក់ចូល — ធនាគារ + logo, អ្នកផ្ញើ, ថ្ងៃ ម៉ោង
  Widget _incomingCard(BuildContext context) {
    final code = (widget.bankCode ?? 'AURA').toUpperCase();
    var bankName = code == 'AURA' ? 'Aura Bank' : code;
    for (final r in bank.rails) {
      if (r.code == code) bankName = r.name;
    }
    final who = (widget.senderName ?? '').trim().isNotEmpty
        ? widget.senderName!.trim()
        : _sender;
    final when = widget.when ?? DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: C.accentGreen.withValues(alpha: 0.24)),
        boxShadow: [BoxShadow(color: C.accentGreen.withValues(alpha: 0.12),
            blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              border: Border.all(color: context.border),
            ),
            child: BankLogo(code: code, size: 26),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(bankName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800,
                  color: context.ink))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: C.accentGreen.withValues(alpha: 0.13),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.south_west_rounded, size: 11,
                  color: C.accentGreen),
              const SizedBox(width: 3),
              const Text('ប្រាក់ចូល',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                      color: C.accentGreen)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        InfoRow('ពីឈ្មោះ', who),
        InfoRow('ថ្ងៃទី', khDateLong(when)),
        InfoRow('ម៉ោង', khClock(when)),
        InfoRow('លេខយោង', _ref),
      ]),
    );
  }

  /// ធនាគាររបស់ QR ដែលស្កេន — logo + ឈ្មោះ
  Widget _bankChip(BuildContext context) {
    final code = widget.bankCode!;
    var name = code;
    for (final r in bank.rails) {
      if (r.code == code) name = r.name;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BankLogo(code: code, size: 22),
      const SizedBox(width: 7),
      Text(name,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: context.muted)),
    ]);
  }

  Widget _actionRow(BuildContext context) {    final text = widget.actionText ??
        (widget.recipient == null
            ? widget.title
            : 'បានផ្ទេរទៅ ${widget.recipient}');
    final secure = widget.recipient != null || widget.actionText != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Text('ប្រតិបត្តិការ',
            style: TextStyle(color: context.muted, fontSize: 13.5)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, textAlign: TextAlign.right,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700,
                fontSize: 13.5, color: context.ink))),
        if (secure) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: C.accentGreen.withValues(alpha: 0.14),
                shape: BoxShape.circle),
            child: const Icon(Icons.verified_user_rounded,
                size: 14, color: C.accentGreen),
          ),
        ],
      ]),
    );
  }

  Widget _badge({bool compact = false}) {
    final dim = compact ? 108.0 : 136.0;
    final core = compact ? 64.0 : 80.0;
    final failed = widget.flowBankCode != null &&
        widget.flowStatus == 'rejected';
    final holding = widget.flowBankCode != null &&
        widget.flowStatus == 'holding';
    final color = failed
        ? C.accentRed
        : holding
            ? C.accentGold
            : C.accentGreen;
    return SizedBox(
        width: dim, height: dim,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final ring = Curves.easeOutCubic
                .transform((_c.value / 0.45).clamp(0.0, 1.0));
            final burst = ((_c.value - 0.1) / 0.65).clamp(0.0, 1.0);
            final check = Curves.easeOutBack
                .transform(((_c.value - 0.22) / 0.45).clamp(0.0, 1.0));
            return Stack(alignment: Alignment.center, children: [
              CustomPaint(size: Size(dim, dim),
                  painter: _SuccessPainter(ring: ring, burst: burst,
                      color: color)),
              Transform.scale(
                scale: 0.35 + 0.65 * check,
                child: Opacity(
                  opacity: check.clamp(0.0, 1.0),
                  child: Container(
                    width: core, height: core,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [color, Color.lerp(color, Colors.black, 0.22)!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(
                          color: color.withValues(alpha: 0.38),
                          blurRadius: 24, offset: const Offset(0, 9))],
                    ),
                    child: Icon(
                        failed
                            ? Icons.close_rounded
                            : holding
                                ? Icons.pause_rounded
                                : Icons.check_rounded,
                        color: Colors.white, size: compact ? 38 : 46),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
  }
}

class _SuccessPainter extends CustomPainter {
  final double ring, burst;
  final Color color;
  const _SuccessPainter({required this.ring, required this.burst,
      this.color = C.accentGreen});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 8;

    final glow = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: 0.22 * ring),
        color.withValues(alpha: 0.0),
      ]).createShader(Rect.fromCircle(center: center, radius: r * 1.5));
    canvas.drawCircle(center, r * 1.5, glow);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.85);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r),
        -math.pi / 2, 2 * math.pi * ring, false, ringPaint);

    if (burst <= 0) return;
    const n = 12;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi - math.pi / 2;
      final d = r * (0.95 + 0.5 * burst);
      final p = center + Offset(math.cos(a) * d, math.sin(a) * d);
      final paint = Paint()
        ..color = (i.isEven ? color : C.accent)
            .withValues(alpha: (1 - burst) * 0.85);
      canvas.drawCircle(p, 1.2 + 2.6 * (1 - burst), paint);
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter old) =>
      old.ring != ring || old.burst != burst || old.color != color;
}

/// ណែនាំពេលអ្នកប្រើមិនឃើញប្រាក់ចូល — ជំហានសាមញ្ញ និងច្បាស់លាស់
class _MissingMoneyScreen extends StatefulWidget {
  const _MissingMoneyScreen();
  @override
  State<_MissingMoneyScreen> createState() => _MissingMoneyScreenState();
}

class _MissingMoneyScreenState extends State<_MissingMoneyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = <(IconData, String, String)>[
      (Icons.receipt_long_rounded, 'ពិនិត្យប្រវត្តិការណ៍',
          'បើកប្រវត្តិការណ៍ ដើម្បីមើលស្ថានភាពចុងក្រោយនៃការផ្ទេរ'),
      (Icons.schedule_rounded, 'រង់ចាំបន្តិច',
          'ការផ្ទេរខ្លះត្រូវការពេលឈានដល់ធនាគារអ្នកទទួល'),
      (Icons.support_agent_rounded, 'ទាក់ទងជំនួយ',
          'បើហួស ១០ នាទីហើយនៅមិនឃើញ សូមទាក់ទងផ្នែកជំនួយ Aura Bank'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('បើមិនឃើញប្រាក់ចូលទេ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = _c.value;
                return Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(alignment: Alignment.center, children: [
                      for (var i = 0; i < 3; i++)
                        _radar((t + i / 3) % 1.0),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              colors: [C.accent, Color(0xFF1E6FA8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          boxShadow: [
                            BoxShadow(
                                color: C.accent.withValues(alpha: 0.4),
                                blurRadius: 20),
                          ],
                        ),
                        child: const Icon(Icons.search_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('មិនឃើញប្រាក់? មិនបារម្ភទេ',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.ink)),
            const SizedBox(height: 6),
            Text('សូមអនុវត្តតាមជំហានខាងក្រោម ដើម្បីពិនិត្យប្រតិបត្តិការរបស់អ្នក',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.muted)),
            const SizedBox(height: 22),
            for (var i = 0; i < steps.length; i++) ...[
              _stepCard(context, index: i, icon: steps[i].$1,
                  title: steps[i].$2, subtitle: steps[i].$3),
              if (i < steps.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 22),
            NeuButton(
              label: 'យល់ហើយ',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radar(double p) => Opacity(
        opacity: (1 - p) * 0.45,
        child: Transform.scale(
          scale: 0.55 + p * 0.7,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: C.accent, width: 1.6),
            ),
          ),
        ),
      );

  Widget _stepCard(BuildContext context,
          {required int index,
          required IconData icon,
          required String title,
          required String subtitle}) =>
      NeuBox(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                  colors: [C.accent, Color(0xFF1E6FA8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('ជំហាន ${index + 1}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: C.accent)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: context.ink)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11.5, height: 1.45, color: context.muted)),
            ]),
          ),
        ]),
      );
}

/// ចលនាប្រាប់អ្នកប្រើឱ្យចុច icon — pulse ring, ម្រាមដៃលោត និង pill "ចុចទីនេះ"
class _MissingMoneyLink extends StatefulWidget {
  final bool prominent;
  const _MissingMoneyLink({this.prominent = false});
  @override
  State<_MissingMoneyLink> createState() => _MissingMoneyLinkState();
}

class _MissingMoneyLinkState extends State<_MissingMoneyLink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _open() => Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const _MissingMoneyScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ));

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    const base = C.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final wave = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
          final bob = math.sin(t * 2 * math.pi * 2);
          final glow = (widget.prominent ? 0.20 : 0.12) + 0.16 * wave;
          return Transform.scale(
            scale: 1 + 0.012 * wave,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [
                          base.withValues(alpha: 0.16 + 0.08 * wave),
                          C.accentGold.withValues(alpha: 0.08 + 0.06 * wave),
                        ]
                      : [
                          base.withValues(alpha: 0.08 + 0.05 * wave),
                          C.accentGold.withValues(alpha: 0.10 + 0.05 * wave),
                        ],
                ),
                border: Border.all(
                    color: base.withValues(alpha: 0.28 + 0.24 * wave),
                    width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: base.withValues(alpha: glow),
                      blurRadius: 16 + 12 * wave,
                      spreadRadius: 1),
                ],
              ),
              child: Row(children: [
                _haloIcon(t, base),
                Transform.translate(
                  offset: Offset(-5 * (0.5 + 0.5 * bob), 0),
                  child: const Icon(Icons.touch_app_rounded,
                      size: 17, color: Color(0xFFE8B54D)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('បើមិនឃើញប្រាក់ទេ',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: context.muted)),
                        const SizedBox(height: 6),
                        _tapPill(t, base),
                      ]),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20,
                    color: context.muted.withValues(alpha: 0.6)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _haloIcon(double t, Color base) {
    final dark = context.isDark;
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(alignment: Alignment.center, children: [
        for (var i = 0; i < 2; i++)
          _ripple((t + i * 0.5) % 1.0, base),
        Transform.rotate(
          angle: t * 2 * math.pi,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  base.withValues(alpha: 0.0),
                  base.withValues(alpha: 0.0),
                  base.withValues(alpha: 0.45),
                  C.accentGold.withValues(alpha: 0.9),
                  base.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.70, 0.86, 0.94, 1.0],
              ),
            ),
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.card,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(3, 4)),
              BoxShadow(
                  color: Colors.white.withValues(alpha: dark ? 0.07 : 0.9),
                  blurRadius: 8,
                  offset: const Offset(-3, -4)),
            ],
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                base.withValues(alpha: 0.55),
                base,
                Colors.white,
                base,
                base.withValues(alpha: 0.55),
              ],
              stops: const [0.0, 0.32, 0.5, 0.68, 1.0],
              transform: _SkeletonSlide(t),
            ).createShader(r),
            child: const Icon(Icons.help_outline_rounded, size: 24),
          ),
        ),
      ]),
    );
  }

  Widget _ripple(double p, Color base) => Opacity(
        opacity: (1 - p) * 0.5,
        child: Transform.scale(
          scale: 0.9 + p * 0.5,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: base, width: 1.5),
            ),
          ),
        ),
      );

  Widget _tapPill(double t, Color base) {
    final slide = math.sin(t * 2 * math.pi);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment(-1.2 + slide, -1),
          end: Alignment(0.8 + slide, 1),
          colors: const [C.accent, Color(0xFF2C7FBE), C.accentGold],
        ),
        boxShadow: [
          BoxShadow(
              color: C.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.touch_app_rounded, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        const Text('ចុចទីនេះ',
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
//  SPLASH
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      final sp = await SharedPreferences.getInstance();
      final seen = sp.getBool('has_seen_onboarding_v1') ?? false;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) {
          if (bank.loggedIn) {
            // Google user មិនមាន PIN → រំលង LockScreen ចូលផ្ទាល់
            return bank._isGoogleUser ? const MainShell() : const LockScreen();
          }
          if (!seen) return const OnboardingScreen();
          return const LoginScreen();
        },
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(color: C.bgDark),
          child: Stack(children: [
            Positioned(top: -80, right: -80, child: _orb(220, 0.06)),
            Positioned(bottom: -100, left: -60, child: _orb(280, 0.05)),
            Positioned(top: 200, left: -50, child: _orb(150, 0.04)),
            Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.scale(
                  scale: v,
                  child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                ),
                child: Row(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('AURA', style: TextStyle(color: Colors.white,
                      fontSize: 52, fontWeight: FontWeight.w900,
                      letterSpacing: 8)),
                  Container(
                      margin: const EdgeInsets.only(left: 4, top: 6),
                      width: 8, height: 14, color: C.abaRed),
                ]),
              ),
              const SizedBox(height: 14),
              Text('ធនាគារឌីជីថល · Digital Banking',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 48),
              SizedBox(width: 32, height: 32,
                  child: CircularProgressIndicator(
                      color: Colors.white.withValues(alpha: 0.9),
                      strokeWidth: 3)),
            ])),
          ]),
        ),
      );

  Widget _orb(double s, double o) => Container(
        width: s, height: s,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: o)),
      );
}

// ============================================================================
//  REGISTRATION
// ============================================================================
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final pin = TextEditingController();
  final pin2 = TextEditingController();
  bool agree = false, loading = false, ob1 = true, ob2 = true;

  @override
  void dispose() {
    name.dispose(); email.dispose(); phone.dispose();
    pin.dispose(); pin2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!agree) { toast(context, 'សូមយល់ព្រមលក្ខខណ្ឌ', error: true); return; }
    setState(() => loading = true);
    try {
      await bank.register(name: name.text.trim(), email: email.text.trim(),
          phone: phone.text.trim(), pin: pin.text);
      if (!mounted) return;
      toast(context, 'បង្កើតគណនីបានជោគជ័យ! 🎉');
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Cannot reach server', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(key: _formKey, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: AuraGrad.button,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance,
                      size: 40, color: Colors.white),
                )),
                const SizedBox(height: 20),
                Text('បង្កើតគណនីថ្មី', textAlign: TextAlign.center,
                    style: TextStyle(color: context.ink, fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text('ចុះឈ្មោះដើម្បីចាប់ផ្តើមប្រើប្រាស់',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.muted, fontSize: 12.5)),
                const SizedBox(height: 24),
                NeuBox(padding: const EdgeInsets.all(20), radius: 18,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      NeuField(controller: name, icon: Icons.person_outline,
                          label: 'ឈ្មោះពេញ',
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? 'សូមបញ្ចូលឈ្មោះ' : null),
                      const SizedBox(height: 12),
                      NeuField(controller: email, icon: Icons.email_outlined,
                          label: 'អ៊ីមែល',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'សូមបញ្ចូលអ៊ីមែល';
                            return RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$')
                                    .hasMatch(v.trim()) ? null : 'អ៊ីមែលមិនត្រឹមត្រូវ';
                          }),
                      const SizedBox(height: 12),
                      NeuField(controller: phone, icon: Icons.phone_outlined,
                          label: 'លេខទូរស័ព្ទ',
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.trim().length < 8)
                              ? 'សូមបញ្ចូលលេខ' : null),
                      const SizedBox(height: 12),
                      NeuField(controller: pin, icon: Icons.lock_outline,
                          label: 'PIN 4 ខ្ទង់', obscure: ob1, maxLength: 4,
                          keyboardType: TextInputType.number,
                          suffix: IconButton(
                            icon: Icon(
                                ob1 ? Icons.visibility : Icons.visibility_off,
                                color: context.muted, size: 18),
                            onPressed: () => setState(() => ob1 = !ob1),
                          ),
                          validator: (v) => (v == null ||
                                  !RegExp(r'^\d{4}$').hasMatch(v))
                              ? 'PIN ត្រូវមាន 4 ខ្ទង់' : null),
                      const SizedBox(height: 12),
                      NeuField(controller: pin2, icon: Icons.lock_outline,
                          label: 'បញ្ជាក់ PIN', obscure: ob2, maxLength: 4,
                          keyboardType: TextInputType.number,
                          suffix: IconButton(
                            icon: Icon(
                                ob2 ? Icons.visibility : Icons.visibility_off,
                                color: context.muted, size: 18),
                            onPressed: () => setState(() => ob2 = !ob2),
                          ),
                          validator: (v) => v != pin.text
                              ? 'PIN មិនត្រូវគ្នា' : null),
                      const SizedBox(height: 12),
                      Row(children: [
                        Checkbox(value: agree, activeColor: C.accent,
                            onChanged: (v) => setState(() => agree = v ?? false)),
                        Expanded(child: GestureDetector(
                          onTap: () => setState(() => agree = !agree),
                          child: Text('ខ្ញុំយល់ព្រមលក្ខខណ្ឌ',
                              style: TextStyle(fontSize: 12, color: context.ink)),
                        )),
                      ]),
                      const SizedBox(height: 14),
                      loading
                          ? const Center(child: SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(
                                  color: C.accent, strokeWidth: 2.5)))
                          : NeuButton(label: 'ចុះឈ្មោះ',
                              icon: Icons.person_add_alt, onPressed: _submit),
                    ])),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('មានគណនីរួចហើយ? ',
                      style: TextStyle(fontSize: 13, color: context.muted)),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('ចូលប្រើ',
                        style: TextStyle(color: C.accent,
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ]),
              ])),
            ),
          ),
        ),
      );
}

// ============================================================================
//  LOGIN
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  bool loading = false, ob = true;
  bool _googleLoading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await bank.login(emailCtrl.text.trim(), pinCtrl.text);
      if (!mounted) return;
      toast(context, 'ចូលប្រើជោគជ័យ! 🎉');
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        toast(context,
            e.message == 'User not found'
                ? 'អ៊ីមែលនេះមិនមានក្នុងប្រព័ន្ធ'
                : e.message == 'Wrong PIN'
                    ? 'PIN មិនត្រឹមត្រូវ'
                    : e.message,
            error: true);
      }
    } catch (_) {
      if (mounted) toast(context, 'Cannot reach server', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await bank.loginWithGoogle();
      if (!mounted) return;
      toast(context, 'ចូលប្រើដោយ Google ជោគជ័យ! 🎉');
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ));
    } catch (e) {
      if (mounted) {
        toast(context, 'Error: $e', error: true);
        print('Google Sign-In Error: $e');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(key: _formKey,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            gradient: AuraGrad.button,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_open,
                              size: 40, color: Colors.white),
                        )),
                        const SizedBox(height: 20),
                        Text('ចូលប្រើគណនី',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.ink, fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        Text('បញ្ចូលអ៊ីមែល និង PIN ដើម្បីចូល',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.muted, fontSize: 12.5)),
                        const SizedBox(height: 24),
                        NeuBox(padding: const EdgeInsets.all(20), radius: 18,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  NeuField(
                                      controller: emailCtrl,
                                      icon: Icons.email_outlined,
                                      label: 'អ៊ីមែល',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'សូមបញ្ចូលអ៊ីមែល';
                                        }
                                        return RegExp(
                                                    r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$')
                                                .hasMatch(v.trim())
                                            ? null : 'អ៊ីមែលមិនត្រឹមត្រូវ';
                                      }),
                                  const SizedBox(height: 12),
                                  NeuField(
                                      controller: pinCtrl,
                                      icon: Icons.lock_outline,
                                      label: 'PIN 4 ខ្ទង់',
                                      obscure: ob, maxLength: 4,
                                      keyboardType: TextInputType.number,
                                      suffix: IconButton(
                                        icon: Icon(
                                            ob ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: context.muted, size: 18),
                                        onPressed: () => setState(() => ob = !ob),
                                      ),
                                      validator: (v) => (v == null ||
                                              !RegExp(r'^\d{4}$').hasMatch(v))
                                          ? 'PIN ត្រូវមាន 4 ខ្ទង់' : null),
                                  const SizedBox(height: 20),
                                  loading
                                      ? const Center(child: SizedBox(
                                          width: 24, height: 24,
                                          child: CircularProgressIndicator(
                                              color: C.accent, strokeWidth: 2.5)))
                                      : NeuButton(label: 'ចូលប្រើ',
                                          icon: Icons.login, onPressed: _login),
                                  const SizedBox(height: 12),
                                  _googleLoading
                                      ? const Center(child: SizedBox(
                                          width: 24, height: 24,
                                          child: CircularProgressIndicator(
                                              color: C.accent, strokeWidth: 2.5)))
                                      : NeuButton(
                                          label: 'ចូលដោយ Google',
                                          icon: Icons.g_mobiledata,
                                          accent: C.abaRed,
                                          onPressed: _loginWithGoogle,
                                        ),
                                ])),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('មិនទាន់មានគណនី? ',
                              style: TextStyle(fontSize: 13, color: context.muted)),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => const RegistrationScreen()),
                            ),
                            child: const Text('បង្កើតគណនី',
                                style: TextStyle(color: C.accent,
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ]),
                      ])),
            ),
          ),
        ),
      );
}

// ============================================================================
//  LOCK
// ============================================================================
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  Future<void> _onPin(BuildContext ctx, String pin) async {
    try {
      await bank.login(bank.userEmail, pin);
      if (!ctx.mounted) return;
      Navigator.of(ctx).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ));
    } on ApiException catch (e) {
      if (ctx.mounted) {
        toast(ctx, e.message == 'Wrong PIN' ? 'PIN មិនត្រឹមត្រូវ' : e.message,
            error: true);
      }
    } catch (_) {
      if (ctx.mounted) toast(ctx, 'Cannot reach server', error: true);
    }
  }

  Future<void> _onBio(BuildContext ctx) async {
    final avail = await BiometricService.isAvailable();
    if (!avail) {
      final ok = await bank.biometricLogin();
      if (!ctx.mounted) return;
      if (ok) {
        Navigator.of(ctx).pushReplacement(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ));
      } else {
        toast(ctx, 'សូមបញ្ចូល PIN', error: true);
      }
      return;
    }
    final auth = await BiometricService.authenticate();
    if (!ctx.mounted || !auth) return;
    final ok = await bank.biometricLogin();
    if (!ctx.mounted) return;
    if (ok) {
      Navigator.of(ctx).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ));
    } else {
      toast(ctx, 'សូមបញ្ចូល PIN ម្តង', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const UserAvatar(radius: 42),
              const SizedBox(height: 20),
              Text('សួស្តី, ${bank.userName.isEmpty ? bank.userEmail : bank.userName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.ink, fontSize: 18,
                      fontWeight: FontWeight.w700)),
              Text('បញ្ចូល PIN ដើម្បីចូលប្រើ',
                  style: TextStyle(color: context.muted, fontSize: 12.5)),
              const SizedBox(height: 30),
              PinPad(showBio: bank.biometric,
                  onSuccess: (pin) => _onPin(context, pin),
                  onBioSuccess: () => _onBio(context)),
            ]),
          ),
        ),
      );
}

// ============================================================================
//  MAIN SHELL — ABA Flat Nav  (⚡ Lazy tabs: បង្កើតតែ Tab ដែលបានបើក)
// ============================================================================
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final Set<int> _built = {0};

  static const List<Widget> _pages = [
    HomeScreen(),
    TransferMenuScreen(),
    AnalyticsScreen(),
    TrackingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (_, i, __) {
        _built.add(i);
        return Scaffold(
          body: IndexedStack(
            index: i,
            children: [
              for (int k = 0; k < _pages.length; k++)
                _built.contains(k) ? _pages[k] : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar:
              _AuraNav(current: i, onTap: (v) => tabIndex.value = v),
        );
      },
    );
  }
}

class _AuraNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _AuraNav({required this.current, required this.onTap});

  static const _items = [
    _Nav(Icons.home_outlined, Icons.home_rounded, 'ដើម'),
    _Nav(Icons.swap_horiz_rounded, Icons.swap_horiz_rounded, 'ផ្ទេរ'),
    _Nav(Icons.insights_outlined, Icons.insights, 'ស្ថិតិ'),
    _Nav(Icons.track_changes_outlined, Icons.track_changes_rounded, 'តាមដាន'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF022B45) : context.card,
          border: Border(top: BorderSide(color: context.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_items.length, (i) {
                final it = _items[i];
                final sel = i == current;
                final col = sel
                    ? (context.isDark ? Colors.white : C.bgDark)
                    : context.muted;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(sel ? it.active : it.icon, color: col, size: 24),
                        const SizedBox(height: 3),
                        Text(it.label,
                            style: TextStyle(
                                color: col, fontSize: 10.5,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500)),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: sel ? 18 : 0, height: 2.5,
                          decoration: BoxDecoration(
                              color: C.abaRed,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}

class _Nav {
  final IconData icon, active;
  final String label;
  const _Nav(this.icon, this.active, this.label);
}

Future<Object?> push(BuildContext c, Widget w) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

// ============================================================================
//  HOME
// ============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return sb(() => Scaffold(
          drawer: Drawer(
            backgroundColor: context.bg,
            width: math.min(MediaQuery.of(context).size.width * 0.88, 380.0),
            child: const SafeArea(child: ProfileScreen()),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: C.accent,
              onRefresh: () async {
                await bank.loadAll();
                await bank.loadExtra();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  _hero(context),
                  const SectionTitle('សេវាកម្មរហ័ស'),
                  AbaGrid(items: [
                    AbaCell(Icons.account_balance_wallet_outlined, 'គណនី',
                        () => push(context, const AccountScreen())),
                    AbaCell(Icons.monetization_on_outlined, 'ទូទាត់ប្រាក់',
                        () => _payBill(context, 'វិក្កយបត្រ', Icons.receipt_long)),
                    AbaCell(Icons.swap_horizontal_circle_outlined, 'ផ្ទេរប្រាក់',
                        () => tabIndex.value = 1),
                    AbaCell(Icons.qr_code_scanner, 'KHQR ស្កេន',
                        () => push(context, const QrScreen(startScan: true))),
                    AbaCell(Icons.savings_outlined, 'សន្សំ',
                        () => push(context, const SavingsScreen())),
                    AbaCell(Icons.request_quote_outlined, 'ប្រាក់កម្ចី',
                        () => push(context, const LoanModuleScreen())),
                    AbaCell(Icons.south_west_rounded, 'ទទួលប្រាក់',
                        () => push(context, const ReceiveMoneyScreen()),
                        iconWidget: ReceiveMoneyGlyph(
                            size: 40,
                            color: context.isDark
                                ? C.iconTint
                                : C.bgDark)),
                    AbaCell(Icons.notifications_active_outlined, 'រំលឹក',
                        () => push(context, const RemindersScreen())),
                    AbaCell(Icons.apps_rounded, 'សមិទ្ធផល',
                        () => push(context, const AchievementsScreen())),
                  ]),
                  SectionTitle('ប្រតិបត្តិការចុងក្រោយ',
                      trailing: TextButton(
                          onPressed: () => push(context, const HistoryScreen()),
                          child: const Text('មើលទាំងអស់',
                              style: TextStyle(color: C.accent,
                                  fontWeight: FontWeight.w700, fontSize: 13)))),
                  for (var i = 0; i < bank.txs.take(4).length; i++)
                    StaggeredItem(index: i,
                        child: TxTile(bank.txs.take(4).elementAt(i))),
                ],
              ),
            ),
          ),
        ));
  }

  // ── Header បែប ABA: ម៉ឺនុយ · ឡូហ្គោ · សារ · កណ្ដឹង · កាបូប · ប៊ូតុងក្រហម ──
  Widget _header(BuildContext context) {
    final col = context.isDark ? Colors.white : C.bgDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Builder(builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Icon(Icons.menu, color: col, size: 28))),
        const SizedBox(width: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AURA',
              style: TextStyle(
                  color: col, fontSize: 24, fontWeight: FontWeight.w900,
                  letterSpacing: 3)),
          Container(
              margin: const EdgeInsets.only(left: 2, top: 2),
              width: 5, height: 9, color: C.abaRed),
        ]),
        const Spacer(),
        GestureDetector(
            onTap: () => toast(context, 'ជំនួយ'),
            child: Icon(Icons.chat_bubble_outline, color: col, size: 26)),
        const SizedBox(width: 18),
        GestureDetector(
          onTap: () => push(context, const NotificationScreen()),
          child: Stack(clipBehavior: Clip.none, children: [
            Icon(Icons.notifications_none, color: col, size: 28),
            if (bank.unread > 0)
              Positioned(
                  right: 1, top: 0,
                  child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                          color: C.abaRed, shape: BoxShape.circle))),
          ]),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: () => push(context, const QrScreen()),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: C.abaRed, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.alternate_email,
                color: Colors.white, size: 24),
          ),
        ),
      ]),
    );
  }

  Widget _hero(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AuraGrad.brand,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Stack(children: [
          Positioned(right: -30, top: -30, child: Container(
            width: 140, height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06)))),
          Positioned(right: 40, bottom: -50, child: Container(
            width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('សមតុល្យសរុប', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () => bank.setHide(!bank.hideBalance),
                child: Icon(
                    bank.hideBalance ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withValues(alpha: 0.85), size: 20),
              ),
            ]),
            const SizedBox(height: 8),
            bank.hideBalance
                ? const Text('••••••••', style: TextStyle(color: Colors.white,
                    fontSize: 32, fontWeight: FontWeight.w800))
                : AnimatedCounter(
                    value: bank.currencyMode == 'KHR'
                        ? bank.total * bank.khrRate : bank.total,
                    formatter: bank.currencyMode == 'KHR'
                        ? (v) => '៛${v.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                            (m) => '${m[1]},')}'
                        : money,
                    style: const TextStyle(color: Colors.white, fontSize: 32,
                        fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.trending_up, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('+2.4%', style: TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => bank.setCurrency(
                    bank.currencyMode == 'USD' ? 'KHR' : 'USD'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      bank.currencyMode == 'USD' ? '\$ USD' : '៛ KHR',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ]),
      );

  Future<void> _payBill(BuildContext context, String title, IconData icon) async {
    if (bank.cards.isEmpty) return;
    final code = TextEditingController();
    final amt = TextEditingController();
    int cardId = bank.cards.first.id;
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w700, color: ctx.ink)),
              const SizedBox(height: 18),
              NeuField(controller: code, label: 'លេខយោង', icon: Icons.tag),
              const SizedBox(height: 12),
              NeuField(controller: amt, label: 'ទឹកប្រាក់ (\$)',
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true)),
              const SizedBox(height: 16),
              CardPicker(selectedId: cardId,
                  onChanged: (id) => setS(() => cardId = id)),
              const SizedBox(height: 20),
              NeuButton(label: 'បន្ត', icon: Icons.arrow_forward,
                  onPressed: () {
                    final a = parseAmt(amt.text);
                    if (code.text.trim().isEmpty || a == null) {
                      toast(ctx, 'សូមបំពេញ', error: true);
                      return;
                    }
                    Navigator.pop(ctx, {'amount': a, 'cardId': cardId,
                        'code': code.text.trim()});
                  }),
            ]),
          ),
        ),
      ),
    );
    if (r != null && context.mounted) {
      await confirmAndPay(context, title: '$title (${r['code']})',
          category: 'វិក្កយបត្រ', amount: r['amount'] as double,
          cardId: r['cardId'] as int, icon: icon);
    }
  }
}

// ============================================================================
//  CARDS (បញ្ជីកាតពិតប្រាកដ)
// ============================================================================
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});
  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('កាតធនាគារ')),
        body: bank.loading && bank.cards.isEmpty
            ? const CardsSkeleton()
            : RefreshIndicator(
                color: C.accent,
                onRefresh: bank.loadAll,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: bank.cards.length,
                  itemBuilder: (_, i) {
                    final c = bank.cards[i];
                    return Padding(padding: const EdgeInsets.only(bottom: 22),
                        child: Column(children: [
                      SizedBox(height: 190, child: BankCardWidget(card: c,
                          onTap: () => push(context,
                              CardDetailScreen(cardId: c.id)))),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: (c.frozen ? C.accentRed : C.accentGreen)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(c.frozen ? Icons.lock : Icons.check_circle,
                                color: c.frozen ? C.accentRed : C.accentGreen,
                                size: 12),
                            Text(c.frozen ? 'បិទ' : 'ដំណើរការ',
                                style: TextStyle(fontSize: 10.5,
                                    color: c.frozen
                                        ? C.accentRed : C.accentGreen)),
                          ]),
                        ),
                        GestureDetector(
                          onTap: () => push(context,
                              CardDetailScreen(cardId: c.id)),
                          child: const Row(children: [
                            Icon(Icons.tune, size: 16, color: C.accent),
                            Text('ការកំណត់', style: TextStyle(fontSize: 12.5,
                                fontWeight: FontWeight.w700, color: C.accent)),
                          ]),
                        ),
                      ]),
                    ]));
                  },
                ),
              )));
}

class CardDetailScreen extends StatefulWidget {
  final int cardId;
  const CardDetailScreen({super.key, required this.cardId});
  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  bool revealed = false;
  @override
  Widget build(BuildContext context) => sb(() {
        if (bank.cards.isEmpty) {
          return Scaffold(appBar: AppBar(),
              body: const Center(child: Text('គ្មានកាត')));
        }
        final c = bank.cards.firstWhere((x) => x.id == widget.cardId,
            orElse: () => bank.cards.first);
        return Scaffold(
          appBar: AppBar(title: Text(c.name)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            SizedBox(height: 200, child: BankCardWidget(card: c, revealed: revealed)),
            const SizedBox(height: 20),
            NeuButton(label: revealed ? 'លាក់លេខកាត' : 'បង្ហាញលេខកាត',
                icon: revealed ? Icons.visibility_off : Icons.visibility,
                onPressed: () async {
                  if (revealed) { setState(() => revealed = false); return; }
                  if (bank._isGoogleUser) {
                    setState(() => revealed = true);
                    return;
                  }
                  final pin = await askPin(context);
                  if (pin != null && mounted) setState(() => revealed = true);
                }),
            const SectionTitle('សុវត្ថិភាព'),
            NeuBox(child: Column(children: [
              SwitchListTile(value: c.frozen, activeThumbColor: C.accent,
                  onChanged: (v) async {
                    try {
                      await bank.freezeCard(c, v);
                      if (context.mounted) {
                        toast(context, v ? 'បានបិទកាត' : 'បានបើកកាត');
                      }
                    } on ApiException catch (e) {
                      if (context.mounted) toast(context, e.message, error: true);
                    }
                  },
                  secondary: Icon(Icons.lock_outline,
                      color: c.frozen ? C.accentRed : C.accent),
                  title: const Text('បិទកាតជាបណ្តោះអាសន្ន')),
              SwitchListTile(value: c.online, activeThumbColor: C.accent,
                  onChanged: (v) async {
                    try { await bank.setCardOnline(c, v); }
                    on ApiException catch (e) {
                      if (context.mounted) toast(context, e.message, error: true);
                    }
                  },
                  secondary: const Icon(Icons.shopping_cart_outlined,
                      color: C.accent),
                  title: const Text('ទិញទំនិញអនឡាញ')),
            ])),
          ]),
        );
      });
}

// ============================================================================
//  TRANSFER MENU (UI ថ្មី - ជម្រើសផ្ទេរប្រាក់)
// ============================================================================
class TransferMenuScreen extends StatelessWidget {
  const TransferMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDark,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => tabIndex.value = 0,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const Row(
                        children: [
                          Text('ផ្ទេរប្រាក់', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          Icon(Icons.info_outline, color: Colors.white70, size: 18),
                        ],
                      ),
                      const Icon(Icons.pets, color: C.accentGold, size: 28),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.sync_alt, color: Colors.white24, size: 100),
                      Positioned(right: 80, top: 10, child: Icon(Icons.monetization_on, color: C.accentGold.withValues(alpha: 0.8), size: 30)),
                      Positioned(left: 80, bottom: 10, child: Icon(Icons.monetization_on, color: C.accentGold.withValues(alpha: 0.8), size: 20)),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  _buildTransferItem(context, icon: Icons.swap_horiz_rounded, iconColor: const Color(0xFF3B5BDB), title: 'គណនីផ្ទាល់ខ្លួន', subtitle: 'ផ្ទេរប្រាក់ទៅគណនីផ្ទាល់ខ្លួន', onTap: () => push(context, const TransferScreen(heading: 'គណនីផ្ទាល់ខ្លួន'))),
                  _buildTransferItem(context, icon: Icons.account_balance_wallet, iconColor: const Color(0xFF1E3A8A), title: 'ធនាគារក្នុងស្រុក', subtitle: 'ជ្រើសរើសធនាគារដើម្បីផ្ទេរប្រាក់', showChevron: true, onTap: () => push(context, const BankSelectionScreen())),
                  _buildTransferItem(context, icon: Icons.account_balance, iconColor: const Color(0xFF9333EA), title: 'ផ្ទេរប្រាក់ក្នុងប្រទេស', subtitle: 'ផ្ទេរប្រាក់ទៅធនាគារ | MFIs | វ៉លឡេត', showChevron: true, onTap: () => push(context, const TransferScreen(bankCode: 'ABA', heading: 'ផ្ទេរក្នុងប្រទេស'))),
                  _buildTransferItem(context, icon: Icons.public, iconColor: const Color(0xFF0F766E), title: 'ផ្ទេរប្រាក់ទៅក្រៅប្រទេស', subtitle: 'ផ្ទេរប្រាក់ទៅធនាគារ | ភ្នាក់ងារផ្ទេរប្រាក់ពិភពលោក', showChevron: true, onTap: () => push(context, const TransferScreen(bankCode: 'OTHER', heading: 'ផ្ទេរក្រៅប្រទេស'))),
                  _buildTransferItem(context, icon: Icons.credit_card, iconColor: const Color(0xFFD946EF), title: 'ផ្ទេរប្រាក់ទៅប័ណ្ណ', subtitle: 'ផ្ទេរប្រាក់ទៅប័ណ្ណរបស់ធនាគារផ្សេង', showChevron: true, onTap: () => push(context, const TransferScreen(bankCode: 'CANADIA', heading: 'ផ្ទេរទៅប័ណ្ណ'))),
                  _buildTransferItem(context, icon: Icons.insert_chart_outlined_rounded, iconColor: const Color(0xFFB45309), title: 'គណនីជូញដួរ', subtitle: 'ផ្ទេរប្រាក់រវាងគណនីអេស៊ីលីដា និងគណនីជូញដួរ', showChevron: true, onTap: () => push(context, const TransferScreen(bankCode: 'JUNTUOR', heading: 'គណនីជូញដួរ'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferItem(BuildContext context, {required IconData icon, required Color iconColor, required String title, required String subtitle, bool showChevron = false, Widget? trailing, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 26)),
              const SizedBox(width: 16),
              Container(width: 1, height: 40, color: context.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.ink)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: context.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailing != null) ...[trailing, const SizedBox(width: 8)],
              if (showChevron || trailing != null) const Icon(Icons.arrow_forward_ios, color: C.accentGold, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  BANK SELECTION SCREEN (ជ្រើសរើសធនាគារ)
// ============================================================================
class BankSelectionScreen extends StatelessWidget {
  const BankSelectionScreen({super.key});

  static const List<Map<String, dynamic>> _banks = [
    {
      'code': 'ACLEDA',
      'name': 'ធនាគារ អេស៊ីលីដា',
      'nameEn': 'ACLEDA Bank',
      'year': 1993,
      'color': Color(0xFF003F87),
      'logo': 'assets/icon/acleda_logo.png',
    },
    {
      'code': 'CANADIA',
      'name': 'ធនាគារ កាណាឌីយ៉ា',
      'nameEn': 'Canadia Bank',
      'year': 1991,
      'color': Color(0xFFD32F2F),
      'logo': 'assets/icon/canadia-logo.png',
    },
    {
      'code': 'VATTANAC',
      'name': 'ធនាគារ វឌ្ឍនៈ',
      'nameEn': 'Vattanac Bank',
      'year': 2002,
      'color': Color(0xFF1976D2),
      'icon': Icons.account_balance,
    },
    {
      'code': 'WING',
      'name': 'ធនាគារ វីង',
      'nameEn': 'Wing Bank',
      'year': 2022,
      'color': Color(0xFF7B1FA2),
      'icon': Icons.mobile_friendly,
    },
    {
      'code': 'CHIPMONG',
      'name': 'ធនាគារ ជីប ម៉ុង',
      'nameEn': 'Chip Mong Bank',
      'year': null,
      'color': Color(0xFF0097A7),
      'icon': Icons.account_balance,
    },
    {
      'code': 'POST',
      'name': 'ធនាគារ ប្រៃសណីយ៍កម្ពុជា',
      'nameEn': 'Cambodia Post Bank',
      'year': null,
      'color': Color(0xFF388E3C),
      'icon': Icons.local_post_office,
    },
    {
      'code': 'FTB',
      'name': 'ធនាគារ FTB',
      'nameEn': 'Foreign Trade Bank',
      'year': 1979,
      'color': Color(0xFF455A64),
      'icon': Icons.account_balance,
    },
    {
      'code': 'SME',
      'name': 'ធនាគារ SME',
      'nameEn': 'SME Bank of Cambodia',
      'year': null,
      'color': Color(0xFFE64A19),
      'icon': Icons.business,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDark,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const Text('ជ្រើសរើសធនាគារ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 38),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _banks.length,
                itemBuilder: (context, index) {
                  final bank = _banks[index];
                  return _buildBankItem(context, bank);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankItem(BuildContext context, Map<String, dynamic> bank) {
    final year = bank['year'];
    final hasLogo = bank['logo'] != null;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          push(context, TransferScreen(
            bankCode: bank['code'],
            heading: bank['name'],
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border),
          ),
          child: Row(
            children: [
              // Logo or Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: hasLogo ? Colors.white : bank['color'],
                  borderRadius: BorderRadius.circular(12),
                  border: hasLogo ? Border.all(color: context.border, width: 1) : null,
                ),
                child: hasLogo
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          bank['logo'],
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(bank['icon'], color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank['name'],
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bank['nameEn'],
                      style: TextStyle(fontSize: 12, color: context.muted),
                    ),
                    if (year != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'បង្កើតឆ្នាំ $year',
                        style: TextStyle(fontSize: 10, color: context.muted.withValues(alpha: 0.7)),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: C.accentGold, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// rails ធនាគារ/MFI ដែល Backend គាំទ្រសម្រាប់ការផ្ទេរចេញក្រៅ
class BankRail {
  final String code, name, currency;
  final double feeRate, feeMax, minAmount, maxAmount;
  const BankRail({required this.code, required this.name,
      this.currency = 'USD', this.feeRate = 0, this.feeMax = 0,
      this.minAmount = 0.01, this.maxAmount = 10000});

  factory BankRail.fromJson(Map<String, dynamic> j) => BankRail(
      code: (j['code'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      currency: (j['currency'] ?? 'USD').toString(),
      feeRate: (j['fee_rate'] as num?)?.toDouble() ?? 0,
      feeMax: (j['fee_max'] as num?)?.toDouble() ?? 0,
      minAmount: (j['min_amount'] as num?)?.toDouble() ?? 0.01,
      maxAmount: (j['max_amount'] as num?)?.toDouble() ?? 10000);

  /// គណនាដូច Server: min(round(amount*rate, 2), feeMax)
  double feeFor(double amount) {
    final raw = (amount * feeRate * 100).roundToDouble() / 100;
    return raw <= feeMax ? raw : feeMax;
  }
}

/// អ្នកទទួលដែលបានចុះឈ្មោះ (Server បង្ហាញតែឈ្មោះ + account បិទបាំង)
class RecipientContact {
  final String id, name, maskedAccount;
  final bool recent;
  final Uint8List? thumb;
  const RecipientContact({required this.id, required this.name,
      required this.maskedAccount, this.recent = false, this.thumb});

  factory RecipientContact.fromJson(Map<String, dynamic> j) {
    Uint8List? thumb;
    final t = j['avatar_thumb'];
    if (t is String && t.isNotEmpty) {
      try {
        thumb = base64Decode(t);
      } catch (_) {
        thumb = null;
      }
    }
    return RecipientContact(
      id: j['recipient_id'].toString(),
      name: (j['name'] ?? '').toString(),
      maskedAccount: (j['masked_account'] ?? '').toString(),
      recent: j['recent'] == true,
      thumb: thumb,
    );
  }
}

/// រូបភាពអ្នកទទួល (thumbnail) — បង្ហាញប្រុង្បាប់ឈ្មោះស្របជាមួយរូបភាព
class RecipientThumb extends StatelessWidget {
  const RecipientThumb({super.key, this.bytes, this.name = '', this.size = 40});

  final Uint8List? bytes;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return ClipOval(
        child: Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: C.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
            color: C.accent,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.4),
      ),
    );
  }
}

class TransferScreen extends StatefulWidget {
  /// bankCode == null → ផ្ទេររវាងគណនី Aura Bank (P2P)
  /// មាន code → ផ្ទេរចេញក្រៅតាម rails នោះ (ACLEDA, WING, ...)
  final String? bankCode;
  final String heading;
  const TransferScreen({super.key, this.bankCode, this.heading = 'ផ្ទេរប្រាក់'});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final contact = TextEditingController();
  final name = TextEditingController();
  final account = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();

  late bool p2pMode = widget.bankCode == null;
  late String railCode = widget.bankCode ?? 'ABA';
  int? cardId;

  Map<String, dynamic>? found;
  String? lookupError;
  bool looking = false;
  bool sending = false;

  // key ស្ទួនសម្រាប់សំណើដូចគ្នា (បណ្ដាញដាច់ → retry មិនកាត់លុយពីរដង)
  String? _retrySig, _retryKey;

  final _flow = _TransferFlowHandle();

  BankRail? get rail {
    for (final b in bank.rails) {
      if (b.code == railCode) return b;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (p2pMode) {
      bank.ensureRecipients();
    } else {
      bank.ensureRails();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    contact.dispose(); name.dispose(); account.dispose();
    amount.dispose(); note.dispose();
    super.dispose();
  }

  void _clearForm() {
    if (p2pMode) {
      contact.clear();
      found = null;
    } else {
      name.clear(); account.clear();
    }
    amount.clear(); note.clear();
  }

  Future<void> _lookup() async {
    final q = contact.text.trim();
    if (q.length < 5) {
      setState(() => lookupError = 'សូមបញ្ចូលលេខទូរស័ព្ទ ឬអ៊ីមែលឲ្យពេញលេញ');
      return;
    }
    setState(() { looking = true; lookupError = null; });
    try {
      final r = await bank.lookupRecipient(q);
      if (!mounted) return;
      setState(() => found = r);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { found = null; lookupError = e.message; });
    } finally {
      if (mounted) setState(() => looking = false);
    }
  }

  Future<void> _pickRecipient() async {
    final r = await showModalBottomSheet<RecipientContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RecipientPickerSheet(),
    );
    if (r == null || !mounted) return;
    contact.clear();
    setState(() {
      lookupError = null;
      found = {
        'recipient_id': r.id,
        'name': r.name,
        'masked_account': r.maskedAccount,
        'avatar_thumb': r.thumb == null ? null : base64Encode(r.thumb!),
      };
    });
  }

  Future<void> submit() async {
    if (sending) return;
    final a = parseAmt(amount.text);
    final cid = cardId ?? (bank.cards.isEmpty ? 0 : bank.cards.first.id);
    if (cid == 0) {
      toast(context, 'គ្មានកាតសម្រាប់ផ្ទេរ', error: true); return;
    }
    if (a == null) {
      toast(context, 'សូមបញ្ចូលចំនួនទឹកប្រាក់', error: true); return;
    }

    String? recipientId;
    if (p2pMode) {
      if (found == null) await _lookup();
      if (found == null || !mounted) return;
      recipientId = found!['recipient_id'].toString();
    } else {
      if (account.text.trim().isEmpty) {
        toast(context, 'សូមបំពេញលេខគណនីអ្នកទទួល', error: true);
        return;
      }
    }

    final pin = await bank.pinForTransfer(context);
    if (pin == null || !mounted) return;

    final nt = note.text.trim();
    final sig = p2pMode
        ? 'p2p|$recipientId|$cid|$a|$nt'
        : 'rail|$railCode|${account.text.trim()}|${name.text.trim()}|$cid|$a|$nt';
    final key = (_retrySig == sig && _retryKey != null)
        ? _retryKey! : ApiService.newIdempotencyKey();

    setState(() => sending = true);
    final flowBank = p2pMode ? 'AURA' : railCode;
    final flowName = p2pMode
        ? ((found?['name']) ?? '').toString()
        : name.text.trim();
    _flow.open(context, bankCode: flowBank,
        recipientName: flowName, amount: a);
    try {
      final r = p2pMode
          ? await bank.transferP2P(recipientId: recipientId!, amount: a,
              cardId: cid, pin: pin, note: nt.isEmpty ? null : nt,
              idempotencyKey: key)
          : await bank.transferToRail(
              rail: rail ?? BankRail(code: railCode, name: railCode),
              recipientName: name.text.trim(),
              recipientAccount: account.text.trim(),
              amount: a, cardId: cid, pin: pin,
              note: nt.isEmpty ? null : nt, idempotencyKey: key);
      _retrySig = null; _retryKey = null;
      final ref = (r['transfer_ref'] ?? '').toString();
      var flowStatus = 'success';
      if (r['pending'] == true && ref.isNotEmpty) {
        final res = await _flow.awaitApproval(ref: ref);
        flowStatus = res?.status ?? 'holding';
        await bank.loadAll();
      } else {
        await _flow.complete();
      }
      if (!mounted) return;
      final rName = p2pMode
          ? ((found?['name']) ?? 'អ្នកទទួល').toString()
          : name.text.trim();
      _clearForm();
      final tx = r['transaction'];
      Navigator.of(context).push(flowReceiptRoute(ReceiptScreen(
          title: (tx is Map ? tx['title'] : null)?.toString() ?? 'ផ្ទេរប្រាក់',
          amount: a, recipient: rName.isEmpty ? null : rName,
          ref: ref.isEmpty ? null : ref,
          flowBankCode: flowBank,
          flowRecipient: rName.isEmpty ? null : rName,
          flowStatus: flowStatus,
          magicReveal: true)));
    } on ApiException catch (e) {
      _flow.close();
      if (e.code == 'TIMEOUT' || e.code == 'NETWORK') {
        _retrySig = sig; _retryKey = key;
      }
      if (mounted) {
        toast(context, e.message == 'Wrong PIN' ? 'PIN មិនត្រឹមត្រូវ' : e.message,
            error: true);
      }
    } catch (_) {
      _flow.close();
      if (mounted) toast(context, 'Network error', error: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (bank.cards.isEmpty) {
      return Scaffold(
        backgroundColor: C.bgDark,
        body: const Center(child: Text('គ្មានកាត', style: TextStyle(color: Colors.white))),
      );
    }

    final selectedCard = bank.cards.firstWhere((c) => c.id == (cardId ?? bank.cards.first.id),
        orElse: () => bank.cards.first);
    final bankName = widget.heading;

    return Scaffold(
      backgroundColor: C.bgDark,
      body: Column(
        children: [
          // Header - Beautiful Gradient Design
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF667EEA),
                  const Color(0xFF764BA2),
                  C.accent.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    // Top Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.account_balance, color: Color(0xFF667EEA), size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Text('ផ្ទេរប្រាក់', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Bank Name
                    Text(
                      bankName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ផ្ទេរទៅគណនី $bankName ណាមួយ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content - Modern Form Design
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                // Source Account Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.card,
                        context.card.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.savings_outlined, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('គណនីរបស់អ្នក', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.muted)),
                                const SizedBox(height: 4),
                                Text('Mobile Savings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.ink)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'សមតុល្យបច្ចុប្បន្ន',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.muted),
                            ),
                            Text(
                              '\$${selectedCard.balance.toStringAsFixed(2)} USD',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.accent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Recipient Account
                Text('គណនីអ្នកទទួល', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.ink)),
                const SizedBox(height: 10),
                NeuField(
                  controller: account,
                  label: 'ដាក់លេខគណនីទទួល',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 20),

                // Amount
                Text('ចំនួនទឹកប្រាក់', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.ink)),
                const SizedBox(height: 10),
                NeuField(
                  controller: amount,
                  label: 'ចំនួនប្រាក់ (\$)',
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 12, right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('\$', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),

                const SizedBox(height: 20),

                // Note
                Text('កំណត់ចំណាំ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.ink)),
                const SizedBox(height: 10),
                NeuField(
                  controller: note,
                  label: 'សម្គាល់ (មិនដាក់ក៏បាន)',
                  icon: Icons.notes_outlined,
                  maxLength: 60,
                ),

                const SizedBox(height: 32),

                // Transfer Button - Beautiful Gradient
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: sending ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(sending ? Icons.hourglass_empty : Icons.send_rounded, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          sending ? 'កំពុងផ្ទេរ...' : 'ផ្ទេរឥឡូវនេះ',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ប្រអប់ជ្រើសអ្នកទទួល — បញ្ជីឈ្មោះអ្នកប្រើទាំងអស់ + ស្វែងរក
class _RecipientPickerSheet extends StatefulWidget {
  const _RecipientPickerSheet();
  @override
  State<_RecipientPickerSheet> createState() => _RecipientPickerSheetState();
}

class _RecipientPickerSheetState extends State<_RecipientPickerSheet> {
  final search = TextEditingController();
  bool loading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!loading) setState(() => loading = true);
    await bank.ensureRecipients(force: true);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => sb(() {
        final q = query.trim().toLowerCase();
        final all = bank.recipients;
        final list = q.isEmpty
            ? all
            : all.where((r) => r.name.toLowerCase().contains(q)).toList();
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
              color: context.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(
                width: 44, height: 5,
                decoration: BoxDecoration(color: context.border,
                    borderRadius: BorderRadius.circular(3))),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(children: [
                  Expanded(
                      child: Text('ជ្រើសរើសអ្នកទទួល',
                          style: TextStyle(fontSize: 17,
                              fontWeight: FontWeight.w800, color: context.ink))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ])),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: NeuField(
                    controller: search,
                    label: 'ស្វែងរកតាមឈ្មោះ',
                    icon: Icons.search,
                    onChanged: (v) => setState(() => query = v))),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body(context, list, q)),
            const SizedBox(height: 8),
          ]),
        );
      });

  Widget _body(BuildContext context, List<RecipientContact> list, String q) {
    if (loading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return ListView(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
            child: Text(
                q.isEmpty ? 'មិនទាន់មានអ្នកប្រើផ្សេងទៀត' : 'រកមិនឃើញអ្នកទទួល',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.muted, fontSize: 13.5))),
        if (q.isEmpty)
          TextButton(onPressed: _refresh, child: const Text('ព្យាយាមម្ដងទៀត')),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: list.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.border, indent: 58),
      itemBuilder: (context, i) {
        final r = list[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, r),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Row(children: [
              RecipientThumb(bytes: r.thumb, name: r.name),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(r.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.ink,
                            fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(r.maskedAccount,
                        style: TextStyle(color: context.muted, fontSize: 12)),
                  ])),
              if (r.recent)
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: C.accentGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('ថ្មីៗ',
                        style: TextStyle(color: C.accentGreen,
                            fontSize: 10.5, fontWeight: FontWeight.w700))),
            ]),
          ),
        );
      },
    );
  }
}

// ============================================================================
//  ANALYTICS
// ============================================================================
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => sb(() {
        final cats = <String, double>{};
        for (final t in bank.txs.where((t) => t.isExpense)) {
          cats[t.category] = (cats[t.category] ?? 0) + t.amount;
        }
        final entries = cats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return Scaffold(
          appBar: AppBar(title: const Text('ស្ថិតិ')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  Expanded(child: _sumCard(context, 'ចំណូល', bank.income,
                      Icons.trending_up, C.accentGreen)),
                  const SizedBox(width: 12),
                  Expanded(child: _sumCard(context, 'ចំណាយ', bank.expense,
                      Icons.trending_down, C.accentRed)),
                ]),
                const SectionTitle('ចំណាយតាមប្រភេទ'),
                NeuBox(child: Column(children: [
                  for (final e in entries.take(6))
                    Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                      Container(width: 12, height: 12,
                          decoration: BoxDecoration(color: catColor(e.key),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.key, style: TextStyle(
                          color: context.ink, fontSize: 13))),
                      Text(money(e.value), style: TextStyle(
                          fontWeight: FontWeight.w700, color: context.ink,
                          fontSize: 12.5)),
                    ])),
                  if (entries.isEmpty)
                    Padding(padding: const EdgeInsets.all(20),
                        child: Text('មិនទាន់មានទិន្នន័យ',
                            style: TextStyle(color: context.muted))),
                ])),
                const SizedBox(height: 16),
                NeuButton(label: 'មើលប្រវត្តិ', icon: Icons.history,
                    onPressed: () => push(context, const HistoryScreen())),
              ]),
        );
      });

  Widget _sumCard(BuildContext context, String l, double v, IconData i,
          Color c) =>
      NeuBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(i, color: c, size: 18)),
            const SizedBox(height: 10),
            Text(l, style: TextStyle(color: context.muted, fontSize: 12)),
            Text(money(v), style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: context.ink)),
          ]));
}

// ============================================================================
//  SAVINGS
// ============================================================================
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  Future<void> _addGoal(BuildContext context) async {
    final n = TextEditingController();
    final t = TextEditingController();
    final ok = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(backgroundColor: ctx.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('បង្កើតគោលដៅ',
              style: TextStyle(color: ctx.ink, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            NeuField(controller: n, label: 'ឈ្មោះ'),
            const SizedBox(height: 12),
            NeuField(controller: t, label: 'គោលដៅ (\$)',
                keyboardType: TextInputType.number),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('បោះបង់', style: TextStyle(color: ctx.muted))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('បង្កើត',
                    style: TextStyle(color: C.accent,
                        fontWeight: FontWeight.w700))),
          ]));
    final target = parseAmt(t.text);
    if (ok == true && n.text.trim().isNotEmpty && target != null) {
      try { await bank.addGoal(n.text.trim(), target); }
      on ApiException catch (e) {
        if (context.mounted) toast(context, e.message, error: true);
      }
    }
  }

  Future<void> _deposit(BuildContext context, Goal g) async {
    if (bank.cards.isEmpty) return;
    final amt = TextEditingController();
    int cardId = bank.cards.first.id;
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('សន្សំ: ${g.name}', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w700, color: ctx.ink)),
              const SizedBox(height: 16),
              CardPicker(selectedId: cardId,
                  onChanged: (id) => setS(() => cardId = id)),
              const SizedBox(height: 12),
              NeuField(controller: amt, label: 'ទឹកប្រាក់ (\$)',
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true)),
              const SizedBox(height: 20),
              NeuButton(label: 'សន្សំ', icon: Icons.savings, onPressed: () {
                final a = parseAmt(amt.text);
                if (a == null) return;
                Navigator.pop(ctx, {'a': a, 'c': cardId});
              }),
            ]),
          ),
        ),
      ),
    );
    if (r != null && context.mounted) {
      final a = r['a'] as double;
      final cid = r['c'] as int;
      await confirmAndPay(context, title: 'សន្សំ: ${g.name}',
          category: 'សន្សំ', amount: a, cardId: cid, icon: Icons.savings,
          onSuccess: () async {
        try { await bank.depositGoal(g, a); } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('សន្សំ')),
        floatingActionButton: FloatingActionButton.extended(
            backgroundColor: C.abaRed, foregroundColor: Colors.white,
            onPressed: () => _addGoal(context),
            icon: const Icon(Icons.add), label: const Text('ថ្មី')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              NeuBox(radius: 18, padding: const EdgeInsets.all(22),
                  child: Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, children: [
                      Text('ការប្រាក់', style: TextStyle(color: context.muted,
                          fontSize: 12)),
                      const Text('6% / ឆ្នាំ', style: TextStyle(
                          color: C.accentGreen, fontSize: 26,
                          fontWeight: FontWeight.w800)),
                    ])),
                    Text(money(bank.goals.fold(0.0, (s, g) => s + g.saved)),
                        style: TextStyle(color: context.ink, fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ])),
              const SectionTitle('គោលដៅ'),
              for (final g in bank.goals)
                Padding(padding: const EdgeInsets.only(bottom: 14),
                    child: NeuBox(padding: const EdgeInsets.all(14), radius: 14,
                        onTap: () => _deposit(context, g),
                        child: Row(children: [
                          SizedBox(width: 58, height: 58,
                              child: Stack(alignment: Alignment.center, children: [
                            SizedBox(width: 58, height: 58,
                                child: CircularProgressIndicator(
                                    value: (g.saved / g.target).clamp(0.0, 1.0),
                                    strokeWidth: 5, color: g.color,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.10))),
                            Icon(g.icon, color: g.color, size: 22),
                          ])),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min, children: [
                            Text(g.name, style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14, color: context.ink)),
                            Text('${money(g.saved)} / ${money(g.target)}',
                                style: TextStyle(color: context.muted,
                                    fontSize: 12)),
                          ])),
                          Icon(Icons.add_circle, color: g.color, size: 26),
                        ]))),
            ]),
      ));
}

// ============================================================================
//  PROFILE
// ============================================================================
/// បង្រួមរូបទៅ 512px JPEG (សម្រាប់ upload) — ដំណើរការក្នុង isolate
Uint8List? _compressAvatar(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = (decoded.width > 512 || decoded.height > 512)
      ? img.copyResize(decoded,
          width: decoded.width >= decoded.height ? 512 : null,
          height: decoded.height > decoded.width ? 512 : null,
          interpolation: img.Interpolation.average)
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
}

/// Thumbnail 96px (កាត់ square ពីកណ្តាល) — បង្ហាញក្នុងបញ្ជីអ្នកទទួល
String? _avatarThumb(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final cropped = img.copyCrop(decoded,
      x: (decoded.width - side) ~/ 2,
      y: (decoded.height - side) ~/ 2,
      width: side, height: side);
  final resized = img.copyResize(cropped,
      width: 96, height: 96, interpolation: img.Interpolation.average);
  return base64Encode(img.encodeJpg(resized, quality: 60));
}

/// រូប Profile — បង្ហាញរូបដែលរក្សាទុក ឬ icon បើមិនទាន់មាន
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.radius = 46,
      this.showEditBadge = false, this.busy = false, this.onTap});

  final double radius;
  final bool showEditBadge;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: bank,
        builder: (context, _) {
          final bytes = bank.avatarBytes;
          return GestureDetector(
            onTap: onTap,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: C.abaRed, width: 2)),
                child: CircleAvatar(
                  radius: radius,
                  backgroundColor: context.card,
                  backgroundImage: bytes != null ? MemoryImage(bytes) : null,
                  child: bytes == null
                      ? Icon(Icons.person, size: radius * 1.05, color: C.accent)
                      : null,
                ),
              ),
              if (busy)
                Positioned.fill(
                  child: ClipOval(
                    child: ColoredBox(
                      color: Colors.black45,
                      child: Center(
                        child: SizedBox(
                          width: radius * .7,
                          height: radius * .7,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      ),
                    ),
                  ),
                )
              else if (showEditBadge)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                        color: C.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.photo_camera,
                        size: 15, color: Colors.white),
                  ),
                ),
            ]),
          );
        },
      );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
          source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      // resize + JPEG encode ខ្លួនឯង ព្រោះ picker មិនបង្រួមរូបលើគ្រប់ platform
      final compressed = await compute(
          _compressAvatar, Uint8List.fromList(bytes));
      if (compressed == null) {
        toast(context, 'មិនអាចអានរូបភាព', error: true);
        return;
      }
      if (compressed.length > 200 * 1024) {
        toast(context, 'រូបភាពធំពេក (អតិបរមា 200 KB)', error: true);
        return;
      }
      setState(() => _uploading = true);
      final thumb = await compute(_avatarThumb, Uint8List.fromList(bytes));
      await bank.updateAvatar(
          'data:image/jpeg;base64,${base64Encode(compressed)}',
          thumb: thumb == null ? null : 'data:image/jpeg;base64,$thumb');
      if (mounted) toast(context, 'បានរក្សាទុករូបភាព');
    } catch (e) {
      if (mounted) toast(context, 'មិនអាចរក្សាទុករូបភាព', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploading = true);
    try {
      await bank.updateAvatar(null);
      if (mounted) toast(context, 'បានលុបរូបភាព');
    } catch (e) {
      if (mounted) toast(context, 'មិនអាចលុបរូបភាព', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showAvatarSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: context.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(
                  width: 42, height: 4,
                  decoration: BoxDecoration(
                      color: ctx.muted.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 10),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: C.accent),
                  title: const Text('ជ្រើសរើសពីវិចិត្រសាល'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAvatar(ImageSource.gallery);
                  }),
              if (!kIsWeb)
                ListTile(
                    leading: const Icon(Icons.photo_camera_outlined,
                        color: C.accent),
                    title: const Text('ថតរូប'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAvatar(ImageSource.camera);
                    }),
              if (bank.userAvatar != null)
                ListTile(
                    leading: const Icon(Icons.delete_outline,
                        color: C.accentRed),
                    title: const Text('លុបរូបភាព'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _removeAvatar();
                    }),
              const SizedBox(height: 10),
            ])));
  }

  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('ព័ត៌មាន')),
        body: RefreshIndicator(
          color: C.accent,
          onRefresh: bank.refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(child: Column(children: [
                UserAvatar(
                    radius: 46, showEditBadge: true, busy: _uploading,
                    onTap: _uploading ? null : _showAvatarSheet),
                const SizedBox(height: 6),
                TextButton(
                    onPressed: _uploading ? null : _showAvatarSheet,
                    child: const Text('ប្តូររូបភាព',
                        style: TextStyle(color: C.accent, fontSize: 12.5))),
                Text(bank.userName.isEmpty ? 'អ្នកប្រើ' : bank.userName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: context.ink)),
                Text(bank.userEmail, style: TextStyle(color: context.muted,
                    fontSize: 12.5)),
              ])),
              const SizedBox(height: 24),
              NeuBox(inset: true, child: Column(children: [
                const InfoRow('ប្រភេទ', 'VIP'),
                InfoRow('ទូរស័ព្ទ',
                    bank.userPhone.isEmpty ? '—' : bank.userPhone),
                InfoRow('អ៊ីមែល', bank.userEmail),
              ])),
              const SectionTitle('ការកំណត់'),
              NeuBox(padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    SwitchListTile(value: context.isDark,
                        activeThumbColor: C.accent,
                        onChanged: (_) => bank.toggleTheme(),
                        secondary: const Icon(Icons.dark_mode_outlined,
                            color: C.accent),
                        title: const Text('Dark Mode')),
                    SwitchListTile(value: bank.biometric,
                        activeThumbColor: C.accent,
                        onChanged: bank.setBio,
                        secondary: const Icon(Icons.fingerprint,
                            color: C.accent),
                        title: const Text('ស្នាមម្រាមដៃ')),
                    SwitchListTile(value: bank.hideBalance,
                        activeThumbColor: C.accent,
                        onChanged: bank.setHide,
                        secondary: const Icon(Icons.visibility_off_outlined,
                            color: C.accent),
                        title: const Text('លាក់សមតុល្យ')),
                    ListTile(leading: const Icon(Icons.savings_outlined,
                        color: C.accent), title: const Text('ថវិកា'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => push(context, const BudgetsScreen())),
                    ListTile(leading: const Icon(Icons.notifications_outlined,
                        color: C.accent), title: const Text('ការរំលឹក'),
                        trailing: bank.reminders.where((r) => !r.paid).isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: C.accentRed,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                    '${bank.reminders.where((r) => !r.paid).length}',
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)))
                            : const Icon(Icons.chevron_right),
                        onTap: () => push(context, const RemindersScreen())),
                    ListTile(leading: const Icon(Icons.repeat, color: C.accent),
                        title: const Text('ស្វ័យប្រវត្តិ'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => push(context, const RecurringScreen())),
                    ListTile(leading: const Icon(Icons.emoji_events_outlined,
                        color: C.accent), title: const Text('សមិទ្ធផល'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            push(context, const AchievementsScreen())),
                    const ExtraProfileMenu(),
                    PremiumProfileMenu(),
                    ListTile(leading: const Icon(Icons.currency_exchange,
                        color: C.accent), title: const Text('រូបិយប័ណ្ណ'),
                        trailing: Text(
                            bank.currencyMode == 'USD' ? 'USD' : 'KHR',
                            style: const TextStyle(color: C.accent,
                                fontWeight: FontWeight.w700)),
                        onTap: () {
                          bank.setCurrency(bank.currencyMode == 'USD'
                              ? 'KHR' : 'USD');
                          toast(context, 'ប្តូរទៅ ${bank.currencyMode}');
                        }),
                  ])),
              const SizedBox(height: 24),
              NeuButton(label: 'ចាកចេញ', icon: Icons.logout,
                  accent: C.accentRed, onPressed: () async {
                final ok = await showDialog<bool>(context: context,
                    builder: (ctx) => AlertDialog(backgroundColor: ctx.card,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      title: Text('ចាកចេញ?', style: TextStyle(color: ctx.ink)),
                      content: Text('ត្រូវបញ្ចូល PIN ម្តងទៀត',
                          style: TextStyle(color: ctx.muted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false),
                            child: Text('បោះបង់',
                                style: TextStyle(color: ctx.muted))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('ចាកចេញ',
                                style: TextStyle(color: C.accentRed,
                                    fontWeight: FontWeight.w700))),
                      ]));
                if (ok == true && context.mounted) {
                  await bank.logout();
                  tabIndex.value = 0;
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const RegistrationScreen()),
                        (r) => false);
                  }
                }
              }),
            ]),
        ),
      ));
}

// ============================================================================
//  HISTORY
// ============================================================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  List<Tx> _results = [];
  bool _loading = false;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _results = bank.txs;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final r = await bank.searchTransactions(
        q: _searchCtrl.text.trim(),
        isExpense: _filter == 0 ? null : _filter == 2,
      );
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ប្រវត្តិ'), actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                try { await PdfService.exportStatement(); }
                catch (e) {
                  if (context.mounted) {
                    toast(context, 'PDF error', error: true);
                  }
                }
              }),
        ]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NeuField(controller: _searchCtrl,
                  label: 'ស្វែងរក...', icon: Icons.search,
                  onChanged: (_) => _search())),
          SizedBox(height: 40, child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final e in ['ទាំងអស់', 'ចំណូល', 'ចំណាយ'].asMap().entries)
                  Padding(padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: Text(e.value,
                              style: const TextStyle(fontSize: 12)),
                          selected: _filter == e.key,
                          onSelected: (_) {
                            setState(() => _filter = e.key);
                            _search();
                          })),
              ])),
          Expanded(
            child: RefreshIndicator(
              color: C.accent,
              onRefresh: () async {
                await bank.refreshAll();
                await _search();
              },
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: C.accent))
                  : _results.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 180),
                            Center(child: Text('រកមិនឃើញ',
                                style: TextStyle(color: context.muted))),
                          ])
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          children: [
                            Padding(padding: const EdgeInsets.only(bottom: 10),
                                child: Text('${_results.length} ប្រតិបត្តិការ',
                                    style: TextStyle(fontSize: 12,
                                        color: context.muted,
                                        fontWeight: FontWeight.w600))),
                            for (final t in _results) TxTile(t),
                          ]),
            ),
          ),
        ]),
      );
}

// ============================================================================
//  NOTIFICATIONS
// ============================================================================
// ============================================================================
//  NOTIF BANK AVATAR  —  logo ធនាគារ + ផ្កាយ "រកឃើញដោយស្វ័យប្រវត្តិ"
// ============================================================================
class _NotifBankAvatar extends StatelessWidget {
  final String code;
  const _NotifBankAvatar({required this.code});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44, height: 44,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center,
            children: [
          BankLogo(code: code, size: 42),
          Positioned(
            right: -2, bottom: -2,
            child: Container(
              width: 17, height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [C.accentGold, Color(0xFFE0A93B)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: Colors.white, width: 1.4),
                boxShadow: [BoxShadow(
                    color: C.accentGold.withValues(alpha: 0.45),
                    blurRadius: 6)],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 9, color: Colors.white),
            ),
          ),
        ]),
      );
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _notifEnabled = true;

  @override
  void initState() {
    super.initState();
    // ផ្ទុកបញ្ជីធនាគារ → ស្គាល់ឈ្មោះក្នុងសារ ដើម្បីបង្ហាញ logo
    bank.ensureRails();
    _checkNotifPermission();
    Future.delayed(const Duration(milliseconds: 600), () async {
      try { await bank.markRead(); } catch (_) {}
    });
  }

  Future<void> _checkNotifPermission() async {
    if (kIsWeb) return;
    try {
      final s = await Permission.notification.status;
      if (mounted) setState(() => _notifEnabled = s.isGranted);
    } catch (_) {}
  }

  Future<void> _enableNotif() async {
    try {
      final s = await Permission.notification.request();
      if (s.isGranted) {
        await _checkNotifPermission();
        NotificationService.showLocal('Aura Bank', 'ការជូនដំណឹងត្រូវបានបើកដំណើរការ ✅');
      } else {
        await openAppSettings();
      }
    } catch (_) {}
  }

  Widget _notifBlockedBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.accentGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.accentGold.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          const Icon(Icons.notifications_off_rounded, color: C.accentGold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ការជូនដំណឹងត្រូវបានបិទ — បើកវាដើម្បីទទួលដំណឹងរាល់ប្រតិបត្តិការ',
              style: TextStyle(fontSize: 12, color: context.ink),
            ),
          ),
          TextButton(
            onPressed: _enableNotif,
            child: const Text('បើក', style: TextStyle(color: C.accentGold)),
          ),
        ]),
      );
  void _openMessage(AppNotif n) {
    final amt = n.transferAmount;
    final reversed = n.isReversalNotice;
    if (amt == null) {
      if (reversed) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const _MissingMoneyScreen()));
      }
      return;
    }
    final outgoing = n.isTransferOut;
    final name = outgoing ? n.transferRecipient : n.transferSender;
    final action = name == null
        ? null
        : (outgoing ? 'បានផ្ទេរទៅ $name' : 'បានទទួលពី $name');
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => ReceiptScreen(
        title: n.title,
        amount: amt,
        ref: n.transferRef,
        when: n.time,
        appBarTitle: 'សារប្រតិបត្តិការ',
        actionText: reversed && action != null ? '$action · ដកវិញ' : action,
        bankCode: n.bankLogoCode,
        incoming: !outgoing,
        senderName: outgoing ? null : name,
        flowBankCode: reversed ? (n.bankLogoCode ?? 'AURA') : null,
        flowRecipient: reversed && outgoing ? name : null,
        flowStatus: reversed ? 'rejected' : 'success',
      ),
      transitionsBuilder: (_, a, __, c) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
          child: c),
    ));
  }

  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('ជូនដំណឹង')),
        body: Column(children: [
          if (!_notifEnabled) _notifBlockedBanner(),
          Expanded(
            child: RefreshIndicator(
          color: C.accent,
          onRefresh: bank.refreshAll,
          child: bank.notifs.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 180),
                    Center(child: Text('គ្មានសារ',
                        style: TextStyle(color: context.muted))),
                  ])
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: bank.notifs.length,
                  itemBuilder: (_, i) {
                    final n = bank.notifs[i];
                    final tappable = n.isTransferMessage;
                    final bankLogo = n.bankLogoCode;
                    return Padding(padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: tappable ? () => _openMessage(n) : null,
                            child: NeuBox(padding: const EdgeInsets.all(14), radius: 14,
                            child: Row(children: [
                              if (bankLogo == null)
                                Container(width: 42, height: 42,
                                    decoration: BoxDecoration(
                                        color: C.accent.withValues(alpha: 0.15),
                                        shape: BoxShape.circle),
                                    child: Icon(n.icon, color: C.accent, size: 20))
                              else
                                _NotifBankAvatar(code: bankLogo),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min, children: [
                                Text(n.title, style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: context.ink, fontSize: 13)),
                                Text(n.body, maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12,
                                    color: context.muted)),
                                Text(fmtTime(n.time), style: TextStyle(
                                    fontSize: 10.5, color: context.muted)),
                              ])),
                              if (!n.read) Container(width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                      color: C.accentRed,
                                      shape: BoxShape.circle)),
                              if (tappable) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded,
                                    size: 20, color: context.muted),
                              ],
                            ]))));
                  }),
            ),
          ),
        ]),
      ));
}

// ============================================================================
//  QR / KHQR  —  Full-screen ABA-style scanner + Receive tab
// ============================================================================
// ============================================================================
//  QrPayScreen — ទូទាត់តាម QR (full-screen, keypad)
// ============================================================================
/// suffix ក្នុង account ID (`012345678@abaa`) → ធនាគារ
const _qrBankSuffix = <String, String>{
  'aba': 'ABA', 'abaa': 'ABA',
  'acleda': 'ACLEDA', 'aclb': 'ACLEDA',
  'canadia': 'CANADIA', 'cana': 'CANADIA',
  'wing': 'WING', 'wingb': 'WING',
  'juntuor': 'JUNTUOR', 'jtrust': 'JUNTUOR',
  'lyf': 'LYF',
  'chipmong': 'CHIPMONG', 'cmb': 'CHIPMONG', 'cmpb': 'CHIPMONG',
  'sathapana': 'SATHAPANA', 'sathapanab': 'SATHAPANA', 'spn': 'SATHAPANA',
  'vattanac': 'VATTANAC', 'vattanacb': 'VATTANAC', 'vtb': 'VATTANAC',
  'cpb': 'CPB', 'cpbank': 'CPB', 'cambodiapostbank': 'CPB',
  'ppcbank': 'PPCBANK', 'ppcb': 'PPCBANK',
  'hattha': 'HATTHA', 'hatthab': 'HATTHA', 'htb': 'HATTHA',
  'maybank': 'MAYBANK', 'mbb': 'MAYBANK',
  'truemoney': 'TRUEMONEY', 'tmn': 'TRUEMONEY',
  'bakong': 'BAKONG', 'nbc': 'BAKONG',
};

/// TLV តូចៗក្នុង KHQR/EMVCo (tag 2 តួ + length 2 តួ + value)
class _TlvField {
  final String tag, value;
  const _TlvField(this.tag, this.value);
}

List<_TlvField> _emvTlv(String s) {
  final out = <_TlvField>[];
  var i = 0;
  while (i + 4 <= s.length) {
    final len = int.tryParse(s.substring(i + 2, i + 4));
    if (len == null) break;
    final start = i + 4;
    if (start + len > s.length) break;
    out.add(_TlvField(s.substring(i, i + 2), s.substring(start, start + len)));
    i = start + len;
  }
  return out;
}

String? _bankCodeFromAccount(String account) {
  final at = account.lastIndexOf('@');
  if (at < 0 || at == account.length - 1) return null;
  return _qrBankSuffix[account.substring(at + 1).toLowerCase()];
}

/// កំណត់ធនាគារពី QR ភ្លាមៗនៅលើទូរសព្ទ (មិនរង់ចាំ server) ដើម្បីបង្ហាញ logo
String? bankCodeFromQr(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (RegExp(r'^aurabank://', caseSensitive: false).hasMatch(t)) return 'AURA';
  if (t.startsWith('{')) {
    try {
      final j = jsonDecode(t);
      if (j is Map) {
        final b = (j['bank'] ?? j['bank_code'] ?? j['bankCode'] ?? '')
            .toString().trim().toUpperCase();
        if (b.isNotEmpty) return b;
      }
    } catch (_) {}
  }
  final uri = Uri.tryParse(t);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    final b = (uri.queryParameters['bank'] ??
            uri.queryParameters['bank_code'] ?? '')
        .trim().toUpperCase();
    if (b.isNotEmpty) return b;
  }
  // KHQR: ធនាគារស្ថិតក្នុង Bakong ID (sub-tag 00) ឬ account (01/02)
  if (t.startsWith('000201')) {
    for (final f in _emvTlv(t)) {
      final n = int.tryParse(f.tag) ?? 0;
      if (n < 26 || n > 51) continue;
      for (final s in _emvTlv(f.value)) {
        if (s.tag != '00' && s.tag != '01' && s.tag != '02') continue;
        final code = _bankCodeFromAccount(s.value);
        if (code != null) return code;
      }
    }
  }
  // យក suffix វែងមុន — `@aba` អាចជាប់លេខ TLV នៅខាងក្រោយ (`@aba0108…`)
  final lower = t.toLowerCase();
  final keys = _qrBankSuffix.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    if (lower.contains('@$k')) return _qrBankSuffix[k];
  }
  return null;
}

class QrPayScreen extends StatefulWidget {
  final String rawQr;
  const QrPayScreen({super.key, required this.rawQr});
  @override
  State<QrPayScreen> createState() => _QrPayScreenState();
}

class _QrPayScreenState extends State<QrPayScreen>
    with SingleTickerProviderStateMixin {
  final _acc = TextEditingController();
  String _amt = '';
  bool _obscure = false;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  String _name = '';
  String _bankName = '';
  String? _bankCode;
  late final String? _guessCode;
  String _recipientId = '';
  bool _external = false;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  int get _cardId => bank.cards.isEmpty ? 0 : bank.cards.first.id;

  double? get _value => parseAmt(_amt);

  final _flow = _TransferFlowHandle();

  @override
  void initState() {
    super.initState();
    _bankCode = _guessCode = bankCodeFromQr(widget.rawQr);
    _load();
  }

  @override
  void dispose() {
    _flow.dispose();
    _pulse.dispose();
    _acc.dispose();
    super.dispose();
  }

  /// កាមេរ៉ាបិទរួច → ទំព័រនេះបង្ហាញ skeleton ខណៈទាញព័ត៌មានអ្នកទទួលពី server
  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    final raw = widget.rawQr;
    final u = Uri.tryParse(raw);
    final token = (u != null && u.scheme == 'aurabank' && u.host == 'pay')
        ? u.queryParameters['token']
        : null;
    var name = '';
    var account = '';
    String? bankCode;
    var bankName = '';
    var recipientId = '';
    var external = false;
    double? preset;
    try {
      if (token != null && token.isNotEmpty) {
        final r = await ApiService.resolveQr(token);
        if (!mounted) return;
        recipientId = (r['recipient_id'] ?? '').toString();
        name = (r['name'] ?? 'អ្នកទទួល').toString();
        account = (r['masked_account'] ?? '').toString();
        preset = (r['amount'] as num?)?.toDouble();
        bankCode = 'AURA';
        bankName = 'Aura Bank';
      } else {
        final info = await ApiService.inspectExternalQr(raw);
        if (!mounted) return;
        external = true;
        var code = (info['bank_code'] ?? 'OTHER').toString().toUpperCase();
        // server មិនស្គាល់ធនាគារ → ប្រើការកំណត់ពី QR នៅលើទូរសព្ទ
        if (code == 'OTHER' && _guessCode != null) code = _guessCode;
        await bank.ensureRails();
        if (!mounted) return;
        if (bank.rails.isNotEmpty && !bank.rails.any((r) => r.code == code)) {
          code = bank.rails.first.code;
        }
        for (final r in bank.rails) {
          if (r.code == code) bankName = r.name;
        }
        if (bankName.isEmpty) {
          bankName = (info['bank_name'] ?? code).toString();
        }
        final n = (info['name'] ?? '').toString().trim();
        bankCode = code;
        name = n.isEmpty ? 'អ្នកទទួល' : n;
        account = (info['account'] ?? '').toString();
        preset = (info['amount'] as num?)?.toDouble();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e.message; });
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'មិនអាចភ្ជាប់ទៅ server បានទេ';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _external = external;
      _recipientId = recipientId;
      _bankCode = bankCode;
      _bankName = bankName;
      _name = name;
      _acc.text = account;
      _amt = preset == null ? '' : preset.toStringAsFixed(2);
      _loading = false;
    });
  }

  void _key(String k) {
    if (_submitting) return;
    setState(() {
      if (k == '⌫') {
        if (_amt.isNotEmpty) _amt = _amt.substring(0, _amt.length - 1);
        return;
      }
      if (k == '.') {
        if (_amt.contains('.')) return;
        _amt = _amt.isEmpty ? '0.' : '$_amt.';
        return;
      }
      if (_amt.contains('.')) {
        if (_amt.split('.').last.length >= 2) return;
      } else if (_amt.length >= 9) {
        return;
      }
      _amt = _amt == '0' ? k : _amt + k;
    });
  }

  Future<void> _pay() async {
    if (_submitting) return;
    final a = _value;
    if (a == null || a <= 0) {
      toast(context, 'សូមបញ្ចូលទឹកប្រាក់', error: true);
      return;
    }
    final acc = _acc.text.trim();
    if (acc.length < 3) {
      toast(context, 'សូមបញ្ចូលលេខគណនីអ្នកទទួល', error: true);
      return;
    }
    if (bank.cards.isEmpty) {
      toast(context, 'គ្មានគណនីសម្រាប់ទូទាត់', error: true);
      return;
    }
    if (_external) {
      await _payExternal(a, acc);
    } else {
      await _payAura(a);
    }
  }

  Future<void> _payAura(double amt) async {
    final pin = await bank.pinForTransfer(context);
    if (pin == null || !mounted) return;
    setState(() => _submitting = true);
    final cid = _cardId;
    _flow.open(context, bankCode: 'AURA', recipientName: _name, amount: amt);
    try {
      final r = await bank.transferP2P(
          recipientId: _recipientId, amount: amt, cardId: cid, pin: pin,
          idempotencyKey: ApiService.newIdempotencyKey());
      final ref = (r['transfer_ref'] ?? '').toString();
      var flowStatus = 'success';
      if (r['pending'] == true && ref.isNotEmpty) {
        final res = await _flow.awaitApproval(ref: ref);
        flowStatus = res?.status ?? 'holding';
        await bank.loadAll();
      } else {
        await _flow.complete();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(flowReceiptRoute(ReceiptScreen(
          title: 'ផ្ទេរប្រាក់', recipient: _name, amount: amt,
          ref: ref.isEmpty ? null : ref,
          flowBankCode: 'AURA', flowRecipient: _name,
          flowStatus: flowStatus,
          magicReveal: true)));
    } on ApiException catch (e) {
      _flow.close();
      if (!mounted) return;
      setState(() => _submitting = false);
      toast(context, e.message == 'Wrong PIN' ? 'PIN មិនត្រឹមត្រូវ' : e.message,
          error: true);
    } catch (_) {
      _flow.close();
      if (!mounted) return;
      setState(() => _submitting = false);
      toast(context, 'Network error', error: true);
    }
  }

  Future<void> _payExternal(double amt, String acc) async {
    final idem = ApiService.newIdempotencyKey();
    Future<Map<String, dynamic>> start() => ApiService.startExternalQr(
          bankCode: _bankCode ?? 'OTHER',
          account: acc,
          name: _name,
          amount: amt,
          cardId: _cardId,
          rawQr: widget.rawQr,
        );

    setState(() => _submitting = true);
    Map<String, dynamic> first;
    try {
      first = await start();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      toast(context, e.message, error: true);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      toast(context, 'Network error', error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _OtpSheet(
        initial: first,
        bankCode: _bankCode ?? 'OTHER',
        bankName: _bankName,
        recipient: _name,
        account: acc,
        amount: amt,
        resend: start,
        confirm: (requestId, otp) => ApiService.confirmExternalQr(
            requestId: requestId, otp: otp, idempotencyKey: idem),
      ),
    );
    if (result == null || !mounted) return;

    final flowBank = _bankCode ?? 'OTHER';
    setState(() => _submitting = true);
    final ref = (result['transfer_ref'] ?? '').toString();
    final pending = result['pending'] == true && ref.isNotEmpty;
    _flow.open(context, bankCode: flowBank, recipientName: _name, amount: amt);
    await bank.loadAll();
    var flowStatus = 'success';
    if (pending) {
      final res = await _flow.awaitApproval(ref: ref);
      flowStatus = res?.status ?? 'holding';
      await bank.loadAll();
    } else {
      await _flow.complete();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(flowReceiptRoute(ReceiptScreen(
        title: 'ផ្ទេរប្រាក់', recipient: _name, amount: amt,
        ref: ref.isEmpty ? null : ref,
        flowBankCode: flowBank, flowRecipient: _name,
        flowStatus: flowStatus,
        magicReveal: true)));
  }

  @override
  Widget build(BuildContext context) {
    final card = bank.cards.isEmpty ? null : bank.cards.first;
    final value = _value;
    final enabled = !_loading && _loadError == null && !_submitting &&
        value != null && value > 0;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ទូទាត់តាម QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('ទូទាត់តាម QR'),
                content: const Text(
                    'ព័ត៌មានអ្នកទទួលត្រូវបានផ្ទៀងផ្ទាត់ជាមួយ server រួចហើយ។ '
                    'សូមពិនិត្យឈ្មោះ និងទឹកប្រាក់មុនចុចទូទាត់។'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(_),
                      child: const Text('យល់ព្រម')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _loading
              ? _QrPaySkeleton(key: const ValueKey('skeleton'),
                  bankCode: _bankCode)
              : (_loadError != null
                  ? _errorView(context)
                  : _content(context, card, value, enabled)),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, BankCard? card, double? value,
      bool enabled) => Column(key: const ValueKey('content'), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(children: [
            _bankAvatar(context),
            const SizedBox(height: 8),
            Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: context.ink)),
            const SizedBox(height: 3),
            if (_acc.text.isEmpty)
              SizedBox(width: 230,
                  child: NeuField(controller: _acc,
                      label: 'លេខគណនីអ្នកទទួល',
                      icon: Icons.account_balance_wallet_outlined,
                      onChanged: (_) => setState(() {})))
            else
              Text(_external ? _acc.text : _masked(_acc.text),
                  style: TextStyle(fontSize: 12.5, letterSpacing: 0.4,
                      color: context.muted)),
            const SizedBox(height: 10),
            _payFrom(context, card),
          ]),
        ),
        const SizedBox(height: 10),
        _amountBox(context, value),
        const SizedBox(height: 8),
        Expanded(child: _keypad(context)),
        _payButton(context, enabled, value),
      ]);

  String _masked(String acc) {
    if (acc.length <= 4) return acc;
    return '${'•' * (acc.length - 4)}${acc.substring(acc.length - 4)}';
  }

  Widget _errorView(BuildContext context) => Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 74, height: 74,
                decoration: BoxDecoration(
                  color: C.accentRed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: C.accentRed, size: 34)),
            const SizedBox(height: 16),
            Text('មិនអាចទាញព័ត៌មាន QR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: context.ink)),
            const SizedBox(height: 6),
            Text(_loadError ?? '', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.5,
                    color: context.muted)),
            const SizedBox(height: 22),
            NeuButton(label: 'ព្យាយាមម្ដងទៀត', icon: Icons.refresh_rounded,
                onPressed: _load),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pop(context),
                child: Text('បិទ',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        color: context.muted))),
          ]),
        ),
      );

  Widget _bankAvatar(BuildContext context) => Container(
        width: 68, height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.card,
          shape: BoxShape.circle,
          border: Border.all(color: C.accent.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [BoxShadow(
              color: C.accent.withValues(alpha: 0.18),
              blurRadius: 20, offset: const Offset(0, 7))],
        ),
        child: ClipOval(
          child: _bankCode == null
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [C.accent, C.bgDark],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: const Icon(Icons.account_balance_rounded,
                      color: Colors.white, size: 28))
              : BankLogo(code: _bankCode!, size: 56),
        ),
      );

  Widget _payFrom(BuildContext context, BankCard? card) => Container(
        padding: const EdgeInsets.fromLTRB(12, 5, 4, 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            C.accent.withValues(alpha: 0.16),
            C.accentGold.withValues(alpha: 0.09),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: C.accent.withValues(alpha: 0.28), width: 1.2),
        ),
        child: Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [C.accent, C.bgDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 17)),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Text('សមតុល្យអាចប្រើប្រាស់',
                style: TextStyle(fontSize: 10.5, color: context.muted)),
            const SizedBox(height: 1),
            Text(_obscure
                    ? '••••••'
                    : (card == null ? '—' : money(card.balance)),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800,
                    color: context.ink)),
          ])),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'បង្ហាញ / បិទសមតុល្យ',
            icon: Icon(_obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 19, color: context.muted),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ]),
      );

  Widget _amountBox(BuildContext context, double? value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity, height: 86,
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: C.accent.withValues(alpha: 0.30), width: 1.5),
            boxShadow: [BoxShadow(
                color: C.accent.withValues(alpha: 0.10),
                blurRadius: 18, offset: const Offset(0, 8))],
          ),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              textBaseline: TextBaseline.alphabetic,
              crossAxisAlignment: CrossAxisAlignment.baseline, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1).animate(anim),
                    child: child)),
              child: Text(_amt.isEmpty ? '0' : _amt,
                  key: ValueKey<String>(_amt),
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                      color: value == null ? context.muted : context.ink)),
            ),
            const SizedBox(width: 6),
            Text('\$', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w700, color: context.muted)),
          ]),
        ),
      );

  Widget _keypad(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(children: [
        for (var r = 0; r < 4; r++) ...[
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < 3; c++)
                  Expanded(child: _keyBtn(context, keys[r * 3 + c])),
              ],
            ),
          ),
          if (r < 3) const SizedBox(height: 6),
        ],
      ]),
    );
  }

  Widget _keyBtn(BuildContext context, String k) => Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _key(k),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.border),
              ),
              child: k == '⌫'
                  ? Icon(Icons.backspace_outlined, size: 21, color: context.ink)
                  : Text(k, style: TextStyle(fontSize: 21,
                      fontWeight: FontWeight.w600, color: context.ink)),
            ),
          ),
        ),
      );

  Widget _payButton(BuildContext context, bool enabled, double? value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = enabled ? _pulse.value : 0.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: enabled
                    ? [Color.lerp(C.bgDark, C.accent, 0.45 * t)!, C.bgDark]
                    : [C.bgDark.withValues(alpha: 0.35),
                       C.bgDark.withValues(alpha: 0.35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: enabled
                  ? [BoxShadow(
                      color: C.accent.withValues(alpha: 0.18 + 0.22 * t),
                      blurRadius: 16 + 14 * t,
                      offset: const Offset(0, 8))]
                  : const [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: enabled ? _pay : null,
                child: Center(
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : const Text('ទូទាត់ឥឡូវ',
                          style: TextStyle(fontSize: 15.5,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
//  SKELETON  —  shimmer ខណៈទាញព័ត៌មាន QR
// ============================================================================
class _QrPaySkeleton extends StatefulWidget {
  final String? bankCode;
  const _QrPaySkeleton({super.key, this.bankCode});
  @override
  State<_QrPaySkeleton> createState() => _QrPaySkeletonState();
}

class _QrPaySkeletonState extends State<_QrPaySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.isDark
        ? const Color(0xFF0B2A42) : const Color(0xFFE4E9F0);
    final hi = context.isDark
        ? const Color(0xFF16435F) : const Color(0xFFF7F9FC);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Stack(children: [
        ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, hi, base],
            stops: const [0.15, 0.5, 0.85],
            transform: _SkeletonSlide(_c.value),
          ).createShader(bounds),
          child: child,
        ),
        // logo ធនាគារ បង្ហាញភ្លាមពេលស្កេន (ស្រួចលើស shimmer)
        if (widget.bankCode != null)
          Positioned(
            top: 8, left: 0, right: 0,
            child: Center(child: BankLogo(code: widget.bankCode!, size: 68)),
          ),
      ]),
      child: _layout(context, base),
    );
  }

  Widget _layout(BuildContext context, Color base) {
    Widget box(double? w, double h, {double r = 10}) => Container(
          width: w, height: h,
          decoration: BoxDecoration(
              color: base, borderRadius: BorderRadius.circular(r)),
        );

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(children: [
          Container(width: 68, height: 68,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
          const SizedBox(height: 12),
          box(150, 18, r: 9),
          const SizedBox(height: 8),
          box(110, 12, r: 6),
          const SizedBox(height: 14),
          box(double.infinity, 52, r: 14),
        ]),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: box(double.infinity, 86, r: 20),
      ),
      const SizedBox(height: 10),
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 6),
        child: Column(children: [
          for (var r = 0; r < 4; r++) ...[
            Expanded(child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: 12),
                  Expanded(child: box(double.infinity, double.infinity, r: 14)),
                ],
              ],
            )),
            if (r < 3) const SizedBox(height: 8),
          ],
        ]),
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: box(double.infinity, 56, r: 18),
      ),
    ]);
  }
}

class _SkeletonSlide extends GradientTransform {
  final double t;
  const _SkeletonSlide(this.t);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2.4 - 1.2), 0, 0);
}

// ============================================================================
//  BankLogo — Logo ពិតរបស់ធនាគារនីមួយៗ (asset) + fallback monogram
// ============================================================================
class BankLogo extends StatelessWidget {
  final String code;
  final double size;
  const BankLogo({super.key, required this.code, this.size = 48});

  static const _assets = <String, String>{
    'AURA': 'assets/icon/app_icon.png',
    'ABA': 'assets/banks/aba.png',
    'ACLEDA': 'assets/banks/acleda.png',
    'CANADIA': 'assets/banks/canadia.png',
    'WING': 'assets/banks/wing.png',
    'JUNTUOR': 'assets/banks/jtrust.png',
    'CHIPMONG': 'assets/banks/chipmong.png',
    'SATHAPANA': 'assets/banks/sathapana.png',
    'VATTANAC': 'assets/banks/vattanac.png',
    'CPB': 'assets/banks/cpb.png',
    'PPCBANK': 'assets/banks/ppcbank.png',
    'HATTHA': 'assets/banks/hattha.png',
    'TRUEMONEY': 'assets/banks/truemoney.png',
    'LYF': 'assets/banks/lyf.png',
    'MAYBANK': 'assets/banks/maybank.png',
    'BAKONG': 'assets/banks/bakong.png',
  };

  /// Asset របស់ធនាគារ (សម្រាប់រូបក្នុង notification ផងដែរ)
  static String? assetFor(String code) => _assets[code.trim().toUpperCase()];

  static const _fallbackColors = <String, List<Color>>{
    'OTHER': [Color(0xFF3B5BDB), Color(0xFF6C8CFF)],
  };

  @override
  Widget build(BuildContext context) {
    final key = code.trim().toUpperCase();
    final asset = _assets[key];
    if (asset != null) {
      return Container(
        width: size, height: size,
        padding: EdgeInsets.all(size * 0.09),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.26),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Image.asset(asset, fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => _monogram(key)),
      );
    }
    return _monogram(key);
  }

  Widget _monogram(String key) {
    final colors = _fallbackColors[key] ??
        const [Color(0xFF1E3A8A), Color(0xFF3B9AD9)];
    final label = key.length > 3 ? key.substring(0, 2) : key;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [BoxShadow(
            color: colors.last.withValues(alpha: 0.30),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      alignment: Alignment.center,
      child: key == 'OTHER'
          ? Icon(Icons.account_balance_rounded,
              color: Colors.white, size: size * 0.44)
          : Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: FittedBox(child: Text(label,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5))),
            ),
    );
  }
}

class _OtpSheet extends StatefulWidget {
  final Map<String, dynamic> initial;
  final String bankCode, bankName, recipient, account;
  final double amount;
  final Future<Map<String, dynamic>> Function() resend;
  final Future<Map<String, dynamic>> Function(int requestId, String otp) confirm;
  const _OtpSheet({required this.initial, required this.bankCode,
      required this.bankName, required this.recipient, required this.account,
      required this.amount, required this.resend, required this.confirm});
  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late int _requestId;
  late String _hint;
  late int _left;
  int _resendIn = 30;
  Timer? _timer;
  bool _busy = false, _resending = false;
  String? _error;
  String _code = '';

  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _apply(widget.initial);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 0 && _resendIn <= 0) return;
      setState(() {
        if (_left > 0) _left--;
        if (_resendIn > 0) _resendIn--;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _apply(Map<String, dynamic> r) {
    _requestId = int.tryParse('${r['request_id']}') ?? 0;
    _hint = (r['hint'] ?? '').toString();
    _left = int.tryParse('${r['expires_in']}') ?? 300;
    _resendIn = 30;
    _code = '';
    _ctrl.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blink.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _code.length != 6) return;
    if (_left <= 0) {
      setState(() => _error = 'OTP ផុតកំណត់ — សូមផ្ញើឡើងវិញ');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final r = await widget.confirm(_requestId, _code);
      if (!mounted) return;
      Navigator.pop(context, r);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
        if (e.code == 'WRONG_OTP') { _code = ''; _ctrl.clear(); }
      });
      _focus.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _error = 'Network error'; });
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendIn > 0) return;
    setState(() { _resending = true; _error = null; });
    try {
      final r = await widget.resend();
      if (!mounted) return;
      setState(() { _apply(r); _resending = false; });
      _focus.requestFocus();
      toast(context, 'បានផ្ញើលេខកូដ OTP ថ្មី');
    } on ApiException catch (e) {
      if (mounted) setState(() { _resending = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _resending = false; _error = 'Network error'; });
    }
  }

  String get _mmss {
    final m = (_left ~/ 60).toString().padLeft(2, '0');
    final s = (_left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final active = _code.length < 6;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20,
          MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                C.accent.withValues(alpha: 0.16),
                C.accentGold.withValues(alpha: 0.08),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: C.accent.withValues(alpha: 0.28), width: 1.2),
            ),
            child: Column(children: [
              Row(children: [
                BankLogo(code: widget.bankCode, size: 44),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.recipient, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800, color: context.ink)),
                  const SizedBox(height: 2),
                  Text('${widget.bankName} · ${widget.account}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: context.muted)),
                ])),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(height: 1,
                    color: context.border.withValues(alpha: 0.6)),
              ),
              Row(children: [
                Text('ទឹកប្រាក់ត្រូវទូទាត់',
                    style: TextStyle(fontSize: 11.5, color: context.muted)),
                const Spacer(),
                Text(money(widget.amount),
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w900, color: C.accent)),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          Text('បញ្ចូលលេខកូដ OTP',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: context.ink)),
          const SizedBox(height: 4),
          Text('បានផ្ញើទៅ ${_hint.isEmpty ? 'ទូរស័ព្ទរបស់អ្នក' : _hint}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.muted)),
          const SizedBox(height: 16),
          _otpBoxes(context, active),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: context.border),
            ),
            child: Row(children: [
              Icon(Icons.timer_outlined, size: 16,
                  color: _left <= 60 ? C.accentRed : context.muted),
              const SizedBox(width: 6),
              Text(_left > 0 ? 'ផុតកំណត់ $_mmss' : 'OTP ផុតកំណត់',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _left <= 60 ? C.accentRed : context.muted)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: (_resendIn > 0 || _resending) ? null : _resend,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _resendIn > 0
                        ? Colors.transparent
                        : C.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_resending ? 'កំពុងផ្ញើ…'
                      : (_resendIn > 0 ? 'ផ្ញើឡើងវិញ ${_resendIn}s'
                          : 'ផ្ញើឡើងវិញ'),
                      style: TextStyle(fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _resendIn > 0 ? context.muted : C.accent)),
                ),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline_rounded,
                  color: C.accentRed, size: 17),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!,
                  style: const TextStyle(fontSize: 12.5,
                      color: C.accentRed, height: 1.4))),
            ]),
          ],
          const SizedBox(height: 16),
          NeuButton(
              label: _busy ? 'កំពុងផ្ទៀងផ្ទាត់…' : 'ផ្ទៀងផ្ទាត់ និងទូទាត់',
              icon: Icons.verified_rounded,
              accent: C.accentGreen,
              onPressed: (_busy || _code.length != 6) ? null : _submit),
        ]),
      ),
    );
  }

  Widget _otpBoxes(BuildContext context, bool active) => GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(children: [
          Row(children: [
            for (int i = 0; i < 6; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: i < _code.length
                      ? LinearGradient(colors: [
                          C.accent.withValues(alpha: 0.18),
                          C.accent.withValues(alpha: 0.05),
                        ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: i < _code.length
                      ? null
                      : (context.isDark
                          ? Colors.black.withValues(alpha: 0.22) : context.bg),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: i == _code.length && active
                          ? C.accent
                          : (i < _code.length
                              ? C.accent.withValues(alpha: 0.55)
                              : context.border),
                      width: i == _code.length && active ? 1.8 : 1.2),
                  boxShadow: i == _code.length && active ? [BoxShadow(
                      color: C.accent.withValues(alpha: 0.22),
                      blurRadius: 14)] : null,
                ),
                child: i < _code.length
                    ? Text(_code[i], style: TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w800, color: context.ink))
                    : (i == _code.length && active
                        ? FadeTransition(
                            opacity: _blink,
                            child: Container(width: 2, height: 24,
                                decoration: BoxDecoration(
                                    color: C.accent,
                                    borderRadius: BorderRadius.circular(1))))
                        : const SizedBox.shrink()),
              )),
            ],
          ]),
          Positioned.fill(child: Opacity(
            opacity: 0.01,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              showCursor: false,
              enableInteractiveSelection: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (v) {
                setState(() { _code = v; _error = null; });
                if (v.length == 6) _submit();
              },
              decoration: const InputDecoration(
                  border: InputBorder.none, counterText: ''),
            ),
          )),
        ]),
      );
}

class QrScreen extends StatefulWidget {
  final bool startScan;
  const QrScreen({super.key, this.startScan = false});
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  late bool _scan = widget.startScan;
  final _amt = TextEditingController();
  MobileScannerController? _ctrl;
  bool _busy = false;
  bool _torchOn = false;

  /// ធនាគារក្នុងស្រុកដែលមាន logo — បង្ហាញក្រោមកាមេរ៉ា ២ ជួរ
  static const _scannerBanks = <String>[
    'ABA', 'ACLEDA', 'CANADIA', 'WING',
    'JUNTUOR', 'CHIPMONG', 'SATHAPANA', 'VATTANAC',
    'CPB', 'PPCBANK', 'HATTHA', 'TRUEMONEY',
    'LYF', 'MAYBANK', 'BAKONG',
  ];

  /// ធនាគារដែលទើបស្កេនឃើញ (បង្ហាញ logo មួយសន្ទុះមុនបើកទំព័រទូទាត់)
  String? _detectedBank;

  // QR របស់យើង = token ខ្លីអាយុពី Server (5 នាទី) ទើបក្លែង/ចម្លង uid មិនបាន
  String? _qrToken;
  bool _qrLoading = false;
  String? _qrError;
  Timer? _qrDebounce;
  Timer? _qrRenew;

  @override
  void initState() {
    super.initState();
    if (_scan) {
      _ctrl = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    } else {
      _generateQr();
    }
  }

  @override
  void dispose() {
    _qrDebounce?.cancel();
    _qrRenew?.cancel();
    _ctrl?.dispose();
    _amt.dispose();
    super.dispose();
  }

  Future<void> _generateQr() async {
    _qrRenew?.cancel();
    setState(() { _qrLoading = true; _qrError = null; });
    try {
      final r = await ApiService.createQr(amount: parseAmt(_amt.text));
      if (!mounted) return;
      setState(() { _qrToken = r['qr_token']?.toString(); _qrLoading = false; });
      _scheduleRenew();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _qrLoading = false; _qrError = e.message; });
      _scheduleRenew();
    } catch (_) {
      if (!mounted) return;
      setState(() { _qrLoading = false; _qrError = 'Network error'; });
      _scheduleRenew();
    }
  }

  /// Token មានអាយុ ៥ នាទី → បង្កើតថ្មីមុនផុតកំណត់ ដើម្បីអោយ QR ស្កេនបានជានិច្ច
  /// ខណៈអេក្រង់នេះនៅបើក (បើបង្កើតមិនបាន → ព្យាយាមម្តងទៀតក្នុង ៣០ វិនាទី)
  void _scheduleRenew() {
    _qrRenew?.cancel();
    final ok = _qrToken != null && _qrError == null;
    _qrRenew = Timer(ok ? const Duration(seconds: 240) : const Duration(seconds: 30), () {
      if (mounted && !_scan) _generateQr();
    });
  }

  /// កែចំនួន → បង្កើត token ថ្មីក្រោយ ៦០០ms (កុំសំណើ request ជាប់ៗគ្នា)
  void _onAmtChanged() {
    _qrDebounce?.cancel();
    setState(() {});
    _qrDebounce = Timer(const Duration(milliseconds: 600), _generateQr);
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  void _setScan(bool v) {
    if (v == _scan) return;
    setState(() {
      _scan = v;
      _torchOn = false;
      if (v) {
        _ctrl = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
        );
      } else {
        _ctrl?.dispose();
        _ctrl = null;
      }
    });
    if (v) {
      _qrRenew?.cancel();
    } else if (_qrToken == null && !_qrLoading) {
      _generateQr();
    } else {
      _scheduleRenew();
    }
  }

  void _stopCamera() {
    if (!mounted || _ctrl == null) return;
    final old = _ctrl;
    setState(() { _ctrl = null; _torchOn = false; });
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  /// បិទ: បើចូលមកជា full-screen route → pop; បើចូលពី tab ទទួលប្រាក់ → ត្រឡប់ទៅ tab នោះ
  void _close() {
    if (widget.startScan) {
      Navigator.of(context).maybePop();
    } else {
      _setScan(false);
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _ctrl?.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  String get _displayName =>
      bank.userName.isEmpty ? bank.userEmail : bank.userName;

  // QR payload: aurabank://pay?token=<token ដែល Server បង្កើត អាយុ ៥ នាទី>
  String get _payload => _qrToken == null
      ? ''
      : Uri(scheme: 'aurabank', host: 'pay',
          queryParameters: {'token': _qrToken!}).toString();

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_busy || cap.barcodes.isEmpty) return;
    final raw = cap.barcodes.first.rawValue;
    if (raw == null) return;
    _busy = true;
    // ធនាគារកំណត់បានភ្លាម → បង្ហាញ logo ក្នុង avatar មួយសន្ទុះ
    // មុនបិទកាមេរ៉ា ដើម្បីអោយអ្នកប្រើឃើញធនាគារនោះភ្លាមៗ
    final guessed = bankCodeFromQr(raw);
    if (guessed != null) {
      setState(() => _detectedBank = guessed);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
    }
    // ស្កេនបាន = បិទកាមេរ៉ា និងបិទទំព័រស្កេនភ្លាម → ទំព័រទូទាត់ (skeleton) ជំនួស
    _stopCamera();
    final route = PageRouteBuilder<Object?>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => QrPayScreen(rawQr: raw),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        child: child),
    );
    if (widget.startScan) {
      Navigator.of(context).pushReplacement(route);
      return;
    }
    _setScan(false);
    await Navigator.of(context).push(route);
    if (mounted) {
      setState(() => _detectedBank = null);
      _busy = false;
    }
  }

  String _bankNameFor(String code) {
    for (final r in bank.rails) {
      if (r.code == code) return r.name;
    }
    return code;
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) =>
      _scan ? _buildFullScreenScanner(context) : _buildReceiveScreen(context);

  // ══════════════════════════════════════════════════════════════════════════
  //  ①  RECEIVE — បង្ហាញ QR របស់ខ្លួន
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReceiveScreen(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('KHQR'),
          actions: [
            IconButton(
              tooltip: 'ស្កេនផ្ញើ',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => _setScan(true),
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          NeuBox(
            padding: const EdgeInsets.all(24), radius: 20,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: C.abaRed,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('KHQR',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2, fontSize: 12)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: _qrToken == null
                    ? SizedBox(
                        height: 220, width: 220,
                        child: Center(
                          child: _qrLoading
                              ? const CircularProgressIndicator(
                                  color: C.accent)
                              : Column(mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.qr_code_2, size: 60,
                                        color: Colors.black26),
                                    const SizedBox(height: 8),
                                    Text(_qrError ?? 'កំពុងត្រៀម QR…',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54)),
                                    if (!_qrLoading && _qrError != null)
                                      TextButton(
                                          onPressed: _generateQr,
                                          child: const Text('ព្យាយាមម្ដងទៀត')),
                                  ]),
                        ))
                    : QrImageView(
                        data: _payload,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
              ),
              const SizedBox(height: 16),
              Text(_displayName.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 14, color: context.ink)),
              if (parseAmt(_amt.text) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(money(parseAmt(_amt.text)!),
                      style: const TextStyle(color: C.accent,
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          NeuField(
            controller: _amt,
            label: 'ទឹកប្រាក់ (មិនបំពេញក៏បាន)',
            icon: Icons.attach_money,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _onAmtChanged(),
          ),
          const SizedBox(height: 10),
          Text('កូដ QR អាយុ ៥ នាទី ហើយកំណត់តែគណនីរបស់អ្នក',
              style: TextStyle(fontSize: 11.5, color: context.muted)),
          const SizedBox(height: 16),
          NeuButton(label: 'ចម្លងកូដ QR', icon: Icons.copy, onPressed: () {
            if (_payload.isEmpty) {
              toast(context, 'QR មិនទាន់ត្រៀម', error: true);
              return;
            }
            Clipboard.setData(ClipboardData(text: _payload));
            toast(context, 'បានចម្លង');
          }),
          const SizedBox(height: 10),
          NeuButton(label: 'បង្កើត QR ថ្មី', icon: Icons.refresh,
              onPressed: _qrLoading ? null : _generateQr),
          const SizedBox(height: 10),
          NeuButton(
            label: 'ស្កេនដើម្បីផ្ញើ',
            icon: Icons.qr_code_scanner,
            accent: C.abaRed,
            onPressed: () => _setScan(true),
          ),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  ②  SCANNER — កាមេរ៉ាពេញអេក្រង់ + overlay
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFullScreenScanner(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final side = math.min(box.maxWidth, box.maxHeight) * 0.70;
            return Stack(fit: StackFit.expand, children: [
              // ── កាមេរ៉ា ──
              if (_ctrl != null)
                MobileScanner(controller: _ctrl!, onDetect: _onDetect)
              else
                const _ScannerProcessingBackdrop(),

              // ── overlay ងងឹត + ជ្រុងស ──
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: QrScannerOverlayPainter()),
                ),
              ),

              // ── បន្ទាត់ស្កេនរត់ ──
              if (_ctrl != null)
                Center(
                  child: SizedBox(
                    width: side, height: side,
                    child: const IgnorePointer(child: _ScanLine()),
                  ),
                ),

              // ── avatar logo ធនាគារ ពេលស្កេនឃើញ ──
              if (_detectedBank != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _DetectedBankReveal(
                      key: ValueKey(_detectedBank),
                      code: _detectedBank!,
                      label: _bankNameFor(_detectedBank!),
                    ),
                  ),
                ),

              // ── Top bar: ABA · ខ្ញុំស្កេន · X ──
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ABA',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 22, fontWeight: FontWeight.w900,
                                  letterSpacing: 2)),
                          Container(
                            margin: const EdgeInsets.only(left: 2, top: 2),
                            width: 5, height: 9, color: C.abaRed,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Text('ខ្ញុំស្កេន',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _close,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              // ── ចំណុចកណ្ដាល៖ អនុសាសន៍ ──
              if (_detectedBank == null)
                Align(
                  alignment: const Alignment(0, 0.78),
                  child: Text(
                      _ctrl == null
                          ? 'កំពុងដំណើរការព័ត៌មាន QR…'
                          : 'តម្រង់កាមេរ៉ាទៅ QR របស់អ្នកទទួល',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5, fontWeight: FontWeight.w500)),
                ),
            ]);
          }),
        ),

        // ── បារខ្មៅខាងក្រោម ──
        _scannerBottomPanel(context),
      ]),
    );
  }

  Widget _scannerBottomPanel(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.black,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _scannerBtn(
                  icon: _torchOn
                      ? Icons.flashlight_on
                      : Icons.flashlight_off,
                  label: 'ពិល',
                  onTap: _toggleTorch,
                ),
                const SizedBox(width: 40),
                _scannerBtn(
                  icon: Icons.qr_code_2,
                  label: 'QR របស់ខ្ញុំ',
                  onTap: () => _setScan(false),
                ),
              ]),
              const SizedBox(height: 16),
              _bankStrip(),
            ]),
          ),
        ),
      );

  Widget _scannerBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );

  /// បន្ទះ logo ធនាគារ ២ ជួរ — កញ្ចក់ស្រាលលើផ្ទៃខ្មៅ
  Widget _bankStrip() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withValues(alpha: 0.11),
                Colors.white.withValues(alpha: 0.035)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _bankLogoRow([
            for (final c in _scannerBanks.sublist(0, 8)) BankLogo(code: c, size: 28),
          ]),
          const SizedBox(height: 7),
          _bankLogoRow([
            for (final c in _scannerBanks.sublist(8)) BankLogo(code: c, size: 28),
            const _SecuritySeal(),
          ]),
          const SizedBox(height: 9),
          Text('ធនាគារ និងកាបូបឌីជីថល · សុវត្ថិភាពខ្ពស់',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9.5, fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
        ]),
      );

  Widget _bankLogoRow(List<Widget> cells) => Row(children: [
        for (final w in cells) Expanded(child: Center(child: w)),
      ]);
}

// ============================================================================
//  QR SCANNER OVERLAY PAINTER  —  ងងឹតខាងក្រៅ + ជ្រុងស 4
// ============================================================================
class QrScannerOverlayPainter extends CustomPainter {
  final Color overlayColor;
  final Color cornerColor;
  final double borderRadius;

  const QrScannerOverlayPainter({
    this.overlayColor = const Color(0xB3000000),
    this.cornerColor = Colors.white,
    this.borderRadius = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.70;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // ១. ផ្ទៃងងឹត លើកលែងក្រឡាការេ
    final overlay = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rrect),
    );
    canvas.drawPath(overlay, Paint()..color = overlayColor);

    // ២. ជ្រុងស ៤
    final p = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final len = side * 0.16;
    final r = borderRadius;
    final l = rect.left, t = rect.top, rt = rect.right, b = rect.bottom;

    // top-left
    canvas.drawPath(
        Path()
          ..moveTo(l, t + len)
          ..lineTo(l, t + r)
          ..quadraticBezierTo(l, t, l + r, t)
          ..lineTo(l + len, t),
        p);
    // top-right
    canvas.drawPath(
        Path()
          ..moveTo(rt - len, t)
          ..lineTo(rt - r, t)
          ..quadraticBezierTo(rt, t, rt, t + r)
          ..lineTo(rt, t + len),
        p);
    // bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(rt, b - len)
          ..lineTo(rt, b - r)
          ..quadraticBezierTo(rt, b, rt - r, b)
          ..lineTo(rt - len, b),
        p);
    // bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(l + len, b)
          ..lineTo(l + r, b)
          ..quadraticBezierTo(l, b, l, b - r)
          ..lineTo(l, b - len),
        p);
  }

  @override
  bool shouldRepaint(covariant QrScannerOverlayPainter old) =>
      old.overlayColor != overlayColor ||
      old.cornerColor != cornerColor ||
      old.borderRadius != borderRadius;
}

// ============================================================================
//  SCAN LINE  —  បន្ទាត់ក្រហមរត់ឡើងចុះ
// ============================================================================
// ============================================================================
//  SCANNER PROCESSING BACKDROP  —  កាមេរ៉ាបិទ ពេលកំពុងដំណើរការ QR
// ============================================================================
class _ScannerProcessingBackdrop extends StatelessWidget {
  const _ScannerProcessingBackdrop();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF02243A), Color(0xFF033553), Color(0xFF02243A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: const Center(child: SizedBox(
          width: 34, height: 34,
          child: CircularProgressIndicator(
              strokeWidth: 2.6, color: Colors.white),
        )),
      );
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Align(
            alignment: Alignment(0, _c.value * 2 - 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    C.abaRed.withValues(alpha: 0.9),
                    Colors.transparent,
                  ]),
                  boxShadow: [
                    BoxShadow(
                      color: C.abaRed.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// ============================================================================
//  SECURITY SEAL  —  ត្រាសុវត្ថិភាពខ្ពស់ (ពន្លឺរត់ជុំវិញ)
// ============================================================================
class _SecuritySeal extends StatefulWidget {
  const _SecuritySeal();
  @override
  State<_SecuritySeal> createState() => _SecuritySealState();
}

class _SecuritySealState extends State<_SecuritySeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
          return SizedBox(
            width: 36, height: 36,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: const Size(36, 36),
                painter: _CometRingPainter(t, C.accentGold, width: 2.4),
              ),
              Container(
                width: 27, height: 27,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E5E86), Color(0xFF033553)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(
                      color: C.accentGold.withValues(alpha: 0.55), width: 1),
                  boxShadow: [BoxShadow(
                      color: C.accentGold.withValues(alpha: 0.20 + 0.25 * glow),
                      blurRadius: 10, spreadRadius: 1)],
                ),
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (r) => LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white,
                      Colors.white,
                      Colors.white.withValues(alpha: 0.45),
                    ],
                    stops: const [0.0, 0.38, 0.55, 1.0],
                    transform: _SkeletonSlide(t),
                  ).createShader(r),
                  child: const Icon(Icons.gpp_good_rounded, size: 15,
                      color: Colors.white),
                ),
              ),
            ]),
          );
        },
      );
}

// ============================================================================
//  DETECTED BANK REVEAL  —  magic reveal ពេលស្កេនឃើញធនាគារ
// ============================================================================
class _DetectedBankReveal extends StatefulWidget {
  final String code;
  final String label;
  const _DetectedBankReveal({super.key, required this.code, required this.label});
  @override
  State<_DetectedBankReveal> createState() => _DetectedBankRevealState();
}

class _DetectedBankRevealState extends State<_DetectedBankReveal>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 620))..forward();
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _in.dispose();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_in, _spin, _pulse]),
        builder: (_, __) {
          final inT = _in.value;
          final e = Curves.easeOutCubic.transform(inT);
          final pop = Curves.easeOutBack.transform(inT);
          final check = inT < 0.45
              ? 0.0
              : Curves.easeOutBack.transform((inT - 0.45) / 0.55);
          final spin = _spin.value;
          final beat = 0.5 + 0.5 * math.sin(_pulse.value * math.pi);
          return Container(
            color: const Color(0xFF021C2C).withValues(alpha: 0.72 * e),
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - e)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 190, height: 190,
                  child: Stack(alignment: Alignment.center, children: [
                    // ពន្លឺ halo ដកដង្ហើម
                    Opacity(
                      opacity: e,
                      child: Container(
                        width: 132 + 12 * beat,
                        height: 132 + 12 * beat,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            C.accentGold.withValues(alpha: 0.34),
                            C.accent.withValues(alpha: 0.10),
                            Colors.transparent,
                          ], stops: const [0.0, 0.55, 1.0]),
                        ),
                      ),
                    ),
                    // រង្វង់ពន្លឺរត់
                    Opacity(
                      opacity: e,
                      child: CustomPaint(
                        size: const Size(176, 176),
                        painter: _CometRingPainter(spin, C.accentGold, width: 3),
                      ),
                    ),
                    Opacity(
                      opacity: e * 0.5,
                      child: Container(
                        width: 176, height: 176,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1),
                        ),
                      ),
                    ),
                    // ផ្កាយតូចៗលេចធ្លោ
                    for (var i = 0; i < 6; i++)
                      Transform.rotate(
                        angle: spin * 2 * math.pi + i * math.pi / 3,
                        child: Transform.translate(
                          offset: const Offset(0, -88),
                          child: Opacity(
                            opacity: e *
                                (0.25 + 0.5 * ((_pulse.value + i / 6) % 1.0)),
                            child: Container(
                              width: i.isEven ? 3.5 : 2.5,
                              height: i.isEven ? 3.5 : 2.5,
                              decoration: const BoxDecoration(
                                  color: C.accentGold, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                      ),
                    // កាត logo + ពន្លឺរអិល + សញ្ញាធីក
                    Opacity(
                      opacity: e,
                      child: Transform.rotate(
                        angle: -0.10 * (1 - e),
                        child: Transform.scale(
                          scale: 0.55 + 0.45 * pop,
                          child: SizedBox(
                            width: 124, height: 124,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: Stack(children: [
                                    BankLogo(code: widget.code, size: 104),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Transform.translate(
                                          offset: Offset(-170 + 340 * e, 0),
                                          child: Transform.rotate(
                                            angle: 0.5,
                                            child: Center(
                                              child: Container(
                                                width: 46, height: 240,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.white.withValues(
                                                          alpha: 0.55),
                                                      Colors.transparent,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ),
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Transform.scale(
                                    scale: check,
                                    child: Container(
                                      width: 34, height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [C.accentGold,
                                              Color(0xFFE0A93B)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight),
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                        boxShadow: [BoxShadow(
                                            color: Colors.black.withValues(
                                                alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4))],
                                      ),
                                      child: const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 19),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: e,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - e)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_user_rounded,
                            size: 12, color: C.accentGold),
                        const SizedBox(width: 5),
                        Text('បានរកឃើញ QR ដោយសុវត្ថិភាព',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        },
      );
}

/// រង្វង់ comet — ពន្លឺមួយកំណាត់រត់ជុំវិញ
class _CometRingPainter extends CustomPainter {
  final double t;
  final Color color;
  final double width;
  const _CometRingPainter(this.t, this.color, {this.width = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.95),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.60, 0.74, 0.88, 0.93, 1.0],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(rect);
    canvas.drawCircle(rect.center, (size.shortestSide - width) / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _CometRingPainter old) =>
      old.t != t || old.color != color || old.width != width;
}

// ============================================================================
//  BUDGETS
// ============================================================================
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  @override
  void initState() {
    super.initState();
    bank.loadBudgets();
  }

  Future<void> _add() async {
    final amtCtrl = TextEditingController();
    String? selectedCat;
    final categories = ['ទិញទំនិញ', 'អាហារ', 'វិក្កយបត្រ',
      'ដឹកជញ្ជូន', 'កម្សាន្ត', 'កម្ចី', 'សន្សំ'];
    await showModalBottomSheet(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('បន្ថែមថវិកា', style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w700, color: ctx.ink)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in categories)
                ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 11)),
                    selected: selectedCat == c,
                    onSelected: (_) => setS(() => selectedCat = c)),
            ]),
            const SizedBox(height: 16),
            NeuField(controller: amtCtrl, label: 'ថវិកា (\$)',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true)),
            const SizedBox(height: 20),
            NeuButton(label: 'រក្សាទុក', icon: Icons.check, onPressed: () {
              final a = parseAmt(amtCtrl.text);
              if (selectedCat == null || a == null) {
                toast(ctx, 'សូមបំពេញ', error: true);
                return;
              }
              Navigator.pop(ctx);
              bank.addBudget(selectedCat!, a);
            }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('ថវិកា'),
            actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)]),
        body: bank.budgets.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: context.muted),
                  Text('មិនទាន់មានថវិកា',
                      style: TextStyle(fontSize: 16, color: context.muted)),
                  const SizedBox(height: 8),
                  NeuButton(label: 'បង្កើត', icon: Icons.add,
                      fullWidth: false, onPressed: _add),
                ]))
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final b in bank.budgets)
                  Padding(padding: const EdgeInsets.only(bottom: 14),
                      child: NeuBox(padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(width: 36, height: 36,
                                      decoration: BoxDecoration(
                                          color: catColor(b.category)
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle),
                                      child: Icon(Icons.category,
                                          color: catColor(b.category),
                                          size: 18)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(b.category, style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14, color: context.ink)),
                                        Text(
                                            b.overBudget
                                                ? 'លើស ${money(b.spent - b.amount)}'
                                                : 'នៅសល់ ${money(b.remaining)}',
                                            style: TextStyle(fontSize: 11,
                                                color: b.overBudget
                                                    ? C.accentRed
                                                    : C.accentGreen,
                                                fontWeight: FontWeight.w600)),
                                      ])),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: C.accentRed, size: 20),
                                      onPressed: () => bank.deleteBudget(b.id)),
                                ]),
                                const SizedBox(height: 12),
                                ClipRRect(borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                        value: b.percent, minHeight: 8,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.10),
                                        valueColor: AlwaysStoppedAnimation(
                                            b.overBudget
                                                ? C.accentRed : C.accent))),
                                const SizedBox(height: 8),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(money(b.spent), style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.ink)),
                                      Text(
                                          '${(b.percent * 100).toStringAsFixed(0)}% / ${money(b.amount)}',
                                          style: TextStyle(fontSize: 11,
                                              color: context.muted)),
                                    ]),
                              ]))),
              ]),
      ));
}

// ============================================================================
//  REMINDERS
// ============================================================================
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    bank.loadReminders();
  }

  Future<void> _add() async {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    DateTime due = DateTime.now().add(const Duration(days: 7));
    await showModalBottomSheet(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('បន្ថែមការរំលឹក', style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w700, color: ctx.ink)),
              const SizedBox(height: 16),
              NeuField(controller: titleCtrl, label: 'ចំណងជើង',
                  icon: Icons.title),
              const SizedBox(height: 12),
              NeuField(controller: amtCtrl, label: 'ចំនួន (\$)',
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(context: ctx,
                      initialDate: due, firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (p != null) setS(() => due = p);
                },
                child: NeuBox(inset: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Icon(Icons.calendar_today, size: 18, color: ctx.muted),
                      const SizedBox(width: 10),
                      Text('${due.day}/${due.month}/${due.year}',
                          style: TextStyle(color: ctx.ink, fontSize: 13)),
                    ])),
              ),
              const SizedBox(height: 20),
              NeuButton(label: 'រក្សាទុក', icon: Icons.check, onPressed: () {
                final a = parseAmt(amtCtrl.text);
                if (titleCtrl.text.trim().isEmpty || a == null) {
                  toast(ctx, 'សូមបំពេញ', error: true);
                  return;
                }
                Navigator.pop(ctx);
                bank.addReminder(titleCtrl.text.trim(), a, due);
              }),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('ការរំលឹក'),
            actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)]),
        body: bank.reminders.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: context.muted),
                  Text('មិនទាន់មាន', style: TextStyle(fontSize: 16,
                      color: context.muted)),
                  const SizedBox(height: 8),
                  NeuButton(label: 'បន្ថែម', icon: Icons.add,
                      fullWidth: false, onPressed: _add),
                ]))
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final r in bank.reminders)
                  Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: NeuBox(padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(width: 44, height: 44,
                                decoration: BoxDecoration(
                                    color: (r.paid ? C.accentGreen
                                        : r.isOverdue ? C.accentRed
                                        : r.isDueSoon ? C.accentGold
                                        : C.accent).withValues(alpha: 0.15),
                                    shape: BoxShape.circle),
                                child: Icon(r.paid ? Icons.check : r.icon,
                                    color: r.paid ? C.accentGreen
                                        : r.isOverdue ? C.accentRed
                                        : r.isDueSoon ? C.accentGold
                                        : C.accent, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min, children: [
                              Text(r.title, style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5, color: context.ink)),
                              Text(
                                  r.paid ? 'បានបង់'
                                      : r.isOverdue
                                          ? 'ហួស ${-r.daysLeft} ថ្ងៃ'
                                          : '${r.daysLeft} ថ្ងៃ',
                                  style: TextStyle(fontSize: 11,
                                      color: r.paid ? C.accentGreen
                                          : r.isOverdue ? C.accentRed
                                          : context.muted)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(money(r.amount), style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13, color: context.ink)),
                                  if (!r.paid)
                                    GestureDetector(
                                      onTap: () =>
                                          bank.toggleReminder(r.id, true),
                                      child: const Text('បង់',
                                          style: TextStyle(fontSize: 11,
                                              color: C.accentGreen,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                ]),
                            IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18,
                                    color: C.accentRed),
                                onPressed: () => bank.deleteReminder(r.id)),
                          ]))),
              ]),
      ));
}

// ============================================================================
//  RECURRING
// ============================================================================
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});
  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  @override
  void initState() {
    super.initState();
    bank.loadRecurring();
  }

  Future<void> _add() async {
    if (bank.cards.isEmpty) return;
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    DateTime next = DateTime.now().add(const Duration(days: 30));
    String frequency = 'monthly';
    int cardId = bank.cards.first.id;
    await showModalBottomSheet(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ស្វ័យប្រវត្តិ', style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w700, color: ctx.ink)),
              const SizedBox(height: 16),
              NeuField(controller: titleCtrl, label: 'ចំណងជើង',
                  icon: Icons.title),
              const SizedBox(height: 12),
              NeuField(controller: amtCtrl, label: 'ចំនួន (\$)',
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final f in ['weekly', 'monthly', 'yearly'])
                  ChoiceChip(
                      label: Text(f, style: const TextStyle(fontSize: 11)),
                      selected: frequency == f,
                      onSelected: (_) => setS(() => frequency = f)),
              ]),
              const SizedBox(height: 12),
              CardPicker(selectedId: cardId,
                  onChanged: (id) => setS(() => cardId = id)),
              const SizedBox(height: 20),
              NeuButton(label: 'រក្សាទុក', icon: Icons.check, onPressed: () {
                final a = parseAmt(amtCtrl.text);
                if (titleCtrl.text.trim().isEmpty || a == null) {
                  toast(ctx, 'សូមបំពេញ', error: true);
                  return;
                }
                Navigator.pop(ctx);
                bank.addRecurring(title: titleCtrl.text.trim(), amount: a,
                    cardId: cardId, nextDate: next, frequency: frequency);
              }),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('ស្វ័យប្រវត្តិ'),
            actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)]),
        body: bank.recurring.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 64, color: context.muted),
                  Text('មិនទាន់មាន', style: TextStyle(fontSize: 15,
                      color: context.muted)),
                  const SizedBox(height: 8),
                  NeuButton(label: 'បង្កើត', icon: Icons.add,
                      fullWidth: false, onPressed: _add),
                ]))
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final r in bank.recurring)
                  Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: NeuBox(padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(width: 44, height: 44,
                                decoration: BoxDecoration(
                                    color: (r.active ? C.accent : context.muted)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle),
                                child: Icon(r.icon,
                                    color: r.active ? C.accent : context.muted,
                                    size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min, children: [
                              Text(r.title, style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5, color: context.ink)),
                              Text(
                                  '${r.frequency} • ${r.nextDate.day}/${r.nextDate.month}',
                                  style: TextStyle(fontSize: 11,
                                      color: context.muted)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(money(r.amount), style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13, color: context.ink)),
                                  Switch(value: r.active,
                                      activeThumbColor: C.accent,
                                      onChanged: (v) =>
                                          bank.toggleRecurring(r.id, v)),
                                ]),
                            IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18,
                                    color: C.accentRed),
                                onPressed: () => bank.deleteRecurring(r.id)),
                          ]))),
              ]),
      ));
}

// ============================================================================
//  ACHIEVEMENTS
// ============================================================================
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    bank.loadAchievements();
    bank.loadStreak();
  }

  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('សមិទ្ធផល')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          NeuBox(padding: const EdgeInsets.all(20), child: Row(children: [
            Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: C.accentGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: const Text('🔥', style: TextStyle(fontSize: 28))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ចូលប្រើ', style: TextStyle(fontSize: 12, color: context.muted)),
                  Text('${bank.streakDays} ថ្ងៃ', style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: context.ink)),
                  Text('សរុប ${bank.streakTotal}',
                      style: TextStyle(fontSize: 11, color: context.muted)),
                ])),
            NeuButton(label: 'ចុះហត្ថលេខា', icon: Icons.touch_app,
                fullWidth: false, height: 42, onPressed: () async {
              final isNew = await bank.checkInStreak();
              if (context.mounted) {
                toast(context, isNew ? 'បាន! 🎉' : 'រួចហើយ');
              }
            }),
          ])),
          const SectionTitle('សមិទ្ធផល'),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              for (final a in bank.achievements)
                NeuBox(padding: const EdgeInsets.all(14),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(a.icon, style: TextStyle(fontSize: 42,
                              color: a.unlocked ? null : Colors.grey)),
                          const SizedBox(height: 8),
                          Text(a.title, textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: a.unlocked
                                      ? context.ink : context.muted)),
                          Text(a.desc, textAlign: TextAlign.center,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10,
                                  color: context.muted)),
                          if (!a.unlocked)
                            Padding(padding: const EdgeInsets.only(top: 4),
                                child: Icon(Icons.lock, size: 14,
                                    color: context.muted)),
                        ])),
            ],
          ),
        ]),
      ));
}

// ============================================================================
//  GOOGLE AUTH SERVICE
// ============================================================================
class GoogleAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: '928292933131-6f82trqaubjp9hgeuvjckcd3m8ug84hq.apps.googleusercontent.com',
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null;
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await _auth.signOut();
  }
}

// ============================================================================
//  NOTIFICATION SERVICE (FCM)
// ============================================================================
class NotificationService {
  static const String channelId = 'bank_channel';
  static const String channelName = 'Aura Bank';
  static const String channelDesc = 'ការជូនដំណឹងប្រតិបត្តិការ Aura Bank';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _seq = 0;

  static AndroidNotificationDetails _details(
          AndroidBitmap<Object>? large, String body) =>
      AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.message,
        styleInformation: BigTextStyleInformation(body),
        largeIcon: large,
      );

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
    } catch (_) {}
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings settings =
          InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (_) => bank.syncIfChanged(),
      );
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ ត្រូវសុំ permission សម្រាប់ notification ក្នុង app
      await android?.requestNotificationsPermission();
      await _ensureChannel();
      _ready = true;
    } catch (e) {
      print('❌ Local notifications init failed: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n != null) {
        final title = n.title ?? 'Aura Bank';
        final body = n.body ?? '';
        showLocal(
          title,
          body,
          id: int.tryParse(message.data['notification_id']?.toString() ?? ''),
          bankCode: resolveBankCode(
            explicit: message.data['bank_code']?.toString(),
            title: title,
            body: body,
          ),
        );
      }
      // សារមកពី backend (admin) → ធ្វើបច្ចុប្បន្នភាពទិន្នន័យថ្មីភ្លាម
      bank.syncIfChanged();
    });

    // Token អាចប្តូរពេល app ធ្វើបច្ចុប្បន្នភាព → ផ្ញើទៅ backend ម្តងទៀត
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        try {
          await ApiService.registerFcmToken(token);
          print('✅ FCM token refreshed and registered');
        } catch (_) {}
      });
    } catch (_) {}
  }

  static Future<void> _ensureChannel() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  /// បង្ហាញ notification ក្នុងទូរស័ព្ទ (FCM ផ្ទាល់ ឬ polling fallback)
  /// bankCode → រូប Logo ធនាគារជា large icon ជំនួស Logo កម្មវិធី
  static Future<void> showLocal(String title, String body,
      {int? id, String? bankCode}) async {
    if (kIsWeb) return;
    try {
      if (!_ready) {
        await _ensureChannel();
        _ready = true;
      }
      AndroidBitmap<Object>? large;
      // AURA = Logo កម្មវិធីខ្លួនឯងរួចហើយ — មិនចាំបាច់ផ្ទុករូបធំជា icon
      final code = (bankCode ?? '').trim().toUpperCase();
      final asset = code == 'AURA' ? null : BankLogo.assetFor(code);
      if (asset != null) {
        try {
          final d = await rootBundle.load(asset);
          large = ByteArrayAndroidBitmap(
              d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
        } catch (_) {}
      }
      final notifId = id ??
          (DateTime.now().millisecondsSinceEpoch.remainder(1 << 30) + (_seq++));
      await _localNotifications.show(
        notifId,
        title,
        body,
        NotificationDetails(android: _details(large, body)),
      );
    } catch (e) {
      print('❌ showLocal failed: $e');
    }
  }

  static Future<void> registerTokenToBackend() async {
    if (kIsWeb) return;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          final short = token.length > 16 ? token.substring(0, 16) : token;
          print('✅ FCM Token sent: $short…');
          await ApiService.registerFcmToken(token);
          print('✅ FCM Token registered on backend');
          return;
        }
      } catch (e) {
        print('❌ Failed to send FCM token (try $attempt): $e');
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}