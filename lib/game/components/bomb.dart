import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Bomb extends CircleComponent {
  final Vector2 gridPosition;
  final Function(Bomb) onExplode;
  final double tileSize;
  double timer = 3.0; // 3 seconds until explosion
  
  Bomb({
    required this.gridPosition,
    required this.onExplode,
    required this.tileSize,
  }) : super(
          position: Vector2(
            gridPosition.x * tileSize + tileSize / 2,
            gridPosition.y * tileSize + tileSize / 2,
          ),
          radius: tileSize / 3,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    paint = Paint()..color = Colors.black;
  }

  @override
  void update(double dt) {
    super.update(dt);
    timer -= dt;
    
    // Flash effect as timer gets lower
    if (timer < 1.0) {
      final flashSpeed = 5.0;
      final flash = ((timer * flashSpeed) % 1.0 > 0.5);
      paint.color = flash ? Colors.red : Colors.black;
    }
    
    if (timer <= 0) {
      onExplode(this);
    }
  }
}
