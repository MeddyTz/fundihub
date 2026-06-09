import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ── Premium shimmer animation ─────────────────────────────────────────────────
// Uses a sweeping diagonal gradient for a high-end look.

class AppShimmer extends StatefulWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: const Alignment(-1.5, -0.3),
            end: const Alignment(1.5, 0.3),
            colors: const [
              Color(0xFFEEEEEE),
              Color(0xFFF8F8F8),
              Color(0xFFFFFFFF),
              Color(0xFFF8F8F8),
              Color(0xFFEEEEEE),
            ],
            stops: [
              0.0,
              (_anim.value * 0.25 + 0.35).clamp(0.0, 1.0),
              (_anim.value * 0.25 + 0.5).clamp(0.0, 1.0),
              (_anim.value * 0.25 + 0.65).clamp(0.0, 1.0),
              1.0,
            ],
          ).createShader(bounds),
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── Shimmer box ───────────────────────────────────────────────────────────────

class ShimmerBox extends StatelessWidget {
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
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ── Fundi card shimmer ────────────────────────────────────────────────────────

class FundiCardShimmer extends StatelessWidget {
  const FundiCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const ShimmerBox(width: 62, height: 62, radius: 31),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.38,
                    height: 14,
                    radius: 7),
                const SizedBox(height: 7),
                ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.26,
                    height: 11,
                    radius: 6),
                const SizedBox(height: 8),
                const Row(children: [
                  ShimmerBox(width: 55, height: 9, radius: 5),
                  SizedBox(width: 8),
                  ShimmerBox(width: 45, height: 9, radius: 5),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const ShimmerBox(width: 70, height: 34, radius: 12),
        ]),
      ),
    );
  }
}

typedef FundiLoadingCard = FundiCardShimmer;

// ── Booking card shimmer ──────────────────────────────────────────────────────

class BookingCardShimmer extends StatelessWidget {
  const BookingCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar placeholder
            Container(
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEEE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const ShimmerBox(width: 48, height: 48, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(
                              width: MediaQuery.of(context).size.width * 0.4,
                              height: 14,
                              radius: 7),
                          const SizedBox(height: 6),
                          const ShimmerBox(width: 80, height: 10, radius: 5),
                        ],
                      ),
                    ),
                    const ShimmerBox(width: 70, height: 26, radius: 13),
                  ]),
                  const SizedBox(height: 12),
                  const ShimmerBox(width: double.infinity, height: 10, radius: 5),
                  const SizedBox(height: 6),
                  ShimmerBox(
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: 10,
                      radius: 5),
                  const SizedBox(height: 14),
                  // Action button placeholders
                  Row(children: const [
                    Expanded(child: ShimmerBox(height: 44, radius: 12)),
                    SizedBox(width: 10),
                    Expanded(flex: 2, child: ShimmerBox(height: 44, radius: 12)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin stat shimmer ────────────────────────────────────────────────────────

class AdminStatShimmer extends StatelessWidget {
  const AdminStatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      const cols = 2, gap = 12.0;
      final w = (constraints.maxWidth - gap) / cols;
      final h = (w * 0.65).clamp(90.0, 130.0);
      return AppShimmer(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
              6,
              (_) => Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  )),
        ),
      );
    });
  }
}

// ── Notification item shimmer ─────────────────────────────────────────────────

class NotifItemShimmer extends StatelessWidget {
  const NotifItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const ShimmerBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 60, height: 8, radius: 4),
                const SizedBox(height: 6),
                ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: 13,
                    radius: 6),
                const SizedBox(height: 5),
                const ShimmerBox(width: double.infinity, height: 9, radius: 4),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Chat list item shimmer ────────────────────────────────────────────────────

class ChatItemShimmer extends StatelessWidget {
  const ChatItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          const ShimmerBox(width: 54, height: 54, radius: 27),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ShimmerBox(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: 13,
                      radius: 6),
                  const Spacer(),
                  const ShimmerBox(width: 38, height: 10, radius: 5),
                ]),
                const SizedBox(height: 7),
                ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.55,
                    height: 10,
                    radius: 5),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Category shimmer ──────────────────────────────────────────────────────────

class CategoryShimmer extends StatelessWidget {
  const CategoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SizedBox(
        height: 82,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) =>
              const ShimmerBox(width: 74, height: 74, radius: 18),
        ),
      ),
    );
  }
}

// ── Dashboard hero shimmer ────────────────────────────────────────────────────

class DashboardHeroShimmer extends StatelessWidget {
  const DashboardHeroShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 180,
            color: const Color(0xFFDDDDDD),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CategoryShimmer(),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              FundiCardShimmer(),
              FundiCardShimmer(),
              FundiCardShimmer(),
            ]),
          ),
        ],
      ),
    );
  }
}
