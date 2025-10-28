import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import 'player_character.dart';
import 'tile_type.dart';

// Animation states for the player
enum PlayerAnimationState {
  idle,
  walkDown,
  walkLeft,
  walkRight,
  walkUp,
  throwBomb,
}

class Player extends PositionComponent {
  Vector2 gridPosition;
  final Color color;
  final PlayerCharacter character;
  final int playerNumber; // 1-4
  static const double moveSpeed = 150.0; // Pixels per second
  final double tileSize;
  final int gridWidth;
  final int gridHeight;
  Vector2 velocity = Vector2.zero();
  int explosionRadius = 1; // Player's explosion radius (upgradeable)
  int playerHealth = 1; // Player's health (upgradeable)
  int maxBombs = 1; // Maximum bombs player can place (upgradeable)
  int currentBombs = 0; // Current number of bombs placed

  // Invincibility
  bool isInvincible = false;
  double invincibilityTimer = 0.0;
  double invincibilityBlinkTimer = 0.0;
  static const double invincibilityBlinkInterval = 0.1;
  bool invincibilityVisible = true;

  // Components for rendering
  SpriteComponent? spriteComponent;
  SpriteAnimationGroupComponent<PlayerAnimationState>? animationGroupComponent;
  RectangleComponent? rectangleComponent;

  // Animation state
  PlayerAnimationState currentAnimationState = PlayerAnimationState.idle;
  bool isThrowingBomb = false;
  double bombThrowTimer = 0.0;
  static const double bombThrowDuration = 0.4; // 2 frames at 0.2s each

  // Reference to game map - will be set by the game
  late List<List<TileType>> Function() getGameMap;
  late bool Function() getIsGameOver;
  late Vector2 Function() getJoystickDirection;
  late bool Function(Vector2) isBombAtPosition;

  Player({
    required this.gridPosition,
    required this.color,
    required this.character,
    required this.playerNumber,
    required this.tileSize,
    required this.gridWidth,
    required this.gridHeight,
    required this.getGameMap,
    required this.getIsGameOver,
    required this.getJoystickDirection,
    required this.isBombAtPosition,
  }) : super(
         position: Vector2(
           gridPosition.x * tileSize + tileSize * 0.1,
           gridPosition.y * tileSize + tileSize * 0.1,
         ),
         size: Vector2.all(tileSize * 0.8),
       );

  @override
  Future<void> onLoad() async {
    // Try to load animated sprite if available, otherwise fall back to static sprite
    try {
      final animatedPath = character.animatedSpritePath;

      if (animatedPath != null) {
        // Character has an animated sprite sheet
        final spriteSheet = await Flame.images.load(animatedPath);

        // Create animations for each direction and state
        final animations = {
          // Idle (frame 10, index starts at 0)
          PlayerAnimationState.idle: SpriteAnimation.fromFrameData(
            spriteSheet,
            SpriteAnimationData.sequenced(
              amount: 1,
              stepTime: 1.0,
              textureSize: Vector2(16, 16),
              texturePosition: Vector2(160, 0), // Frame 10 (10 * 16 = 160)
            ),
          ),

          // Walk Down (frames 0-1)
          PlayerAnimationState.walkDown: SpriteAnimation.fromFrameData(
            spriteSheet,
            SpriteAnimationData.sequenced(
              amount: 2,
              stepTime: 0.2,
              textureSize: Vector2(16, 16),
              texturePosition: Vector2(0, 0),
            ),
          ),

          // Walk Left (frames 2-3)
          PlayerAnimationState.walkLeft: SpriteAnimation.fromFrameData(
            spriteSheet,
            SpriteAnimationData.sequenced(
              amount: 2,
              stepTime: 0.2,
              textureSize: Vector2(16, 16),
              texturePosition: Vector2(32, 0), // Frame 2 (2 * 16 = 32)
            ),
          ),

          // Walk Right (frames 4-5)
          PlayerAnimationState.walkRight: SpriteAnimation.fromFrameData(
            spriteSheet,
            SpriteAnimationData.sequenced(
              amount: 2,
              stepTime: 0.2,
              textureSize: Vector2(16, 16),
              texturePosition: Vector2(64, 0), // Frame 4 (4 * 16 = 64)
            ),
          ),

          // Walk Up (frames 6-7)
          PlayerAnimationState.walkUp: SpriteAnimation.fromFrameData(
            spriteSheet,
            SpriteAnimationData.sequenced(
              amount: 2,
              stepTime: 0.2,
              textureSize: Vector2(16, 16),
              texturePosition: Vector2(96, 0), // Frame 6 (6 * 16 = 96)
            ),
          ),

          // Throw Bomb (frames 8-9)
          PlayerAnimationState.throwBomb: SpriteAnimation.fromFrameData(
            spriteSheet,
            SpriteAnimationData.sequenced(
              amount: 2,
              stepTime: 0.2,
              textureSize: Vector2(16, 16),
              texturePosition: Vector2(128, 0), // Frame 8 (8 * 16 = 128)
              loop: false, // Don't loop the throw animation
            ),
          ),
        };

        animationGroupComponent =
            SpriteAnimationGroupComponent<PlayerAnimationState>(
              animations: animations,
              current: PlayerAnimationState.idle,
              size: size,
            );
        add(animationGroupComponent!);
      } else {
        // Try to load static sprite for other characters
        final sprite = await Sprite.load(
          character.spritePath.replaceFirst('assets/images/', ''),
        );
        spriteComponent = SpriteComponent(sprite: sprite, size: size);
        add(spriteComponent!);
      }
    } catch (e) {
      // Sprite not found, use colored rectangle as fallback
      rectangleComponent = RectangleComponent(
        size: size,
        paint: Paint()..color = color,
      );
      add(rectangleComponent!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (getIsGameOver()) return;

    // Handle invincibility timer
    if (isInvincible) {
      invincibilityTimer -= dt;
      invincibilityBlinkTimer -= dt;

      if (invincibilityTimer <= 0) {
        isInvincible = false;
        _setVisible(true);
      } else if (invincibilityBlinkTimer <= 0) {
        // Blink effect
        invincibilityVisible = !invincibilityVisible;
        _setVisible(invincibilityVisible);
        invincibilityBlinkTimer = invincibilityBlinkInterval;
      }
    }

    // Handle bomb throw animation timer
    if (isThrowingBomb) {
      bombThrowTimer -= dt;
      if (bombThrowTimer <= 0) {
        isThrowingBomb = false;
      }
    }

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

      // Update animation based on movement direction (only for character 1)
      if (animationGroupComponent != null && !isThrowingBomb) {
        _updateAnimationState(inputDirection);
      }
    } else {
      // Player is not moving
      if (animationGroupComponent != null && !isThrowingBomb) {
        animationGroupComponent!.current = PlayerAnimationState.idle;
      }
    }
  }

  void _updateAnimationState(Vector2 direction) {
    // Determine animation based on primary movement direction
    if (direction.y.abs() > direction.x.abs()) {
      // Vertical movement is stronger
      if (direction.y > 0) {
        currentAnimationState = PlayerAnimationState.walkDown;
      } else {
        currentAnimationState = PlayerAnimationState.walkUp;
      }
    } else {
      // Horizontal movement is stronger
      if (direction.x > 0) {
        currentAnimationState = PlayerAnimationState.walkRight;
      } else {
        currentAnimationState = PlayerAnimationState.walkLeft;
      }
    }

    animationGroupComponent?.current = currentAnimationState;
  }

  void playBombThrowAnimation() {
    if (animationGroupComponent != null) {
      isThrowingBomb = true;
      bombThrowTimer = bombThrowDuration;
      animationGroupComponent!.current = PlayerAnimationState.throwBomb;
    }
  }

  void setMovement(Vector2 direction) {
    velocity = direction * moveSpeed;
  }

  bool _canMoveToPixelPosition(Vector2 newPosition) {
    final gameMap = getGameMap();

    // Calculate which grid tile the player's center will be on after moving
    final newCenterX = ((newPosition.x + size.x / 2) / tileSize).floor();
    final newCenterY = ((newPosition.y + size.y / 2) / tileSize).floor();

    // Calculate current grid tile (center)
    final currentCenterX = ((position.x + size.x / 2) / tileSize).floor();
    final currentCenterY = ((position.y + size.y / 2) / tileSize).floor();

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

      if (gridX < 0 || gridX >= gridWidth || gridY < 0 || gridY >= gridHeight) {
        return false;
      }

      if (gameMap[gridY][gridX] != TileType.empty) {
        return false;
      }
    }

    // Check for bombs - only block if moving INTO a new tile with a bomb
    final gridPos = Vector2(newCenterX.toDouble(), newCenterY.toDouble());
    final movingToNewTile =
        (newCenterX != currentCenterX || newCenterY != currentCenterY);

    if (movingToNewTile && isBombAtPosition(gridPos)) {
      return false;
    }

    return true;
  }

  void activateInvincibility(double duration) {
    isInvincible = true;
    invincibilityTimer = duration;
    invincibilityBlinkTimer = invincibilityBlinkInterval;
  }

  void _setVisible(bool visible) {
    if (spriteComponent != null) {
      spriteComponent!.opacity = visible ? 1.0 : 0.3;
    } else if (animationGroupComponent != null) {
      animationGroupComponent!.opacity = visible ? 1.0 : 0.3;
    } else if (rectangleComponent != null) {
      rectangleComponent!.opacity = visible ? 1.0 : 0.3;
    }
  }

  bool canPlaceBomb() {
    return currentBombs < maxBombs;
  }

  void incrementBombCount() {
    currentBombs++;
  }

  void decrementBombCount() {
    if (currentBombs > 0) {
      currentBombs--;
    }
  }
}
