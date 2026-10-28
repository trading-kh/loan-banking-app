// ============================================================================
//  Loan & Banking App — Complete Clean Edition
// ============================================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'services/biometric_service.dart';
import 'services/pdf_service.dart';
import 'extra_features.dart';
import 'premium_features.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await premium.bootstrap();
  await bank.bootstrap();
  runApp(const BankApp());
}

// ============================================================================
//  PALETTE
// ============================================================================
class C {
  static const bgLight = Color(0xFFE0E5EC);
  static const darkShadowLight = Color(0xFFA3B1C6);
  static const lightShadowLight = Color(0xFFFFFFFF);
  static const bgDark = Color(0xFF1E2128);
  static const darkShadowDark = Color(0xFF0F1115);
  static const lightShadowDark = Color(0xFF2A2D34);
  static const accent = Color(0xFF5B6EF5);
  static const accentGreen = Color(0xFF2F855A);
  static const accentRed = Color(0xFFC53030);
  static const accentGold = Color(0xFFC05621);
  static const accentPurple = Color(0xFF6B46C1);
  static const accentTeal = Color(0xFF2C7A7B);

}

extension Ctx on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? C.bgDark : C.bgLight;
  Color get shadowDark => isDark ? C.darkShadowDark : C.darkShadowLight;
  Color get shadowLight => isDark ? C.lightShadowDark : C.lightShadowLight;
  Color get muted => isDark ? const Color(0xFF8B95A8) : const Color(0xFF6B7280);
  Color get ink => isDark ? const Color(0xFFEDF2F7) : const Color(0xFF2D3748);
}

// ============================================================================
//  THEME
// ============================================================================
ThemeData buildTheme(Brightness b, Color seed) {
  final dark = b == Brightness.dark;
  final bg = dark ? C.bgDark : C.bgLight;
  final ink = dark ? const Color(0xFFEDF2F7) : const Color(0xFF2D3748);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,          // ⬅️ ប្រើពណ៌ dynamic
      brightness: b,
      surface: bg,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      centerTitle: true,
      foregroundColor: ink,
      titleTextStyle: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: ink),
    ),
  );
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
    case 'អាហារ': return const Color(0xFFDD6B20);
    case 'វិក្កយបត្រ': return const Color(0xFFB7791F);
    case 'ដឹកជញ្ជូន': return C.accentTeal;
    case 'កម្សាន្ត': return const Color(0xFFB83280);
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
//  TOAST WIDGET
// ============================================================================
class _ToastWidget extends StatefulWidget {
  final String message;
  final bool error;
  final VoidCallback onDone;
  const _ToastWidget({
    required this.message, required this.error, required this.onDone,
  });
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: context.shadowLight,
                      offset: const Offset(-4, -4), blurRadius: 12),
                  BoxShadow(color: context.shadowDark,
                      offset: const Offset(4, 4), blurRadius: 12),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: context.bg, shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: context.shadowLight,
                          offset: const Offset(-2, -2), blurRadius: 4),
                      BoxShadow(color: context.shadowDark,
                          offset: const Offset(2, 2), blurRadius: 4),
                    ],
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
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration, curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(formatter(v), style: style),
    );
  }
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
  int paid;
  bool active;
  Loan({required this.id, required this.principal, required this.months,
      required this.annualRate, required this.paid, required this.active});
  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id: j['id'] as int,
        principal: (j['principal'] as num).toDouble(),
        months: j['months'] as int,
        annualRate: (j['annual_rate'] as num).toDouble(),
        paid: j['paid'] as int, active: j['active'] == 1,
      );
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
  ThemeMode themeMode = ThemeMode.light;
  bool hideBalance = false;
  bool biometric = true;
  bool loggedIn = false;
  int? userId;
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  String? _lastPin;

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
  int streakDays = 0;
  int streakTotal = 0;
  String currencyMode = 'USD';
  double khrRate = 4100;

  Future<void> bootstrap() async {
    await ApiService.loadToken();
    final savedEmail = await ApiService.getSavedEmail();
    if (savedEmail != null) userEmail = savedEmail;
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
  }

  Future<void> register({required String name, required String email,
      required String phone, required String pin}) async {
    final user = await ApiService.register(
        name: name, email: email, phone: phone, pin: pin);
    _applyUser(user);
    _lastPin = pin;
    loggedIn = true;
    await loadAll();
    await loadExtra();
  }

  Future<void> login(String email, String pin) async {
    final user = await ApiService.login(email: email, pin: pin);
    _applyUser(user);
    _lastPin = pin;
    loggedIn = true;
    await loadAll();
    await loadExtra();
    await processRecurringDue();
  }

  Future<void> logout() async {
    await ApiService.logout();
    loggedIn = false;
    userId = null;
    userName = '';
    userEmail = '';
    userPhone = '';
    cards = [];
    txs = [];
    goals = [];
    notifs = [];
    loan = null;
    _lastPin = null;
    budgets = [];
    reminders = [];
    recurring = [];
    achievements = [];
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
      required double rate}) async {
    await ApiService.takeLoan(
        principal: principal, months: months, annualRate: rate);
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
      listenable: Listenable.merge([bank, premium]),  // ⬅️ ស្តាប់ទាំង ២
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Loan & Banking',
        themeMode: bank.themeMode,
        theme: buildTheme(Brightness.light, premium.accent),      // ⬅️
        darkTheme: buildTheme(Brightness.dark, premium.accent),    // ⬅️
        home: const SplashScreen(),
      ),
    );
  }
}

// ============================================================================
//  WIDGETS
// ============================================================================
class NeuBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double radius;
  final bool inset;

  const NeuBox({super.key, required this.child,
      this.padding = const EdgeInsets.all(16), this.onTap,
      this.radius = 20, this.inset = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: inset
            ? [
                BoxShadow(color: context.shadowDark,
                    offset: const Offset(2, 2), blurRadius: 6),
                BoxShadow(color: context.shadowLight,
                    offset: const Offset(-2, -2), blurRadius: 6),
              ]
            : [
                BoxShadow(color: context.shadowLight,
                    offset: const Offset(-5, -5), blurRadius: 12),
                BoxShadow(color: context.shadowDark,
                    offset: const Offset(5, 5), blurRadius: 12),
              ],
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
      this.icon, this.accent, this.fullWidth = true, this.height = 52});

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? C.accent;
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: widget.height,
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: widget.fullWidth ? 0 : 22),
        decoration: BoxDecoration(
          color: context.bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _pressed
              ? [
                  BoxShadow(color: context.shadowDark,
                      offset: const Offset(2, 2), blurRadius: 6),
                  BoxShadow(color: context.shadowLight,
                      offset: const Offset(-2, -2), blurRadius: 6),
                ]
              : [
                  BoxShadow(color: context.shadowLight,
                      offset: const Offset(-4, -4), blurRadius: 10),
                  BoxShadow(color: context.shadowDark,
                      offset: const Offset(4, 4), blurRadius: 10),
                ],
        ),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: enabled ? accent : context.muted, size: 20),
              const SizedBox(width: 8),
            ],
            Text(widget.label, style: TextStyle(
                color: enabled ? accent : context.muted,
                fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
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
            color: context.bg, shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: context.shadowLight,
                  offset: const Offset(-3, -3), blurRadius: 8),
              BoxShadow(color: context.shadowDark,
                  offset: const Offset(3, 3), blurRadius: 8),
            ],
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
  Widget build(BuildContext context) => NeuBox(
        inset: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        radius: 14,
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          style: TextStyle(color: context.ink, fontSize: 14.5),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon != null ? Icon(icon, color: context.muted, size: 20) : null,
            suffixIcon: suffix,
            counterText: '',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
        padding: const EdgeInsets.only(top: 22, bottom: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w700, color: context.ink)),
          if (trailing != null) trailing!,
        ]),
      );
}

class InfoRow extends StatelessWidget {
  final String k, v;
  const InfoRow(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuBox(
        padding: const EdgeInsets.all(14),
        radius: 18,
        onTap: () => showTxDetail(context, tx),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: context.shadowDark,
                        offset: const Offset(2, 2), blurRadius: 4),
                    BoxShadow(color: context.shadowLight,
                        offset: const Offset(-2, -2), blurRadius: 4),
                  ]),
              child: Icon(tx.icon, color: catColor(tx.category), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 13.5, color: context.ink)),
            Text('${tx.category} • ${fmtTime(tx.time)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.muted, fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          Text('${tx.isExpense ? "-" : "+"}${money(tx.amount)}',
              style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 13.5, color: color)),
        ]),
      ),
    );
  }
}

void showTxDetail(BuildContext context, Tx tx) {
  showModalBottomSheet(
    context: context, backgroundColor: context.bg, showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64,
            decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: context.shadowLight,
                      offset: const Offset(-4, -4), blurRadius: 8),
                  BoxShadow(color: context.shadowDark,
                      offset: const Offset(4, 4), blurRadius: 8),
                ]),
            child: Icon(tx.icon, color: catColor(tx.category), size: 28)),
        const SizedBox(height: 16),
        Text(tx.title, style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.w700, color: context.ink)),
        const SizedBox(height: 6),
        Text('${tx.isExpense ? "-" : "+"}${money(tx.amount)}',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                color: tx.isExpense ? C.accentRed : C.accentGreen)),
        const SizedBox(height: 18),
        InfoRow('ប្រភេទ', tx.category),
        InfoRow('កាលបរិច្ឆេទ', fmtTime(tx.time)),
        InfoRow('ស្ថានភាព', 'ជោគជ័យ'),
      ]),
    ),
  );
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
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: context.shadowLight,
                  offset: const Offset(-4, -4), blurRadius: 12),
              BoxShadow(color: context.shadowDark,
                  offset: const Offset(4, 6), blurRadius: 16),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
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
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, children: [
                          Text('BANK', style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 9, fontWeight: FontWeight.w800,
                              letterSpacing: 3)),
                          Text(card.name, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ])),
                        const Icon(Icons.contactless,
                            color: Colors.white, size: 22),
                      ]),
                      Row(children: [
                        Container(width: 38, height: 28,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFFFFE08A), Color(0xFFE0A93B)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(child: CustomPaint(
                                size: const Size(24, 18),
                                painter: _ChipPainter()))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(revealed ? card.full : card.masked,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15, letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace'))),
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, children: [
                          Text('សមតុល្យ',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 9)),
                          Text(bank.hideBalance ? '••••' : money(card.balance),
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min, children: [
                          Text('VALID THRU',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 9)),
                          Text(card.expiry,
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                        ]),
                      ]),
                    ]),
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

  Widget _circle(double s, double o) => Container(width: s, height: s,
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
      paint.shader = gradient.createShader(Rect.fromLTWH(0, y - 20, size.width, 40));
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
                  color: sel ? null : context.bg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: sel
                      ? [BoxShadow(color: c.c1.withValues(alpha: 0.4),
                          blurRadius: 12, offset: const Offset(0, 4))]
                      : [
                          BoxShadow(color: context.shadowLight,
                              offset: const Offset(-3, -3), blurRadius: 6),
                          BoxShadow(color: context.shadowDark,
                              offset: const Offset(3, 3), blurRadius: 6),
                        ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, children: [
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : context.ink)),
                  Text(money(c.balance), style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : context.muted)),
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
              decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: context.shadowLight,
                        offset: const Offset(-3, -3), blurRadius: 8),
                    BoxShadow(color: context.shadowDark,
                        offset: const Offset(3, 3), blurRadius: 8),
                  ]),
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
                border: Border.all(color: context.shadowDark, width: 1.5)),
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
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56,
              decoration: BoxDecoration(color: ctx.bg, shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: ctx.shadowLight,
                        offset: const Offset(-3, -3), blurRadius: 6),
                    BoxShadow(color: ctx.shadowDark,
                        offset: const Offset(3, 3), blurRadius: 6),
                  ]),
              child: Icon(Icons.lock_outline, size: 24, color: ctx.ink)),
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
//  PAYMENT
// ============================================================================
Future<void> confirmAndPay(BuildContext context, {
  required String title, required String category,
  required double amount, required int cardId,
  required IconData icon, VoidCallback? onSuccess,
}) async {
  try {
    final pin = await askPin(context);
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
              builder: (_, v, __) => Transform.scale(scale: v,
                  child: Container(padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(color: context.bg,
                          shape: BoxShape.circle, boxShadow: [
                        BoxShadow(color: context.shadowLight,
                            offset: const Offset(-6, -6), blurRadius: 14),
                        BoxShadow(color: context.shadowDark,
                            offset: const Offset(6, 6), blurRadius: 14),
                      ]),
                      child: const Icon(Icons.check_rounded,
                          color: C.accentGreen, size: 52))),
            ),
            const SizedBox(height: 22),
            Text('ប្រតិបត្តិការជោគជ័យ!',
                style: TextStyle(color: context.ink, fontSize: 20,
                    fontWeight: FontWeight.w800)),
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
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) =>
            bank.loggedIn ? const LockScreen() : const RegistrationScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0),
                  child: Transform.scale(scale: v, child: child)),
              child: Container(padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: context.bg,
                      shape: BoxShape.circle, boxShadow: [
                    BoxShadow(color: context.shadowLight,
                        offset: const Offset(-8, -8), blurRadius: 16),
                    BoxShadow(color: context.shadowDark,
                        offset: const Offset(8, 8), blurRadius: 16),
                  ]),
                  child: const Icon(Icons.account_balance,
                      size: 56, color: C.accent)),
            ),
            const SizedBox(height: 30),
            Text('Loan & Banking', style: TextStyle(color: context.ink,
                fontSize: 26, fontWeight: FontWeight.w800)),
            Text('ធនាគារឌីជីថលសម្រាប់អ្នក',
                style: TextStyle(color: context.muted, fontSize: 13)),
            const SizedBox(height: 40),
            const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(color: C.accent, strokeWidth: 2.5)),
          ]),
        ),
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
    if (!agree) {
      toast(context, 'សូមយល់ព្រមលក្ខខណ្ឌ', error: true);
      return;
    }
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
                Center(child: Container(padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: context.bg,
                        shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: context.shadowLight,
                          offset: const Offset(-6, -6), blurRadius: 12),
                      BoxShadow(color: context.shadowDark,
                          offset: const Offset(6, 6), blurRadius: 12),
                    ]),
                    child: const Icon(Icons.account_balance,
                        size: 40, color: C.accent))),
                const SizedBox(height: 20),
                Text('បង្កើតគណនីថ្មី', textAlign: TextAlign.center,
                    style: TextStyle(color: context.ink, fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text('ចុះឈ្មោះដើម្បីចាប់ផ្តើមប្រើប្រាស់',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.muted, fontSize: 12.5)),
                const SizedBox(height: 24),
                NeuBox(padding: const EdgeInsets.all(20), radius: 22,
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
                                    .hasMatch(v.trim())
                                ? null : 'អ៊ីមែលមិនត្រឹមត្រូវ';
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
                            icon: Icon(ob1 ? Icons.visibility : Icons.visibility_off,
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
                            icon: Icon(ob2 ? Icons.visibility : Icons.visibility_off,
                                color: context.muted, size: 18),
                            onPressed: () => setState(() => ob2 = !ob2),
                          ),
                          validator: (v) =>
                              v != pin.text ? 'PIN មិនត្រូវគ្នា' : null),
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
                              child: CircularProgressIndicator(color: C.accent,
                                  strokeWidth: 2.5)))
                          : NeuButton(label: 'ចុះឈ្មោះ',
                              icon: Icons.person_add_alt, onPressed: _submit),
                    ])),
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
      if (ctx.mounted) toast(ctx, e.message == 'Wrong PIN'
          ? 'PIN មិនត្រឹមត្រូវ' : e.message, error: true);
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
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
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
              Container(padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle,
                      boxShadow: [
                    BoxShadow(color: context.shadowLight,
                        offset: const Offset(-6, -6), blurRadius: 12),
                    BoxShadow(color: context.shadowDark,
                        offset: const Offset(6, 6), blurRadius: 12),
                  ]),
                  child: CircleAvatar(radius: 42, backgroundColor: context.bg,
                      child: const Icon(Icons.person, color: C.accent, size: 44))),
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
//  MAIN SHELL
// ============================================================================
class MainShell extends StatelessWidget {
  const MainShell({super.key});
  @override
  Widget build(BuildContext context) {
    const screens = [HomeScreen(), CardsScreen(), TransferScreen(),
        AnalyticsScreen(), ProfileScreen()];
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (_, i, __) => Scaffold(
        body: IndexedStack(index: i, children: screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(color: context.bg, boxShadow: [
            BoxShadow(color: context.shadowLight,
                offset: const Offset(0, -4), blurRadius: 12),
            BoxShadow(color: context.shadowDark,
                offset: const Offset(0, -2), blurRadius: 8),
          ]),
          child: SafeArea(top: false, child: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (v) => tabIndex.value = v,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded), label: 'ដើម'),
              NavigationDestination(icon: Icon(Icons.credit_card_outlined),
                  selectedIcon: Icon(Icons.credit_card), label: 'កាត'),
              NavigationDestination(icon: Icon(Icons.swap_horiz_rounded),
                  selectedIcon: Icon(Icons.swap_horiz_rounded), label: 'ផ្ទេរ'),
              NavigationDestination(icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights), label: 'ស្ថិតិ'),
              NavigationDestination(icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded), label: 'ខ្ញុំ'),
            ],
          )),
        ),
      ),
    );
  }
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
                  const SizedBox(height: 20),
                  _hero(context),
                  SectionTitle('កាតធនាគាររបស់អ្នក',
                      trailing: TextButton(
                          onPressed: () => tabIndex.value = 1,
                          child: const Text('គ្រប់គ្រង',
                              style: TextStyle(color: C.accent,
                                  fontWeight: FontWeight.w700, fontSize: 13)))),
                  SizedBox(height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: bank.cards.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => SizedBox(
                          width: MediaQuery.of(context).size.width * 0.82,
                          child: BankCardWidget(card: bank.cards[i],
                              onTap: () => push(context,
                                  CardDetailScreen(cardId: bank.cards[i].id))),
                        ),
                      )),
                  const SectionTitle('សេវាកម្មរហ័ស'),
                  GridView.count(
                    crossAxisCount: 4, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.72,
                    mainAxisSpacing: 14, crossAxisSpacing: 10,
                    children: [
                      _svc(context, Icons.qr_code_scanner, 'KHQR',
                          C.accent, () => push(context, const QrScreen())),
                      _svc(context, Icons.people_alt_outlined, 'P2P',
                          C.accentPurple, () => tabIndex.value = 2),
                      _svc(context, Icons.savings_outlined, 'សន្សំ',
                          C.accentGreen,
                          () => push(context, const SavingsScreen())),
                      _svc(context, Icons.request_quote_outlined, 'កម្ចី',
                          C.accentGold, () => push(context, const LoanScreen())),
                      _svc(context, Icons.pie_chart_outline, 'ថវិកា',
                          C.accentTeal,
                          () => push(context, const BudgetsScreen())),
                      _svc(context, Icons.notifications_outlined, 'រំលឹក',
                          const Color(0xFFB7791F),
                          () => push(context, const RemindersScreen())),
                      _svc(context, Icons.repeat, 'ស្វ័យ',
                          C.accentPurple,
                          () => push(context, const RecurringScreen())),
                      _svc(context, Icons.emoji_events_outlined, 'មេដាយ',
                          const Color(0xFF4C51BF),
                          () => push(context, const AchievementsScreen())),
                    ],
                  ),
                  SectionTitle('ប្រតិបត្តិការចុងក្រោយ',
                      trailing: TextButton(
                          onPressed: () =>
                              push(context, const HistoryScreen()),
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

  Widget _header(BuildContext context) => Row(children: [
        Container(padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle,
                boxShadow: [
              BoxShadow(color: context.shadowLight,
                  offset: const Offset(-3, -3), blurRadius: 6),
              BoxShadow(color: context.shadowDark,
                  offset: const Offset(3, 3), blurRadius: 6),
            ]),
            child: CircleAvatar(radius: 22, backgroundColor: context.bg,
                child: const Icon(Icons.person, color: C.accent, size: 22))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text('សួស្តី, ${bank.userName} 👋', maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: context.ink)),
          Text('គណនី VIP', style: TextStyle(fontSize: 11, color: context.muted)),
        ])),
        NeuIcon(
            icon: context.isDark ? Icons.light_mode : Icons.dark_mode_outlined,
            size: 40, color: context.ink, onTap: bank.toggleTheme),
        const SizedBox(width: 8),
        Stack(clipBehavior: Clip.none, children: [
          NeuIcon(icon: Icons.notifications_none, size: 40, color: context.ink,
              onTap: () => push(context, const NotificationScreen())),
          if (bank.unread > 0)
            Positioned(right: -2, top: -2, child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: C.accentRed,
                  shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(child: Text('${bank.unread}',
                  style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold))),
            )),
        ]),
      ]);

  Widget _hero(BuildContext context) => NeuBox(
        radius: 24, padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('សមតុល្យសរុប', style: TextStyle(color: context.muted,
                fontSize: 12.5, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: () => bank.setHide(!bank.hideBalance),
              child: Icon(bank.hideBalance ? Icons.visibility_off : Icons.visibility,
                  color: context.muted, size: 20),
            ),
          ]),
          const SizedBox(height: 6),
          bank.hideBalance
              ? Text('••••••••', style: TextStyle(color: context.ink,
                  fontSize: 30, fontWeight: FontWeight.w800))
              : AnimatedCounter(
                  value: bank.currencyMode == 'KHR'
                      ? bank.total * bank.khrRate : bank.total,
                  formatter: bank.currencyMode == 'KHR'
                      ? (v) => '៛${v.toStringAsFixed(0).replaceAllMapped(
                          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
                      : money,
                  style: TextStyle(color: context.ink, fontSize: 30,
                      fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: C.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.trending_up, color: C.accentGreen, size: 14),
                  Text('+2.4%',
                      style: TextStyle(color: C.accentGreen,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ])),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => bank.setCurrency(
                  bank.currencyMode == 'USD' ? 'KHR' : 'USD'),
              child: Container(padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: C.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(bank.currencyMode == 'USD' ? '\$ USD' : '៛ KHR',
                      style: const TextStyle(color: C.accent, fontSize: 11,
                          fontWeight: FontWeight.w700))),
            ),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            _heroBtn(context, Icons.send_rounded, 'ផ្ទេរ',
                () => tabIndex.value = 2),
            _heroBtn(context, Icons.qr_code_2, 'ទទួល',
                () => push(context, const QrScreen())),
            _heroBtn(context, Icons.receipt_long, 'ទូទាត់',
                () => _payBill(context, 'វិក្កយបត្រ', Icons.receipt_long)),
          ]),
        ]),
      );

  Widget _heroBtn(BuildContext context, IconData i, String l, VoidCallback t) =>
      Expanded(child: GestureDetector(onTap: t,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 50, height: 50,
            decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle,
                boxShadow: [
              BoxShadow(color: context.shadowLight,
                  offset: const Offset(-3, -3), blurRadius: 6),
              BoxShadow(color: context.shadowDark,
                  offset: const Offset(3, 3), blurRadius: 6),
            ]),
            child: Icon(i, color: C.accent, size: 22)),
        const SizedBox(height: 6),
        Text(l, style: TextStyle(color: context.ink, fontSize: 11,
            fontWeight: FontWeight.w700)),
      ])));

  Widget _svc(BuildContext context, IconData icon, String label,
          Color color, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 52, height: 52,
            decoration: BoxDecoration(color: context.bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
              BoxShadow(color: context.shadowLight,
                  offset: const Offset(-3, -3), blurRadius: 6),
              BoxShadow(color: context.shadowDark,
                  offset: const Offset(3, 3), blurRadius: 6),
            ]),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: context.ink))),
      ]));

  Future<void> _payBill(BuildContext context, String title, IconData icon) async {
    if (bank.cards.isEmpty) return;
    final code = TextEditingController();
    final amt = TextEditingController();
    int cardId = bank.cards.first.id;
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
//  CARDS
// ============================================================================
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});
  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('កាតធនាគារ')),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bank.cards.length,
          itemBuilder: (_, i) {
            final c = bank.cards[i];
            return Padding(padding: const EdgeInsets.only(bottom: 22),
                child: Column(children: [
              SizedBox(height: 190, child: BankCardWidget(card: c,
                  onTap: () => push(context, CardDetailScreen(cardId: c.id)))),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(padding: const EdgeInsets.symmetric(
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
                              color: c.frozen ? C.accentRed : C.accentGreen)),
                    ])),
                GestureDetector(
                  onTap: () => push(context, CardDetailScreen(cardId: c.id)),
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
      ));
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
//  TRANSFER
// ============================================================================
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final name = TextEditingController();
  final account = TextEditingController();
  final amount = TextEditingController();
  int? cardId;
  String bankName = 'ABA';

  @override
  void dispose() {
    name.dispose(); account.dispose(); amount.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final a = parseAmt(amount.text);
    final cid = cardId ?? (bank.cards.isEmpty ? 0 : bank.cards.first.id);
    if (name.text.trim().isEmpty || account.text.trim().isEmpty ||
        a == null || cid == 0) {
      toast(context, 'សូមបំពេញព័ត៌មាន', error: true);
      return;
    }
    await confirmAndPay(context,
        title: 'ផ្ទេរទៅ ${name.text.trim()} ($bankName)',
        category: 'ផ្ទេរប្រាក់', amount: a, cardId: cid,
        icon: Icons.send_rounded, onSuccess: () {
      name.clear(); account.clear(); amount.clear();
    });
  }

  @override
  Widget build(BuildContext context) => sb(() {
        if (bank.cards.isEmpty) {
          return Scaffold(appBar: AppBar(title: const Text('ផ្ទេរ')),
              body: const Center(child: Text('គ្មានកាត')));
        }
        final sel = cardId ?? bank.cards.first.id;
        return Scaffold(
          appBar: AppBar(title: const Text('ផ្ទេរប្រាក់')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
            Text('ផ្ទេរពីកាត', style: TextStyle(color: context.muted,
                fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            CardPicker(selectedId: sel, onChanged: (id) => setState(() => cardId = id)),
            const SizedBox(height: 18),
            Wrap(spacing: 8, children: [
              for (final b in ['ABA', 'ACLEDA', 'Wing', 'Canadia'])
                ChoiceChip(label: Text(b), selected: bankName == b,
                    onSelected: (_) => setState(() => bankName = b)),
            ]),
            const SizedBox(height: 16),
            NeuField(controller: name, label: 'ឈ្មោះអ្នកទទួល',
                icon: Icons.person_outline),
            const SizedBox(height: 12),
            NeuField(controller: account, label: 'លេខគណនី',
                icon: Icons.account_balance_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            NeuField(controller: amount, label: 'ចំនួន (\$)',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 24),
            NeuButton(label: 'បន្ត', icon: Icons.lock_outline, onPressed: submit),
          ]),
        );
      });
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
                  Expanded(child: Text(e.key,
                      style: TextStyle(color: context.ink, fontSize: 13))),
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
            decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle,
                boxShadow: [
              BoxShadow(color: context.shadowDark,
                  offset: const Offset(2, 2), blurRadius: 4),
              BoxShadow(color: context.shadowLight,
                  offset: const Offset(-2, -2), blurRadius: 4),
            ]),
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
        builder: (ctx) => AlertDialog(backgroundColor: ctx.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('បង្កើតគោលដៅ', style: TextStyle(color: ctx.ink, fontSize: 16)),
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
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
            backgroundColor: context.bg, foregroundColor: C.accent,
            onPressed: () => _addGoal(context),
            icon: const Icon(Icons.add), label: const Text('ថ្មី')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
          NeuBox(radius: 22, padding: const EdgeInsets.all(22),
              child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text('ការប្រាក់', style: TextStyle(color: context.muted, fontSize: 12)),
              const Text('6% / ឆ្នាំ', style: TextStyle(color: C.accentGreen,
                  fontSize: 26, fontWeight: FontWeight.w800)),
            ])),
            Text(money(bank.goals.fold(0.0, (s, g) => s + g.saved)),
                style: TextStyle(color: context.ink, fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ])),
          const SectionTitle('គោលដៅ'),
          for (final g in bank.goals)
            Padding(padding: const EdgeInsets.only(bottom: 14),
                child: NeuBox(padding: const EdgeInsets.all(14), radius: 18,
                    onTap: () => _deposit(context, g),
                    child: Row(children: [
              SizedBox(width: 58, height: 58,
                  child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 58, height: 58,
                    child: CircularProgressIndicator(
                        value: (g.saved / g.target).clamp(0.0, 1.0),
                        strokeWidth: 5, color: g.color,
                        backgroundColor: context.bg)),
                Icon(g.icon, color: g.color, size: 22),
              ])),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                Text(g.name, style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 14, color: context.ink)),
                Text('${money(g.saved)} / ${money(g.target)}',
                    style: TextStyle(color: context.muted, fontSize: 12)),
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
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
            if (loan != null) ...[
              NeuBox(radius: 22, padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, children: [
                Text('កម្ចីកំពុងដំណើរការ',
                    style: TextStyle(color: context.muted, fontSize: 12)),
                Text(money(loan.principal), style: TextStyle(
                    color: context.ink, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: loan.paid / loan.months,
                        minHeight: 10, backgroundColor: context.bg,
                        valueColor: const AlwaysStoppedAnimation(C.accent))),
                const SizedBox(height: 10),
                Text('បង់ ${loan.paid}/${loan.months} ខែ',
                    style: TextStyle(color: context.muted, fontSize: 12)),
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
              _slider(context, 'ចំនួន', money(amount), amount, 500, 50000, 99,
                  (v) => setState(() => amount = (v / 500).round() * 500.0)),
              _slider(context, 'រយៈពេល', '${months.round()} ខែ', months, 6, 60, 54,
                  (v) => setState(() => months = v)),
              _slider(context, 'អត្រា', '${rate.toStringAsFixed(1)}%', rate, 6, 24, 36,
                  (v) => setState(() => rate = v)),
            ])),
            const SizedBox(height: 14),
            NeuBox(inset: true, child: Column(children: [
              Text('បង់ប្រចាំខែ',
                  style: TextStyle(color: context.muted, fontSize: 12)),
              Text(money(monthly), style: const TextStyle(fontSize: 30,
                  fontWeight: FontWeight.w800, color: C.accent)),
            ])),
            const SizedBox(height: 20),
            NeuButton(label: loan != null ? 'មានកម្ចីរួច' : 'ស្នើសុំកម្ចី',
                icon: Icons.request_quote,
                onPressed: loan != null ? null : () async {
                  try {
                    await bank.takeLoan(principal: amount,
                        months: months.round(), rate: rate);
                    if (mounted) toast(context, 'អនុម័ត!');
                  } on ApiException catch (e) {
                    if (mounted) toast(context, e.message, error: true);
                  }
                }),
          ]),
        );
      });

  Widget _slider(BuildContext context, String l, String v, double val,
          double min, double max, int div, ValueChanged<double> on) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => sb(() => Scaffold(
        appBar: AppBar(title: const Text('ព័ត៌មាន')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
          Center(child: Column(children: [
            Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle,
                    boxShadow: [
                  BoxShadow(color: context.shadowLight,
                      offset: const Offset(-6, -6), blurRadius: 12),
                  BoxShadow(color: context.shadowDark,
                      offset: const Offset(6, 6), blurRadius: 12),
                ]),
                child: CircleAvatar(radius: 46, backgroundColor: context.bg,
                    child: const Icon(Icons.person, size: 50, color: C.accent))),
            const SizedBox(height: 14),
            Text(bank.userName.isEmpty ? 'អ្នកប្រើ' : bank.userName,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: context.ink)),
            Text(bank.userEmail, style: TextStyle(color: context.muted,
                fontSize: 12.5)),
          ])),
          const SizedBox(height: 24),
          NeuBox(inset: true, child: Column(children: [
            const InfoRow('ប្រភេទ', 'VIP'),
            InfoRow('ទូរស័ព្ទ', bank.userPhone.isEmpty ? '—' : bank.userPhone),
            InfoRow('អ៊ីមែល', bank.userEmail),
          ])),
          const SectionTitle('ការកំណត់'),
          NeuBox(padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
            SwitchListTile(value: context.isDark, activeThumbColor: C.accent,
                onChanged: (_) => bank.toggleTheme(),
                secondary: const Icon(Icons.dark_mode_outlined, color: C.accent),
                title: const Text('Dark Mode')),
            SwitchListTile(value: bank.biometric, activeThumbColor: C.accent,
                onChanged: bank.setBio,
                secondary: const Icon(Icons.fingerprint, color: C.accent),
                title: const Text('ស្នាមម្រាមដៃ')),
            SwitchListTile(value: bank.hideBalance, activeThumbColor: C.accent,
                onChanged: bank.setHide,
                secondary: const Icon(Icons.visibility_off_outlined, color: C.accent),
                title: const Text('លាក់សមតុល្យ')),
            ListTile(leading: const Icon(Icons.savings_outlined, color: C.accent),
                title: const Text('ថវិកា'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const BudgetsScreen())),
            ListTile(leading: const Icon(Icons.notifications_outlined, color: C.accent),
                title: const Text('ការរំលឹក'),
                trailing: bank.reminders.where((r) => !r.paid).isNotEmpty
                    ? Container(padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: C.accentRed,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('${bank.reminders.where((r) => !r.paid).length}',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.bold)))
                    : const Icon(Icons.chevron_right),
                onTap: () => push(context, const RemindersScreen())),
            ListTile(leading: const Icon(Icons.repeat, color: C.accent),
                title: const Text('ស្វ័យប្រវត្តិ'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const RecurringScreen())),
            ListTile(leading: const Icon(Icons.emoji_events_outlined, color: C.accent),
                title: const Text('សមិទ្ធផល'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const AchievementsScreen())),
                
            // ⬇️⬇️⬇️ បន្ថែម Features ថ្មី ⬇️⬇️⬇️
            const ExtraProfileMenu(),

            const PremiumProfileMenu(),
            ListTile(leading: const Icon(Icons.currency_exchange, color: C.accent),
                title: const Text('រូបិយប័ណ្ណ'),
                trailing: Text(bank.currencyMode == 'USD' ? 'USD' : 'KHR',
                    style: const TextStyle(color: C.accent,
                        fontWeight: FontWeight.w700)),
                onTap: () {
                  bank.setCurrency(bank.currencyMode == 'USD' ? 'KHR' : 'USD');
                  toast(context, 'ប្តូរទៅ ${bank.currencyMode}');
                }),
          ])),
          const SizedBox(height: 24),
          NeuButton(label: 'ចាកចេញ', icon: Icons.logout, accent: C.accentRed,
              onPressed: () async {
            final ok = await showDialog<bool>(context: context,
                builder: (ctx) => AlertDialog(backgroundColor: ctx.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Text('ចាកចេញ?', style: TextStyle(color: ctx.ink)),
                  content: Text('ត្រូវបញ្ចូល PIN ម្តងទៀត',
                      style: TextStyle(color: ctx.muted)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false),
                        child: Text('បោះបង់', style: TextStyle(color: ctx.muted))),
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
                    MaterialPageRoute(builder: (_) => const RegistrationScreen()),
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
        appBar: AppBar(title: const Text('ប្រវត្តិ'),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf),
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
                          label: Text(e.value, style: const TextStyle(fontSize: 12)),
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
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
            ? Center(child: Text('គ្មានសារ', style: TextStyle(color: context.muted)))
            : ListView.builder(padding: const EdgeInsets.all(16),
                itemCount: bank.notifs.length,
                itemBuilder: (_, i) {
                  final n = bank.notifs[i];
                  return Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: NeuBox(padding: const EdgeInsets.all(14), radius: 18,
                          child: Row(children: [
                        Container(width: 42, height: 42,
                            decoration: BoxDecoration(color: context.bg,
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
                          Text(fmtTime(n.time), style: TextStyle(fontSize: 10.5,
                              color: context.muted)),
                        ])),
                        if (!n.read) Container(width: 8, height: 8,
                            decoration: const BoxDecoration(color: C.accentRed,
                                shape: BoxShape.circle)),
                      ])));
                }),
      ));
}

// ============================================================================
//  QR
// ============================================================================
class QrScreen extends StatelessWidget {
  const QrScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('KHQR')),
        body: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            NeuBox(padding: const EdgeInsets.all(24), radius: 26,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(color: C.accentRed,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('KHQR', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900,
                      letterSpacing: 2, fontSize: 12))),
              const SizedBox(height: 16),
              Container(width: 200, height: 200, color: context.bg,
                  child: Icon(Icons.qr_code_2, size: 180, color: context.ink)),
              const SizedBox(height: 16),
              Text(bank.userName.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 14, color: context.ink)),
            ])),
            const SizedBox(height: 24),
            NeuButton(label: 'រក្សាទុក', icon: Icons.download,
                onPressed: () => toast(context, 'បានរក្សាទុក')),
          ]),
        )),
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
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                ChoiceChip(label: Text(c, style: const TextStyle(fontSize: 11)),
                    selected: selectedCat == c,
                    onSelected: (_) => setS(() => selectedCat = c)),
            ]),
            const SizedBox(height: 16),
            NeuField(controller: amtCtrl, label: 'ថវិកា (\$)',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
                                  color: catColor(b.category), size: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(b.category, style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14, color: context.ink)),
                            Text(b.overBudget
                                ? 'លើស ${money(b.spent - b.amount)}'
                                : 'នៅសល់ ${money(b.remaining)}',
                                style: TextStyle(fontSize: 11,
                                    color: b.overBudget ? C.accentRed
                                        : C.accentGreen,
                                    fontWeight: FontWeight.w600)),
                          ])),
                          IconButton(icon: Icon(Icons.delete_outline,
                              color: C.accentRed, size: 20),
                              onPressed: () => bank.deleteBudget(b.id)),
                        ]),
                        const SizedBox(height: 12),
                        ClipRRect(borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                                value: b.percent, minHeight: 8,
                                backgroundColor: context.shadowDark
                                    .withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation(
                                    b.overBudget ? C.accentRed : C.accent))),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                          Text(money(b.spent), style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w700, color: context.ink)),
                          Text('${(b.percent * 100).toStringAsFixed(0)}% / ${money(b.amount)}',
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
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              NeuField(controller: titleCtrl, label: 'ចំណងជើង', icon: Icons.title),
              const SizedBox(height: 12),
              NeuField(controller: amtCtrl, label: 'ចំនួន (\$)',
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(context: ctx, initialDate: due,
                      firstDate: DateTime.now(),
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
                  Text('មិនទាន់មាន',
                      style: TextStyle(fontSize: 16, color: context.muted)),
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
                          Text(r.paid ? 'បានបង់'
                              : r.isOverdue ? 'ហួស ${-r.daysLeft} ថ្ងៃ'
                              : '${r.daysLeft} ថ្ងៃ',
                              style: TextStyle(fontSize: 11,
                                  color: r.paid ? C.accentGreen
                                      : r.isOverdue ? C.accentRed
                                      : context.muted)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          Text(money(r.amount), style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13,
                              color: context.ink)),
                          if (!r.paid)
                            GestureDetector(
                              onTap: () => bank.toggleReminder(r.id, true),
                              child: const Text('បង់', style: TextStyle(
                                  fontSize: 11, color: C.accentGreen,
                                  fontWeight: FontWeight.w700)),
                            ),
                        ]),
                        IconButton(icon: Icon(Icons.delete_outline,
                            size: 18, color: C.accentRed),
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
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              NeuField(controller: titleCtrl, label: 'ចំណងជើង', icon: Icons.title),
              const SizedBox(height: 12),
              NeuField(controller: amtCtrl, label: 'ចំនួន (\$)',
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final f in ['weekly', 'monthly', 'yearly'])
                  ChoiceChip(label: Text(f, style: const TextStyle(fontSize: 11)),
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
                  Text('មិនទាន់មាន',
                      style: TextStyle(fontSize: 15, color: context.muted)),
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
                          Text('${r.frequency} • ${r.nextDate.day}/${r.nextDate.month}',
                              style: TextStyle(fontSize: 11,
                                  color: context.muted)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          Text(money(r.amount), style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13,
                              color: context.ink)),
                          Switch(value: r.active, activeThumbColor: C.accent,
                              onChanged: (v) => bank.toggleRecurring(r.id, v)),
                        ]),
                        IconButton(icon: Icon(Icons.delete_outline,
                            size: 18, color: C.accentRed),
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
              Text('សរុប ${bank.streakTotal}', style: TextStyle(
                  fontSize: 11, color: context.muted)),
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
                              color: a.unlocked ? context.ink : context.muted)),
                      Text(a.desc, textAlign: TextAlign.center, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: context.muted)),
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
