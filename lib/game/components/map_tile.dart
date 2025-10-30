import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'tile_type.dart';

class MapTile extends PositionComponent {
  final Vector2 gridPosition;
  TileType tileType;
  final double tileSize;

  // Components for rendering
  SpriteComponent? spriteComponent;
  RectangleComponent? rectangleComponent;

  MapTile({
    required this.gridPosition,
    required this.tileType,
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
    await _loadTileGraphics();
  }

  Future<void> _loadTileGraphics() async {
    // Remove existing components
    if (spriteComponent != null) {
      spriteComponent!.removeFromParent();
      spriteComponent = null;
    }
    if (rectangleComponent != null) {
      rectangleComponent!.removeFromParent();
      rectangleComponent = null;
    }

    // Try to load sprite, fall back to colored rectangle...
    try {
      final spritePath = _getSpritePath();
      if (spritePath != null) {
        final sprite = await Sprite.load(spritePath);
        spriteComponent = SpriteComponent(sprite: sprite, size: size);
        add(spriteComponent!);
        return;
      }
    } catch (e) {
      // Sprite not found, fall through to rectangle
    }

    // Use colored rectangle as fallback
    rectangleComponent = RectangleComponent(
      size: size,
      paint: Paint()..color = _getColor(),
    );
    add(rectangleComponent!);
  }

  String? _getSpritePath() {
    switch (tileType) {
      case TileType.empty:
        return 'tiles/ground.png';
      case TileType.wall:
        return 'tiles/wall.png';
      case TileType.destructible:
        return 'tiles/destructible.png';
    }
  }

  Color _getColor() {
    switch (tileType) {
      case TileType.empty:
        return const Color.fromARGB(255, 22, 22, 22)!;
      case TileType.wall:
        return Colors.grey[800]!;
      case TileType.destructible:
        return Colors.brown[400]!;
    }
  }

  bool isWalkable() {
    return tileType == TileType.empty;
  }

  bool isDestructible() {
    return tileType == TileType.destructible;
  }

  Future<void> updateTileType(TileType newType) async {
    tileType = newType;
    await _loadTileGraphics();
  }
}
