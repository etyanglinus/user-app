import 'dart:math' as math;

import 'package:flutter/material.dart';

class UnlockModuleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Color? ringColor;
  final Duration duration;

  const UnlockModuleTap({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.ringColor,
    this.duration = const Duration(milliseconds: 380),
  });

  @override
  State<UnlockModuleTap> createState() => _UnlockModuleTapState();
}

class _UnlockModuleTapState extends State<UnlockModuleTap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  bool _isUnlocking = false;

  Future<void> _handleTap() async {
    if (_isUnlocking) return;

    _isUnlocking = true;
    await _controller.forward(from: 0);
    if (mounted) {
      widget.onTap();
    }
    _isUnlocking = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color ringColor = widget.ringColor ?? Theme.of(context).primaryColor;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final double progress = Curves.easeOutCubic.transform(_controller.value);
        final double pulse = math.sin(_controller.value * math.pi) * 0.035;

        return Transform.scale(
          scale: 1 + pulse,
          child: CustomPaint(
            foregroundPainter: _UnlockRingPainter(progress: progress, color: ringColor),
            child: Material(
              color: Colors.transparent,
              borderRadius: widget.borderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: widget.borderRadius,
                onTap: _handleTap,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnlockRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _UnlockRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final Rect rect = Offset.zero & size;
    final Rect ringRect = rect.deflate(3);
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _UnlockRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}