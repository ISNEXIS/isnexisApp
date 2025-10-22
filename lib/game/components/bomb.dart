import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'player_character.dart';

class Bomb extends PositionComponent {
  final Vector2 gridPosition;
  final Function(Bomb) onExplode;
  final double tileSize;
  final PlayerCharacter? ownerCharacter; // Which character placed this bomb
  final Color fallbackColor; // Fallback color if no sprite
  double timer = 3.0; // 3 seconds until explosion

  // Components for rendering
  SpriteComponent? spriteComponent;
  CircleComponent? circleComponent;

  Bomb({
    required this.gridPosition,
    required this.onExplode,
    required this.tileSize,
    this.ownerCharacter,
    this.fallbackColor = Colors.black,
  }) : super(
         position: Vector2(
           gridPosition.x * tileSize + tileSize / 2,
           gridPosition.y * tileSize + tileSize / 2,
         ),
         size: Vector2.all(tileSize * 0.66),
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Try to load character-specific bomb sprite, fall back to generic, then circle
    try {
      String spritePath;

      if (ownerCharacter != null) {
        // Try character-specific bomb sprite first
        spritePath = 'bombs/bomb_${ownerCharacter!.name}.png';
        try {
          final sprite = await Sprite.load(spritePath);
          spriteComponent = SpriteComponent(sprite: sprite, size: size);
          add(spriteComponent!);
          return;
        } catch (e) {
          // Character-specific sprite not found, try generic
        }
      }

      // Try generic bomb sprite
      final sprite = await Sprite.load('bombs/bomb.png');
      spriteComponent = SpriteComponent(sprite: sprite, size: size);
      add(spriteComponent!);
    } catch (e) {
      // No sprite found, use circle as fallback
      circleComponent = CircleComponent(
        radius: tileSize / 3,
        paint: Paint()..color = fallbackColor,
      );
      add(circleComponent!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    timer -= dt;

    // Flash effect as timer gets lower
    if (timer < 1.0) {
      final flashSpeed = 5.0;
      final flash = ((timer * flashSpeed) % 1.0 > 0.5);

      if (spriteComponent != null) {
        // Flash sprite by changing opacity or tint
        spriteComponent!.paint.colorFilter = flash
            ? const ColorFilter.mode(Colors.red, BlendMode.modulate)
            : null;
      } else if (circleComponent != null) {
        // Flash circle by changing color between fallback color and red
        circleComponent!.paint.color = flash ? Colors.red : fallbackColor;
      }
    }

    if (timer <= 0) {
      onExplode(this);
    }
  }
}
