import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'tile_type.dart';

class Player extends RectangleComponent {
  Vector2 gridPosition;
  final Color color;
  static const double moveSpeed = 150.0; // Pixels per second
  final double tileSize;
  final int gridWidth;
  final int gridHeight;
  Vector2 velocity = Vector2.zero();
  int explosionRadius = 1; // Player's explosion radius (upgradeable)
  
  // Reference to game map - will be set by the game
  late List<List<TileType>> Function() getGameMap;
  late bool Function() getIsGameOver;
  late Vector2 Function() getJoystickDirection;

  Player({
    required this.gridPosition,
    required this.color,
    required this.tileSize,
    required this.gridWidth,
    required this.gridHeight,
    required this.getGameMap,
    required this.getIsGameOver,
    required this.getJoystickDirection,
  }) : super(
          position: Vector2(
            gridPosition.x * tileSize + tileSize * 0.1,
            gridPosition.y * tileSize + tileSize * 0.1,
          ),
          size: Vector2.all(tileSize * 0.8),
        );

  @override
  Future<void> onLoad() async {
    paint = Paint()..color = color;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (getIsGameOver()) return;
    
    // Get input from joystick or keyboard
    Vector2 inputDirection = Vector2.zero();
    
    // Prioritize joystick input if available
    final joystickDir = getJoystickDirection();
    if (joystickDir.length > 0.1) {
      inputDirection = joystickDir;
    } else {
      inputDirection = velocity.normalized();
    }
    
    // Apply movement with separate X and Y collision detection
    if (inputDirection.length > 0) {
      final newVelocity = inputDirection * moveSpeed;
      final deltaMovement = newVelocity * dt;
      
      // Try movement on X axis first
      final newPositionX = Vector2(position.x + deltaMovement.x, position.y);
      if (_canMoveToPixelPosition(newPositionX)) {
        position.x = newPositionX.x;
      }
      
      // Try movement on Y axis second
      final newPositionY = Vector2(position.x, position.y + deltaMovement.y);
      if (_canMoveToPixelPosition(newPositionY)) {
        position.y = newPositionY.y;
      }
      
      // Update grid position based on current pixel position
      gridPosition = Vector2(
        ((position.x + size.x / 2) / tileSize).floor().toDouble(),
        ((position.y + size.y / 2) / tileSize).floor().toDouble(),
      );
    }
  }

  void setMovement(Vector2 direction) {
    velocity = direction * moveSpeed;
  }

  bool _canMoveToPixelPosition(Vector2 newPosition) {
    final gameMap = getGameMap();
    
    // Check all four corners of the player rectangle
    final corners = [
      newPosition, // Top-left
      Vector2(newPosition.x + size.x, newPosition.y), // Top-right
      Vector2(newPosition.x, newPosition.y + size.y), // Bottom-left
      Vector2(newPosition.x + size.x, newPosition.y + size.y), // Bottom-right
    ];
    
    for (final corner in corners) {
      final gridX = (corner.x / tileSize).floor();
      final gridY = (corner.y / tileSize).floor();
      
      if (gridX < 0 || gridX >= gridWidth || 
          gridY < 0 || gridY >= gridHeight) {
        return false;
      }
      
      if (gameMap[gridY][gridX] != TileType.empty) {
        return false;
      }
    }
    
    return true;
  }
}
