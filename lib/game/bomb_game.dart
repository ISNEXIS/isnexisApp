import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isnexis_app/services/game_hub_client.dart';

import '../models/player_selection_data.dart';
// Component imports
import 'components/bomb.dart';
import 'components/bot_player.dart';
import 'components/explosion_effect.dart';
import 'components/map_tile.dart';
import 'components/player.dart';
import 'components/player_character.dart';
import 'components/powerup.dart';
import 'components/remote_player.dart';
import 'components/tile_type.dart';

class BombGame extends FlameGame
    with HasKeyboardHandlerComponents, ChangeNotifier {
  late int gridWidth; // Will be calculated based on screen size
  late int gridHeight; // Will be calculated based on screen size
  late double tileSize; // Will be calculated to fill available screen space

  late List<List<TileType>> gameMap;
  List<Player> players = []; // Support multiple players (includes bots)
  final List<PlayerSelectionData> selectedPlayers;
  Offset joystickDirection = Offset.zero; // Flutter joystick direction
  List<Bomb> bombs = [];
  List<Powerup> powerups = []; // Track active powerups
  final Random _random = Random(); // For powerup drop chance
  bool isGameOver = false;
  Player? winner; // Track the winning player
  late Function(bool, {Player? winner}) onGameStateChanged; // Callback to notify main app

  // Player stats (for tracking overall game state)
  int maxBombs = 1; // Maximum bombs that can be placed at once (upgradeable)
  int score = 0;

  // Invincibility state for each player
  List<bool> playerInvincibility = [false, false, false, false];
  List<double> invincibilityTimers = [0.0, 0.0, 0.0, 0.0];
  static const double invincibilityDuration = 2.0; // 2 seconds of invincibility

  int alivePlayers = 0;

  final GameHubClient? networkClient;
  final int? networkRoomId;
  final int? networkPlayerId;
  final int? localPlayerId;
  final String? localPlayerName;
  final Map<int, RemotePlayer> _remotePlayers = {};
  final Map<int, Color> _playerColors = {};
  final Map<int, String> _playerNames = {};

  bool _networkJoined = false;
  static const double _movementBroadcastInterval = 0.1;
  double _movementBroadcastTimer = 0.0;
  final List<StreamSubscription<dynamic>> _networkSubscriptions = [];

  BombGame({
    required this.onGameStateChanged,
    required this.selectedPlayers,
    this.networkClient,
    this.networkRoomId,
    this.networkPlayerId,
    this.localPlayerId,
    this.localPlayerName,
  });

  bool get _networkEnabled =>
      networkClient != null && networkRoomId != null && networkPlayerId != null;

  Iterable<int> get remotePlayerIds => _remotePlayers.keys;

  @override
  Color backgroundColor() => const Color(0xFF2E7D32);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (_networkEnabled) {
      await _initializeNetworking();
    }

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

    for (final remote in _remotePlayers.values) {
      remote.updateTileSize(tileSize);
      if (!remote.isMounted) {
        add(remote);
      }
    }
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
    gameMap = List.generate(
      gridHeight,
      (y) => List.generate(gridWidth, (x) {
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
            (x == 1 && y == 2)) {
          // Below player
          return TileType.empty;
        }

        // Player 2 spawn area (top-right corner) - must be clear
        if ((x == gridWidth - 2 && y == 1) || // Player spawn
            (x == gridWidth - 3 && y == 1) || // Left of player
            (x == gridWidth - 2 && y == 2)) {
          // Below player
          return TileType.empty;
        }

        // Player 3 spawn area (bottom-left corner) - must be clear
        if ((x == 1 && y == gridHeight - 2) || // Player spawn
            (x == 2 && y == gridHeight - 2) || // Right of player
            (x == 1 && y == gridHeight - 3)) {
          // Above player
          return TileType.empty;
        }

        // Player 4 spawn area (bottom-right corner) - must be clear
        if ((x == gridWidth - 2 && y == gridHeight - 2) || // Player spawn
            (x == gridWidth - 3 && y == gridHeight - 2) || // Left of player
            (x == gridWidth - 2 && y == gridHeight - 3)) {
          // Above player
          return TileType.empty;
        }

        // Fill all remaining spaces with destructible walls
        // This creates a maze that must be cleared with bombs
        return TileType.destructible;
      }),
    );
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
    // Spawn positions for up to 4 players (corners of the map)
    final spawnPositions = [
      Vector2(1, 1), // Top-left
      Vector2(gridWidth - 2, 1), // Top-right
      Vector2(1, gridHeight - 2), // Bottom-left
      Vector2(gridWidth - 2, gridHeight - 2), // Bottom-right
    ];

    // Clear existing players
    players.clear();
    alivePlayers = selectedPlayers.length;

    // Spawn each player
    for (int i = 0; i < selectedPlayers.length; i++) {
      final playerData = selectedPlayers[i];
      Player player;
      
      if (playerData.isBot) {
        // Create bot player (hard difficulty)
        final botPlayer = BotPlayer(
          gridPosition: spawnPositions[i],
          color: playerData.character.fallbackColor,
          character: playerData.character,
          playerNumber: i + 1,
          tileSize: tileSize,
          gridWidth: gridWidth,
          gridHeight: gridHeight,
          getGameMap: () => gameMap,
          getIsGameOver: () => isGameOver,
          getJoystickDirection: () => Vector2.zero(), // Bots don't use joystick
          isBombAtPosition: _isBombAtPosition,
          getOtherPlayers: () => players, // Give bot access to all players for enemy tracking
        );
        
        // Override the requestBombPlacement method to connect to game logic
        botPlayer.onBombPlaceRequest = () {
          _handleBotBombPlacement(botPlayer);
        };
        
        player = botPlayer;
      } else {
        // Create human player
        player = Player(
          gridPosition: spawnPositions[i],
          color: playerData.character.fallbackColor,
          character: playerData.character,
          playerNumber: i + 1,
          tileSize: tileSize,
          gridWidth: gridWidth,
          gridHeight: gridHeight,
          getGameMap: () => gameMap,
          getIsGameOver: () => isGameOver,
          getJoystickDirection: () => i == 0
              ? Vector2(joystickDirection.dx, joystickDirection.dy)
              : Vector2.zero(), // Only player 1 uses joystick for now
          isBombAtPosition: _isBombAtPosition,
        );
      }
      
      player.playerHealth = 1; // Initialize player health
      players.add(player);
      add(player);
    }
  }

  void _handleBotBombPlacement(BotPlayer bot) {
    if (!bot.canPlaceBomb() || isGameOver) return;
    
    final bombPosition = bot.gridPosition;
    
    // Check if there's already a bomb at this position
    if (_isBombAtPosition(bombPosition)) {
      return;
    }
    
    // Place the bomb
    final newBomb = Bomb(
      gridPosition: bombPosition,
      tileSize: tileSize,
      onExplode: explodeBomb,
      ownerPlayer: bot,
      ownerCharacter: bot.character,
      fallbackColor: bot.color,
    );
    
    bombs.add(newBomb);
    add(newBomb);
    bot.incrementBombCount();
    bot.playBombThrowAnimation();
  }

  Future<void> _initializeNetworking() async {
    if (!_networkEnabled) {
      return;
    }

    _ensureNetworkListeners();

    if (_networkJoined) {
      return;
    }

    try {
      await networkClient!.ensureConnected();
      await networkClient!.joinRoom(networkRoomId!, networkPlayerId!);
      _networkJoined = true;
    } catch (error) {
      debugPrint('Failed to join game hub room: $error');
    }
  }

  void _ensureNetworkListeners() {
    if (!_networkEnabled || _networkSubscriptions.isNotEmpty) {
      return;
    }

    final client = networkClient!;

    _networkSubscriptions.add(
      client.roomRosterStream.listen(_applyRemoteRoster),
    );

    _networkSubscriptions.add(
      client.playerJoinedStream.listen(_handleRemotePlayerJoined),
    );

    _networkSubscriptions.add(
      client.playerLeftStream.listen(_handleRemotePlayerLeft),
    );

    _networkSubscriptions.add(
      client.playerDisconnectedStream.listen(_handleRemotePlayerLeft),
    );

    _networkSubscriptions.add(
      client.playerMovementStream.listen(_handleRemoteMovement),
    );

    _networkSubscriptions.add(
      client.gameEndedStream.listen(_handleRemoteGameEnded),
    );
  }

  Future<void> _teardownNetworking() async {
    if (_networkSubscriptions.isNotEmpty) {
      for (final subscription in _networkSubscriptions) {
        await subscription.cancel();
      }
      _networkSubscriptions.clear();
    }

    if (_remotePlayers.isNotEmpty) {
      for (final remote in _remotePlayers.values) {
        remote.removeFromParent();
      }
      _remotePlayers.clear();
    }
    _playerColors.clear();

    if (_networkJoined && networkRoomId != null) {
      try {
        await networkClient!.leaveRoom(networkRoomId!);
      } catch (error) {
        debugPrint('Failed to leave game hub room cleanly: $error');
      }
    }

    _networkJoined = false;
  }

  void _handleRemoteGameEnded(GameEndedEvent event) {
    if (isGameOver) {
      return;
    }

    isGameOver = true;
    paused = true;
    onGameStateChanged(true);
  }

  void _dispatchNetworkCall(Future<void> future, String actionDescription) {
    unawaited(
      future.catchError((error, stackTrace) {
        debugPrint('Game hub $actionDescription failed: $error');
      }),
    );
  }

  void _applyRemoteRoster(List<PlayerSummary> roster) {
    final desiredIds = <int>{};
    for (final summary in roster) {
      if (summary.playerId == networkPlayerId) {
        continue;
      }
      _playerNames[summary.playerId] = summary.displayName;
      desiredIds.add(summary.playerId);
      _ensureRemotePlayer(summary);
    }

    final toRemove = _remotePlayers.keys
        .where((id) => !desiredIds.contains(id))
        .toList(growable: false);
    for (final id in toRemove) {
      _removeRemotePlayer(id);
    }

    if (roster.isNotEmpty) {
      notifyListeners();
    }
  }

  void _handleRemotePlayerJoined(PlayerSummary summary) {
    if (summary.playerId == networkPlayerId) {
      return;
    }
    _playerNames[summary.playerId] = summary.displayName;
    _ensureRemotePlayer(summary);
    notifyListeners();
  }

  void _handleRemotePlayerLeft(PlayerSummary summary) {
    _removeRemotePlayer(summary.playerId);
    notifyListeners();
  }

  void _handleRemoteMovement(PlayerMovementEvent event) {
    if (event.playerId == networkPlayerId) {
      return;
    }
    var remote = _remotePlayers[event.playerId];
    if (remote == null) {
      final name = _playerNames[event.playerId] ?? 'Player ${event.playerId}';
      _ensureRemotePlayer(
        PlayerSummary(playerId: event.playerId, displayName: name),
      );
      remote = _remotePlayers[event.playerId];
    }
    if (remote == null) {
      return;
    }
    final effectiveTileSize = tileSize == 0 ? 1.0 : tileSize;
    remote.applyMovement(event.payload, effectiveTileSize);
  }

  void _ensureRemotePlayer(PlayerSummary summary) {
    if (summary.playerId == networkPlayerId) {
      return;
    }

    _playerNames[summary.playerId] = summary.displayName;
    final color = _colorForPlayer(summary.playerId);
    final existing = _remotePlayers[summary.playerId];

    if (existing != null) {
      existing.displayName = summary.displayName;
      return;
    }

    final effectiveTileSize = tileSize == 0 ? 1.0 : tileSize;
    final remotePlayer = RemotePlayer(
      playerId: summary.playerId,
      displayName: summary.displayName,
      tileSize: effectiveTileSize,
      color: color,
    );
    if (tileSize > 0) {
      remotePlayer.updateTileSize(tileSize);
    }
    remotePlayer.position = Vector2.all(tileSize);
    add(remotePlayer);
    _remotePlayers[summary.playerId] = remotePlayer;
  }

  void _removeRemotePlayer(int playerId) {
    final remote = _remotePlayers.remove(playerId);
    remote?.removeFromParent();
    _playerNames.remove(playerId);
  }

  Color _colorForPlayer(int playerId) {
    return _playerColors.putIfAbsent(playerId, () {
      final colors = Colors.primaries;
      final material = colors[playerId % colors.length];
      return material.shade400;
    });
  }

  void _broadcastLocalMovement() {
    if (!_networkJoined ||
        networkClient == null ||
        networkRoomId == null ||
        networkPlayerId == null) {
      return;
    }

    final localPlayer = players.firstOrNull;
    if (localPlayer == null) {
      return;
    }

    final payload = <String, dynamic>{
      'gridX': localPlayer.gridPosition.x.toInt(),
      'gridY': localPlayer.gridPosition.y.toInt(),
      'pixelX': localPlayer.position.x,
      'pixelY': localPlayer.position.y,
      'velocityX': localPlayer.velocity.x,
      'velocityY': localPlayer.velocity.y,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    _dispatchNetworkCall(
      networkClient!.sendPlayerMovement(networkRoomId!, payload),
      'sendPlayerMovement',
    );
  }

  void _broadcastBombPlacement(Bomb bomb) {
    if (!_networkJoined || networkClient == null || networkRoomId == null) {
      return;
    }

    final payload = <String, dynamic>{
      'gridX': bomb.gridPosition.x.toInt(),
      'gridY': bomb.gridPosition.y.toInt(),
      'timer': bomb.timer,
    };

    if (networkPlayerId != null) {
      payload['playerId'] = networkPlayerId;
    }

    _dispatchNetworkCall(
      networkClient!.sendBombPlaced(networkRoomId!, payload),
      'sendBombPlaced',
    );
  }

  void _broadcastExplosion(Vector2 centerPos, int explosionRadius) {
    if (!_networkJoined || networkClient == null || networkRoomId == null) {
      return;
    }

    final payload = <String, dynamic>{
      'center': {'x': centerPos.x.toInt(), 'y': centerPos.y.toInt()},
      'radius': explosionRadius,
    };

    if (networkPlayerId != null) {
      payload['playerId'] = networkPlayerId;
    }

    _dispatchNetworkCall(
      networkClient!.sendExplosion(networkRoomId!, payload),
      'sendExplosion',
    );
  }

  // Method to update joystick direction from Flutter widget
  void updateJoystickDirection(Offset direction) {
    joystickDirection = direction;
  }

  bool canMoveToPosition(Vector2 gridPos) {
    if (gridPos.x < 0 ||
        gridPos.x >= gridWidth ||
        gridPos.y < 0 ||
        gridPos.y >= gridHeight) {
      return false;
    }
    return gameMap[gridPos.y.toInt()][gridPos.x.toInt()] == TileType.empty;
  }

  bool _isBombAtPosition(Vector2 gridPos) {
    return bombs.any(
      (bomb) =>
          bomb.gridPosition.x.toInt() == gridPos.x.toInt() &&
          bomb.gridPosition.y.toInt() == gridPos.y.toInt(),
    );
  }

  void placeBomb() {
    if (isGameOver || players.isEmpty) return;

    // Place bomb for player 1 (controlled by keyboard/joystick)
    // In the future, this can be extended to handle multiple player inputs
    final activePlayer = players.firstOrNull;
    if (activePlayer == null) return;

    // Check if player can place more bombs
    if (!activePlayer.canPlaceBomb()) return;

    final playerGridPos = activePlayer.gridPosition;

    // Check if there's already a bomb at this position
    final existingBomb = bombs.any(
      (bomb) =>
          bomb.gridPosition.x.toInt() == playerGridPos.x.toInt() &&
          bomb.gridPosition.y.toInt() == playerGridPos.y.toInt(),
    );

    if (!existingBomb) {
      final bomb = Bomb(
        gridPosition: playerGridPos,
        onExplode: explodeBomb,
        tileSize: tileSize,
        ownerCharacter: activePlayer.character,
        ownerPlayer: activePlayer,
        fallbackColor: activePlayer.color,
      );
      bombs.add(bomb);
      add(bomb);

      // Increment player's bomb count
      activePlayer.incrementBombCount();

      _broadcastBombPlacement(bomb);

      // Play bomb throw animation for the active player
      activePlayer.playBombThrowAnimation();
    }
  }

  void explodeBomb(Bomb bomb) {
    bombs.remove(bomb);
    bomb.removeFromParent();

    // Decrement the owner player's bomb count
    if (bomb.ownerPlayer != null) {
      bomb.ownerPlayer!.decrementBombCount();
    }

    // Use the owner player's explosion radius
    final explosionRadius = bomb.ownerPlayer?.explosionRadius ?? 1;

    // Create explosion with player's explosion radius
    createExplosion(bomb.gridPosition, explosionRadius);
    _broadcastExplosion(bomb.gridPosition, explosionRadius);
  }

  void createExplosion(Vector2 centerPos, int explosionRadius) {
    // Explosion directions (up, down, left, right)
    final directions = [
      Vector2(0, -1), // Up
      Vector2(0, 1), // Down
      Vector2(-1, 0), // Left
      Vector2(1, 0), // Right
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
        if (explodePos.x < 0 ||
            explodePos.x >= gridWidth ||
            explodePos.y < 0 ||
            explodePos.y >= gridHeight) {
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
    final explosion = ExplosionEffect(gridPosition: pos, tileSize: tileSize);
    add(explosion);

    // Check if player is at this position
    _checkPlayerDamage(pos);

    // Destroy destructible walls
    if (gameMap[y][x] == TileType.destructible) {
      gameMap[y][x] = TileType.empty;
      score += 10; // Add points for destroying walls

      // 20% chance to spawn a random powerup
      if (_random.nextDouble() < 0.20) {
        _spawnRandomPowerup(pos);
      }

      // Update the visual tile
      _updateTileVisual(pos);
    }
  }

  void _spawnRandomPowerup(Vector2 pos) {
    // Randomly select one of the 4 powerup types with equal probability
    final powerupTypes = PowerupType.values;
    final randomType = powerupTypes[_random.nextInt(powerupTypes.length)];
    
    final powerup = Powerup(
      type: randomType,
      gridPosition: pos,
      tileSize: tileSize,
    );
    
    add(powerup);
    powerups.add(powerup);
  }

  void _updateTileVisual(Vector2 gridPos) {
    // Find and update the tile component
    final tileComponents = children.whereType<MapTile>();
    for (final tile in tileComponents) {
      if (tile.gridPosition.x == gridPos.x &&
          tile.gridPosition.y == gridPos.y) {
        tile.updateTileType(TileType.empty);
        break;
      }
    }
  }

  void _checkPlayerDamage(Vector2 explosionPos) {
    if (isGameOver) return;

    final explosionX = explosionPos.x.toInt();
    final explosionY = explosionPos.y.toInt();

    // Check each player
    for (int i = 0; i < players.length; i++) {
      final player = players[i];

      // Skip if player is already dead or invincible
      if (player.playerHealth <= 0 || playerInvincibility[i]) continue;

      // Check if player's grid position matches explosion position
      final playerGridX = player.gridPosition.x.toInt();
      final playerGridY = player.gridPosition.y.toInt();

      if (playerGridX == explosionX && playerGridY == explosionY) {
        // Reduce player health by 1
        player.playerHealth--;

        // Activate invincibility
        playerInvincibility[i] = true;
        invincibilityTimers[i] = invincibilityDuration;

        // Check if player is dead
        if (player.playerHealth <= 0) {
          alivePlayers--;
          player.removeFromParent();

          // Check if game is over (only one or no players left)
          if (alivePlayers <= 1) {
            _gameOver();
          }
        }
      }
    }
  }

  void _checkPowerupCollection() {
    if (isGameOver) return;

    // Check each player against each powerup
    for (final player in players) {
      if (player.playerHealth <= 0) continue;

      final playerGridX = player.gridPosition.x.toInt();
      final playerGridY = player.gridPosition.y.toInt();

      // Check all powerups
      final powerupsToRemove = <Powerup>[];
      for (final powerup in powerups) {
        if (powerup.collected) continue;

        final powerupGridX = powerup.gridPosition.x.toInt();
        final powerupGridY = powerup.gridPosition.y.toInt();

        // Check if player is on the same grid position as powerup
        if (playerGridX == powerupGridX && playerGridY == powerupGridY) {
          // Apply powerup to player
          powerup.applyToPlayer(player);
          
          // Mark for removal
          powerupsToRemove.add(powerup);
          powerup.removeFromParent();
        }
      }

      // Remove collected powerups from tracking list
      powerups.removeWhere((p) => powerupsToRemove.contains(p));
    }
  }

  void _gameOver() {
    isGameOver = true;
    paused = true;
    
    // Find the winner (the last player alive)
    winner = players.firstWhere(
      (player) => player.playerHealth > 0,
      orElse: () => players.first, // Fallback if all died simultaneously
    );
    
    onGameStateChanged(true, winner: winner); // Notify that game is over with winner
  }

  void restartGame() {
    isGameOver = false;
    paused = false;
    maxBombs = 1; // Reset to default
    score = 0;
    alivePlayers = selectedPlayers.length;
    winner = null; // Clear winner

    // Reset invincibility for all players
    playerInvincibility = [false, false, false, false];
    invincibilityTimers = [0.0, 0.0, 0.0, 0.0];

    // Clear existing components
    removeAll(children.whereType<Bomb>());
    removeAll(children.whereType<ExplosionEffect>());
    removeAll(children.whereType<Player>());
    removeAll(children.whereType<JoystickComponent>());
    removeAll(
      children.whereType<RectangleComponent>(),
    ); // Remove any backgrounds
    bombs.clear();

    // Regenerate map and respawn players
    removeAll(children.whereType<MapTile>());
    _generateMap();
    _renderMap();
    _spawnPlayer();

    onGameStateChanged(false); // Notify that game restarted
  }

  @override
  void onRemove() {
    if (_networkEnabled) {
      _dispatchNetworkCall(_teardownNetworking(), 'teardownNetworking');
    }
    super.onRemove();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
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
    // Control player 1 with keyboard
    if (joystickDirection.distance < 0.1 && players.isNotEmpty) {
      players.first.setMovement(direction);
    }

    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update invincibility timer for each player
    for (int i = 0; i < players.length; i++) {
      if (playerInvincibility[i]) {
        invincibilityTimers[i] -= dt;

        if (invincibilityTimers[i] <= 0) {
          playerInvincibility[i] = false;
          invincibilityTimers[i] = 0.0;
        }

        // Visual feedback: make player flash by changing opacity
        final player = players[i];
        if (player.playerHealth > 0) {
          // Flash effect: alternates visibility every 0.2 seconds
          final flashInterval = 0.2;
          final flashPhase =
              (invincibilityTimers[i] % flashInterval) / flashInterval;

          // Update opacity for all component types
          if (player.rectangleComponent != null) {
            player.rectangleComponent!.paint.color = player.color.withOpacity(
              flashPhase > 0.5 ? 1.0 : 0.3,
            );
          } else if (player.animationGroupComponent != null) {
            player.animationGroupComponent!.opacity = flashPhase > 0.5
                ? 1.0
                : 0.3;
          } else if (player.spriteComponent != null) {
            player.spriteComponent!.opacity = flashPhase > 0.5 ? 1.0 : 0.3;
          }
        }
      } else {
        // Restore full opacity when not invincible
        final player = players[i];
        if (player.playerHealth > 0) {
          if (player.rectangleComponent != null) {
            player.rectangleComponent!.paint.color = player.color.withOpacity(
              1.0,
            );
          } else if (player.animationGroupComponent != null) {
            player.animationGroupComponent!.opacity = 1.0;
          } else if (player.spriteComponent != null) {
            player.spriteComponent!.opacity = 1.0;
          }
        }
      }
    }

    // Check for powerup collection
    _checkPowerupCollection();

    if (_networkJoined) {
      _movementBroadcastTimer += dt;
      if (_movementBroadcastTimer >= _movementBroadcastInterval) {
        _movementBroadcastTimer = 0.0;
        _broadcastLocalMovement();
      }
    }
  }
}
