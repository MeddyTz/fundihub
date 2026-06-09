// Provides: AppLoader, AppLoaderCenter, AppWrenchLoader, TechnicalLoader,
//           BookingLoader, FundiLoadingCard, RadarLoader, PulseLoader
// AppLoadingOverlay lives in app_loading_overlay.dart — not duplicated here.
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ── Custom arc spinner ────────────────────────────────────────────────────────

class AppLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const AppLoader({super.key, this.size = 24, this.color});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _ArcPainter(
            progress: _ctrl.value,
            color: widget.color ?? AppColors.primary,
            strokeWidth: widget.size * 0.12,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _ArcPainter({required this.progress, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = color.withOpacity(0.12)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + 2 * math.pi * progress,
      math.pi * 1.2,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Animated wrench icon ──────────────────────────────────────────────────────

class AppWrenchLoader extends StatefulWidget {
  const AppWrenchLoader({super.key});
  @override
  State<AppWrenchLoader> createState() => _AppWrenchLoaderState();
}

class _AppWrenchLoaderState extends State<AppWrenchLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rot;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _rot = Tween<double>(begin: -0.3, end: 0.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Transform.rotate(
          angle: _rot.value,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

// ── AppLoaderCenter ───────────────────────────────────────────────────────────

class AppLoaderCenter extends StatelessWidget {
  final Color color;
  const AppLoaderCenter({super.key, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) =>
      Center(child: AppLoader(size: 36, color: color));
}

// ── TechnicalLoader — spinning dual-ring with hub dot ─────────────────────────
// Used for: home screen, category loading, technical heavy screens

class TechnicalLoader extends StatefulWidget {
  final double size;
  final String? message;
  const TechnicalLoader({super.key, this.size = 56, this.message});

  @override
  State<TechnicalLoader> createState() => _TechnicalLoaderState();
}

class _TechnicalLoaderState extends State<TechnicalLoader>
    with TickerProviderStateMixin {
  late final AnimationController _outerCtrl;
  late final AnimationController _innerCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _outerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _innerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: false);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _outerCtrl.dispose();
    _innerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: s,
          height: s,
          child: AnimatedBuilder(
            animation: Listenable.merge([_outerCtrl, _innerCtrl, _pulseCtrl]),
            builder: (_, __) => CustomPaint(
              painter: _TechPainter(
                outer: _outerCtrl.value,
                inner: _innerCtrl.value,
                pulse: _pulse.value,
              ),
            ),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 14),
          _AnimatedLoadingText(message: widget.message!),
        ],
      ],
    );
  }
}

class _TechPainter extends CustomPainter {
  final double outer;
  final double inner;
  final double pulse;
  _TechPainter({required this.outer, required this.inner, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Outer ring track
    canvas.drawCircle(
      center, cx - 4,
      Paint()
        ..color = AppColors.primary.withOpacity(0.10)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke,
    );
    // Outer arc (clockwise)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: cx - 4),
      -math.pi / 2 + 2 * math.pi * outer,
      math.pi * 1.1,
      false,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Inner ring track
    canvas.drawCircle(
      center, cx * 0.56,
      Paint()
        ..color = AppColors.secondary.withOpacity(0.12)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    // Inner arc (counter-clockwise)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: cx * 0.56),
      math.pi / 2 - 2 * math.pi * inner,
      math.pi * 0.9,
      false,
      Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Centre hub pulsing dot
    final dotR = (cx * 0.15) * pulse;
    canvas.drawCircle(
      center, dotR,
      Paint()..color = AppColors.primary.withOpacity(0.85),
    );
    canvas.drawCircle(
      center, dotR * 0.5,
      Paint()..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(_TechPainter old) => true;
}

// ── BookingLoader — progress steps with pulsing icons ─────────────────────────
// Used specifically for booking accept / update screens

class BookingLoader extends StatefulWidget {
  final String? message;
  const BookingLoader({super.key, this.message});

  @override
  State<BookingLoader> createState() => _BookingLoaderState();
}

class _BookingLoaderState extends State<BookingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;
  late final Animation<double> _scale;
  int _stepIndex = 0;
  static const _steps = [
    (Icons.assignment_outlined, 'Updating booking...'),
    (Icons.notifications_active_outlined, 'Sending notification...'),
    (Icons.chat_bubble_outline_rounded, 'Setting up secure chat...'),
    (Icons.check_circle_outline_rounded, 'Almost done...'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat();
    _rotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_ctrl);
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 800), _nextStep);
  }

  void _nextStep() {
    if (!mounted) return;
    setState(() => _stepIndex = (_stepIndex + 1) % _steps.length);
    Future.delayed(const Duration(milliseconds: 900), _nextStep);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_stepIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(step.$1, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            widget.message ?? step.$2,
            key: ValueKey(_stepIndex),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        // Mini step dots
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_steps.length, (i) {
            final active = i == _stepIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.primary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── RadarLoader — scanning pulse for "Finding nearby fundis" ──────────────────

class RadarLoader extends StatefulWidget {
  final double size;
  final String? message;
  const RadarLoader({super.key, this.size = 80, this.message});

  @override
  State<RadarLoader> createState() => _RadarLoaderState();
}

class _RadarLoaderState extends State<RadarLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _RadarPainter(progress: _ctrl.value),
            ),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          _AnimatedLoadingText(message: widget.message!),
        ],
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Concentric circles
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        cx * i / 3,
        Paint()
          ..color = AppColors.primary.withOpacity(0.08 * (4 - i))
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    // Sweep gradient arc
    final sweepAngle = 2 * math.pi * progress;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 1.8,
        endAngle: sweepAngle,
        colors: [
          AppColors.primary.withOpacity(0),
          AppColors.primary.withOpacity(0.35),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: cx))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, cx, sweepPaint);

    // Leading edge line
    final ex = cx + cx * math.cos(sweepAngle - math.pi / 2);
    final ey = cy + cx * math.sin(sweepAngle - math.pi / 2);
    canvas.drawLine(
      center,
      Offset(ex, ey),
      Paint()
        ..color = AppColors.primary.withOpacity(0.7)
        ..strokeWidth = 1.5,
    );

    // Center dot
    canvas.drawCircle(center, 4, Paint()..color = AppColors.primary);

    // Blip dot at ~120°
    final blipAngle = sweepAngle + math.pi * 0.7;
    final blipR = cx * 0.55;
    final bx = cx + blipR * math.cos(blipAngle - math.pi / 2);
    final by = cy + blipR * math.sin(blipAngle - math.pi / 2);
    final blipOpacity = (math.sin(progress * math.pi * 4) * 0.5 + 0.5).clamp(0.2, 1.0);
    canvas.drawCircle(
      Offset(bx, by),
      3.5,
      Paint()..color = AppColors.secondary.withOpacity(blipOpacity),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}

// ── PulseLoader — pulsing glow hub for "Connecting service..." ────────────────

class PulseLoader extends StatefulWidget {
  final double size;
  final String? message;
  final Color? color;
  const PulseLoader({super.key, this.size = 60, this.message, this.color});

  @override
  State<PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<PulseLoader>
    with TickerProviderStateMixin {
  late final AnimationController _ripple1;
  late final AnimationController _ripple2;
  late final AnimationController _icon;

  @override
  void initState() {
    super.initState();
    _ripple1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _ripple2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _icon = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    // Offset the second ripple
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _ripple2.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _ripple1.dispose();
    _ripple2.dispose();
    _icon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.color ?? AppColors.primary;
    final s = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: s * 2.2,
          height: s * 2.2,
          child: AnimatedBuilder(
            animation: Listenable.merge([_ripple1, _ripple2, _icon]),
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple 1
                  Opacity(
                    opacity: (1 - _ripple1.value).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.5 + _ripple1.value * 1.0,
                      child: Container(
                        width: s * 2,
                        height: s * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: col.withOpacity(0.4), width: 2),
                        ),
                      ),
                    ),
                  ),
                  // Ripple 2
                  Opacity(
                    opacity: (1 - _ripple2.value).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.5 + _ripple2.value * 1.0,
                      child: Container(
                        width: s * 2,
                        height: s * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: col.withOpacity(0.25), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // Icon container
                  Transform.scale(
                    scale: 0.93 + _icon.value * 0.07,
                    child: Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [col, col.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: col.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(Icons.hub_rounded, color: Colors.white, size: s * 0.45),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 10),
          _AnimatedLoadingText(message: widget.message!),
        ],
      ],
    );
  }
}

// ── FundiLoadingCard — skeleton for fundi list items ──────────────────────────
// (re-exports from app_shimmer for convenience)

// ── Animated loading text with cycling ellipsis ───────────────────────────────

class _AnimatedLoadingText extends StatefulWidget {
  final String message;
  const _AnimatedLoadingText({required this.message});

  @override
  State<_AnimatedLoadingText> createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<_AnimatedLoadingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addListener(() {
        if (_ctrl.value >= 1.0) {
          _ctrl.forward(from: 0);
          if (mounted) setState(() => _dots = _dots % 3 + 1);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.message}${'.' * _dots}',
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ── Contextual loading messages ───────────────────────────────────────────────

class LoadingMessages {
  static const findingFundis = 'Finding nearby fundis';
  static const settingUpChat = 'Setting up secure chat';
  static const connectingService = 'Connecting service';
  static const preparingWorkspace = 'Preparing your workspace';
  static const loadingProfessionals = 'Loading professionals';
  static const acceptingBooking = 'Accepting booking';
  static const sendingNotification = 'Sending notification';
  static const updatingProfile = 'Updating profile';
  static const processingPayment = 'Processing payment';
  static const loadingBookings = 'Loading bookings';
}
