import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ExplosionEffect extends RectangleComponent {
  final Vector2 gridPosition;
  final double tileSize;
  double timer = 0.3; // How long explosion effect lasts
  
  ExplosionEffect({
    required this.gridPosition,
    required this.tileSize,
  }) : super(
          position: Vector2(
            gridPosition.x * tileSize,
            gridPosition.y * tileSize,
          ),
          size: Vector2.all(tileSize),
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    paint = Paint()..color = Colors.orange.withOpacity(0.8);
  }

  @override
  void update(double dt) {
    super.update(dt);
    timer -= dt;
    
    // Fade out effect
    final opacity = (timer / 0.3).clamp(0.0, 1.0);
    paint.color = Colors.orange.withOpacity(opacity * 0.8);
    
    if (timer <= 0) {
      removeFromParent();
    }
  }
}
