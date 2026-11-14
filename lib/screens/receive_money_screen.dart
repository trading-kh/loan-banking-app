// ============================================================================
//  UNAVAILABLE FEATURE — មុខងារមិនទាន់ដំណើរការ (ទទួលប្រាក់ · ទូទាត់ប្រាក់ · សន្សំ)
//  អេក្រង់សារស្អាតៗ + icon animation
// ============================================================================
import 'package:flutter/material.dart';

import '../main.dart';

class UnavailableFeatureScreen extends StatefulWidget {
  /// ឈ្មោះមុខងារ — បង្ហាញលើ AppBar និងក្នុងអត្ថបទ
  final String label;
  /// Icon ក្នុងរង្វង់ gradient (ទំហំ 44 · ពណ៌ស)
  final Widget icon;
  const UnavailableFeatureScreen(
      {super.key, required this.label, required this.icon});

  @override
  State<UnavailableFeatureScreen> createState() =>
      _UnavailableFeatureScreenState();
}

class _UnavailableFeatureScreenState extends State<UnavailableFeatureScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.label)),
        body: Container(
          decoration: const BoxDecoration(gradient: AuraGrad.soft),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, __) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                        offset: Offset(0, 26 * (1 - t)),
                        child: _content(context)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _content(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 184,
            height: 184,
            child: Stack(alignment: Alignment.center, children: [
              ..._rings(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [C.accentTeal, C.accentGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: C.accentTeal.withValues(alpha: 0.4),
                      offset: const Offset(0, 14),
                      blurRadius: 30,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Center(child: widget.icon),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: C.accentGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: C.accentGold.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: C.accentGold, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              const Text('មិនអាចប្រើប្រាស់បាន',
                  style: TextStyle(
                      color: C.accentGold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          Text('មុខងារនេះមិនទាន់ដំណើរការ',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
              'បច្ចុប្បន្នមុខងារ "${widget.label}" មិនដំណើរការទេក្នុងពេលនេះ។\n'
              'យើងកំពុងអភិវឌ្ឍវា ហើយនឹងប្រកាសឱ្យដឹងឆាប់ៗខាងមុខ។',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.muted, fontSize: 13, height: 1.65)),
          const SizedBox(height: 24),
          NeuBox(
            inset: true,
            radius: 14,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: C.accentGold, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text('សូមអភ័យទោសសម្រាប់ការរអាក់រអួល។',
                    style:
                        TextStyle(color: context.muted, fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 26),
          NeuButton(
              label: 'ត្រឡប់ក្រោយ',
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.pop(context)),
        ],
      );

  /// រង្វង់ពន្លឺពីក្រោយ icon — ពង្រីកចេញថ្នមៗ
  List<Widget> _rings() => [
        for (var i = 0; i < 2; i++)
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = (_pulse.value + i * 0.5) % 1.0;
              final size = 96 + 72 * t;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        C.accentTeal.withValues(alpha: 0.34 * (1 - t)),
                    width: 1.4,
                  ),
                ),
              );
            },
          ),
      ];
}

class ReceiveMoneyScreen extends StatelessWidget {
  const ReceiveMoneyScreen({super.key});
  @override
  Widget build(BuildContext context) => const UnavailableFeatureScreen(
        label: 'ទទួលប្រាក់',
        icon: ReceiveMoneyGlyph(size: 44, color: Colors.white),
      );
}

// ============================================================================
//  RECEIVE GLYPH — គូរដោយដៃ (មិនពឹងលើ icon font — បង្ហាញគ្រប់ platform/web)
//  ព្រួញចុះចូល "ថាស" (ដូច inbox) = ទទួលប្រាក់
// ============================================================================
class ReceiveMoneyGlyph extends StatelessWidget {
  final double size;
  final Color color;
  const ReceiveMoneyGlyph(
      {super.key, required this.size, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ReceiveGlyphPainter(color)),
      );
}

class _ReceiveGlyphPainter extends CustomPainter {
  final Color color;
  _ReceiveGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ដងព្រួញ
    canvas.drawLine(
        Offset(s * 0.5, s * 0.12), Offset(s * 0.5, s * 0.56), p);
    // ក្បាលព្រួញ
    canvas.drawPath(
        Path()
          ..moveTo(s * 0.33, s * 0.40)
          ..lineTo(s * 0.5, s * 0.57)
          ..lineTo(s * 0.67, s * 0.40),
        p);
    // ថាសទទួល (open tray)
    canvas.drawPath(
        Path()
          ..moveTo(s * 0.15, s * 0.64)
          ..lineTo(s * 0.15, s * 0.79)
          ..quadraticBezierTo(s * 0.15, s * 0.90, s * 0.26, s * 0.90)
          ..lineTo(s * 0.74, s * 0.90)
          ..quadraticBezierTo(s * 0.85, s * 0.90, s * 0.85, s * 0.79)
          ..lineTo(s * 0.85, s * 0.64),
        p);
  }

  @override
  bool shouldRepaint(covariant _ReceiveGlyphPainter old) =>
      old.color != color;
}
