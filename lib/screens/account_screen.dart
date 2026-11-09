// ============================================================================
//  ACCOUNT SCREEN — គណនី
//  សមតុល្យដែលអាចប្រើបាន + ក្រាហ្វចំណាយ + ប្រវត្តិតាមថ្ងៃ
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int _range = 7;

  String _fmt(double v) => bank.currencyMode == 'KHR'
      ? '៛${(v * bank.khrRate).toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
      : money(v);

  String _accountLine() {
    final raw = bank.userPhone.replaceAll(RegExp(r'\D'), '');
    final digits = raw.isNotEmpty
        ? raw
        : (1000000000 + (bank.userId ?? 0)).toString();
    final last4 =
        digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    return 'គណនី •••• $last4';
  }

  /// ស៊េរីចំណាយប្រចាំថ្ងៃ (ចុងក្រោយបំផុត [days] ថ្ងៃ)
  List<double> _series(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final v = List<double>.filled(days, 0);
    for (final t in bank.txs) {
      if (!t.isExpense) continue;
      final d = DateTime(t.time.year, t.time.month, t.time.day);
      final i = d.difference(start).inDays;
      if (i >= 0 && i < days) v[i] += t.amount;
    }
    return v;
  }

  double _todayExpense() {
    final n = DateTime.now();
    return bank.txs
        .where((t) =>
            t.isExpense &&
            t.time.year == n.year &&
            t.time.month == n.month &&
            t.time.day == n.day)
        .fold(0.0, (s, t) => s + t.amount);
  }

  double _monthIncome() {
    final n = DateTime.now();
    return bank.txs
        .where((t) =>
            !t.isExpense && t.time.year == n.year && t.time.month == n.month)
        .fold(0.0, (s, t) => s + t.amount);
  }

  @override
  Widget build(BuildContext context) => sb(() {
        final groups = groupByDay(bank.txs);
        final series = _series(_range);
        final rangeTotal = series.fold(0.0, (s, v) => s + v);
        return Scaffold(
          appBar: AppBar(
            title: const Text('គណនី'),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () async {
                    await bank.refreshAll();
                    if (context.mounted) toast(context, 'បានធ្វើបច្ចុប្បន្នភាព');
                  }),
              const SizedBox(width: 4),
            ],
          ),
          body: RefreshIndicator(
            color: C.accent,
            onRefresh: bank.refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _hero(context),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: _statCard(context, 'ចំណាយថ្ងៃនេះ',
                          _fmt(_todayExpense()), Icons.trending_down_rounded,
                          C.accentRed)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _statCard(context, 'ចំណូលខែនេះ',
                          _fmt(_monthIncome()), Icons.trending_up_rounded,
                          C.accentGreen)),
                ]),
                const SizedBox(height: 14),
                _chartCard(context, series, rangeTotal),
                SectionTitle('ប្រវត្តិនៃការប្រើប្រាសតាមថ្ងៃ',
                    trailing: TextButton(
                        onPressed: () =>
                            push(context, const DailyHistoryScreen()),
                        child: const Text('មើលទាំងអស់',
                            style: TextStyle(
                                color: C.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)))),
                if (groups.isEmpty)
                  _emptyDays(context)
                else
                  for (var i = 0; i < math.min(3, groups.length); i++)
                    StaggeredItem(
                        index: i, child: _dayTile(context, groups[i])),
              ],
            ),
          ),
        );
      });

  // ── សមតុល្យ (ចុច → ប្រវត្តិតាមថ្ងៃ) ─────────────────────────────────
  Widget _hero(BuildContext context) {
    final hidden = bank.hideBalance;
    final shown = bank.currencyMode == 'KHR'
        ? bank.total * bank.khrRate
        : bank.total;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => push(context, const DailyHistoryScreen()),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AuraGrad.brand,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                  color: C.brandStart.withValues(alpha: 0.35),
                  offset: const Offset(0, 14),
                  blurRadius: 28,
                  spreadRadius: -10),
            ],
          ),
          child: Stack(children: [
            Positioned(
                right: -46,
                top: -46,
                child: _blob(150, 0.07)),
            Positioned(
                right: 46,
                bottom: -70,
                child: _blob(140, 0.05)),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 7),
                    Text('សមតុល្យដែលអាចប្រើបាន',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _auraBadge(),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: hidden
                            ? const Text('••••••••',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 31,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1))
                            : AnimatedCounter(
                                value: shown,
                                formatter: bank.currencyMode == 'KHR'
                                    ? (v) => '៛${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
                                    : money,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 31,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8)),
                      ),
                      GestureDetector(
                        onTap: () => bank.setHide(!hidden),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 2),
                          child: Icon(
                              hidden
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    GestureDetector(
                      onTap: () => bank.setCurrency(
                          bank.currencyMode == 'USD' ? 'KHR' : 'USD'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            bank.currencyMode == 'USD' ? '\$ USD' : '៛ KHR',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_accountLine(),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.history_rounded,
                        color: Colors.white.withValues(alpha: 0.8), size: 15),
                    const SizedBox(width: 4),
                    Text('ប្រវត្តិ',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.8), size: 17),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _blob(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha)),
      );

  Widget _auraBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.22))),
        child: const Text('AURA',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2)),
      );

  Widget _statCard(BuildContext context, String label, String value,
          IconData icon, Color color) =>
      NeuBox(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(color: context.muted, fontSize: 11.5)),
          const SizedBox(height: 2),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: context.ink))),
        ]),
      );

  // ── ក្រាហ្វ ──────────────────────────────────────────────────────────
  Widget _chartCard(BuildContext context, List<double> series,
          double rangeTotal) =>
      NeuBox(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('លំហូរចំណាយ',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.ink)),
                    const SizedBox(height: 3),
                    Text('សរុប ${_fmt(rangeTotal)} ក្នុង $_range ថ្ងៃ',
                        style:
                            TextStyle(color: context.muted, fontSize: 11.5)),
                  ]),
            ),
            _rangeSwitch(context),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('chart-$_range'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 950),
              curve: Curves.easeOutCubic,
              builder: (_, t, __) => CustomPaint(
                size: Size.infinite,
                painter: _TrendPainter(
                  values: series,
                  progress: t,
                  gridColor: context.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0x140F2A3D),
                  startColor: C.accentTeal,
                  endColor: C.accent,
                  dotColor: C.accentTeal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _axisLabels(context),
        ]),
      );

  Widget _rangeSwitch(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: context.isDark
                ? Colors.black.withValues(alpha: 0.18)
                : context.bg,
            borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _rangePill(context, '៧ ថ្ងៃ', 7),
          _rangePill(context, '៣០ ថ្ងៃ', 30),
        ]),
      );

  Widget _rangePill(BuildContext context, String label, int days) {
    final sel = _range == days;
    return GestureDetector(
      onTap: () => setState(() => _range = days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
            gradient: sel ? AuraGrad.button : null,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : context.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _axisLabels(BuildContext context) {
    final now = DateTime.now();
    if (_range == 7) {
      return Row(
        children: [
          for (var i = 6; i >= 0; i--)
            Expanded(
              child: Text(
                  now.subtract(Duration(days: i)).day.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: i == 0 ? C.accent : context.muted,
                      fontSize: 10.5,
                      fontWeight:
                          i == 0 ? FontWeight.w800 : FontWeight.w500)),
            ),
        ],
      );
    }
    final start = now.subtract(const Duration(days: 29));
    final mid = now.subtract(const Duration(days: 14));
    String d(DateTime t) => '${t.day}/${t.month}';
    return Row(children: [
      Text(d(start), style: TextStyle(color: context.muted, fontSize: 10.5)),
      const Spacer(),
      Text(d(mid), style: TextStyle(color: context.muted, fontSize: 10.5)),
      const Spacer(),
      const Text('ថ្ងៃនេះ',
          style: TextStyle(
              color: C.accent, fontSize: 10.5, fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _emptyDays(BuildContext context) => NeuBox(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                gradient: AuraGrad.soft, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined,
                color: context.muted, size: 24),
          ),
          const SizedBox(height: 12),
          Text('មិនទាន់មានប្រតិបត្តិការ',
              style: TextStyle(
                  color: context.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('ប្រវត្តិនឹងបង្ហាញនៅទីនេះ ពេលអ្នកចាប់ផ្ដើមប្រើប្រាស់',
              style: TextStyle(color: context.muted, fontSize: 11.5)),
        ]),
      );

  Widget _dayTile(BuildContext context, DayGroup g) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NeuBox(
          radius: 16,
          padding: const EdgeInsets.all(14),
          onTap: () => push(context, const DailyHistoryScreen()),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  gradient: AuraGrad.soft,
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.calendar_today_rounded,
                  color: C.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dayLabel(g.day),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: context.ink)),
                    const SizedBox(height: 2),
                    Text('${g.txs.length} ប្រតិបត្តិការ',
                        style: TextStyle(
                            color: context.muted, fontSize: 11.5)),
                  ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min, children: [
                  if (g.expense > 0)
                    Text('-${money(g.expense)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: C.accentRed)),
                  if (g.income > 0)
                    Text('+${money(g.income)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: C.accentGreen)),
                  if (g.expense == 0 && g.income == 0)
                    Text(money(0),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: context.muted)),
                ]),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded,
                color: context.muted, size: 20),
          ]),
        ),
      );
}

// ============================================================================
//  ប្រវត្តិនៃការប្រើប្រាសតាមថ្ងៃ (រហូតដល់ថ្ងៃដំបូង)
// ============================================================================
class DailyHistoryScreen extends StatelessWidget {
  const DailyHistoryScreen({super.key});

  static const _weekdays = [
    'ថ្ងៃអាទិត្យ',
    'ថ្ងៃចន្ទ',
    'ថ្ងៃអង្គារ',
    'ថ្ងៃពុធ',
    'ថ្ងៃព្រហស្បតិ៍',
    'ថ្ងៃសុក្រ',
    'ថ្ងៃសៅរ៍',
  ];

  @override
  Widget build(BuildContext context) => sb(() {
        final groups = groupByDay(bank.txs);
        return Scaffold(
          appBar: AppBar(
            title: const Text('ប្រវត្តិតាមថ្ងៃ'),
            actions: [
              IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => push(context, const HistoryScreen())),
              const SizedBox(width: 4),
            ],
          ),
          body: RefreshIndicator(
            color: C.accent,
            onRefresh: bank.refreshAll,
            child: groups.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 150),
                      Center(
                        child: Column(children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                                gradient: AuraGrad.soft,
                                shape: BoxShape.circle),
                            child: Icon(Icons.receipt_long_outlined,
                                color: context.muted, size: 30),
                          ),
                          const SizedBox(height: 14),
                          Text('មិនទាន់មានប្រតិបត្តិការ',
                              style: TextStyle(
                                  color: context.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('ប្រវត្តិនៃការប្រើប្រាសនឹងបង្ហាញនៅទីនេះ',
                              style: TextStyle(
                                  color: context.muted, fontSize: 12)),
                        ]),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (var i = 0; i < groups.length; i++) ...[
                        _dayHeader(context, groups[i]),
                        for (final t in groups[i].txs) TxTile(t),
                        const SizedBox(height: 6),
                      ],
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                              'ចាប់ផ្ដើមគណនី • ${dayLabel(groups.last.day)}',
                              style: TextStyle(
                                  color: context.muted, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      });

  Widget _dayHeader(BuildContext context, DayGroup g) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
        child: Row(children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                gradient: AuraGrad.button,
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dayLabel(g.day),
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: context.ink)),
                  Text(
                      '${_weekdays[g.day.weekday % 7]} • ${g.txs.length} ប្រតិបត្តិការ',
                      style:
                          TextStyle(color: context.muted, fontSize: 10.5)),
                ]),
          ),
          if (g.expense > 0)
            _amountChip('-${money(g.expense)}', C.accentRed),
          if (g.expense > 0 && g.income > 0) const SizedBox(width: 6),
          if (g.income > 0) _amountChip('+${money(g.income)}', C.accentGreen),
        ]),
      );

  Widget _amountChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800)),
      );
}

// ============================================================================
//  ក្រុមប្រតិបត្តិការតាមថ្ងៃ
// ============================================================================
class DayGroup {
  final DateTime day;
  final List<Tx> txs;
  final double income, expense;
  DayGroup(this.day, this.txs)
      : income =
            txs.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount),
        expense =
            txs.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
}

List<DayGroup> groupByDay(List<Tx> txs) {
  final map = <String, List<Tx>>{};
  for (final t in txs) {
    final k = '${t.time.year}-${t.time.month}-${t.time.day}';
    map.putIfAbsent(k, () => []).add(t);
  }
  final groups = map.values.map((list) {
    list.sort((a, b) => b.time.compareTo(a.time));
    return DayGroup(
        DateTime(list.first.time.year, list.first.time.month,
            list.first.time.day),
        list);
  }).toList()
    ..sort((a, b) => b.day.compareTo(a.day));
  return groups;
}

// ============================================================================
//  GRAPH PAINTER — ខ្សែកោងរលូន + ពណ៌ gradient + ចំណុចភ្លឺ
// ============================================================================
class _TrendPainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final Color gridColor, startColor, endColor, dotColor;
  _TrendPainter({
    required this.values,
    required this.progress,
    required this.gridColor,
    required this.startColor,
    required this.endColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;

    const padTop = 12.0, padBottom = 4.0;
    final w = size.width;
    final h = size.height - padTop - padBottom;
    final peak = math.max(1e-9, values.fold<double>(0, math.max));

    double xFor(int i) => n == 1 ? w / 2 : i / (n - 1) * w;
    double yFor(double v) =>
        padTop + h - (v / peak) * h * 0.86 * progress;

    // បន្ទាត់ណែនាំ (dashed, ស្រាល)
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final y = padTop + h * (g / 3);
      _dash(canvas, Offset(0, y), Offset(w, y), grid);
    }

    final pts = [
      for (var i = 0; i < n; i++) Offset(xFor(i), yFor(values[i])),
    ];

    // ខ្សែកោង smooth (Catmull-Rom → cubic bezier)
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    final area = Path.from(line)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              endColor.withValues(alpha: 0.34),
              endColor.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(0, padTop, w, h)));

    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(
            colors: [startColor, endColor],
          ).createShader(Rect.fromLTWH(0, 0, w, size.height)));

    // ចំណុចចុងក្រោយ — glow
    final last = pts.last;
    canvas.drawCircle(
        last, 11, Paint()..color = dotColor.withValues(alpha: 0.14));
    canvas.drawCircle(
        last, 6.5, Paint()..color = dotColor.withValues(alpha: 0.28));
    canvas.drawCircle(last, 4, Paint()..color = dotColor);
    canvas.drawCircle(last, 1.8, Paint()..color = Colors.white);
  }

  void _dash(Canvas c, Offset a, Offset b, Paint p,
      {double dash = 5, double gap = 5}) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, total), p);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.startColor != startColor ||
      old.endColor != endColor ||
      old.gridColor != gridColor;
}
