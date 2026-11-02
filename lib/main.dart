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

class Loan {
  final int id;
  final double principal;
  final int months;
  final double annualRate;
  final String province, district, commune, village;
  int paid;
  bool active;
  Loan({required this.id, required this.principal, required this.months,
      required this.annualRate, required this.paid, required this.active,
      this.province = '', this.district = '', this.commune = '',
      this.village = ''});
  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id: j['id'] as int,
        principal: (j['principal'] as num).toDouble(),
        months: j['months'] as int,
        annualRate: (j['annual_rate'] as num).toDouble(),
        paid: j['paid'] as int, active: j['active'] == 1,
        province: (j['province'] as String?) ?? '',
        district: (j['district'] as String?) ?? '',
        commune: (j['commune'] as String?) ?? '',
        village: (j['village'] as String?) ?? '',
      );
  String get address => [village, commune, district, province]
      .where((s) => s.isNotEmpty).join(' · ');
  double get monthly {
    final r = annualRate / 12 / 100;
    if (r == 0) return principal / months;
    return principal * r / (1 - math.pow(1 + r, -months));
  }
}

class AppNotif {
  final int id;
  final String title, body;
  final DateTime time;
  final IconData icon;
  bool read;
  AppNotif({required this.id, required this.title, required this.body,
      required this.time, required this.icon, required this.read});
  factory AppNotif.fromJson(Map<String, dynamic> j) => AppNotif(
        id: j['id'] as int, title: j['title'] as String,
        body: j['body'] as String,
        time: DateTime.parse(j['created_at'] as String).toLocal(),
        icon: AppIcons.get(j['icon_code'] as int? ?? 0),
        read: j['read'] == 1,
      );
}

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
  Loan? loan;
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
        loggedIn = true;
        await loadAll();
        await loadExtra();
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

  Future<void> updateAvatar(String? dataUrl) async {
    await ApiService.updateAvatar(dataUrl);
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
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception('Backend Error: ${e.message}');
    } catch (e) {
      throw Exception('Network Error: $e');
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    await GoogleAuthService.signOut();
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
    loan = null;
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
        ApiService.getLoan(),
      ]);
      cards = (r[0] as List).map((e) => BankCard.fromJson(e)).toList();
      txs = (r[1] as List).map((e) => Tx.fromJson(e)).toList();
      goals = (r[2] as List).map((e) => Goal.fromJson(e)).toList();
      notifs = (r[3] as List).map((e) => AppNotif.fromJson(e)).toList();
      final l = r[4] as Map<String, dynamic>?;
      loan = l != null ? Loan.fromJson(l) : null;
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

  Future<void> takeLoan({required double principal, required int months,
      required double rate, required String province, required String district,
      required String commune, required String village}) async {
    await ApiService.takeLoan(
        principal: principal, months: months, annualRate: rate,
        province: province, district: district, commune: commune,
        village: village);
    await loadAll();
  }
  Future<void> payLoan() async {
    await ApiService.payLoan();
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
    return ListenableBuilder(
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
    );
  }
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
  final bool obscure;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const NeuField({super.key, this.controller, this.label, this.icon,
      this.obscure = false, this.maxLength, this.keyboardType,
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
            prefixIcon: icon != null
                ? Icon(icon, color: context.muted, size: 20)
                : null,
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
  const AbaCell(this.icon, this.label, this.onTap);
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
                              Icon(items[idx].icon, color: iconCol, size: 40),
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
    final card = bank.cards.firstWhere((c) => c.id == cardId);
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) =>
          ReceiptScreen(title: title, amount: amount, card: card),
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

class ReceiptScreen extends StatelessWidget {
  final String title;
  final double amount;
  final BankCard card;
  const ReceiptScreen({super.key, required this.title,
      required this.amount, required this.card});

  @override
  Widget build(BuildContext context) {
    final ref = 'TXN${DateTime.now().millisecondsSinceEpoch % 1000000000}';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      C.accentGreen.withValues(alpha: 0.2),
                      C.accentGreen.withValues(alpha: 0.1),
                    ]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: C.accentGreen, size: 52),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('ប្រតិបត្តិការជោគជ័យ!', style: TextStyle(
                color: context.ink, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(money(amount), style: const TextStyle(color: C.accent,
                fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            NeuBox(inset: true, child: Column(children: [
              InfoRow('ប្រតិបត្តិការ', title),
              InfoRow('ពីកាត', '${card.name} • ${card.last4}'),
              InfoRow('លេខយោង', ref),
              InfoRow('កាលបរិច្ឆេទ', fmtTime(DateTime.now())),
            ])),
            const Spacer(),
            NeuButton(label: 'រួចរាល់', icon: Icons.done,
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
          ]),
        ),
      ),
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
    CardMenuScreen(),
    TransferMenuScreen(),
    AnalyticsScreen(),
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
    _Nav(Icons.credit_card_outlined, Icons.credit_card, 'កាត'),
    _Nav(Icons.swap_horiz_rounded, Icons.swap_horiz_rounded, 'ផ្ទេរ'),
    _Nav(Icons.insights_outlined, Icons.insights, 'ស្ថិតិ'),
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

void push(BuildContext c, Widget w) =>
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
                    AbaCell(Icons.credit_card, 'កាត',
                        () => tabIndex.value = 1),
                    AbaCell(Icons.monetization_on_outlined, 'ទូទាត់ប្រាក់',
                        () => _payBill(context, 'វិក្កយបត្រ', Icons.receipt_long)),
                    AbaCell(Icons.swap_horizontal_circle_outlined, 'ផ្ទេរប្រាក់',
                        () => tabIndex.value = 2),
                    AbaCell(Icons.qr_code_scanner, 'KHQR ស្កេន',
                        () => push(context, const QrScreen(startScan: true))),
                    AbaCell(Icons.savings_outlined, 'សន្សំ',
                        () => push(context, const SavingsScreen())),
                    AbaCell(Icons.request_quote_outlined, 'ប្រាក់កម្ចី',
                        () => push(context, const LoanScreen())),
                    AbaCell(Icons.pie_chart_outline, 'ថវិកា',
                        () => push(context, const BudgetsScreen())),
                    AbaCell(Icons.notifications_active_outlined, 'រំលឹក',
                        () => push(context, const RemindersScreen())),
                    AbaCell(Icons.apps_rounded, 'មីនីអេប',
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
        const SizedBox(width: 18),
        GestureDetector(
            onTap: () => tabIndex.value = 1,
            child: Icon(Icons.account_balance_wallet_outlined,
                color: col, size: 27)),
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
//  CARD MENU — ⚡ Optimized (ត្រូវតាមរូប: ប័ណ្ណឥណពន្ធប្លាស្ទិក / និម្មិត)
// ============================================================================
class CardMenuScreen extends StatelessWidget {
  const CardMenuScreen({super.key});

  static const _plasticColors = [Color(0xFF6366F1), Color(0xFF9333EA)];
  static const _virtualColors = [Color(0xFF22C55E), Color(0xFF10B981)];

  void _showInfo(BuildContext context) {
    HapticFeedback.selectionClick();
    showDialog(context: context, builder: (_) => const _CardInfoDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDark,
      body: Column(children: [
        const _CardHeader(),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                _CardOptionTile(
                  title: 'ប័ណ្ណឥណពន្ធប្លាស្ទិក',
                  subtitle:
                      'រាល់ប្រតិបត្តិការប័ណ្ណនេះ ត្រូវបានកាត់ទឹកប្រាក់ចេញពីគណនីរបស់ម្ចាស់ប័ណ្ណនៅធនាគារ អេស៊ីលីដា។',
                  colors: _plasticColors,
                  showCss: true,
                  onTap: () => _showInfo(context),
                ),
                const SizedBox(height: 16),
                _CardOptionTile(
                  title: 'ប័ណ្ណឥណពន្ធនិម្មិត',
                  subtitle:
                      'ប្រើសម្រាប់ទិញទំនិញតាមអនឡាញ ភ្ជាប់ការទូទាត់ និងប្រតិបត្តិការផ្សេងៗទៀត។',
                  colors: _virtualColors,
                  showCss: false,
                  onTap: () => _showInfo(context),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Header (const → មិន Rebuild) ──────────────────────────────────────────
class _CardHeader extends StatelessWidget {
  const _CardHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF12305A), Color(0xFF4A78B5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(children: [
            Row(children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => tabIndex.value = 0,
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0x33FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Text('ប័ណ្ណ',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.pets, color: C.accentGold, size: 28),
            ]),
            const SizedBox(height: 36),
            const Icon(Icons.credit_card_outlined,
                color: Colors.white, size: 120),
            const SizedBox(height: 28),
          ]),
        ),
      ),
    );
  }
}

// ── Card option tile ──────────────────────────────────────────────────────
class _CardOptionTile extends StatelessWidget {
  final String title, subtitle;
  final List<Color> colors;
  final bool showCss;
  final VoidCallback onTap;
  const _CardOptionTile({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.showCss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: context.card,
        elevation: context.isDark ? 0 : 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ខ្សែពណ៌ + pattern
              SizedBox(
                width: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: const RepaintBoundary(
                    child: CustomPaint(
                      painter: _DiamondPatternPainter(),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: context.ink)),
                      const SizedBox(height: 10),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 13, height: 1.5, color: context.muted)),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: context.border),
                      const SizedBox(height: 14),
                      Row(children: [
                        Flexible(child: _PaymentLogos(showCss: showCss)),
                        const SizedBox(width: 8),
                        const Text('បន្ថែមឥឡូវនេះ',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3B5BDB))),
                      ]),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Logos (const) ─────────────────────────────────────────────────────────
class _PaymentLogos extends StatelessWidget {
  final bool showCss;
  const _PaymentLogos({required this.showCss});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('VISA',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Color(0xFF1A237E))),
        const SizedBox(width: 10),
        const SizedBox(
          width: 24, height: 14,
          child: Stack(children: [
            Positioned(left: 0, child: _Dot(Color(0xFFEB001B))),
            Positioned(left: 9, child: _Dot(Color(0xCCF79E1B))),
          ]),
        ),
        const SizedBox(width: 10),
        _chip('JCB', const Color(0xFF0B7A3B), null),
        const SizedBox(width: 6),
        _chip('UnionPay', Colors.white, const Color(0xFFD32F2F)),
        if (showCss) ...[
          const SizedBox(width: 6),
          _chip('CSS', const Color(0xFF1A237E), null),
        ],
      ]),
    );
  }

  static Widget _chip(String t, Color fg, Color? bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3),
          border: bg == null
              ? Border.all(color: const Color(0xFFB0BEC5), width: 0.8)
              : null,
        ),
        child: Text(t,
            style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w800, color: fg)),
      );
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: 14, height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ── Pattern (គូរតែម្តង / 1 draw call) ───────────────────────────────────
class _DiamondPatternPainter extends CustomPainter {
  const _DiamondPatternPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x26FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const s = 16.0;
    final path = Path();
    for (double y = 0; y < size.height + s; y += s) {
      for (double x = 0; x < size.width + s; x += s) {
        path
          ..moveTo(x, y - s / 2)
          ..lineTo(x + s / 2, y)
          ..lineTo(x, y + s / 2)
          ..lineTo(x - s / 2, y)
          ..close();
      }
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Dialog (const) ────────────────────────────────────────────────────────
class _CardInfoDialog extends StatelessWidget {
  const _CardInfoDialog();
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFFF8F9FA),
            child: Text('i',
                style: TextStyle(
                    color: Color(0xFFC9A050),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif')),
          ),
          const SizedBox(height: 20),
          const Text(
            'សូមក្រៀប ឬបើកគណនីធនាគារ ជាមុន ដើម្បីបានប្រើប្រាស់សេវានេះ',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2A3D),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('យល់ព្រម',
                  style: TextStyle(
                      color: Color(0xFFC9A050),
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
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
                  _buildTransferItem(context, icon: Icons.account_balance_wallet, iconColor: const Color(0xFF1E3A8A), title: 'គណនីអេស៊ីលីដា | លេខទូរសព្ទ', subtitle: 'ផ្ទេរប្រាក់ទៅគណនីអេស៊ីលីដា | លេខទូរសព្ទ', onTap: () => push(context, const TransferScreen(bankCode: 'ACLEDA', heading: 'គណនីអេស៊ីលីដា'))),
                  _buildTransferItem(context, icon: Icons.account_balance, iconColor: const Color(0xFF9333EA), title: 'ផ្ទេរប្រាក់ក្នុងប្រទេស', subtitle: 'ផ្ទេរប្រាក់ទៅធនាគារ | MFIs | វ៉លឡេត', showChevron: true, onTap: () => push(context, const TransferScreen(bankCode: 'ABA', heading: 'ផ្ទេរក្នុងប្រទេស'))),
                  _buildTransferItem(context, icon: Icons.public, iconColor: const Color(0xFF0F766E), title: 'ផ្ទេរប្រាក់ទៅក្រៅប្រទេស', subtitle: 'ផ្ទេរប្រាក់ទៅធនាគារ | ភ្នាក់ងារផ្ទេរប្រាក់ពិភពលោក', showChevron: true, onTap: () => push(context, const TransferScreen(bankCode: 'OTHER', heading: 'ផ្ទេរក្រៅប្រទេស'))),
                  _buildTransferItem(context, icon: Icons.credit_card, iconColor: const Color(0xFFD946EF), title: 'ផ្ទេរប្រាក់ទៅប័ណ្ណ', subtitle: 'ផ្ទេរប្រាក់ទៅប័ណ្ណរបស់ធនាគារផ្សេង', showChevron: true, trailing: Row(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.circular(3)), child: const Text('VISA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))), const SizedBox(width: 4), Container(width: 16, height: 12, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3)), child: Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))))]), onTap: () => push(context, const TransferScreen(bankCode: 'CANADIA', heading: 'ផ្ទេរទៅប័ណ្ណ'))),
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
  const RecipientContact({required this.id, required this.name,
      required this.maskedAccount, this.recent = false});

  factory RecipientContact.fromJson(Map<String, dynamic> j) => RecipientContact(
      id: j['recipient_id'].toString(),
      name: (j['name'] ?? '').toString(),
      maskedAccount: (j['masked_account'] ?? '').toString(),
      recent: j['recent'] == true);
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
      if (name.text.trim().isEmpty || account.text.trim().isEmpty) {
        toast(context, 'សូមបំពេញឈ្មោះ និងលេខគណនីអ្នកទទួល', error: true);
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
      if (!mounted) return;
      _clearForm();
      final card = bank.cards.firstWhere((c) => c.id == cid,
          orElse: () => bank.cards.first);
      final tx = r['transaction'];
      Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => ReceiptScreen(
            title: (tx is Map ? tx['title'] : null)?.toString() ?? 'ផ្ទេរប្រាក់',
            amount: a, card: card),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    } on ApiException catch (e) {
      if (e.code == 'TIMEOUT' || e.code == 'NETWORK') {
        _retrySig = sig; _retryKey = key;
      }
      if (mounted) {
        toast(context, e.message == 'Wrong PIN' ? 'PIN មិនត្រឹមត្រូវ' : e.message,
            error: true);
      }
    } catch (_) {
      if (mounted) toast(context, 'Network error', error: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget _modeSwitch(BuildContext context) => Row(children: [
        for (final e in <String, bool>{'គណនី Aura Bank': true, 'ធនាគារ / MFI': false}.entries)
          Expanded(child: GestureDetector(
            onTap: () => setState(() {
              p2pMode = e.value;
              lookupError = null;
              if (p2pMode) {
                bank.ensureRecipients();
              } else {
                bank.ensureRails();
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: p2pMode == e.value ? C.accent : context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border)),
              child: Text(e.key, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: p2pMode == e.value
                          ? Colors.white : context.ink)),
            ),
          ))
      ]);

  Widget _recipientBlock(BuildContext context) {
    if (p2pMode) {
      if (found != null) {
        return NeuBox(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('អ្នកទទួល', style: TextStyle(color: context.muted,
              fontSize: 12)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(found!['name'].toString(),
                      style: TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 16, color: context.ink)),
                  const SizedBox(height: 2),
                  Text('${found!['masked_account']}',
                      style: TextStyle(color: context.muted, fontSize: 12.5)),
                ])),
            NeuButton(label: 'ប្ដូរ', icon: Icons.edit_outlined,
                fullWidth: false, height: 40,
                onPressed: () => setState(() => found = null)),
          ]),
        ]));
      }
      return Column(children: [
        NeuButton(
            label: 'ជ្រើសរើសអ្នកទទួល',
            icon: Icons.people_outline,
            onPressed: () => _pickRecipient()),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('ឬស្វែងរកតាមលេខទូរស័ព្ទ / អ៊ីមែល',
                  style: TextStyle(color: context.muted, fontSize: 11.5))),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 14),
        NeuField(controller: contact, label: 'លេខទូរស័ព្ទ ឬ អ៊ីមែលអ្នកទទួល',
            icon: Icons.person_search_outlined,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) { if (lookupError != null) setState(() => lookupError = null); }),
        const SizedBox(height: 12),
        NeuButton(
            label: looking ? 'កំពុងស្វែងរក…' : 'ពិនិត្យអ្នកទទួល',
            icon: Icons.search,
            onPressed: looking ? null : _lookup),
        if (lookupError != null) ...[
          const SizedBox(height: 10),
          Text(lookupError!, style: const TextStyle(
              color: C.accentRed, fontSize: 12.5)),
        ],
      ]);
    }

    final rails = bank.rails;
    return Column(children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final b in (rails.isEmpty
            ? [BankRail(code: railCode, name: railCode)]
            : rails))
          ChoiceChip(
              label: Text(b.name),
              selected: railCode == b.code,
              onSelected: (_) => setState(() => railCode = b.code)),
      ]),
      const SizedBox(height: 16),
      NeuField(controller: name, label: 'ឈ្មោះអ្នកទទួល',
          icon: Icons.person_outline),
      const SizedBox(height: 12),
      NeuField(controller: account, label: 'លេខគណនី ឬ លេខទូរស័ព្ទ',
          icon: Icons.account_balance_outlined,
          keyboardType: TextInputType.phone),
    ]);
  }

  Widget _feeHint(BuildContext context) {
    final a = parseAmt(amount.text);
    final r = rail;
    if (p2pMode || a == null) return const SizedBox.shrink();
    final fee = r?.feeFor(a) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'ថ្លៃសេវា ${money(fee)} · សរុបកាត់ ${money(a + fee)}'
        '${r == null ? ' · កំពុងផ្ទុកបញ្ជីធនាគារ…' : ''}',
        style: TextStyle(color: context.muted, fontSize: 12.5)),
    );
  }

  @override
  Widget build(BuildContext context) => sb(() {
        if (bank.cards.isEmpty) {
          return Scaffold(appBar: AppBar(title: const Text('ផ្ទេរ')),
              body: const Center(child: Text('គ្មានកាត')));
        }
        final sel = cardId ?? bank.cards.first.id;
        return Scaffold(
          appBar: AppBar(title: Text(widget.heading)),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _modeSwitch(context),
                const SizedBox(height: 18),
                Text('ផ្ទេរពីកាត', style: TextStyle(color: context.muted,
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                CardPicker(selectedId: sel,
                    onChanged: (id) => setState(() => cardId = id)),
                const SizedBox(height: 18),
                SectionTitle(p2pMode ? 'អ្នកទទួល' : 'គណនីគោលដៅ'),
                _recipientBlock(context),
                const SizedBox(height: 16),
                NeuField(controller: amount, label: 'ចំនួន (\$)',
                    icon: Icons.attach_money,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true)),
                const SizedBox(height: 12),
                NeuField(controller: note, label: 'សម្គាល់ (មិនបំពេញក៏បាន)',
                    icon: Icons.notes_outlined, maxLength: 60),
                _feeHint(context),
                const SizedBox(height: 24),
                NeuButton(
                    label: sending ? 'កំពុងផ្ទេរ…'
                        : (_retryKey != null ? 'ព្យាយាមម្ដងទៀត' : 'បញ្ជូន'),
                    icon: Icons.lock_outline,
                    onPressed: sending ? null : submit),
              ]),
        );
      });
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
              Container(
                  width: 40, height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: C.accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle),
                  child: Text(
                      r.name.isEmpty ? '?' : r.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: C.accent,
                          fontWeight: FontWeight.w800, fontSize: 16))),
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
//  LOAN
// ============================================================================
class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});
  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  double amount = 5000, months = 24, rate = 12;
  @override
  Widget build(BuildContext context) => sb(() {
        final r = rate / 12 / 100;
        final monthly = r == 0 ? amount / months
            : amount * r / (1 - math.pow(1 + r, -months.round()));
        final loan = bank.loan;
        return Scaffold(
          appBar: AppBar(title: const Text('កម្ចី')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (loan != null) ...[
                  NeuBox(radius: 18, padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, children: [
                        Text('កម្ចីកំពុងដំណើរការ',
                            style: TextStyle(color: context.muted, fontSize: 12)),
                        Text(money(loan.principal), style: TextStyle(
                            color: context.ink, fontSize: 28,
                            fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        ClipRRect(borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                                value: loan.paid / loan.months, minHeight: 10,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.10),
                                valueColor: const AlwaysStoppedAnimation(
                                    C.accent))),
                        const SizedBox(height: 10),
                        Text('បង់ ${loan.paid}/${loan.months} ខែ',
                            style: TextStyle(color: context.muted,
                                fontSize: 12)),
                        if (loan.address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(loan.address,
                              style: TextStyle(color: context.muted,
                                  fontSize: 11.5)),
                        ],
                        const SizedBox(height: 14),
                        NeuButton(label: 'បង់រំលោះ', icon: Icons.payment,
                            accent: C.accentGold, onPressed: () async {
                          try {
                            await bank.payLoan();
                            if (mounted) toast(context, 'បង់ជោគជ័យ');
                          } on ApiException catch (e) {
                            if (mounted) toast(context, e.message, error: true);
                          }
                        }),
                      ])),
                  const SizedBox(height: 8),
                ],
                const SectionTitle('ម៉ាស៊ីនគណនា'),
                NeuBox(child: Column(children: [
                  _slider(context, 'ចំនួន', money(amount), amount,
                      500, 50000, 99,
                      (v) => setState(() => amount = (v / 500).round() * 500.0)),
                  _slider(context, 'រយៈពេល', '${months.round()} ខែ', months,
                      6, 60, 54, (v) => setState(() => months = v)),
                  _slider(context, 'អត្រា', '${rate.toStringAsFixed(1)}%', rate,
                      6, 24, 36, (v) => setState(() => rate = v)),
                ])),
                const SizedBox(height: 14),
                NeuBox(inset: true, child: Column(children: [
                  Text('បង់ប្រចាំខែ', style: TextStyle(color: context.muted,
                      fontSize: 12)),
                  Text(money(monthly), style: const TextStyle(fontSize: 30,
                      fontWeight: FontWeight.w800, color: C.accent)),
                ])),
                const SizedBox(height: 20),
                NeuButton(label: loan != null ? 'មានកម្ចីរួច' : 'ស្នើសុំកម្ចី',
                    icon: Icons.request_quote,
                    onPressed: loan != null ? null : () => push(context,
                        LoanApplyScreen(initialAmount: amount,
                            initialMonths: months.round(),
                            initialRate: rate))),
              ]),
        );
      });

  Widget _slider(BuildContext context, String l, String v, double val,
          double min, double max, int div, ValueChanged<double> on) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l, style: TextStyle(color: context.muted, fontSize: 12.5)),
              Text(v, style: TextStyle(fontWeight: FontWeight.w700,
                  color: context.ink, fontSize: 13)),
            ]),
            Slider(value: val, min: min, max: max, divisions: div,
                activeColor: C.accent, onChanged: on),
          ]));
}

// ============================================================================
//  LOAN APPLICATION — ខេត្ត → ស្រុក → ឃុំ → ភូមិ → ទឹកប្រាក់
// ============================================================================
class _AdminProvince {
  final String code, name;
  final List<_AdminDistrict> districts;
  _AdminProvince(this.code, this.name, this.districts);
  factory _AdminProvince.fromJson(Map<String, dynamic> j) => _AdminProvince(
        j['c'] as String, j['n'] as String,
        [for (final d in j['d'] as List)
          _AdminDistrict.fromJson(Map<String, dynamic>.from(d as Map))]);
}

class _AdminDistrict {
  final String code, name;
  final List<_AdminCommune> communes;
  _AdminDistrict(this.code, this.name, this.communes);
  factory _AdminDistrict.fromJson(Map<String, dynamic> j) => _AdminDistrict(
        j['c'] as String, j['n'] as String,
        [for (final m in j['m'] as List)
          _AdminCommune.fromJson(Map<String, dynamic>.from(m as Map))]);
}

class _AdminCommune {
  final String code, name;
  final List<String> villages;
  _AdminCommune(this.code, this.name, this.villages);
  factory _AdminCommune.fromJson(Map<String, dynamic> j) => _AdminCommune(
      j['c'] as String, j['n'] as String,
      List<String>.from(j['v'] as List));
}

Future<List<_AdminProvince>> _loadAdminData() async {
  final raw = await rootBundle.loadString('assets/data/cambodia_admin.json');
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return [for (final p in j['p'] as List)
    _AdminProvince.fromJson(Map<String, dynamic>.from(p as Map))];
}

class LoanApplyScreen extends StatefulWidget {
  const LoanApplyScreen({super.key, this.initialAmount = 5000,
      this.initialMonths = 24, this.initialRate = 12});
  final double initialAmount;
  final int initialMonths;
  final double initialRate;
  @override
  State<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends State<LoanApplyScreen> {
  late Future<List<_AdminProvince>> _regions = _loadAdminData();
  int _step = 0;
  _AdminProvince? _province;
  _AdminDistrict? _district;
  _AdminCommune? _commune;
  String? _village;
  String _query = '';
  late double _amount = widget.initialAmount;
  late double _months = widget.initialMonths.toDouble();
  late double _rate = widget.initialRate;
  bool _submitting = false;

  static const _labels = ['ខេត្ត', 'ស្រុក', 'ឃុំ', 'ភូមិ', 'ទឹកប្រាក់'];

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _query = '';
      if (_step == 4) {
        _step = 3;
        _village = null;
      } else if (_step == 3) {
        _step = 2;
        _commune = null;
        _village = null;
      } else if (_step == 2) {
        _step = 1;
        _district = null;
        _commune = null;
        _village = null;
      } else {
        _step = 0;
        _province = null;
        _district = null;
        _commune = null;
        _village = null;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await bank.takeLoan(
          principal: _amount, months: _months.round(), rate: _rate,
          province: _province!.name, district: _district!.name,
          commune: _commune!.name, village: _village!);
      if (!mounted) return;
      toast(context, 'អនុម័ត!');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => sb(() => PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.arrow_back),
                  onPressed: _back),
              title: const Text('ស្នើសុំកម្ចី')),
          body: FutureBuilder<List<_AdminProvince>>(
            future: _regions,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('មិនអាចអានទិន្នន័យទីតាំង',
                      style: TextStyle(color: context.muted)),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: () => setState(
                          () => _regions = _loadAdminData()),
                      child: const Text('ព្យាយាមម្តងទៀត',
                          style: TextStyle(color: C.accent))),
                ]));
              }
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: C.accent));
              }
              return Column(children: [
                _progress(context),
                Expanded(child: _step < 4
                    ? _currentStep(snap.data!)
                    : _amountStep(context)),
              ]);
            },
          ),
        ),
      ));

  Widget _progress(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Column(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: (_step + 1) / 5,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation(C.accent))),
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                  child: Column(children: [
                Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= _step ? C.accent : Colors.transparent,
                        border: Border.all(
                            color: i <= _step ? C.accent : context.border)),
                    child: i < _step
                        ? const Icon(Icons.check, size: 13,
                            color: Colors.white)
                        : Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: i == _step
                                        ? Colors.white : context.muted)))),
                const SizedBox(height: 4),
                Text(_labels[i],
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            i == _step ? FontWeight.w700 : FontWeight.w400,
                        color: i <= _step ? context.ink : context.muted)),
              ])),
          ]),
        ]),
      );

  String get _path => [_province?.name, _district?.name, _commune?.name]
      .whereType<String>().join(' › ');

  Widget _currentStep(List<_AdminProvince> data) {
    switch (_step) {
      case 0:
        return _stepList(context, 'ជ្រើសរើសខេត្ត/ក្រុង',
            [for (final p in data) p.name],
            (i) => setState(() {
                  _province = data[i];
                  _step = 1;
                  _query = '';
                }));
      case 1:
        final list = _province!.districts;
        return _stepList(context, 'ជ្រើសរើសស្រុក/ខណ្ឌ',
            [for (final d in list) d.name],
            (i) => setState(() {
                  _district = list[i];
                  _step = 2;
                  _query = '';
                }));
      case 2:
        final list = _district!.communes;
        return _stepList(context, 'ជ្រើសរើសឃុំ/សង្កាត់',
            [for (final c in list) c.name],
            (i) => setState(() {
                  _commune = list[i];
                  _step = 3;
                  _query = '';
                }));
      default:
        final list = _commune!.villages;
        return _stepList(context, 'ជ្រើសរើសភូមិ', list,
            (i) => setState(() {
                  _village = list[i];
                  _step = 4;
                  _query = '';
                }));
    }
  }

  Widget _stepList(BuildContext context, String title, List<String> names,
      ValueChanged<int> onPick) {
    final q = _query.trim();
    final hits = [for (var i = 0; i < names.length; i++)
      if (q.isEmpty || names[i].contains(q)) i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.w800, color: context.ink)),
          const SizedBox(height: 3),
          Text(
              _path.isEmpty
                  ? 'ជំហាន ${_step + 1} ក្នុង 5'
                  : 'ជំហាន ${_step + 1} ក្នុង 5 · $_path',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.muted, fontSize: 11.5)),
          if (names.length > 4) ...[
            const SizedBox(height: 12),
            NeuField(key: ValueKey('search-$_step'), label: 'ស្វែងរក',
                icon: Icons.search, onChanged: (v) => setState(() => _query = v)),
          ],
        ]),
      ),
      Expanded(
          child: hits.isEmpty
              ? Center(child: Text('រកមិនឃើញ',
                  style: TextStyle(color: context.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: hits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, k) {
                    final name = names[hits[k]];
                    return NeuBox(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        onTap: () => onPick(hits[k]),
                        child: Row(children: [
                          Expanded(
                              child: Text(name,
                                  style: TextStyle(color: context.ink,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500))),
                          Icon(Icons.chevron_right, size: 18,
                              color: context.muted),
                        ]));
                  })),
    ]);
  }

  Widget _amountStep(BuildContext context) {
    final r = _rate / 12 / 100;
    final monthly = r == 0 ? _amount / _months
        : _amount * r / (1 - math.pow(1 + r, -_months.round()));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SectionTitle('ទីតាំងរបស់អ្នក'),
          NeuBox(inset: true, child: Column(children: [
            InfoRow('ខេត្ត/ក្រុង', _province!.name),
            InfoRow('ស្រុក/ខណ្ឌ', _district!.name),
            InfoRow('ឃុំ/សង្កាត់', _commune!.name),
            InfoRow('ភូមិ', _village!),
          ])),
          const SectionTitle('ចំនួនទឹកប្រាក់'),
          NeuBox(child: Column(children: [
            _slider(context, 'ចំនួន', money(_amount), _amount, 500, 50000, 99,
                (v) => setState(() => _amount = (v / 500).round() * 500.0)),
            _slider(context, 'រយៈពេល', '${_months.round()} ខែ', _months,
                6, 60, 54, (v) => setState(() => _months = v)),
            _slider(context, 'អត្រា', '${_rate.toStringAsFixed(1)}%', _rate,
                6, 24, 36, (v) => setState(() => _rate = v)),
          ])),
          const SizedBox(height: 14),
          NeuBox(inset: true, child: Column(children: [
            Text('បង់ប្រចាំខែ',
                style: TextStyle(color: context.muted, fontSize: 12)),
            Text(money(monthly), style: const TextStyle(fontSize: 30,
                fontWeight: FontWeight.w800, color: C.accent)),
          ])),
          const SizedBox(height: 20),
          NeuButton(
              label: _submitting ? 'កំពុងផ្ញើ...' : 'ផ្ញើសំណើ',
              icon: Icons.request_quote,
              onPressed: _submitting ? null : _submit),
        ]);
  }

  Widget _slider(BuildContext context, String l, String v, double val,
          double min, double max, int div, ValueChanged<double> on) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l, style: TextStyle(color: context.muted, fontSize: 12.5)),
              Text(v, style: TextStyle(fontWeight: FontWeight.w700,
                  color: context.ink, fontSize: 13)),
            ]),
            Slider(value: val, min: min, max: max, divisions: div,
                activeColor: C.accent, onChanged: on),
          ]));
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
      await bank.updateAvatar(
          'data:image/jpeg;base64,${base64Encode(compressed)}');
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
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: C.accent))
                : _results.isEmpty
                    ? Center(child: Text('រកមិនឃើញ',
                        style: TextStyle(color: context.muted)))
                    : ListView(
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
        ]),
      );
}

// ============================================================================
//  NOTIFICATIONS
// ============================================================================
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () async {
      try { await bank.markRead(); } catch (_) {}
    });
  }
  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('ជូនដំណឹង')),
        body: bank.notifs.isEmpty
            ? Center(child: Text('គ្មានសារ',
                style: TextStyle(color: context.muted)))
            : ListView.builder(padding: const EdgeInsets.all(16),
                itemCount: bank.notifs.length,
                itemBuilder: (_, i) {
                  final n = bank.notifs[i];
                  return Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: NeuBox(padding: const EdgeInsets.all(14), radius: 14,
                          child: Row(children: [
                            Container(width: 42, height: 42,
                                decoration: BoxDecoration(
                                    color: C.accent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle),
                                child: Icon(n.icon, color: C.accent, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min, children: [
                              Text(n.title, style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: context.ink, fontSize: 13)),
                              Text(n.body, style: TextStyle(fontSize: 12,
                                  color: context.muted)),
                              Text(fmtTime(n.time), style: TextStyle(
                                  fontSize: 10.5, color: context.muted)),
                            ])),
                            if (!n.read) Container(width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    color: C.accentRed,
                                    shape: BoxShape.circle)),
                          ])));
                }),
      ));
}

// ============================================================================
//  QR / KHQR  —  Full-screen ABA-style scanner + Receive tab
// ============================================================================
class _QrAmountSheet extends StatefulWidget {
  final String name;
  final String masked;
  final double? initialAmount;
  const _QrAmountSheet({
    required this.name, required this.masked, this.initialAmount,
  });
  @override
  State<_QrAmountSheet> createState() => _QrAmountSheetState();
}

class _QrAmountSheetState extends State<_QrAmountSheet> {
  late final TextEditingController _amt = TextEditingController(
      text: widget.initialAmount?.toStringAsFixed(2) ?? '');
  late int _cardId = bank.cards.first.id;

  @override
  void dispose() {
    _amt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20,
            MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ផ្ញើប្រាក់ទៅ',
                style: TextStyle(fontSize: 12.5, color: context.muted)),
            Text(widget.name, style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: context.ink)),
            if (widget.masked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(widget.masked,
                    style: TextStyle(fontSize: 12.5, color: context.muted)),
              ),
            const SizedBox(height: 16),
            NeuField(controller: _amt, label: 'ទឹកប្រាក់ (\$)',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true)),
            const SizedBox(height: 14),
            CardPicker(selectedId: _cardId,
                onChanged: (id) => setState(() => _cardId = id)),
            const SizedBox(height: 20),
            NeuButton(label: 'បន្ត', icon: Icons.send_rounded, onPressed: () {
              final a = parseAmt(_amt.text);
              if (a == null) {
                toast(context, 'សូមបញ្ចូលទឹកប្រាក់', error: true);
                return;
              }
              Navigator.pop(context, {'a': a, 'c': _cardId});
            }),
          ]),
        ),
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
    final u = Uri.tryParse(raw);
    final token = (u != null && u.scheme == 'aurabank' && u.host == 'pay')
        ? u.queryParameters['token']
        : null;
    if (token == null || token.isEmpty) {
      toast(context, 'QR នេះមិនត្រូវបានគាំទ្រ', error: true);
      Future.delayed(const Duration(seconds: 2), () => _busy = false);
      return;
    }
    try {
      // Server បក token → អ្នកទទួលពិតប្រាកដ (មិនជឿឈ្មោះ/uid ក្នុង QR)
      final r = await ApiService.resolveQr(token);
      if (!mounted) return;
      await _confirmSend(r);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Network error', error: true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _confirmSend(Map<String, dynamic> recipient) async {
    if (bank.cards.isEmpty) {
      toast(context, 'គ្មានកាត', error: true);
      return;
    }
    final name = (recipient['name'] ?? 'អ្នកទទួល').toString();
    final masked = (recipient['masked_account'] ?? '').toString();
    final preAmt = (recipient['amount'] as num?)?.toDouble();
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _QrAmountSheet(
          name: name, masked: masked, initialAmount: preAmt),
    );
    if (r == null || !mounted) return;

    final amt = r['a'] as double;
    final cid = r['c'] as int;
    final pin = await bank.pinForTransfer(context);
    if (pin == null || !mounted) return;
    try {
      await bank.transferP2P(
          recipientId: recipient['recipient_id'].toString(),
          amount: amt, cardId: cid, pin: pin,
          idempotencyKey: ApiService.newIdempotencyKey());
      if (!mounted) return;
      final card = bank.cards.firstWhere((c) => c.id == cid,
          orElse: () => bank.cards.first);
      Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => ReceiptScreen(
            title: 'ផ្ទេរទៅ $name (QR)', amount: amt, card: card),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        toast(context, e.message == 'Wrong PIN' ? 'PIN មិនត្រឹមត្រូវ' : e.message,
            error: true);
      }
    } catch (_) {
      if (mounted) toast(context, 'Network error', error: true);
    }
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
                MobileScanner(controller: _ctrl!, onDetect: _onDetect),

              // ── overlay ងងឹត + ជ្រុងស ──
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: QrScannerOverlayPainter()),
                ),
              ),

              // ── បន្ទាត់ស្កេនរត់ ──
              Center(
                child: SizedBox(
                  width: side, height: side,
                  child: const IgnorePointer(child: _ScanLine()),
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
              Align(
                alignment: const Alignment(0, 0.78),
                child: Text('តម្រង់កាមេរ៉ាទៅ QR របស់អ្នកទទួល',
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
              const SizedBox(height: 18),
              SizedBox(
                height: 26,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final l in const [
                      'eCASH', 'CASHin', 'PAY', 'KHQR', 'Wing',
                      'ABA', 'DuitNow', 'VietQR', 'VISA', 'Mastercard',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _logoBox(l),
                      ),
                  ],
                ),
              ),
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

  Widget _logoBox(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.black,
                fontSize: 9.5, fontWeight: FontWeight.w800,
                letterSpacing: 0.2)),
      );
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
          const SectionTitle('មេដាយ'),
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
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'bank_channel', 'Bank Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  static Future<void> registerTokenToBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print('✅ FCM Token sent: $token');
        await ApiService.registerFcmToken(token);
        print('✅ FCM Token registered on backend');
      }
    } catch (e) {
      print('❌ Failed to send FCM token: $e');
    }
  }
}