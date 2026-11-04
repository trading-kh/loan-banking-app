// ============================================================================
//  UI Extras — Empty State, Shimmer, Refresh Helper
// ============================================================================
import 'package:flutter/material.dart';
import 'main.dart';

// ============================================================
//  EMPTY STATE — ពេលគ្មានទិន្នន័យ
// ============================================================
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.accent;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Neumorphic circle with icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: context.bg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: context.shadowLight,
                      offset: const Offset(-8, -8),
                      blurRadius: 20),
                  BoxShadow(
                      color: context.shadowDark,
                      offset: const Offset(8, 8),
                      blurRadius: 20),
                ],
              ),
              child: Icon(icon, size: 64, color: c.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 28),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.ink)),
            if (description != null) ...[
              const SizedBox(height: 10),
              Text(description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: context.muted, height: 1.5)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              NeuButton(
                label: actionLabel!,
                icon: Icons.add,
                fullWidth: false,
                accent: c,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  SHIMMER BOX — skeleton loading
// ============================================================
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [
                context.shadowDark.withValues(alpha: 0.06),
                context.shadowLight.withValues(alpha: 0.7),
                context.shadowDark.withValues(alpha: 0.06),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
//  LIST SKELETON — បង្ហាញពេល Load data
// ============================================================
class ListSkeleton extends StatelessWidget {
  final int count;
  const ListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          const ShimmerBox(width: 48, height: 48, radius: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: double.infinity, height: 14, radius: 6),
                SizedBox(height: 8),
                ShimmerBox(width: 120, height: 12, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ShimmerBox(width: 70, height: 16, radius: 6),
        ]),
      ),
    );
  }
}

// ============================================================
//  CARD SKELETON — skeleton សម្រាប់កាត
// ============================================================
class CardsSkeleton extends StatelessWidget {
  const CardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: ShimmerBox(
            width: double.infinity, height: 190, radius: 22),
      ),
    );
  }
}