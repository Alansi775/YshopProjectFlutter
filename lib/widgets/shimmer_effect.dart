// lib/widgets/shimmer_effect.dart

import 'package:flutter/material.dart';

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerEffect({
    Key? key,
    required this.child,
    this.baseColor = const Color(0xFFEBEBF4), // Light background fill
    this.highlightColor = const Color(0xFFF4F4F4), // Shimmering light
  }) : super(key: key);

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      // تحديد المظهر اللامع
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
          stops: const [0.1, 0.3, 0.5], // توزيع الألوان
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
          // تحريك الـ Gradient من اليسار لليمين
          transform: _SlidingGradientTransform(
            slidePercent: _shimmerController.value,
          ),
        ).createShader(bounds);
      },
      // يجعل الـ Shimmer يطبق على المحتوى الفعلي
      blendMode: BlendMode.srcATop,
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // تحريك الـ gradient
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}