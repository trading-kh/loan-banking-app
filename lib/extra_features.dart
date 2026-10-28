// ============================================================================
//  Extra Features — Split Bill, Virtual Cards, Referral, Insights, Cashback
//  ឯកសារនេះបន្ថែម features ៥ ដោយមិនកែ main.dart
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'api_service.dart';

// ============================================================
//  MODELS
// ============================================================
class SplitBill {
  final int id;
  final String title;
  final double totalAmount, yourShare;
  final List<String> participants;
  final DateTime createdAt;
  SplitBill({required this.id, required this.title, required this.totalAmount,
      required this.yourShare, required this.participants,
      required this.createdAt});
  factory SplitBill.fromJson(Map<String, dynamic> j) {
    final raw = (j['participants'] as String)
        .replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    final list = raw.split(',').map((s) => s.trim())
        .where((s) => s.isNotEmpty).toList();
    return SplitBill(
      id: j['id'] as int,
      title: j['title'] as String,
      totalAmount: (j['total_amount'] as num).toDouble(),
      yourShare: (j['your_share'] as num).toDouble(),
      participants: list,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    );
  }
}

class VirtualCard {
  final int id;
  final String name, number, cvv, expiry;
  final double limitAmount, spent;
  final bool active, frozen;
  VirtualCard({required this.id, required this.name, required this.number,
      required this.cvv, required this.expiry, required this.limitAmount,
      required this.spent, required this.active, required this.frozen});
  factory VirtualCard.fromJson(Map<String, dynamic> j) => VirtualCard(
        id: j['id'] as int,
        name: j['name'] as String,
        number: j['number'] as String,
        cvv: j['cvv'] as String,
        expiry: j['expiry'] as String,
        limitAmount: (j['limit_amount'] as num).toDouble(),
        spent: (j['spent'] as num).toDouble(),
        active: j['active'] == 1,
        frozen: j['frozen'] == 1,
      );
  String get masked => '•••• •••• •••• ${number.substring(number.length - 4)}';
}

class Referral {
  final String code;
  final int referredCount;
  final double earnings;
  Referral({required this.code, required this.referredCount,
      required this.earnings});
  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
        code: j['code'] as String,
        referredCount: j['referred_count'] as int,
        earnings: (j['earnings'] as num).toDouble(),
      );
}

class Insight {
  final String type, icon, title, body, severity;
  Insight({required this.type, required this.icon, required this.title,
      required this.body, required this.severity});
  factory Insight.fromJson(Map<String, dynamic> j) => Insight(
        type: j['type'] as String,
        icon: j['icon'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        severity: j['severity'] as String? ?? 'info',
      );
}

class CashbackItem {
  final int id;
  final String category;
  final double amount, rate;
  final DateTime createdAt;
  CashbackItem({required this.id, required this.category,
      required this.amount, required this.rate, required this.createdAt});
  factory CashbackItem.fromJson(Map<String, dynamic> j) => CashbackItem(
        id: j['id'] as int,
        category: j['category'] as String,
        amount: (j['amount'] as num).toDouble(),
        rate: (j['rate'] as num).toDouble(),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

// ============================================================
//  EXTRA STATE (ដាច់ដោយឡែកពី bank)
// ============================================================
class ExtraState extends ChangeNotifier {
  List<SplitBill> splits = [];
  List<VirtualCard> virtualCards = [];
  List<CashbackItem> cashbackHistory = [];
  List<Insight> insights = [];
  double cashbackTotal = 0;
  Map<String, double> cashbackRates = {};
  Referral? referral;
  bool loading = false;

  // ---- Splits ----
  Future<void> loadSplits() async {
    loading = true;
    notifyListeners();
    try {
      final raw = await ApiService.getSplits();
      splits = raw.map((e) => SplitBill.fromJson(e)).toList();
    } catch (_) {} finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> createSplit(String title, double total,
      List<String> participants) async {
    await ApiService.createSplit(title, total, participants);
    await loadSplits();
  }

  // ---- Virtual Cards ----
  Future<void> loadVirtualCards() async {
    loading = true;
    notifyListeners();
    try {
      final raw = await ApiService.getVirtualCards();
      virtualCards = raw.map((e) => VirtualCard.fromJson(e)).toList();
    } catch (_) {} finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> createVirtualCard(String name, {double limit = 500}) async {
    await ApiService.createVirtualCard(name, limit: limit);
    await loadVirtualCards();
  }

  Future<void> toggleVirtualCard(int id,
      {bool? active, bool? frozen}) async {
    await ApiService.updateVirtualCard(id, active: active, frozen: frozen);
    await loadVirtualCards();
  }

  Future<void> deleteVirtualCard(int id) async {
    await ApiService.deleteVirtualCard(id);
    await loadVirtualCards();
  }

  // ---- Referral ----
  Future<void> loadReferral() async {
    try {
      final r = await ApiService.getReferral();
      referral = Referral.fromJson(r);
    } catch (_) {} finally {
      notifyListeners();
    }
  }

  Future<double> redeemReferral(String code) async {
    final r = await ApiService.redeemReferral(code);
    await loadReferral();
    return (r['bonus'] as num).toDouble();
  }

  // ---- Cashback ----
  Future<void> loadCashback() async {
    loading = true;
    notifyListeners();
    try {
      final r = await ApiService.getCashback();
      cashbackTotal = (r['total'] as num?)?.toDouble() ?? 0;
      final hist = (r['history'] as List?) ?? [];
      cashbackHistory = hist
          .map((e) => CashbackItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final rates = (r['rates'] as Map?) ?? {};
      cashbackRates =
          rates.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    } catch (_) {} finally {
      loading = false;
      notifyListeners();
    }
  }

  // ---- Insights ----
  Future<void> loadInsights() async {
    loading = true;
    notifyListeners();
    try {
      final r = await ApiService.getInsights();
      final raw = (r['insights'] as List?) ?? [];
      insights = raw
          .map((e) => Insight.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {} finally {
      loading = false;
      notifyListeners();
    }
  }
}

final ExtraState extraState = ExtraState();

// ============================================================
//  SPLIT BILL SCREEN
// ============================================================
class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});
  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  @override
  void initState() {
    super.initState();
    extraState.loadSplits();
  }

  Future<void> _add() async {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final partCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ចែកវិក្កយបត្រ',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ctx.ink)),
              const SizedBox(height: 16),
              NeuField(
                  controller: titleCtrl,
                  label: 'ចំណងជើង',
                  icon: Icons.title),
              const SizedBox(height: 12),
              NeuField(
                  controller: amtCtrl,
                  label: 'ចំនួនសរុប (\$)',
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true)),
              const SizedBox(height: 12),
              NeuField(
                  controller: partCtrl,
                  label: 'អ្នកចូលរួម (បំបែកដោយ ,)',
                  icon: Icons.people),
              const SizedBox(height: 20),
              NeuButton(
                  label: 'បង្កើត',
                  icon: Icons.check,
                  onPressed: () {
                    final a = parseAmt(amtCtrl.text);
                    final names = partCtrl.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    if (titleCtrl.text.trim().isEmpty ||
                        a == null ||
                        names.isEmpty) {
                      toast(ctx, 'សូមបំពេញ', error: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    extraState.createSplit(titleCtrl.text.trim(), a, names);
                  }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: extraState, builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ចែកវិក្កយបត្រ'),
            actions: [
              IconButton(icon: const Icon(Icons.add), onPressed: _add),
            ],
          ),
          body: extraState.splits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: context.muted),
                      const SizedBox(height: 16),
                      Text('មិនទាន់មាន',
                          style: TextStyle(
                              fontSize: 16, color: context.muted)),
                      const SizedBox(height: 8),
                      NeuButton(
                          label: 'ចែកវិក្កយបត្រ',
                          icon: Icons.add,
                          fullWidth: false,
                          onPressed: _add),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final s in extraState.splits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NeuBox(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: C.accentPurple
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.people,
                                      color: C.accentPurple, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.title,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: context.ink)),
                                      Text(
                                          '${s.participants.length + 1} នាក់',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: context.muted)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(money(s.totalAmount),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: context.muted)),
                                    Text(money(s.yourShare),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: C.accent)),
                                  ],
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: C.accent
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Text('អ្នក',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: C.accent)),
                                  ),
                                  for (final p in s.participants)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: C.accentGreen
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text(p,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: C.accentGreen)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      });
}

// ============================================================
//  VIRTUAL CARDS SCREEN
// ============================================================
class VirtualCardsScreen extends StatefulWidget {
  const VirtualCardsScreen({super.key});
  @override
  State<VirtualCardsScreen> createState() => _VirtualCardsScreenState();
}

class _VirtualCardsScreenState extends State<VirtualCardsScreen> {
  @override
  void initState() {
    super.initState();
    extraState.loadVirtualCards();
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '500');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('បង្កើតកាតនិម្មិត',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ctx.ink)),
            const SizedBox(height: 16),
            NeuField(
                controller: nameCtrl,
                label: 'ឈ្មោះកាត',
                icon: Icons.credit_card),
            const SizedBox(height: 12),
            NeuField(
                controller: limitCtrl,
                label: 'កម្រិត (\$)',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            NeuButton(
                label: 'បង្កើត',
                icon: Icons.check,
                onPressed: () {
                  final l = double.tryParse(limitCtrl.text) ?? 500;
                  if (nameCtrl.text.trim().isEmpty) {
                    toast(ctx, 'សូមបំពេញឈ្មោះ', error: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  extraState.createVirtualCard(nameCtrl.text.trim(),
                      limit: l);
                }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: extraState, builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('កាតនិម្មិត'),
            actions: [
              IconButton(icon: const Icon(Icons.add), onPressed: _add),
            ],
          ),
          body: extraState.virtualCards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.credit_card,
                          size: 64, color: context.muted),
                      const SizedBox(height: 16),
                      Text('មិនទាន់មាន',
                          style: TextStyle(
                              fontSize: 16, color: context.muted)),
                      const SizedBox(height: 8),
                      NeuButton(
                          label: 'បង្កើត',
                          icon: Icons.add,
                          fullWidth: false,
                          onPressed: _add),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final v in extraState.virtualCards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: NeuBox(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 56,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: v.frozen
                                          ? [
                                              Colors.grey.shade400,
                                              Colors.grey.shade600
                                            ]
                                          : [C.accentPurple, C.accent],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.credit_card,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(v.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: context.ink)),
                                      Text(v.masked,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: context.muted,
                                              fontFamily: 'monospace')),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: C.accentRed),
                                  onPressed: () =>
                                      extraState.deleteVirtualCard(v.id),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('CVV: ${v.cvv}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: context.muted)),
                                      Text('Expiry: ${v.expiry}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: context.muted)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text('កម្រិត',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: context.muted)),
                                      Text(money(v.limitAmount),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: context.ink)),
                                    ],
                                  ),
                                  Switch(
                                    value: v.frozen,
                                    activeThumbColor: C.accentRed,
                                    inactiveThumbColor: C.accentGreen,
                                    onChanged: (val) => extraState
                                        .toggleVirtualCard(v.id, frozen: val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      });
}

// ============================================================
//  REFERRAL SCREEN
// ============================================================
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    extraState.loadReferral();
  }

  Future<void> _redeem() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('ប្រើកូដ',
            style: TextStyle(color: ctx.ink, fontSize: 16)),
        content: NeuField(controller: ctrl, label: 'កូដ'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('បោះបង់',
                  style: TextStyle(color: ctx.muted))),
          TextButton(
              onPressed: () async {
                final code = ctrl.text.trim().toUpperCase();
                if (code.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final bonus = await extraState.redeemReferral(code);
                  if (context.mounted) {
                    toast(context,
                        'ទទួលបាន \$${bonus.toStringAsFixed(2)}! 🎉');
                  }
                } on ApiException catch (e) {
                  if (context.mounted) {
                    toast(context, e.message, error: true);
                  }
                }
              },
              child: const Text('យល់ព្រម',
                  style: TextStyle(
                      color: C.accent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) => NeuBox(
        inset: true,
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Icon(icon, color: C.accent, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.ink)),
          Text(label,
              style: TextStyle(fontSize: 10, color: context.muted)),
        ]),
      );

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: extraState, builder: (_, __) {
        return Scaffold(
          appBar: AppBar(title: const Text('ណែនាំមិត្តភក្តិ')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NeuBox(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: C.accentGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.card_giftcard,
                        color: C.accentGold, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text('ណែនាំមិត្តភក្តិ',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.ink)),
                  const SizedBox(height: 4),
                  Text('អ្នក + មិត្តភក្តិ ទាំងពីរទទួលបាន \$5',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: context.muted)),
                  const SizedBox(height: 20),
                  if (extraState.referral != null) ...[
                    Text('កូដរបស់អ្នក',
                        style: TextStyle(
                            fontSize: 11, color: context.muted)),
                    const SizedBox(height: 8),
                    NeuBox(
                      inset: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(extraState.referral!.code,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3,
                                  color: C.accent,
                                  fontFamily: 'monospace')),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.copy,
                                color: C.accent, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: extraState.referral!.code));
                              toast(context, 'បានចម្លង!');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: _statCard(
                              'បានណែនាំ',
                              '${extraState.referral!.referredCount}',
                              Icons.people)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                              'ចំណូល',
                              money(extraState.referral!.earnings),
                              Icons.attach_money)),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  NeuButton(
                      label: 'ប្រើកូដរបស់មិត្តភក្តិ',
                      icon: Icons.redeem,
                      onPressed: _redeem),
                ]),
              ),
            ],
          ),
        );
      });
}

// ============================================================
//  INSIGHTS SCREEN
// ============================================================
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    extraState.loadInsights();
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'success':
        return C.accentGreen;
      case 'warning':
        return C.accentGold;
      case 'danger':
        return C.accentRed;
      default:
        return C.accent;
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: extraState, builder: (_, __) {
        return Scaffold(
          appBar: AppBar(title: const Text('ការវិភាគចំណាយ')),
          body: extraState.insights.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insights_outlined,
                          size: 64, color: context.muted),
                      const SizedBox(height: 16),
                      Text('មិនទាន់មានទិន្នន័យ',
                          style: TextStyle(
                              fontSize: 15, color: context.muted)),
                      const SizedBox(height: 8),
                      Text('ធ្វើប្រតិបត្តិការដើម្បីទទួលបានការវិភាគ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: context.muted)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final i in extraState.insights)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NeuBox(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: _severityColor(i.severity)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle),
                                child: Center(
                                    child: Text(i.icon,
                                        style: const TextStyle(
                                            fontSize: 22))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(i.title,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: _severityColor(
                                                i.severity))),
                                    const SizedBox(height: 4),
                                    Text(i.body,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: context.ink,
                                            height: 1.4)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      });
}

// ============================================================
//  CASHBACK SCREEN
// ============================================================
class CashbackScreen extends StatefulWidget {
  const CashbackScreen({super.key});
  @override
  State<CashbackScreen> createState() => _CashbackScreenState();
}

class _CashbackScreenState extends State<CashbackScreen> {
  @override
  void initState() {
    super.initState();
    extraState.loadCashback();
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: extraState, builder: (_, __) {
        return Scaffold(
          appBar: AppBar(title: const Text('Cashback')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NeuBox(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: C.accentGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.savings,
                        color: C.accentGreen, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text('ចំណូលសរុបពី Cashback',
                      style: TextStyle(
                          fontSize: 12, color: context.muted)),
                  Text(money(extraState.cashbackTotal),
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: C.accentGreen)),
                ]),
              ),
              const SectionTitle('អត្រា Cashback'),
              NeuBox(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  if (extraState.cashbackRates.isEmpty)
                    Text('មិនទាន់មាន',
                        style: TextStyle(color: context.muted))
                  else
                    for (final e in extraState.cashbackRates.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: catColor(e.key),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Text(e.key,
                                  style: TextStyle(
                                      fontSize: 13, color: context.ink)),
                            ]),
                            Text(
                                '${(e.value * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: C.accentGreen)),
                          ],
                        ),
                      ),
                ]),
              ),
              const SectionTitle('ប្រវត្តិ'),
              if (extraState.cashbackHistory.isEmpty)
                NeuBox(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                      child: Text('មិនទាន់មាន Cashback',
                          style: TextStyle(color: context.muted))),
                )
              else
                for (final c in extraState.cashbackHistory)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NeuBox(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: catColor(c.category)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle),
                          child: Icon(Icons.savings,
                              color: catColor(c.category), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.category,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: context.ink)),
                              Text(fmtTime(c.createdAt),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: context.muted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('+${money(c.amount)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: C.accentGreen)),
                            Text('${(c.rate * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: context.muted)),
                          ],
                        ),
                      ]),
                    ),
                  ),
            ],
          ),
        );
      });
}

// ============================================================
//  EXTRA PROFILE MENU (ដាក់ក្នុង ProfileScreen)
// ============================================================
class ExtraProfileMenu extends StatelessWidget {
  const ExtraProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: extraState,
      builder: (_, __) => Column(children: [
        ListTile(
          leading: const Icon(Icons.people_outline, color: C.accent),
          title: const Text('ចែកវិក្កយបត្រ'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SplitBillScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.credit_card, color: C.accent),
          title: const Text('កាតនិម្មិត'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VirtualCardsScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.card_giftcard, color: C.accent),
          title: const Text('ណែនាំមិត្តភក្តិ'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReferralScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.insights, color: C.accent),
          title: const Text('ការវិភាគចំណាយ'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InsightsScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.savings, color: C.accentGreen),
          title: const Text('Cashback'),
          trailing: extraState.cashbackTotal > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: C.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('+${money(extraState.cashbackTotal)}',
                      style: const TextStyle(
                          color: C.accentGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)))
              : const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CashbackScreen())),
        ),
      ]),
    );
  }
}