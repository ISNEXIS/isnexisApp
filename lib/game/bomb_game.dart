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
  int score = 0;

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
    // Calculate tile size to fill the available screen space
    // Only account for sidebar (180px) - controls panel is within game area
    const sidebarWidth = 180.0;
    
    // Available space for the game (controls are overlaid, not subtracted)
    final availableWidth = size.x - sidebarWidth;
    final availableHeight = size.y;
    
    // Validate we have proper dimensions
    if (availableWidth <= 0 || availableHeight <= 0) {
      return;
    }
    
    // FIXED MAP SIZE - 16:9 aspect ratio with proper tile count
    // Using a good balance: 51x27 tiles (17:9 ratio, close to 16:9)
    // Alternative options: 48x27, 45x25, 51x29
    gridWidth = 51;  // Fixed grid width (horizontal)
    gridHeight = 27; // Fixed grid height (vertical) - gives ~1.89:1 ratio (close to 16:9 = 1.78:1)
    
    // Ensure grid dimensions are odd for proper bomb-it style gameplay
    if (gridWidth % 2 == 0) gridWidth -= 1;
    if (gridHeight % 2 == 0) gridHeight -= 1;
    
    // DYNAMIC TILE SIZE - Calculate to fit the screen
    final tileWidth = availableWidth / gridWidth;
    final tileHeight = availableHeight / gridHeight;
    
    // Use the smaller dimension to ensure everything fits
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
        
        // Explode this position
        _explodePosition(explodePos);
        
        // Stop explosion if we hit a wall or destructible (after destroying it)
        if (tileType == TileType.wall || tileType == TileType.destructible) {
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
    
    // Check if player's grid position matches explosion position
    final playerGridX = player!.gridPosition.x.toInt();
    final playerGridY = player!.gridPosition.y.toInt();
    final explosionX = explosionPos.x.toInt();
    final explosionY = explosionPos.y.toInt();
    
    if (playerGridX == explosionX && playerGridY == explosionY) {
      _gameOver();
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
    score = 0;
    
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
    // Game logic updates
  }
}
