import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'player.dart';
import 'player_character.dart';

class Bomb extends PositionComponent {
  final Vector2 gridPosition;
  final Function(Bomb) onExplode;
  final double tileSize;
  final PlayerCharacter? ownerCharacter; // Which character placed this bomb
  final Player? ownerPlayer; // Reference to player who placed this bomb
  final Color fallbackColor; // Fallback color if no sprite
  final bool isRemote; // If true, this bomb was placed by another player and shouldn't auto-explode
  final int explosionRadius; // Explosion radius for this bomb
  double timer = 3.0; // 3 seconds until explosion

  // Components for rendering
  SpriteComponent? spriteComponent;
  CircleComponent? circleComponent;

  Bomb({
    required this.gridPosition,
    required this.onExplode,
    required this.tileSize,
    this.ownerCharacter,
    this.ownerPlayer,
    this.fallbackColor = Colors.black,
    this.isRemote = false,
    this.explosionRadius = 1, // Default radius is 1
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
      if (ownerCharacter != null) {
        // Try character-specific bomb sprite using the bombSpritePath property
        try {
          final sprite = await Sprite.load(ownerCharacter!.bombSpritePath);
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
    
    // Remote bombs don't count down - they wait for server explosion event
    if (!isRemote) {
      timer -= dt;
    }

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

    // Only local bombs explode on their own timer
    if (!isRemote && timer <= 0) {
      onExplode(this);
    }
  }
}
