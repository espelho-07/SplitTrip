import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Subtle pulsing skeleton loader.
class ShimmerSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceSubtle;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _opacityAnim,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: _opacityAnim.value),
              borderRadius: widget.borderRadius ?? AppRadius.mdBorder,
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer card for expense list items
class ExpenseCardSkeleton extends StatelessWidget {
  const ExpenseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceCard
              : AppColors.lightSurfaceCard,
          borderRadius: AppRadius.mdBorder,
        ),
        child: Row(
          children: [
            const ShimmerSkeleton(width: 44, height: 44, borderRadius: AppRadius.fullBorder),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: MediaQuery.of(context).size.width * 0.45, height: 16),
                  const SizedBox(height: 8),
                  ShimmerSkeleton(width: MediaQuery.of(context).size.width * 0.25, height: 12),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ShimmerSkeleton(width: 60, height: 20),
          ],
        ),
      ),
    );
  }
}

/// Shimmer list of multiple expense items
class ExpenseListSkeleton extends StatelessWidget {
  final int count;
  const ExpenseListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, index) => const ExpenseCardSkeleton(),
    );
  }
}

/// Shimmer card for hero balance summary
class BalanceCardSkeleton extends StatelessWidget {
  const BalanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceCard
              : AppColors.lightSurfaceCard,
          borderRadius: AppRadius.lgBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerSkeleton(width: 120, height: 14),
            const SizedBox(height: 12),
            const ShimmerSkeleton(width: 180, height: 32),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerSkeleton(width: 100, height: 16),
                ShimmerSkeleton(width: 100, height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer timeline for Person Ledger conversational chat
class PersonLedgerSkeleton extends StatelessWidget {
  const PersonLedgerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Hero Balance Skeleton
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceCard
                : AppColors.lightSurfaceCard,
            borderRadius: AppRadius.lgBorder,
          ),
          child: Column(
            children: const [
              ShimmerSkeleton(width: 140, height: 14),
              SizedBox(height: 10),
              ShimmerSkeleton(width: 160, height: 30),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Timeline Bubbles
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceSubtle
                  : AppColors.lightSurfaceSubtle,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerSkeleton(width: 120, height: 14),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 80, height: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceElevated
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                ShimmerSkeleton(width: 140, height: 14),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 90, height: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.65,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceSubtle
                  : AppColors.lightSurfaceSubtle,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerSkeleton(width: 110, height: 14),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 70, height: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
