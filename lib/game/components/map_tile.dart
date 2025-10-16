import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'tile_type.dart';

class MapTile extends RectangleComponent {
  final Vector2 gridPosition;
  TileType tileType;
  final double tileSize;

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
    _updateColor();
  }

  void _updateColor() {
    switch (tileType) {
      case TileType.empty:
        paint = Paint()..color = Colors.green[100]!;
        break;
      case TileType.wall:
        paint = Paint()..color = Colors.grey[800]!;
        break;
      case TileType.destructible:
        paint = Paint()..color = Colors.brown[400]!;
        break;
    }
  }

  bool isWalkable() {
    return tileType == TileType.empty;
  }

  bool isDestructible() {
    return tileType == TileType.destructible;
  }

  void updateTileType(TileType newType) {
    tileType = newType;
    _updateColor();
  }
}
