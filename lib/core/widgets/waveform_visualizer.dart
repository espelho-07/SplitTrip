import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Sinusoidal audio waveform visualizer for recording / voice recognition states.
class WaveformVisualizer extends StatefulWidget {
  final bool isListening;
  final int barCount;
  final double height;
  final Color? color;

  const WaveformVisualizer({
    super.key,
    required this.isListening,
    this.barCount = 28,
    this.height = 48.0,
    this.color,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isListening) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!widget.isListening && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.color ?? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return SizedBox(
            height: widget.height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(widget.barCount, (index) {
                double barHeightFactor;
                if (widget.isListening) {
                  final wavePhase = _animController.value * 2 * pi;
                  final offset = (index / widget.barCount) * 2 * pi;
                  final sinVal = sin(wavePhase + offset).abs();
                  barHeightFactor = (0.2 + (sinVal * 0.8)).clamp(0.15, 1.0);
                } else {
                  barHeightFactor = 0.18;
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  width: 3.5,
                  height: widget.height * barHeightFactor,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: widget.isListening ? 0.9 : 0.35),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
