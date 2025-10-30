import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import 'player_character.dart';

typedef JsonMap = Map<String, dynamic>;

class RemotePlayer extends PositionComponent {
  RemotePlayer({
    required this.playerId,
    required this.displayName,
    required double tileSize,
    required Color color,
    PlayerCharacter? character,
  })  : _color = color,
        character = character ?? PlayerCharacter.character1 {
    // Use topLeft anchor to match local Player positioning
    anchor = Anchor.topLeft;
    size = Vector2.all(tileSize * 0.8);
  }

  final int playerId;
  String displayName;
  final Color _color;
  final PlayerCharacter character;
  SpriteAnimationComponent? _animationComponent;
  
  // Smooth movement interpolation
  Vector2? _targetPosition;
  static const double _interpolationSpeed = 12.0; // Higher = faster interpolation
  static const double _snapDistance = 2.0; // Snap when this close to avoid shaking

  @override
  Future<void> onLoad() async {
    print('RemotePlayer $playerId onLoad() called');
    // Try to load character sprite animation
    try {
      // Use animatedSpritePath which doesn't include 'assets/images/' prefix
      final spritePath = character.animatedSpritePath;
      if (spritePath != null) {
        final spriteSheet = await Flame.images.load(spritePath);
        
        // Create idle animation (frame 10) - same as local player
        final idleAnimation = SpriteAnimation.fromFrameData(
          spriteSheet,
          SpriteAnimationData.sequenced(
            amount: 1,
            stepTime: 1.0,
            textureSize: Vector2(16, 16),
            texturePosition: Vector2(160, 0), // Frame 10 (10 * 16 = 160)
          ),
        );
        
        _animationComponent = SpriteAnimationComponent(
          animation: idleAnimation,
          size: size,
        );
        add(_animationComponent!);
        print('RemotePlayer $playerId sprite animation loaded: $spritePath');
      } else {
        // No sprite available for this character
        print('No sprite available for ${character.displayName}, using fallback');
        final rect = RectangleComponent(
          size: size,
          paint: Paint()..color = _color,
        );
        add(rect);
      }
    } catch (e) {
      print('Failed to load sprite for remote player ${character.animatedSpritePath}: $e');
      // Fallback to colored rectangle if sprite fails to load
      final rect = RectangleComponent(
        size: size,
        paint: Paint()..color = _color,
      );
      add(rect);
      print('RemotePlayer $playerId using fallback rectangle');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Smoothly interpolate to target position
    if (_targetPosition != null) {
      final distance = _targetPosition!.distanceTo(position);
      
      // If very close, snap to target to avoid shaking
      if (distance < _snapDistance) {
        position = _targetPosition!;
        _targetPosition = null;
      } else {
        // Use lerp for smoother interpolation
        final t = (_interpolationSpeed * dt).clamp(0.0, 1.0);
        position = Vector2(
          position.x + (_targetPosition!.x - position.x) * t,
          position.y + (_targetPosition!.y - position.y) * t,
        );
      }
    }
  }

  void updateTileSize(double tileSize) {
    size = Vector2.all(tileSize * 0.8);
    if (_animationComponent != null) {
      _animationComponent!.size = size;
    }
  }

  void applyMovement(JsonMap? payload, double tileSize) {
    if (payload == null) {
      print('RemotePlayer $playerId: Null payload!');
      return;
    }

    // Prioritize grid positions for cross-platform compatibility
    final gridX = payload['gridX'] as num?;
    final gridY = payload['gridY'] as num?;
    if (gridX != null && gridY != null) {
      // Convert grid to pixel with the same 0.1 offset that local players have
      final newPos = Vector2(
        gridX.toDouble() * tileSize + tileSize * 0.1,
        gridY.toDouble() * tileSize + tileSize * 0.1,
      );
      print('RemotePlayer $playerId: grid($gridX, $gridY) * $tileSize = pixel $newPos');
      
      // Set target position for smooth interpolation
      _targetPosition = newPos;
      return;
    }

    // Fallback to pixel positions (legacy support)
    final pixelX = payload['pixelX'] as num?;
    final pixelY = payload['pixelY'] as num?;
    if (pixelX != null && pixelY != null) {
      final newPos = Vector2(pixelX.toDouble(), pixelY.toDouble());
      print('RemotePlayer $playerId: pixel $newPos');
      
      // Set target position for smooth interpolation
      _targetPosition = newPos;
      return;
    }

    print('RemotePlayer $playerId: No valid position data in payload: $payload');
  }
}
