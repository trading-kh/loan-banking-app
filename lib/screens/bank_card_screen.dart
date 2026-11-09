// ============================================================================
//  BANK CARD — កាតផ្ទាល់ខ្លួនដ៏ស្រស់ស្អាត + ភ្ជាប់គណនីធនាគារ
//  ទទេ រហូតទាល់តែអ្នកប្រើចូលគណនី + ភ្ជាប់លេខគណនីធនាគារ ទើបបង្កើតកាតមួយ។
// ============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble, FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../api_service.dart';

// ============================================================================
//  CARD MENU SCREEN (Tab "កាត")
// ============================================================================
class CardMenuScreen extends StatelessWidget {
  const CardMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => sb(() {
        final Widget body = !bank.loggedIn
            ? const _LoginPrompt()
            : !bank.hasLinkedBank
                ? _EmptyCardState(
                    onLink: () =>
                        push(context, const LinkBankAccountScreen()))
                : _LinkedCardView(
                    onManage: () => _showManageSheet(context));
        return Scaffold(
          backgroundColor: C.bgDark,
          body: Column(children: [
            const _CardTopBar(),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: RefreshIndicator(
                  color: C.accent,
                  onRefresh: bank.refreshAll,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 26, 18, 28),
                    children: [body],
                  ),
                ),
              ),
            ),
          ]),
        );
      });
}

// ── Header ────────────────────────────────────────────────────────────────
class _CardTopBar extends StatelessWidget {
  const _CardTopBar();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A2A4A), Color(0xFF12507C), Color(0xFF0A2A4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(children: [
              Row(children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => tabIndex.value = 0,
                  child: Ink(
                    padding: const EdgeInsets.all(11),
                    decoration: const BoxDecoration(
                        color: Color(0x33FFFFFF), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 17),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('កាត',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_user_outlined,
                        color: C.accentGold, size: 15),
                    SizedBox(width: 5),
                    Text('សុវត្ថិភាព',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('គ្រប់គ្រងកាត និងគណនីធនាគាររបស់អ្នក',
                    style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5)),
              ),
            ]),
          ),
        ),
      );
}

// ── មិនទាន់ចូលគណនី ────────────────────────────────────────────────────────
class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();
  @override
  Widget build(BuildContext context) => _EmptyShell(
        icon: Icons.lock_outline_rounded,
        title: 'សូមចូលគណនីជាមុន',
        subtitle:
            'ចូលគណនី Aura Bank របស់អ្នក ដើម្បីភ្ជាប់ធនាគារ និងបង្កើតកាតផ្ទាល់ខ្លួន។',
        action: NeuButton(
            label: 'ចូលគណនី',
            icon: Icons.login_rounded,
            onPressed: () => tabIndex.value = 0),
      );
}

// ── ទទេ (មិនទាន់ភ្ជាប់គណនីធនាគារ) ──────────────────────────────────────────
class _EmptyCardState extends StatelessWidget {
  final VoidCallback onLink;
  const _EmptyCardState({required this.onLink});
  @override
  Widget build(BuildContext context) => Column(children: [
        const _GhostCard(),
        const SizedBox(height: 26),
        Text('មិនទាន់មានកាតនៅឡើយទេ',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: context.ink)),
        const SizedBox(height: 10),
        Text(
            'ភ្ជាប់គណនីធនាគាររបស់អ្នក ដើម្បីបង្កើតកាតផ្ទាល់ខ្លួនដ៏ស្រស់ស្អាត មានឈ្មោះអ្នក និងឈ្មោះធនាគារដែលអ្នកបានជ្រើសរើស។',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.6, color: context.muted)),
        const SizedBox(height: 24),
        NeuButton(
            label: 'ភ្ជាប់គណនីធនាគារ',
            icon: Icons.add_link_rounded,
            onPressed: onLink),
        const SizedBox(height: 24),
        Row(children: [
          _featurePill(context, Icons.shield_outlined, 'សុវត្ថិភាពខ្ពស់'),
          const SizedBox(width: 10),
          _featurePill(context, Icons.bolt_rounded, 'បង្កើតភ្លាមៗ'),
          const SizedBox(width: 10),
          _featurePill(context, Icons.badge_outlined, 'ផ្ទាល់ខ្លួន'),
        ]),
      ]);

  Widget _featurePill(BuildContext context, IconData icon, String label) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.border),
          ),
          child: Column(children: [
            Icon(icon, color: C.accent, size: 22),
            const SizedBox(height: 7),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.muted)),
          ]),
        ),
      );
}

class _EmptyShell extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget action;
  const _EmptyShell(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.action});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            gradient: AuraGrad.soft,
            shape: BoxShape.circle,
            border: Border.all(color: context.border),
          ),
          child: Icon(icon, size: 44, color: C.accent),
        ),
        const SizedBox(height: 22),
        Text(title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: context.ink)),
        const SizedBox(height: 10),
        Text(subtitle,
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13.5, height: 1.6, color: context.muted)),
        const SizedBox(height: 24),
        action,
      ]);
}

// ── កាតខ្មោច (placeholder ទទេ) ──────────────────────────────────────────────
class _GhostCard extends StatelessWidget {
  const _GhostCard();
  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1.586,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: context.isDark
                      ? [const Color(0xFF07293F), const Color(0xFF0A3A57)]
                      : [const Color(0xFFE9EFF4), const Color(0xFFDCE6EE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            CustomPaint(painter: _DashedRRectPainter(context.border)),
            Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.credit_card_rounded,
                  size: 46, color: context.muted.withValues(alpha: 0.55)),
              const SizedBox(height: 12),
              Text('កាតរបស់អ្នកនឹងបង្ហាញនៅទីនេះ',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.muted.withValues(alpha: 0.8))),
            ])),
          ]),
        ),
      );
}

// ============================================================================
//  ជាវកាតដែលបានភ្ជាប់ (កាត + សកម្មភាព + ព័ត៌មាន)
// ============================================================================
class _LinkedCardView extends StatelessWidget {
  final VoidCallback onManage;
  const _LinkedCardView({required this.onManage});
  @override
  Widget build(BuildContext context) => Column(children: [
        AuraBankCard(
          holderName: bank.userName,
          bankName: bank.bankName,
          accountNumber: bank.bankAccount,
          onManage: onManage,
        ),
        const SizedBox(height: 24),
        NeuBox(
          inset: true,
          child: Column(children: [
            Row(children: [
              Icon(Icons.account_balance_rounded, color: C.accent, size: 19),
              const SizedBox(width: 9),
              Text('ព័ត៌មានគណនី',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.ink)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: C.accentGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle, color: C.accentGreen, size: 13),
                  SizedBox(width: 4),
                  Text('បានភ្ជាប់',
                      style: TextStyle(
                          color: C.accentGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            InfoRow('ធនាគារ', bank.bankName),
            InfoRow('លេខគណនី', _maskNumber(bank.bankAccount)),
            InfoRow('ម្ចាស់កាត',
                bank.userName.isEmpty ? '—' : bank.userName.toUpperCase()),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.accent.withValues(alpha: 0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: C.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    'កាតនេះជាតំណាងនិម្មិតនៃគណនីធនាគារដែលអ្នកបានភ្ជាប់ សម្រាប់ប្រើប្រាស់ក្នុង Aura Bank។ ចុចលើកាតដើម្បីបត់មើលខាងក្រោយ។',
                    style: TextStyle(
                        fontSize: 12, height: 1.55, color: context.muted))),
          ]),
        ),
      ]);
}

// ============================================================================
//  AURA BANK CARD — កាតពិតដ៏ស្រស់ស្អាត (flip / tilt / gloss / EMV chip)
// ============================================================================
class AuraBankCard extends StatefulWidget {
  final String holderName, bankName, accountNumber;
  final VoidCallback? onManage;
  final bool compact;
  const AuraBankCard({
    super.key,
    required this.holderName,
    required this.bankName,
    required this.accountNumber,
    this.onManage,
    this.compact = false,
  });
  @override
  State<AuraBankCard> createState() => _AuraBankCardState();
}

class _AuraBankCardState extends State<AuraBankCard>
    with TickerProviderStateMixin {
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _gloss =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  late final AnimationController _tiltReturn = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));

  bool _revealed = false;
  double _tilX = 0, _tilY = 0, _fromX = 0, _fromY = 0;
  Timer? _glossTimer;

  @override
  void initState() {
    super.initState();
    _tiltReturn.addListener(() {
      setState(() {
        _tilX = lerpDouble(_fromX, 0, _tiltReturn.value)!;
        _tilY = lerpDouble(_fromY, 0, _tiltReturn.value)!;
      });
    });
    _glossTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) _gloss.forward(from: 0);
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _gloss.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _glossTimer?.cancel();
    _flip.dispose();
    _gloss.dispose();
    _tiltReturn.dispose();
    super.dispose();
  }

  void _flipCard() {
    HapticFeedback.selectionClick();
    if (_flip.value > 0.5) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  void _springBack() {
    _fromX = _tilX;
    _fromY = _tilY;
    _tiltReturn.forward(from: 0);
  }

  String get _digits => widget.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      final h = w / 1.586;
      final s = (w / 340).clamp(0.72, 1.25);

      final card = AnimatedBuilder(
        animation: Listenable.merge([_flip, _gloss, _tiltReturn]),
        builder: (context, _) {
          final fa = Curves.easeInOutCubic.transform(_flip.value) * math.pi;
          final back = fa > math.pi / 2;
          final mx = Matrix4.identity()
            ..setEntry(3, 2, 0.0011)
            ..rotateX(_tilX)
            ..rotateY(_tilY + fa);
          return Transform(
            alignment: Alignment.center,
            transform: mx,
            child: back
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: _buildBack(w, h, s),
                  )
                : _buildFront(w, h, s),
          );
        },
      );

      return Column(children: [
        Listener(
          onPointerMove: (e) => _tiltTo(e.localPosition, w, h),
          onPointerHover: (e) => _tiltTo(e.localPosition, w, h),
          onPointerUp: (_) => _springBack(),
          onPointerCancel: (_) => _springBack(),
          child: GestureDetector(
            onTap: _flipCard,
            child: SizedBox(
                width: w, height: h, child: RepaintBoundary(child: card)),
          ),
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: _CardAction(
                    icon: _revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    label: _revealed ? 'លាក់' : 'បង្ហាញ',
                    active: _revealed,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _revealed = !_revealed);
                    })),
            const SizedBox(width: 10),
            Expanded(
                child: _CardAction(
                    icon: Icons.flip_camera_android_rounded,
                    label: 'បត់',
                    onTap: _flipCard)),
            const SizedBox(width: 10),
            Expanded(
                child: _CardAction(
                    icon: Icons.copy_rounded,
                    label: 'ចម្លង',
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.accountNumber));
                      HapticFeedback.selectionClick();
                      toast(context, 'បានចម្លងលេខគណនី');
                    })),
            const SizedBox(width: 10),
            Expanded(
                child: _CardAction(
                    icon: Icons.tune_rounded,
                    label: 'កែប្រែ',
                    onTap: widget.onManage ?? () {})),
          ]),
        ],
      ]);
    });
  }

  void _tiltTo(Offset local, double w, double h) {
    _tiltReturn.stop();
    final nx = (local.dx / w - 0.5).clamp(-0.5, 0.5);
    final ny = (local.dy / h - 0.5).clamp(-0.5, 0.5);
    setState(() {
      _tilY = nx * 0.26;
      _tilX = -ny * 0.22;
    });
  }

  // ── FRONT ──────────────────────────────────────────────────────────────
  Widget _buildFront(double w, double h, double s) {
    final bank = widget.bankName.trim().isEmpty
        ? 'YOUR BANK'
        : widget.bankName.trim().toUpperCase();
    final holder = widget.holderName.trim().isEmpty
        ? 'YOUR NAME'
        : widget.holderName.trim().toUpperCase();
    final number = _revealed ? _groupDigits(_digits) : _maskNumber(_digits);
    final pad = 20 * s;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20 * s),
      child: Stack(fit: StackFit.expand, children: [
        // base gradient
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF061A2F),
                Color(0xFF0E3B57),
                Color(0xFF15698A),
                Color(0xFF0A2740),
              ],
              stops: [0.0, 0.42, 0.78, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // security pattern
        CustomPaint(painter: _CardPatternPainter()),
        // radial glow top-right
        Positioned(
          right: -w * 0.12,
          top: -h * 0.22,
          child: Container(
            width: w * 0.62,
            height: w * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                C.accentTeal.withValues(alpha: 0.34),
                C.accentTeal.withValues(alpha: 0.0),
              ]),
            ),
          ),
        ),
        // gold glow bottom-left
        Positioned(
          left: -w * 0.1,
          bottom: -h * 0.3,
          child: Container(
            width: w * 0.5,
            height: w * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                C.accentGold.withValues(alpha: 0.16),
                C.accentGold.withValues(alpha: 0.0),
              ]),
            ),
          ),
        ),
        // content
        Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // top: bank mark + name | contactless + aura
                Row(children: [
                  Container(
                    width: 30 * s,
                    height: 30 * s,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFF7D774), Color(0xFFC9A227)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(8 * s),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Center(
                        child: Text(_initials(bank),
                            style: TextStyle(
                                color: const Color(0xFF0A2740),
                                fontSize: 13 * s,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3))),
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                      child: Text(bank,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15 * s,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1))),
                  SizedBox(width: 8 * s),
                  SizedBox(
                      width: 22 * s,
                      height: 22 * s,
                      child: CustomPaint(painter: _ContactlessPainter())),
                  SizedBox(width: 8 * s),
                  Text('AURA',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12 * s,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                ]),
                const Spacer(),
                // chip + hologram
                Row(children: [
                  SizedBox(
                      width: 46 * s,
                      height: 36 * s,
                      child: CustomPaint(painter: _ChipPainter())),
                  SizedBox(width: 12 * s),
                  Container(
                    width: 30 * s,
                    height: 22 * s,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5 * s),
                      gradient: SweepGradient(colors: [
                        C.accentGold.withValues(alpha: 0.75),
                        C.accentTeal.withValues(alpha: 0.7),
                        C.accentPurple.withValues(alpha: 0.7),
                        C.accentGreen.withValues(alpha: 0.6),
                        C.accentGold.withValues(alpha: 0.75),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  Text('DEBIT',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9 * s,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                ]),
                SizedBox(height: 14 * s),
                // number
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(number,
                      maxLines: 1,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 21 * s,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2 * s,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                offset: const Offset(0, 1.5),
                                blurRadius: 2),
                          ])),
                ),
                const Spacer(),
                // bottom: holder | valid thru | network
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('CARD HOLDER',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 7.5 * s,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                        SizedBox(height: 3 * s),
                        Text(holder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13 * s,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                      ])),
                  SizedBox(width: 10 * s),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('VALID THRU',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 7.5 * s,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0)),
                    SizedBox(height: 3 * s),
                    Text(_expiry(_digits),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ]),
                  SizedBox(width: 14 * s),
                  Text('VISA',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                offset: const Offset(0, 1),
                                blurRadius: 2),
                          ])),
                ]),
              ]),
        ),
        // gloss sweep
        _glossLayer(w, h),
        // inner edge highlight
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20 * s),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14), width: 1),
            ),
          ),
        ),
      ]),
    );
  }

  // ── BACK ───────────────────────────────────────────────────────────────
  Widget _buildBack(double w, double h, double s) {
    final bank = widget.bankName.trim().isEmpty
        ? 'YOUR BANK'
        : widget.bankName.trim().toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20 * s),
      child: Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A2740), Color(0xFF0E3B57), Color(0xFF061A2F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        CustomPaint(painter: _CardPatternPainter()),
        // magnetic stripe
        Positioned(
          left: 0,
          right: 0,
          top: 24 * s,
          height: 44 * s,
          child: Container(color: const Color(0xFF0B0F14)),
        ),
        // signature + cvv
        Positioned(
          left: 20 * s,
          right: 20 * s,
          top: 84 * s,
          height: 40 * s,
          child: Row(children: [
            Expanded(
                child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE8E2D4),
                borderRadius: BorderRadius.circular(4 * s),
              ),
              child: Stack(children: [
                Positioned.fill(
                    child: CustomPaint(painter: _SignaturePainter())),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8 * s),
                    child: Text('AUTHORIZED SIGNATURE',
                        style: TextStyle(
                            color: const Color(0xFF6B6252),
                            fontSize: 7 * s,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.5)),
                  ),
                ),
              ]),
            )),
            SizedBox(width: 8 * s),
            Container(
              width: 56 * s,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4 * s),
              ),
              child: Center(
                  child: Text(_revealed ? _cvv(_digits) : '•••',
                      style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: 14 * s,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1))),
            ),
          ]),
        ),
        // small print
        Positioned(
          left: 20 * s,
          right: 20 * s,
          top: 138 * s,
          child: Text(
              'កាតនេះជាតំណាងនិម្មិតនៃគណនីដែលបានភ្ជាប់ជាមួយ Aura Bank។ ប្រើប្រាស់ដោយអនុលោមតាមលក្ខខណ្ឌរបស់ធនាគារ។ សេវាអតិថិជន ០២៣ ៨៨៨ ៩៩៩។',
              maxLines: 3,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 8 * s,
                  height: 1.5)),
        ),
        // bottom row
        Positioned(
          left: 20 * s,
          right: 20 * s,
          bottom: 16 * s,
          child: Row(children: [
            Text(bank,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11 * s,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const Spacer(),
            Text('AURA',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11 * s,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            SizedBox(width: 12 * s),
            Text('VISA',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16 * s,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic)),
          ]),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20 * s),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12), width: 1),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _glossLayer(double w, double h) {
    final g = _gloss.value;
    final op = (math.sin(g * math.pi)).clamp(0.0, 1.0) * 0.13;
    if (op <= 0.001) return const SizedBox.shrink();
    final shift = -1.6 + 3.2 * g;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(shift - 0.5, -1),
              end: Alignment(shift + 0.5, 1),
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: op),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

// ── សកម្មភាពក្រោមកាត ───────────────────────────────────────────────────────
class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _CardAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.active = false});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? C.accent.withValues(alpha: 0.5) : context.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(children: [
                Icon(icon,
                    size: 21, color: active ? C.accent : context.muted),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? C.accent : context.muted)),
              ]),
            ),
          ),
        ),
      );
}

// ============================================================================
//  MANAGE SHEET (កែប្រែ / ផ្ដាច់)
// ============================================================================
void _showManageSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    backgroundColor: context.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
              color: ctx.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          const Icon(Icons.account_balance_rounded, color: C.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(bank.bankName,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ctx.ink))),
          Text(_maskNumber(bank.bankAccount),
              style: TextStyle(fontSize: 12.5, color: ctx.muted)),
        ]),
      ),
      const SizedBox(height: 12),
      ListTile(
          leading: const Icon(Icons.edit_outlined, color: C.accent),
          title: const Text('កែប្រែគណនីធនាគារ'),
          subtitle: const Text('ប្ដូរឈ្មោះធនាគារ ឬលេខគណនី'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(ctx);
            push(
                context,
                LinkBankAccountScreen(
                    initialBankName: bank.bankName,
                    initialAccount: bank.bankAccount));
          }),
      ListTile(
          leading: const Icon(Icons.link_off_rounded, color: C.accentRed),
          title: const Text('ផ្ដាច់ការភ្ជាប់',
              style: TextStyle(color: C.accentRed)),
          subtitle: const Text('លុបកាតនេះចេញពីគណនីរបស់អ្នក'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(ctx);
            _confirmUnlink(context);
          }),
      const SizedBox(height: 12),
    ])),
  );
}

void _confirmUnlink(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('ផ្ដាច់ការភ្ជាប់?'),
      content: const Text(
          'កាតនឹងត្រូវបានលុបចេញ។ អ្នកអាចភ្ជាប់គណនីធនាគារម្ដងទៀតបានគ្រប់ពេល។'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('បោះបង់', style: TextStyle(color: ctx.muted))),
        TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await bank.unlinkBankAccount();
                if (context.mounted) toast(context, 'បានផ្ដាច់ការភ្ជាប់');
              } on ApiException catch (e) {
                if (context.mounted) toast(context, e.message, error: true);
              } catch (_) {
                if (context.mounted)
                  toast(context, 'មិនអាចផ្ដាច់បានទេ', error: true);
              }
            },
            child: const Text('ផ្ដាច់',
                style: TextStyle(
                    color: C.accentRed, fontWeight: FontWeight.w700))),
      ],
    ),
  );
}

// ============================================================================
//  LINK BANK ACCOUNT SCREEN (ភ្ជាប់ / កែប្រែ) — ជាមួយ live preview
// ============================================================================
class LinkBankAccountScreen extends StatefulWidget {
  final String? initialBankName, initialAccount;
  const LinkBankAccountScreen(
      {super.key, this.initialBankName, this.initialAccount});
  @override
  State<LinkBankAccountScreen> createState() => _LinkBankAccountScreenState();
}

class _LinkBankAccountScreenState extends State<LinkBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bankCtrl =
      TextEditingController(text: widget.initialBankName ?? '');
  late final TextEditingController _acctCtrl =
      TextEditingController(text: widget.initialAccount ?? '');
  bool _saving = false;

  static const _suggestions = [
    'ABA Bank',
    'ACLEDA Bank',
    'Canadia Bank',
    'Sathapana Bank',
    'Wing Bank',
    'Maybank',
    'PPCBank',
    'Phillip Bank',
  ];

  bool get _isEdit =>
      (widget.initialBankName ?? '').isNotEmpty ||
      (widget.initialAccount ?? '').isNotEmpty;

  @override
  void dispose() {
    _bankCtrl.dispose();
    _acctCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await bank.linkBankAccount(
          name: _bankCtrl.text.trim(), account: _acctCtrl.text.trim());
      if (mounted) {
        toast(context, _isEdit ? 'បានកែប្រែគណនី' : 'បានភ្ជាប់ និងបង្កើតកាត');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'មិនអាចភ្ជាប់បានទេ', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final holder = bank.userName.isEmpty ? 'YOUR NAME' : bank.userName;
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'កែប្រែគណនីធនាគារ' : 'ភ្ជាប់គណនីធនាគារ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          // intro
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AuraGrad.brand,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.add_card_rounded,
                  color: C.accentGold, size: 26),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text(
                      'បញ្ចូលឈ្មោះធនាគារ និងលេខគណនីរបស់អ្នក។ កាតផ្ទាល់ខ្លួននឹងត្រូវបានបង្កើតភ្លាមៗ មានឈ្មោះអ្នក និងឈ្មោះធនាគារ។',
                      style: TextStyle(
                          color: Colors.white, fontSize: 12.5, height: 1.55))),
            ]),
          ),
          const SizedBox(height: 22),
          // live preview
          Text('ការមើលជាមុន',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.muted,
                  letterSpacing: 0.3)),
          const SizedBox(height: 12),
          AuraBankCard(
            holderName: holder,
            bankName: _bankCtrl.text,
            accountNumber: _acctCtrl.text,
            compact: true,
          ),
          const SizedBox(height: 24),
          // form
          Form(
            key: _formKey,
            child: Column(children: [
              NeuField(
                controller: _bankCtrl,
                label: 'ឈ្មោះធនាគារ',
                icon: Icons.account_balance_rounded,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 2) return 'សូមបញ្ចូលឈ្មោះធនាគារ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions
                      .map((b) => _suggestionChip(b))
                      .toList()),
              const SizedBox(height: 18),
              NeuField(
                controller: _acctCtrl,
                label: 'លេខគណនីធនាគារ',
                icon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
                maxLength: 30,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final d = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                  if (!RegExp(r'^[0-9]{6,30}$').hasMatch(d))
                    return 'លេខគណនីត្រូវមាន ៦–៣០ ខ្ទង់';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              NeuBox(
                inset: true,
                child: Row(children: [
                  Icon(Icons.person_outline_rounded,
                      color: context.muted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('ម្ចាស់កាត',
                            style: TextStyle(
                                fontSize: 11.5, color: context.muted)),
                        const SizedBox(height: 3),
                        Text(holder.toUpperCase(),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.ink)),
                      ])),
                  Icon(Icons.verified_outlined,
                      color: C.accentGreen.withValues(alpha: 0.8), size: 18),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          NeuButton(
            label: _saving
                ? 'កំពុងរក្សាទុក...'
                : (_isEdit ? 'រក្សាទុកការកែប្រែ' : 'ភ្ជាប់ និងបង្កើតកាត'),
            icon: _saving ? null : Icons.check_circle_outline_rounded,
            onPressed: _saving ? null : _submit,
          ),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline, size: 15, color: context.muted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    'ព័ត៌មានគណនីរបស់អ្នកត្រូវបានរក្សាទុកដោយសុវត្ថិភាពនៅលើម៉ាស៊ីនមូលដ្ឋានរបស់ Aura Bank។',
                    style: TextStyle(
                        fontSize: 11.5, height: 1.5, color: context.muted))),
          ]),
        ],
      ),
    );
  }

  Widget _suggestionChip(String b) {
    final selected = _bankCtrl.text.trim().toLowerCase() == b.toLowerCase();
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _bankCtrl.text = b);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? C.accent : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? C.accent : context.border, width: 1.1),
        ),
        child: Text(b,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : context.muted)),
      ),
    );
  }
}

// ============================================================================
//  HELPERS
// ============================================================================
String _groupDigits(String d) {
  if (d.isEmpty) return '•••• •••• •••• ••••';
  final buf = StringBuffer();
  for (int i = 0; i < d.length; i++) {
    if (i > 0 && i % 4 == 0) buf.write(' ');
    buf.write(d[i]);
  }
  return buf.toString();
}

String _maskNumber(String account) {
  final d = account.replaceAll(RegExp(r'[^0-9]'), '');
  final last4 = d.length >= 4 ? d.substring(d.length - 4) : d;
  return '•••• •••• •••• ${last4.isEmpty ? '••••' : last4}';
}

String _initials(String bank) {
  final words =
      bank.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'B';
  if (words.length == 1) {
    return words[0].substring(0, math.min(2, words[0].length)).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

int _seed(String d) {
  int h = 7;
  for (final c in d.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

String _expiry(String d) {
  final s = _seed(d);
  final m = 1 + (s % 12);
  final y = (DateTime.now().year + 3 + (s % 4)) % 100;
  return '${m.toString().padLeft(2, '0')}/${y.toString().padLeft(2, '0')}';
}

String _cvv(String d) {
  if (d.isEmpty) return '•••';
  return (100 + (_seed(d) % 900)).toString();
}

// ============================================================================
//  PAINTERS
// ============================================================================
class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    // fine diagonal lattice
    const step = 15.0;
    final path = Path();
    for (double x = -size.height; x < size.width + size.height; x += step) {
      path
        ..moveTo(x, 0)
        ..lineTo(x + size.height, size.height);
    }
    canvas.drawPath(path, p);
    // guilloché arcs bottom-right
    final c = Offset(size.width * 0.92, size.height * 1.05);
    final arc = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (double r = 20; r < size.width * 0.9; r += 12) {
      canvas.drawCircle(c, r, arc);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.width * 0.16));
    final fill = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFBE9A8), Color(0xFFE3C05C), Color(0xFFC9A227)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRRect(r, fill);
    final line = Paint()
      ..color = const Color(0xFF8A6D1A).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028;
    // inner pad
    final inset = size.width * 0.16;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(inset, inset, size.width - inset * 2,
                size.height - inset * 2),
            Radius.circular(size.width * 0.08)),
        line);
    // contact divisions
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawLine(Offset(cx, inset), Offset(cx, size.height - inset), line);
    canvas.drawLine(Offset(inset, cy), Offset(size.width - inset, cy), line);
    canvas.drawLine(Offset(inset, size.height * 0.34),
        Offset(cx, size.height * 0.34), line);
    canvas.drawLine(Offset(cx, size.height * 0.66),
        Offset(size.width - inset, size.height * 0.66), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ContactlessPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width * 0.18, size.height * 0.5);
    for (int i = 0; i < 4; i++) {
      final r = size.width * (0.2 + i * 0.2);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), -0.7, 1.4,
          false, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SignaturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF3A4A6B).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.62)
      ..cubicTo(size.width * 0.58, size.height * 0.2, size.width * 0.64,
          size.height * 0.85, size.width * 0.72, size.height * 0.42)
      ..cubicTo(size.width * 0.78, size.height * 0.18, size.width * 0.84,
          size.height * 0.72, size.width * 0.93, size.height * 0.4);
    canvas.drawPath(path, p);
    // faint repeated lines
    final faint = Paint()
      ..color = const Color(0xFF9A917C).withValues(alpha: 0.4)
      ..strokeWidth = 0.6;
    for (double y = size.height * 0.3; y < size.height; y += size.height * 0.22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), faint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  _DashedRRectPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
          const Radius.circular(18)));
    const dash = 9.0, gap = 7.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final len = math.min(dash, metric.length - dist);
        canvas.drawPath(metric.extractPath(dist, dist + len), p);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}