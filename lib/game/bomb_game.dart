import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Component imports
import 'components/bomb.dart';
import 'components/explosion_effect.dart';
import 'components/map_tile.dart';
import 'components/player.dart';
import 'components/tile_type.dart';

class BombGame extends FlameGame with HasKeyboardHandlerComponents, ChangeNotifier {
  late int gridWidth;  // Will be calculated based on screen size
  late int gridHeight; // Will be calculated based on screen size
  late double tileSize; // Will be calculated to fill available screen space
  
  late List<List<TileType>> gameMap;
  Player? player; // Make nullable to avoid LateInitializationError
  Offset joystickDirection = Offset.zero; // Flutter joystick direction
  List<Bomb> bombs = [];
  bool isGameOver = false;
  late Function(bool) onGameStateChanged; // Callback to notify main app
  
  // Player stats
  int playerHealth = 1;
  int maxBombs = 1; // Maximum bombs that can be placed at once (upgradeable)
  int score = 0;
  
  // Invincibility state
  bool isPlayerInvincible = false;
  double invincibilityTimer = 0.0;
  static const double invincibilityDuration = 2.0; // 2 seconds of invincibility

  BombGame({required this.onGameStateChanged});

  @override
  Color backgroundColor() => const Color(0xFF2E7D32);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Wait for the game size to be properly set
    if (size.x == 0 || size.y == 0) {
      // Defer initialization until size is available
      return;
    }
    
    _initializeGame();
  }
  
  void _initializeGame() {
    // PLAYABLE AREA: 15x13 tiles
    // TOTAL MAP SIZE: 17x15 tiles (15+2 borders horizontally, 13+2 borders vertically)
    gridWidth = 17;
    gridHeight = 15;

    // Validate we have proper dimensions
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    
    // Calculate tile size to fit the screen perfectly
    // Calculate based on screen dimensions divided by grid size
    final tileWidth = size.x / gridWidth;
    final tileHeight = size.y / gridHeight;
    
    // Use the smaller dimension to ensure the entire map fits on screen
    tileSize = tileWidth < tileHeight ? tileWidth : tileHeight;
    
    // Center camera on map
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(
      (gridWidth * tileSize) / 2,
      (gridHeight * tileSize) / 2,
    );
    
    // Initialize the game map
    _generateMap();
    _renderMap();
    _spawnPlayer();
  }
  
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    // Initialize game when size becomes available
    if (children.isEmpty && size.x > 0 && size.y > 0) {
      _initializeGame();
    }
  }

  void _generateMap() {
    gameMap = List.generate(gridHeight, (y) => List.generate(gridWidth, (x) {
      // Create border walls
      if (x == 0 || x == gridWidth - 1 || y == 0 || y == gridHeight - 1) {
        return TileType.wall;
      }
      
      // Create inner structural walls (every other tile starting from even positions)
      if (x % 2 == 0 && y % 2 == 0) {
        return TileType.wall;
      }
      
      // Player 1 spawn area (top-left corner) - must be clear
      if ((x == 1 && y == 1) || // Player spawn
          (x == 2 && y == 1) || // Right of player
          (x == 1 && y == 2)) { // Below player
        return TileType.empty;
      }
      
      // Player 2 spawn area (top-right corner) - must be clear
      if ((x == gridWidth - 2 && y == 1) || // Player spawn
          (x == gridWidth - 3 && y == 1) || // Left of player
          (x == gridWidth - 2 && y == 2)) { // Below player
        return TileType.empty;
      }
      
      // Player 3 spawn area (bottom-left corner) - must be clear
      if ((x == 1 && y == gridHeight - 2) || // Player spawn
          (x == 2 && y == gridHeight - 2) || // Right of player
          (x == 1 && y == gridHeight - 3)) { // Above player
        return TileType.empty;
      }
      
      // Player 4 spawn area (bottom-right corner) - must be clear
      if ((x == gridWidth - 2 && y == gridHeight - 2) || // Player spawn
          (x == gridWidth - 3 && y == gridHeight - 2) || // Left of player
          (x == gridWidth - 2 && y == gridHeight - 3)) { // Above player
        return TileType.empty;
      }
      
      // Fill all remaining spaces with destructible walls
      // This creates a maze that must be cleared with bombs
      return TileType.destructible;
    }));
  }

  void _renderMap() {
    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final tile = MapTile(
          gridPosition: Vector2(x.toDouble(), y.toDouble()),
          tileType: gameMap[y][x],
          tileSize: tileSize,
        );
        add(tile);
      }
    }
  }

  void _spawnPlayer() {
    // Spawn player 1 at top-left corner with clear movement space
    player = Player(
      gridPosition: Vector2(1, 1),
      color: Colors.blue,
      tileSize: tileSize,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      getGameMap: () => gameMap,
      getIsGameOver: () => isGameOver,
      getJoystickDirection: () => Vector2(joystickDirection.dx, joystickDirection.dy),
    );
    player!.playerHealth = 1; // Initialize player health
    add(player!);
  }

  // Method to update joystick direction from Flutter widget
  void updateJoystickDirection(Offset direction) {
    joystickDirection = direction;
  }

  bool canMoveToPosition(Vector2 gridPos) {
    if (gridPos.x < 0 || gridPos.x >= gridWidth || 
        gridPos.y < 0 || gridPos.y >= gridHeight) {
      return false;
    }
    return gameMap[gridPos.y.toInt()][gridPos.x.toInt()] == TileType.empty;
  }

  void placeBomb() {
    if (isGameOver || player == null) return;
    
    // Check if player has reached maximum bomb limit
    if (bombs.length >= maxBombs) return;
    
    final playerGridPos = player!.gridPosition;
    
    // Check if there's already a bomb at this position
    final existingBomb = bombs.any((bomb) => 
        bomb.gridPosition.x.toInt() == playerGridPos.x.toInt() &&
        bomb.gridPosition.y.toInt() == playerGridPos.y.toInt());
    
    if (!existingBomb) {
      final bomb = Bomb(
        gridPosition: playerGridPos,
        onExplode: explodeBomb,
        tileSize: tileSize,
      );
      bombs.add(bomb);
      add(bomb);
    }
  }

  void explodeBomb(Bomb bomb) {
    bombs.remove(bomb);
    bomb.removeFromParent();
    
    // Create explosion with player's radius
    createExplosion(bomb.gridPosition, player?.explosionRadius.toInt() ?? 1);
  }

  void createExplosion(Vector2 centerPos, int explosionRadius) {
    // Explosion directions (up, down, left, right)
    final directions = [
      Vector2(0, -1), // Up
      Vector2(0, 1),  // Down  
      Vector2(-1, 0), // Left
      Vector2(1, 0),  // Right
    ];
    
    // Explode center position
    _explodePosition(centerPos);
    
    // Explode in each direction
    for (final direction in directions) {
      for (int i = 1; i <= explosionRadius; i++) {
        final explodePos = Vector2(
          centerPos.x + (direction.x * i),
          centerPos.y + (direction.y * i),
        );
        
        // Check if position is valid
        if (explodePos.x < 0 || explodePos.x >= gridWidth ||
            explodePos.y < 0 || explodePos.y >= gridHeight) {
          break; // Stop explosion in this direction
        }
        
        final tileType = gameMap[explodePos.y.toInt()][explodePos.x.toInt()];
        
        // Stop explosion if we hit an unbreakable wall (don't show effect)
        if (tileType == TileType.wall) {
          break;
        }
        
        // Explode this position (only for empty or destructible tiles)
        _explodePosition(explodePos);
        
        // Stop explosion if we hit a destructible (after destroying it)
        if (tileType == TileType.destructible) {
          break;
        }
      }
    }
  }

  void _explodePosition(Vector2 pos) {
    final x = pos.x.toInt();
    final y = pos.y.toInt();
    
    // Create explosion effect
    final explosion = ExplosionEffect(
      gridPosition: pos,
      tileSize: tileSize,
    );
    add(explosion);
    
    // Check if player is at this position
    _checkPlayerDamage(pos);
    
    // Destroy destructible walls
    if (gameMap[y][x] == TileType.destructible) {
      gameMap[y][x] = TileType.empty;
      score += 10; // Add points for destroying walls
      
      // Update the visual tile
      _updateTileVisual(pos);
    }
  }

  void _updateTileVisual(Vector2 gridPos) {
    // Find and update the tile component
    final tileComponents = children.whereType<MapTile>();
    for (final tile in tileComponents) {
      if (tile.gridPosition.x == gridPos.x && tile.gridPosition.y == gridPos.y) {
        tile.updateTileType(TileType.empty);
        break;
      }
    }
  }

  void _checkPlayerDamage(Vector2 explosionPos) {
    if (isGameOver || player == null) return;
    
    // Don't damage player if they're invincible
    if (isPlayerInvincible) return;
    
    // Check if player's grid position matches explosion position
    final playerGridX = player!.gridPosition.x.toInt();
    final playerGridY = player!.gridPosition.y.toInt();
    final explosionX = explosionPos.x.toInt();
    final explosionY = explosionPos.y.toInt();
    
    if (playerGridX == explosionX && playerGridY == explosionY) {
      // Reduce player health by 1
      playerHealth--;
      player!.playerHealth--;
      
      // Activate invincibility
      isPlayerInvincible = true;
      invincibilityTimer = invincibilityDuration;
      
      // Check if player is dead
      if (playerHealth <= 0) {
        _gameOver();
      }
    }
  }

  void _gameOver() {
    isGameOver = true;
    paused = true;
    playerHealth = 0;
    onGameStateChanged(true); // Notify that game is over
  }

  void restartGame() {
    isGameOver = false;
    paused = false;
    playerHealth = 1;
    maxBombs = 1; // Reset to default
    score = 0;
    
    // Reset invincibility
    isPlayerInvincible = false;
    invincibilityTimer = 0.0;
    
    // Clear existing components
    removeAll(children.whereType<Bomb>());
    removeAll(children.whereType<ExplosionEffect>());
    removeAll(children.whereType<Player>());
    removeAll(children.whereType<JoystickComponent>());
    removeAll(children.whereType<RectangleComponent>()); // Remove any backgrounds
    bombs.clear();
    
    // Regenerate map and respawn player
    removeAll(children.whereType<MapTile>());
    _generateMap();
    _renderMap();
    _spawnPlayer();
    
    onGameStateChanged(false); // Notify that game restarted
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isGameOver) return KeyEventResult.ignored;
    
    // Handle bomb placement with spacebar
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      placeBomb();
      return KeyEventResult.handled;
    }
    
    // Calculate movement direction based on currently pressed keys
    Vector2 direction = Vector2.zero();
    
    if (keysPressed.contains(LogicalKeyboardKey.keyW)) {
      direction.y -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyS)) {
      direction.y += 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyA)) {
      direction.x -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyD)) {
      direction.x += 1;
    }
    
    // Normalize diagonal movement
    if (direction.length > 0) {
      direction = direction.normalized();
    }
    
    // Only use keyboard if joystick is not being used
    if (joystickDirection.distance < 0.1) {
      player?.setMovement(direction);
    }
    
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update invincibility timer
    if (isPlayerInvincible) {
      invincibilityTimer -= dt;
      
      if (invincibilityTimer <= 0) {
        isPlayerInvincible = false;
        invincibilityTimer = 0.0;
      }
      
      // Visual feedback: make player flash by changing opacity
      if (player != null) {
        // Flash effect: alternates visibility every 0.2 seconds
        final flashInterval = 0.2;
        final flashPhase = (invincibilityTimer % flashInterval) / flashInterval;
        player!.paint.color = player!.color.withOpacity(flashPhase > 0.5 ? 1.0 : 0.3);
      }
    } else {
      // Restore full opacity when not invincible
      if (player != null) {
        player!.paint.color = player!.color.withOpacity(1.0);
      }
    }
  }
}
