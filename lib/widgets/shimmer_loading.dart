import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ShimmerLoading extends StatefulWidget {
  final int itemCount;

  const ShimmerLoading({super.key, this.itemCount = 3});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          children: List.generate(widget.itemCount, (index) {
            final delay = index * 0.15;
            final t = ((_controller.value + delay) % 1.0);
            final opacity = 0.3 + (0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0));

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                height: index == 0 ? 120 : 72,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(0.04)),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
