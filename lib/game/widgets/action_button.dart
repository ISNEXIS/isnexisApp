import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class ActionButton extends CircleComponent with TapCallbacks {
  final VoidCallback onPressed;
  
  ActionButton({
    required Vector2 position,
    required this.onPressed,
  }) : super(
          position: position,
          radius: 40,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    paint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    // Add border
    add(CircleComponent(
      radius: radius,
      paint: Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    ));
    
    // Add text
    add(TextComponent(
      text: 'B',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
    ));
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    paint.color = Colors.red.withOpacity(0.9);
    onPressed();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    paint.color = Colors.red.withOpacity(0.7);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    paint.color = Colors.red.withOpacity(0.7);
  }
}
