// ============================================================================
//  Onboarding — 3 ទំព័រសម្រាប់អ្នកប្រើថ្មី
// ============================================================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final IconData icon;
  final String title, description;
  final Color color;
  const _Slide({required this.icon, required this.title,
      required this.description, required this.color});
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.account_balance_wallet,
      title: 'គ្រប់គ្រងប្រាក់កាន់តែងាយ',
      description: 'គណនី កាត ប្រតិបត្តិការ និងការវិភាគ — ទាំងអស់នៅកន្លែងតែមួយ',
      color: C.accent,
    ),
    _Slide(
      icon: Icons.qr_code_scanner,
      title: 'ទូទាត់លឿន សុវត្ថិភាព',
      description: 'ស្កេន KHQR ផ្ទេរប្រាក់ និងបង់វិក្កយបត្រក្នុងរយៈពេលប៉ុន្មានវិនាទី',
      color: C.accentPurple,
    ),
    _Slide(
      icon: Icons.insights,
      title: 'តាមដានចំណាយ',
      description: 'ការវិភាគចំណាយ ថវិកា និងសន្សំប្រាក់ឲ្យមានប្រសិទ្ធភាព',
      color: C.accentGreen,
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('has_seen_onboarding_v1', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const RegistrationScreen(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Header: Logo + Skip
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: C.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text('Loan Banking',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.ink)),
                ]),
                if (_page < _slides.length - 1)
                  TextButton(
                    onPressed: _complete,
                    child: Text('រំលង',
                        style: TextStyle(
                            color: context.muted,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  const SizedBox(width: 56),
              ],
            ),
          ),

          // Slides
          Expanded(
            child: PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _slides.length,
              itemBuilder: (_, i) => _buildSlide(_slides[i], i),
            ),
          ),

          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final on = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: on
                      ? _slides[_page].color
                      : context.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // CTA Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: NeuButton(
              label: _page < _slides.length - 1 ? 'បន្ទាត់បន្ទាប់' : 'ចាប់ផ្តើម',
              icon: _page < _slides.length - 1
                  ? Icons.arrow_forward
                  : Icons.rocket_launch,
              accent: _slides[_page].color,
              onPressed: () {
                if (_page < _slides.length - 1) {
                  _pc.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic);
                } else {
                  _complete();
                }
              },
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildSlide(_Slide s, int index) {
    // Animation សម្រាប់ slide បច្ចុប្បន្នតែប៉ុណ្ណោះ
    final isActive = index == _page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('slide_$index'),
            tween: Tween(begin: isActive ? 0.6 : 1, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              padding: const EdgeInsets.all(44),
              decoration: BoxDecoration(
                color: context.bg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: context.shadowLight,
                      offset: const Offset(-12, -12),
                      blurRadius: 24),
                  BoxShadow(
                      color: context.shadowDark,
                      offset: const Offset(12, 12),
                      blurRadius: 24),
                ],
              ),
              child: Icon(s.icon, size: 88, color: s.color),
            ),
          ),
          const SizedBox(height: 52),
          Text(s.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                  height: 1.3)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(s.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: context.muted, height: 1.6)),
          ),
        ],
      ),
    );
  }
}