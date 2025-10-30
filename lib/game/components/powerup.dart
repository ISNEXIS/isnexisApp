import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'player.dart';

enum PowerupType {
  extraLife,
  extraBomb,
  explosionRange,
}

class Powerup extends PositionComponent {
  final PowerupType type;
  final Vector2 gridPosition;
  final double tileSize;
  final int id; // Unique ID for network synchronization
  bool collected = false;
  
  SpriteComponent? spriteComponent;
  RectangleComponent? rectangleComponent;
  
  Powerup({
    required this.type,
    required this.gridPosition,
    required this.tileSize,
    required this.id,
  }) : super(
         position: Vector2(
           gridPosition.x * tileSize + tileSize * 0.2,
           gridPosition.y * tileSize + tileSize * 0.2,
         ),
         size: Vector2.all(tileSize * 0.6),
       );

  @override
  Future<void> onLoad() async {
    // Try to load sprite based on powerup type
    try {
      final sprite = await Sprite.load(_getSpritePath());
      spriteComponent = SpriteComponent(sprite: sprite, size: size);
      add(spriteComponent!);
    } catch (e) {
      // Sprite not found, use colored rectangle as fallback
      rectangleComponent = RectangleComponent(
        size: size,
        paint: Paint()..color = _getColor(),
      );
      add(rectangleComponent!);
    }
  }

  String _getSpritePath() {
    switch (type) {
      case PowerupType.extraLife:
        return 'powerups/extra_life.png';
      case PowerupType.extraBomb:
        return 'powerups/extra_bomb.png';
      case PowerupType.explosionRange:
        return 'powerups/explosion_range.png';
    }
  }

  Color _getColor() {
    switch (type) {
      case PowerupType.extraLife:
        return Colors.green;
      case PowerupType.extraBomb:
        return Colors.blue;
      case PowerupType.explosionRange:
        return Colors.orange;
    }
  }

  String getDisplayName({int multiplier = 1}) {
    switch (type) {
      case PowerupType.extraLife:
        return '+$multiplier Life';
      case PowerupType.extraBomb:
        return '+$multiplier Bomb';
      case PowerupType.explosionRange:
        return '+$multiplier Range';
    }
  }

  void applyToPlayer(Player player, {int multiplier = 1}) {
    if (collected) return;
    
    collected = true;
    
    switch (type) {
      case PowerupType.extraLife:
        player.playerHealth += multiplier;
        break;
      case PowerupType.extraBomb:
        player.maxBombs += multiplier;
        break;
      case PowerupType.explosionRange:
        player.explosionRadius += multiplier;
        break;
    }
  }
}
