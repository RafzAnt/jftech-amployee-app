import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The bright line that sweeps up and down over the QR frame while the camera is looking for a code. [animation] runs from 0 (top) to 1
/// (bottom); the caller makes it repeat back and forth. A soft glow trails the line on the side it has just passed.
class ScanLine extends StatelessWidget {
  final Animation<double> animation;
  final double radius;

  const ScanLine({super.key, required this.animation, this.radius = 16});

  static const double _lineHeight = 3;
  static const double _glowHeight = 56;
  static const double _margin = 8;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, box) => AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final travel = box.maxHeight - 2 * _margin - _lineHeight;
                final top = _margin + Curves.easeInOut.transform(animation.value.clamp(0.0, 1.0)) * travel;
                // Going down, the glow is above the line; going up, below it.
                final goingDown = animation.status != AnimationStatus.reverse;
                final glow = Container(
                  height: _glowHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: goingDown ? Alignment.topCenter : Alignment.bottomCenter,
                      end: goingDown ? Alignment.bottomCenter : Alignment.topCenter,
                      colors: [AppColors.primary.withValues(alpha: 0), AppColors.primary.withValues(alpha: 0.32)],
                    ),
                  ),
                );
                return Stack(
                  children: [
                    Positioned(top: goingDown ? top - _glowHeight : top + _lineHeight, left: 0, right: 0, child: glow),
                    Positioned(
                      top: top,
                      left: 12,
                      right: 12,
                      child: Container(
                        height: _lineHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0),
                              const Color(0xFF9CC4FF),
                              AppColors.primary.withValues(alpha: 0),
                            ],
                          ),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.9), blurRadius: 12, spreadRadius: 1)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}
