import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudioVisualizer extends StatefulWidget {
  final bool isActive;
  final double amplitude;
  final Color color;
  final int barCount;

  const AudioVisualizer({
    super.key,
    required this.isActive,
    this.amplitude = 0.5,
    this.color = Colors.blue,
    this.barCount = 20,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<AnimationController> _barControllers;
  final List<double> _barHeights = [];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _barControllers = List.generate(
      widget.barCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: 300 + (index * 50)),
        vsync: this,
      ),
    );

    _barHeights.addAll(List.filled(widget.barCount, 0.1));

    if (widget.isActive) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    for (int i = 0; i < _barControllers.length; i++) {
      _barControllers[i].repeat(reverse: true);
    }
  }

  void _stopAnimation() {
    for (var controller in _barControllers) {
      controller.stop();
      controller.reset();
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (index) {
          return AnimatedBuilder(
            animation: _barControllers[index],
            builder: (context, child) {
              double height = widget.isActive
                  ? 20 + (40 * _barControllers[index].value * widget.amplitude)
                  : 4;
              
              return Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(
                    widget.isActive ? 0.7 + (0.3 * _barControllers[index].value) : 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _barControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}