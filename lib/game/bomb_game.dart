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
  int _nextPowerupId = 0; // Counter for generating unique powerup IDs
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
  final Map<int, PlayerCharacter> _playerCharacters = {}; // Maps playerId to selected character
  final Map<int, int> _playerIdToRoomPosition = {}; // Maps server playerId to room position (1-4)
  final List<PlayerSummary> _pendingRemotePlayers = []; // Store players until grid is ready
  final Set<int> _deadPlayers = {}; // Track dead players to prevent re-adding them
  
  int? _winnerPlayerNumber; // Stores the winner's player number (1-4) for display
  String? _winnerNameFromBackend; // Stores winner name received from backend

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
  
  // Get the winner's player number for multiplayer (useful for dead players)
  int? get winnerPlayerNumber => _winnerPlayerNumber;
  
  // Get the winner's name for multiplayer display
  String? get winnerName {
    // Prioritize backend winner name if available
    if (_winnerNameFromBackend != null) {
      return _winnerNameFromBackend;
    }
    
    if (_winnerPlayerNumber == null) return null;
    
    // Find the player ID with this room position
    final winnerEntry = _playerIdToRoomPosition.entries
        .firstWhere(
          (entry) => entry.value == _winnerPlayerNumber,
          orElse: () => const MapEntry(-1, -1),
        );
    
    if (winnerEntry.key != -1) {
      return _playerNames[winnerEntry.key];
    }
    return null;
  }

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

    // Update any remote players that were created before grid initialization
    _repositionRemotePlayers();

    for (final remote in _remotePlayers.values) {
      remote.updateTileSize(tileSize);
      if (!remote.isMounted) {
        add(remote);
      }
    }
  }

  void _repositionRemotePlayers() {
    print('=== REPOSITIONING REMOTE PLAYERS ===');
    print('Grid: ${gridWidth}x$gridHeight, Tile: $tileSize');
    print('Pending players: ${_pendingRemotePlayers.length}');
    print('Existing remote players: ${_remotePlayers.length}');

    // First, create any pending remote players
    for (final pendingPlayer in _pendingRemotePlayers) {
      print('Creating pending player: ${pendingPlayer.playerId}');
      _ensureRemotePlayer(pendingPlayer);
    }
    _pendingRemotePlayers.clear();

    // Then reposition existing players (in case they were created with wrong dimensions)
    if (_remotePlayers.isEmpty) {
      print('No remote players to reposition');
      return;
    }

    final spawnPositions = [
      Vector2(1, 1), // Top-left - Player ID 1
      Vector2(gridWidth - 2.0, 1), // Top-right - Player ID 2
      Vector2(1, gridHeight - 2.0), // Bottom-left - Player ID 3
      Vector2(gridWidth - 2.0, gridHeight - 2.0), // Bottom-right - Player ID 4
    ];

    for (final entry in _remotePlayers.entries) {
      final playerId = entry.key;
      final remote = entry.value;
      
      // Get room position from mapping, default to position based on playerId if not found
      final roomPosition = _playerIdToRoomPosition[playerId] ?? playerId;
      final spawnIndex = (roomPosition - 1).clamp(0, spawnPositions.length - 1);
      final spawnPos = spawnPositions[spawnIndex];
      // Add the same 0.1 offset that local players have
      final pixelPos = Vector2(
        spawnPos.x * tileSize + tileSize * 0.1,
        spawnPos.y * tileSize + tileSize * 0.1,
      );
      
      remote.position = pixelPos;
      remote.updateTileSize(tileSize);
      
      print('Repositioned Player $playerId (Room Pos $roomPosition) to grid(${spawnPos.x}, ${spawnPos.y}) = pixel$pixelPos');
    }
    
    print('Total remote players after repositioning: ${_remotePlayers.length}');
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
      Vector2(1, 1), // Top-left - Player ID 1
      Vector2(gridWidth - 2, 1), // Top-right - Player ID 2
      Vector2(1, gridHeight - 2), // Bottom-left - Player ID 3
      Vector2(gridWidth - 2, gridHeight - 2), // Bottom-right - Player ID 4
    ];

    // Clear existing players
    players.clear();
    alivePlayers = selectedPlayers.length;

    // In multiplayer mode, only create local player
    if (_networkEnabled && networkPlayerId != null) {
      print('=== MULTIPLAYER SPAWN ===');
      print('Network Player ID: $networkPlayerId');
      print('Local Player ID: $localPlayerId');
      print('Selected Players: ${selectedPlayers.length}');
      print('Player ID to Room Position map: $_playerIdToRoomPosition');
      
      // Get room position (1-4) from mapping
      // If not yet set (roster hasn't arrived), we need to wait or use a default
      int roomPosition;
      if (_playerIdToRoomPosition.containsKey(networkPlayerId)) {
        roomPosition = _playerIdToRoomPosition[networkPlayerId]!;
        print('Using mapped room position: $roomPosition');
      } else {
        // Roster hasn't arrived yet - this shouldn't happen but handle gracefully
        // For now, assume position 1 and it will be corrected when roster arrives
        print('WARNING: Room position not yet assigned, using temporary position 1');
        roomPosition = 1;
      }
      
      print('Room Position for Player $networkPlayerId: $roomPosition');
      
      // Use room position (1-based) to determine spawn position
      final spawnIndex = (roomPosition - 1).clamp(0, spawnPositions.length - 1);
      final spawnPos = spawnPositions[spawnIndex];
      
      print('Spawning local player at index $spawnIndex (${spawnPos.x}, ${spawnPos.y})');
      
      // Get the character for this player
      // First try to get from the character map (populated from roster)
      PlayerCharacter character;
      if (networkPlayerId != null && _playerCharacters.containsKey(networkPlayerId)) {
        character = _playerCharacters[networkPlayerId]!;
        print('Using character from character map: ${character.displayName}');
      } else if (selectedPlayers.isNotEmpty && roomPosition <= selectedPlayers.length) {
        // Fallback: get character from selectedPlayers based on room position
        character = selectedPlayers[roomPosition - 1].character;
        print('Using character from position ${roomPosition}: ${character.displayName}');
      } else {
        // Final fallback
        character = selectedPlayers.isNotEmpty 
            ? selectedPlayers.first.character
            : PlayerCharacter.character1;
        print('WARNING: Using fallback character: ${character.displayName}');
      }
      
      final playerData = PlayerSelectionData(character: character, isBot: false);
      
      // Create only the local player
      final player = Player(
        gridPosition: spawnPos,
        color: playerData.character.fallbackColor,
        character: playerData.character,
        playerNumber: roomPosition, // Use room position (1-4)
        tileSize: tileSize,
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        getGameMap: () => gameMap,
        getIsGameOver: () => isGameOver,
        getJoystickDirection: () => Vector2(joystickDirection.dx, joystickDirection.dy),
        isBombAtPosition: _isBombAtPosition,
      );
      
      player.playerHealth = 1;
      players.add(player);
      add(player);
      
      print('Local player spawned: gridPos(${player.gridPosition.x}, ${player.gridPosition.y}), pixelPos(${player.position.x}, ${player.position.y})');
      print('TileSize: $tileSize, GridSize: ${gridWidth}x$gridHeight');
      print('Player character: ${playerData.character.displayName} (index: ${playerData.character.index})');
      
      // Send character selection to backend to ensure consistency
      _sendCharacterSelection(networkPlayerId, playerData.character);
      
      return;
    }

    print('=== SINGLE PLAYER SPAWN ===');
    print('Spawning ${selectedPlayers.length} player(s)');
    // Single player / local mode - create all players
    for (int i = 0; i < selectedPlayers.length; i++) {
      final playerData = selectedPlayers[i];
      final spawnPos = spawnPositions[i];
      print('Player ${i + 1} spawning at: (${spawnPos.x}, ${spawnPos.y})');
      Player player;
      
      if (playerData.isBot) {
        // Create bot player (hard difficulty)
        final botPlayer = BotPlayer(
          gridPosition: spawnPos,
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
          gridPosition: spawnPos,
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
      print('  -> Added: Player ${i + 1} at (${player.gridPosition.x}, ${player.gridPosition.y}), Health: ${player.playerHealth}');
    }
    
    print('Total players spawned: ${players.length}');
    for (int i = 0; i < players.length; i++) {
      print('  Player ${i + 1}: Position (${players[i].gridPosition.x}, ${players[i].gridPosition.y})');
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
      client.gameStartStream.listen(_handleGameStarted),
    );

    _networkSubscriptions.add(
      client.characterSelectedStream.listen(_handleCharacterSelected),
    );

    _networkSubscriptions.add(
      client.playerMovementStream.listen(_handleRemoteMovement),
    );

    _networkSubscriptions.add(
      client.bombPlacedStream.listen(_handleRemoteBombPlaced),
    );

    _networkSubscriptions.add(
      client.explosionStream.listen(_handleRemoteExplosion),
    );

    _networkSubscriptions.add(
      client.playerDiedStream.listen(_handleRemotePlayerDied),
    );

    _networkSubscriptions.add(
      client.itemCollectedStream.listen(_handleRemoteItemCollected),
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

  void _handleGameStarted(GameStartEvent event) {
    print('=== GAME STARTED EVENT RECEIVED ===');
    print('Room ID: ${event.roomId}');
    print('Player Characters from backend: ${event.playerCharacters}');
    
    // Apply character data from backend if available
    if (event.playerCharacters != null) {
      final charMap = event.playerCharacters!;
      for (final entry in charMap.entries) {
        final playerId = int.tryParse(entry.key);
        var characterId = entry.value as int?;
        
        print('Processing character for player $playerId: characterId=$characterId');
        
        // Backend might use 1-based IDs (1,2,3,4) while enum is 0-based (0,1,2,3)
        // Convert if necessary
        if (characterId != null && characterId > 0) {
          // Assume backend uses 1-based, convert to 0-based index
          final characterIndex = characterId - 1;
          
          print('  Backend characterId: $characterId (1-based)');
          print('  Converted to index: $characterIndex (0-based)');
          
          if (playerId != null && 
              characterIndex >= 0 && characterIndex < PlayerCharacter.values.length) {
            final character = PlayerCharacter.values[characterIndex];
            _playerCharacters[playerId] = character;
            print('✓ Applied character for player $playerId: ${character.displayName} (${character.name})');
            
            // If remote player already exists, update their character
            if (_remotePlayers.containsKey(playerId)) {
              print('  Recreating remote player $playerId with correct character');
              _removeRemotePlayer(playerId);
              final name = _playerNames[playerId] ?? 'Player $playerId';
              _ensureRemotePlayer(
                PlayerSummary(playerId: playerId, displayName: name),
              );
            }
          } else {
            print('⚠ Invalid character index after conversion: $characterIndex (from ID: $characterId)');
          }
        } else {
          print('⚠ Invalid character ID: $characterId');
        }
      }
    }
  }

  void _handleCharacterSelected(CharacterSelectedEvent event) {
    print('=== CHARACTER SELECTED EVENT RECEIVED ===');
    print('Player ID: ${event.playerId}');
    print('Character ID from backend: ${event.characterIndex}');
    
    // Backend might use 1-based IDs (1,2,3,4) while enum is 0-based (0,1,2,3)
    // Convert if necessary
    var characterId = event.characterIndex;
    if (characterId > 0) {
      final characterIndex = characterId - 1; // Convert to 0-based
      
      print('  Backend characterId: $characterId (1-based)');
      print('  Converted to index: $characterIndex (0-based)');
      
      if (characterIndex >= 0 && characterIndex < PlayerCharacter.values.length) {
        final character = PlayerCharacter.values[characterIndex];
        _playerCharacters[event.playerId] = character;
        print('✓ Stored character for player ${event.playerId}: ${character.displayName} (${character.name})');
        
        // If remote player already exists and it's not us, update their character
        if (event.playerId != networkPlayerId && _remotePlayers.containsKey(event.playerId)) {
          print('  Recreating remote player ${event.playerId} with new character');
          _removeRemotePlayer(event.playerId);
          final name = _playerNames[event.playerId] ?? 'Player ${event.playerId}';
          _ensureRemotePlayer(
            PlayerSummary(playerId: event.playerId, displayName: name),
          );
        }
      } else {
        print('⚠ Invalid character index after conversion: $characterIndex (from ID: $characterId)');
      }
    } else {
      print('⚠ Invalid character ID: $characterId');
    }
  }

  void _handleRemoteGameEnded(GameEndedEvent event) {
    if (isGameOver) {
      return;
    }

    print('Received gameEnded event from server');
    print('=== GAME ENDED EVENT FROM BACKEND ===');
    print('  winnerId: ${event.winnerId}');
    print('  winnerName: "${event.winnerName}"');
    print('  winnerRoomPosition: ${event.winnerRoomPosition}');
    print('  Current _playerNames map: $_playerNames');
    isGameOver = true;
    
    // Use winner data from backend if available
    if (event.winnerRoomPosition != null) {
      _winnerPlayerNumber = event.winnerRoomPosition;
      _winnerNameFromBackend = event.winnerName; // Store name from backend
      print('✓ Using winner data from backend:');
      print('  - Winner room position: P${event.winnerRoomPosition}');
      print('  - Winner name from backend: "${event.winnerName}"');
      print('  - Stored as _winnerNameFromBackend: "$_winnerNameFromBackend"');
    } else {
      // Fallback: Find the winner - the player NOT in the dead set
      print('=== GAME ENDED - FINDING WINNER FOR DEAD PLAYER ===');
      print('Dead players: $_deadPlayers');
      print('All players in room: ${_playerIdToRoomPosition.keys.toList()}');
      
      int? winnerPlayerId;
      
      // Find the player who is NOT dead
      for (var playerId in _playerIdToRoomPosition.keys) {
        if (!_deadPlayers.contains(playerId)) {
          winnerPlayerId = playerId;
          break;
        }
      }
      
      if (winnerPlayerId != null) {
        final winnerRoomPos = _playerIdToRoomPosition[winnerPlayerId] ?? 1;
        _winnerPlayerNumber = winnerRoomPos;
        final winnerName = _playerNames[winnerPlayerId] ?? 'Player $winnerRoomPos';
        print('✓ Winner is player $winnerPlayerId (P$winnerRoomPos - $winnerName)');
      } else {
        print('⚠ Warning: Could not determine winner from gameEnded event!');
        _winnerPlayerNumber = 1; // Fallback
      }
    }
    
    // Now notify to show winning screen to dead players
    onGameStateChanged(true, winner: winner);
  }

  void _sendGameEndToBackend(int winnerId, int winnerRoomPosition, String? winnerName) {
    if (!_networkJoined || networkClient == null || networkRoomId == null) {
      print('Cannot send game end - not connected to network');
      return;
    }

    print('=== SENDING GAME END TO BACKEND ===');
    print('Winner ID: $winnerId');
    print('Winner Room Position: $winnerRoomPosition');
    print('Winner Name: $winnerName');

    final summary = <String, dynamic>{
      'winnerId': winnerId,
      'winnerRoomPosition': winnerRoomPosition,
      'winnerName': winnerName ?? 'Player $winnerRoomPosition',
      'timestamp': DateTime.now().toIso8601String(),
    };

    _dispatchNetworkCall(
      networkClient!.sendGameEnd(networkRoomId!, summary),
      'sendGameEnd',
    );
  }

  void _sendCharacterSelection(int? playerId, PlayerCharacter character) {
    if (!_networkJoined || networkClient == null || networkRoomId == null || playerId == null) {
      print('Cannot send character selection - not connected to network');
      return;
    }

    print('=== SENDING CHARACTER SELECTION TO BACKEND ===');
    print('Player ID: $playerId');
    print('Character: ${character.displayName} (enum: ${character.name})');
    print('Enum index (0-based): ${character.index}');
    
    // Backend expects 1-based character IDs (1,2,3,4), so add 1 to the 0-based index
    final characterId = character.index + 1;
    print('Sending character ID (1-based): $characterId');

    _dispatchNetworkCall(
      networkClient!.selectCharacter(networkRoomId!, playerId, characterId),
      'selectCharacter',
    );
  }

  void _dispatchNetworkCall(Future<void> future, String actionDescription) {
    unawaited(
      future.catchError((error, stackTrace) {
        debugPrint('Game hub $actionDescription failed: $error');
      }),
    );
  }

  void _applyRemoteRoster(RoomRosterEvent rosterEvent) {
    final roster = rosterEvent.players;
    final hostPlayerId = rosterEvent.hostPlayerId;
    
    print('=== APPLY REMOTE ROSTER ===');
    print('Roster size: ${roster.length}');
    print('Host player ID from backend: $hostPlayerId');
    print('My player ID: $networkPlayerId');
    print('Roster contents:');
    for (var p in roster) {
      print('  - Player ${p.playerId}: ${p.displayName}${p.playerId == hostPlayerId ? " (HOST)" : ""}');
    }
    
    // Build the full player list in join order
    // The roster from server should already be in join order
    final allPlayers = <PlayerSummary>[];
    
    // Check if we're in the roster
    bool foundSelf = roster.any((p) => p.playerId == networkPlayerId);
    print('Am I in roster? $foundSelf');
    
    if (foundSelf) {
      // Roster includes us - use it as-is (server knows the correct order)
      allPlayers.addAll(roster);
    } else {
      // We're not in roster yet - shouldn't happen normally
      // But if it does, just use the roster and we'll get our position later
      print('WARNING: Not in roster yet, using roster as-is');
      allPlayers.addAll(roster);
    }
    
    print('Final player list for position assignment:');
    for (int i = 0; i < allPlayers.length; i++) {
      print('  Position ${i + 1}: Player ${allPlayers[i].playerId} (${allPlayers[i].displayName})');
    }
    
    // Assign room positions (1-4) based on roster order (join order)
    _playerIdToRoomPosition.clear();
    for (int i = 0; i < allPlayers.length; i++) {
      final playerId = allPlayers[i].playerId;
      final roomPosition = i + 1; // 1-based position
      _playerIdToRoomPosition[playerId] = roomPosition;
      print('Player ID $playerId -> Room Position $roomPosition (${allPlayers[i].displayName})');
      
      // Map character from selectedPlayers based on roster order
      // selectedPlayers is ordered by lobby/roster join order, so index i should match
      if (i < selectedPlayers.length) {
        _playerCharacters[playerId] = selectedPlayers[i].character;
        print('  -> Character from selectedPlayers[$i]: ${selectedPlayers[i].character.displayName}');
      }
    }
    
    // Update our own player if position changed
    if (networkPlayerId != null && _playerIdToRoomPosition.containsKey(networkPlayerId)) {
      final myPosition = _playerIdToRoomPosition[networkPlayerId]!;
      print('My assigned position: P$myPosition');
      
      // If we have a local player and position changed, recreate it
      if (players.isNotEmpty) {
        final oldNumber = players.first.playerNumber;
        if (oldNumber != myPosition) {
          print('Position changed from P$oldNumber to P$myPosition, recreating player');
          // Remove old player
          players.first.removeFromParent();
          players.clear();
          // Recreate with correct position
          _spawnPlayer();
        }
      }
    }
    
    final desiredIds = <int>{};
    for (final summary in roster) {
      print('Processing roster entry: playerId=${summary.playerId}, displayName="${summary.displayName}"');
      if (summary.playerId == networkPlayerId) {
        print('  -> Skipping (this is me)');
        continue;
      }
      _playerNames[summary.playerId] = summary.displayName;
      print('  -> Stored player name: $_playerNames[${summary.playerId}] = "${summary.displayName}"');
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
    
    print('Remote players after roster: ${_remotePlayers.keys.toList()}');
    print('Final position mapping: $_playerIdToRoomPosition');
  }

  void _handleRemotePlayerJoined(PlayerSummary summary) {
    if (summary.playerId == networkPlayerId) {
      return;
    }
    _playerNames[summary.playerId] = summary.displayName;
    print('Remote player joined: playerId=${summary.playerId}, playerName="${summary.displayName}"');
    print('  -> Stored in _playerNames: ${_playerNames[summary.playerId]}');
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
    
    print('RECV: Player ${event.playerId} movement - payload: ${event.payload}');
    
    // Handle character selection messages
    final payload = event.payload;
    if (payload != null && payload['type'] == 'character_selection') {
      final characterIndex = payload['characterIndex'] as int?;
      if (characterIndex != null && characterIndex >= 0 && characterIndex < PlayerCharacter.values.length) {
        final character = PlayerCharacter.values[characterIndex];
        _playerCharacters[event.playerId] = character;
        print('Player ${event.playerId} character selection received: ${character.displayName}');
        
        // If remote player already exists, recreate with new character
        if (_remotePlayers.containsKey(event.playerId)) {
          print('Updating existing remote player with new character');
          _removeRemotePlayer(event.playerId);
          final name = _playerNames[event.playerId] ?? 'Player ${event.playerId}';
          _ensureRemotePlayer(
            PlayerSummary(playerId: event.playerId, displayName: name),
          );
        }
      }
      return; // Don't process as movement
    }
    
    var remote = _remotePlayers[event.playerId];
    if (remote == null) {
      print('Creating remote player ${event.playerId} on-the-fly');
      final name = _playerNames[event.playerId] ?? 'Player ${event.playerId}';
      _ensureRemotePlayer(
        PlayerSummary(playerId: event.playerId, displayName: name),
      );
      remote = _remotePlayers[event.playerId];
    }
    if (remote == null) {
      print('ERROR: Failed to create remote player ${event.playerId}');
      return;
    }
    final effectiveTileSize = tileSize == 0 ? 1.0 : tileSize;
    print('Applying with tileSize=$effectiveTileSize, grid: ${gridWidth}x${gridHeight}');
    remote.applyMovement(event.payload, effectiveTileSize);
    print('Remote player ${event.playerId} now at: ${remote.position}');
  }

  void _handleRemoteBombPlaced(BombPlacedEvent event) {
    if (event.playerId == networkPlayerId) {
      return; // Don't place our own bombs twice
    }

    final payload = event.payload;
    if (payload == null) {
      print('RECV: Bomb placed but no payload');
      return;
    }

    final gridX = payload['gridX'] as num?;
    final gridY = payload['gridY'] as num?;
    
    if (gridX == null || gridY == null) {
      print('RECV: Bomb placed but invalid grid position');
      return;
    }

    print('RECV: Bomb placed by player ${event.playerId} at grid($gridX, $gridY)');
    
    // Create the bomb at the specified location
    final bombGridPos = Vector2(gridX.toDouble(), gridY.toDouble());
    
    // Check if a bomb already exists here
    if (_isBombAtPosition(bombGridPos)) {
      print('Bomb already exists at this position, skipping');
      return;
    }

    final newBomb = Bomb(
      gridPosition: bombGridPos,
      tileSize: tileSize,
      onExplode: explodeBomb,
      ownerPlayer: null, // Remote player bomb - don't track owner
      ownerCharacter: null,
      fallbackColor: Colors.grey,
      isRemote: true, // Mark as remote bomb - won't auto-explode
    );

    bombs.add(newBomb);
    add(newBomb);
    print('Added remote bomb at grid($gridX, $gridY) - waiting for explosion event');
  }

  void _handleRemoteExplosion(ExplosionEvent event) {
    final payload = event.payload;
    if (payload == null) return;
    
    // Check if this is a powerup spawn event (piggyback on explosion events)
    final isPowerupSpawn = payload['isPowerupSpawn'] as bool?;
    if (isPowerupSpawn == true) {
      _handleRemotePowerupSpawn(payload);
      return;
    }
    
    // Handle remote bomb explosion
    final center = payload['center'] as Map<String, dynamic>?;
    final radius = payload['radius'] as num?;
    
    if (center == null || radius == null) {
      print('RECV: Invalid explosion payload');
      return;
    }
    
    final gridX = center['x'] as num?;
    final gridY = center['y'] as num?;
    
    if (gridX == null || gridY == null) {
      print('RECV: Invalid explosion center');
      return;
    }
    
    final bombPos = Vector2(gridX.toDouble(), gridY.toDouble());
    print('RECV: Explosion at grid($gridX, $gridY) with radius $radius');
    
    // Find and remove the bomb at this position
    final bomb = bombs.where((b) => 
      b.gridPosition.x.toInt() == bombPos.x.toInt() &&
      b.gridPosition.y.toInt() == bombPos.y.toInt()
    ).firstOrNull;
    
    if (bomb != null) {
      print('Found remote bomb at explosion position - exploding it now');
      // Trigger the explosion manually for this remote bomb
      explodeBomb(bomb);
    } else {
      print('No bomb found at explosion position - may have already exploded');
    }
  }

  void _handleRemotePowerupSpawn(Map<String, dynamic> payload) {
    final gridX = payload['gridX'] as num?;
    final gridY = payload['gridY'] as num?;
    final typeIndex = payload['type'] as num?;
    final powerupId = payload['id'] as num?;
    
    if (gridX == null || gridY == null || typeIndex == null || powerupId == null) {
      print('RECV: Invalid powerup spawn payload: $payload');
      return;
    }
    
    final pos = Vector2(gridX.toDouble(), gridY.toDouble());
    final type = PowerupType.values[typeIndex.toInt()];
    
    print('=== RECEIVED POWERUP SPAWN ===');
    print('Type: ${type.name} (index: ${typeIndex.toInt()})');
    print('Position: ($gridX, $gridY)');
    print('ID: $powerupId');
    
    // Create the powerup
    final powerup = Powerup(
      type: type,
      gridPosition: pos,
      tileSize: tileSize,
      id: powerupId.toInt(),
    );
    
    add(powerup);
    powerups.add(powerup);
    print('✓ Powerup created and added to game');
    
    // Update our counter to avoid ID conflicts
    if (powerupId.toInt() >= _nextPowerupId) {
      _nextPowerupId = powerupId.toInt() + 1;
    }
  }

  void _handleRemotePlayerDied(int playerId) {
    print('=== PLAYER DEATH EVENT RECEIVED ===');
    print('Dead Player ID: $playerId');
    print('My Player ID: $networkPlayerId');
    print('Current alive players: $alivePlayers');
    print('Remote players before removal: ${_remotePlayers.keys.toList()}');
    
    // Add to dead players set to prevent re-adding
    if (!_deadPlayers.contains(playerId)) {
      _deadPlayers.add(playerId);
      print('Added $playerId to dead players set: $_deadPlayers');
      
      // Only decrement if this player wasn't already marked as dead
      // This prevents double-decrement when receiving own death event
      if (alivePlayers > 0) {
        alivePlayers--;
        print('Alive players decreased to: $alivePlayers');
      }
    } else {
      print('Player $playerId already in dead set, not decrementing alivePlayers again');
    }
    
    if (playerId == networkPlayerId) {
      // Handle local player death from remote event (duplicate from server)
      print('This is MY death event (duplicate/from server)');
      if (players.isNotEmpty) {
        players.first.playerHealth = 0;
        // Remove the player body from the screen
        players.first.removeFromParent();
        print('Local player died (from remote event) and removed from map.');
      }
    } else {
      // Remove remote player - THIS MAKES THEM DISAPPEAR FOR OTHER PLAYERS
      print('Removing remote player $playerId from my screen');
      _removeRemotePlayer(playerId);
      print('Remote player $playerId should now be invisible');
    }
    
    print('Remote players after removal: ${_remotePlayers.keys.toList()}');
    
    // Check if game should end (only 1 player remaining wins)
    if (alivePlayers == 1 && !isGameOver) {
      print('Only $alivePlayers player left, ending game');
      _gameOver();
    }
  }

  void _handleRemoteItemCollected(ItemCollectedEvent event) {
    print('=== RECEIVED ItemCollected EVENT ===');
    print('Item ID: ${event.itemId}');
    print('Collected by player: ${event.playerId}');
    print('My player ID: $networkPlayerId');
    
    // Don't process our own collection events - we already applied it locally
    if (event.playerId == networkPlayerId) {
      print('This is my own collection event - just removing powerup visually');
      // Just remove the powerup from the list, don't apply it again
      final powerupToRemove = powerups.where((p) => p.id == event.itemId).firstOrNull;
      if (powerupToRemove != null) {
        print('Removing my collected powerup ${event.itemId} from game');
        powerupToRemove.collected = true;
        powerupToRemove.removeFromParent();
        powerups.remove(powerupToRemove);
      }
      return;
    }
    
    // For other players' collections, just remove the powerup from our view
    print('Another player collected this item - removing from my view');
    final powerupToRemove = powerups.where((p) => p.id == event.itemId).firstOrNull;
    if (powerupToRemove != null) {
      print('Removing powerup ${event.itemId} from game');
      powerupToRemove.collected = true;
      powerupToRemove.removeFromParent();
      powerups.remove(powerupToRemove);
    } else {
      print('Powerup ${event.itemId} not found (already collected?)');
    }
  }

  void _ensureRemotePlayer(PlayerSummary summary) {
    if (summary.playerId == networkPlayerId) {
      return;
    }

    // Don't create remote player if they're dead
    if (_deadPlayers.contains(summary.playerId)) {
      print('Player ${summary.playerId} is dead, not creating remote player');
      return;
    }

    print('=== ENSURE REMOTE PLAYER ===');
    print('Remote Player ID: ${summary.playerId}');
    print('Remote Player Name: ${summary.displayName}');
    print('Grid dimensions: ${gridWidth}x$gridHeight');
    print('Tile size: $tileSize');

    // Store player name regardless
    _playerNames[summary.playerId] = summary.displayName;
    
    // If grid not initialized yet, add to pending list
    if (gridWidth == 0 || gridHeight == 0 || tileSize == 0) {
      print('Grid not ready, adding to pending list');
      // Check if already in pending list
      if (!_pendingRemotePlayers.any((p) => p.playerId == summary.playerId)) {
        _pendingRemotePlayers.add(summary);
      }
      return;
    }

    final color = _colorForPlayer(summary.playerId);
    final existing = _remotePlayers[summary.playerId];

    if (existing != null) {
      print('Remote player ${summary.playerId} already exists, updating name only');
      existing.displayName = summary.displayName;
      return;
    }

    final effectiveTileSize = tileSize == 0 ? 1.0 : tileSize;
    
    // Calculate spawn position based on room position (1-4)
    final spawnPositions = [
      Vector2(1, 1), // Top-left - Position 1
      Vector2(gridWidth - 2.0, 1), // Top-right - Position 2
      Vector2(1, gridHeight - 2.0), // Bottom-left - Position 3
      Vector2(gridWidth - 2.0, gridHeight - 2.0), // Bottom-right - Position 4
    ];
    
    // Get room position from mapping, default to position based on playerId if not found
    final roomPosition = _playerIdToRoomPosition[summary.playerId] ?? summary.playerId;
    final spawnIndex = (roomPosition - 1).clamp(0, spawnPositions.length - 1);
    final spawnPos = spawnPositions[spawnIndex];
    
    print('Remote player ${summary.playerId} (Room Pos $roomPosition) spawn index: $spawnIndex');
    print('Remote player ${summary.playerId} grid spawn pos: (${spawnPos.x}, ${spawnPos.y})');
    
    // Get character for this remote player from the character map
    PlayerCharacter character;
    if (_playerCharacters.containsKey(summary.playerId)) {
      character = _playerCharacters[summary.playerId]!;
      print('Using character from character map: ${character.displayName}');
    } else {
      // Character not received from server yet, use default
      character = PlayerCharacter.character1;
      print('WARNING: Character not in map for player ${summary.playerId}, using fallback character1');
    }
    
    final remotePlayer = RemotePlayer(
      playerId: summary.playerId,
      displayName: summary.displayName,
      tileSize: effectiveTileSize,
      color: color,
      character: character,
    );
    if (tileSize > 0) {
      remotePlayer.updateTileSize(tileSize);
    }
    // Set spawn position based on room position
    // Add the same 0.1 offset that local players have
    final pixelPos = Vector2(
      spawnPos.x * tileSize + tileSize * 0.1,
      spawnPos.y * tileSize + tileSize * 0.1,
    );
    remotePlayer.position = pixelPos;
    
    print('Remote player ${summary.playerId} created:');
    print('  - Room Position: $roomPosition');
    print('  - Spawn Index: $spawnIndex');
    print('  - Grid Spawn: (${spawnPos.x}, ${spawnPos.y})');
    print('  - Pixel Spawn: $pixelPos');
    print('  - Character: ${character.displayName}');
    print('  - TileSize: $tileSize');
    
    add(remotePlayer);
    _remotePlayers[summary.playerId] = remotePlayer;
    
    print('Remote player ${summary.playerId} added to game');
  }

  void _removeRemotePlayer(int playerId) {
    print('=== REMOVING REMOTE PLAYER ===');
    print('Player ID: $playerId');
    
    final remote = _remotePlayers.remove(playerId);
    if (remote != null) {
      remote.removeFromParent();
      print('Removed remote player ${playerId} from game');
    }
    
    // Also remove from pending list if they haven't been created yet
    _pendingRemotePlayers.removeWhere((p) => p.playerId == playerId);
    
    _playerNames.remove(playerId);
    _playerIdToRoomPosition.remove(playerId);
    _playerColors.remove(playerId);
    
    print('Remaining remote players: ${_remotePlayers.keys.toList()}');
    print('Remaining pending players: ${_pendingRemotePlayers.length}');
    print('Remaining position mapping: $_playerIdToRoomPosition');
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
      'gridX': localPlayer.gridPosition.x,
      'gridY': localPlayer.gridPosition.y,
      'velocityX': localPlayer.velocity.x,
      'velocityY': localPlayer.velocity.y,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    print('SEND: Player ${networkPlayerId} at grid(${localPlayer.gridPosition.x.toStringAsFixed(2)}, ${localPlayer.gridPosition.y.toStringAsFixed(2)})');

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

    print('SEND: Bomb placed at grid(${bomb.gridPosition.x}, ${bomb.gridPosition.y})');

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
    
    // Don't allow dead players to place bombs
    if (activePlayer.playerHealth <= 0) return;

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

    // Determine if this client should spawn powerups
    // In single player: always
    // In multiplayer: only if this is our bomb (we placed it)
    final isOurBomb = bomb.ownerPlayer != null && 
                      players.isNotEmpty && 
                      bomb.ownerPlayer == players.first;
    
    print('=== BOMB EXPLODED ===');
    print('Network enabled: $_networkEnabled');
    print('Is our bomb: $isOurBomb');
    print('Should spawn powerups: $isOurBomb');
    
    // Create explosion with player's explosion radius
    createExplosion(bomb.gridPosition, explosionRadius, shouldSpawnPowerups: isOurBomb);
    _broadcastExplosion(bomb.gridPosition, explosionRadius);
  }

  void createExplosion(Vector2 centerPos, int explosionRadius, {bool shouldSpawnPowerups = false}) {
    // Explosion directions (up, down, left, right)
    final directions = [
      Vector2(0, -1), // Up
      Vector2(0, 1), // Down
      Vector2(-1, 0), // Left
      Vector2(1, 0), // Right
    ];

    // Collect all destroyed destructible positions
    final List<Vector2> destroyedPositions = [];

    // Explode center position
    _explodePosition(centerPos, shouldSpawnPowerups: false, destroyedPositions: destroyedPositions);

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
        _explodePosition(explodePos, shouldSpawnPowerups: false, destroyedPositions: destroyedPositions);

        // Stop explosion if we hit a destructible (after destroying it)
        if (tileType == TileType.destructible) {
          break;
        }
      }
    }

    // After all explosions, spawn ONE powerup if conditions are met
    if (shouldSpawnPowerups && destroyedPositions.isNotEmpty && _random.nextDouble() < 0.20) {
      // Pick a random destroyed position to spawn the powerup
      final spawnPos = destroyedPositions[_random.nextInt(destroyedPositions.length)];
      print('  Rolling for powerup spawn at (${spawnPos.x.toInt()}, ${spawnPos.y.toInt()})...');
      final powerupType = _spawnRandomPowerup(spawnPos);
      print('  ✓ Spawned powerup: ${powerupType.name}');
      
      // Broadcast powerup spawn in multiplayer
      if (_networkEnabled && networkClient != null && networkRoomId != null) {
        _broadcastPowerupSpawn(spawnPos, powerupType);
      }
    }
  }

  void _explodePosition(Vector2 pos, {bool shouldSpawnPowerups = false, List<Vector2>? destroyedPositions}) {
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

      // Track destroyed positions for later powerup spawning
      if (destroyedPositions != null) {
        destroyedPositions.add(pos.clone());
      }

      // Update the visual tile
      _updateTileVisual(pos);
    }
  }

  void _broadcastPowerupSpawn(Vector2 pos, PowerupType type) {
    if (!_networkJoined || networkClient == null || networkRoomId == null) {
      return;
    }

    final powerupId = _nextPowerupId - 1; // Use the ID that was just assigned
    final payload = <String, dynamic>{
      'gridX': pos.x.toInt(),
      'gridY': pos.y.toInt(),
      'type': type.index,
      'id': powerupId,
      'isPowerupSpawn': true,
    };

    print('=== BROADCASTING POWERUP SPAWN ===');
    print('Type: ${type.name} (index: ${type.index})');
    print('Position: (${pos.x}, ${pos.y})');
    print('ID: $powerupId');
    
    _dispatchNetworkCall(
      networkClient!.sendExplosion(networkRoomId!, payload),
      'sendPowerupSpawn',
    );
  }

  PowerupType _spawnRandomPowerup(Vector2 pos) {
    // Randomly select one of the 4 powerup types with equal probability
    final powerupTypes = PowerupType.values;
    final randomType = powerupTypes[_random.nextInt(powerupTypes.length)];
    
    final powerupId = _nextPowerupId++;
    final powerup = Powerup(
      type: randomType,
      gridPosition: pos,
      tileSize: tileSize,
      id: powerupId,
    );
    
    add(powerup);
    powerups.add(powerup);
    
    return randomType;
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
          
          print('=== LOCAL PLAYER DIED ===');
          print('Player health: ${player.playerHealth}');
          print('Alive players: $alivePlayers');
          
          // Add to dead players set
          if (networkPlayerId != null) {
            _deadPlayers.add(networkPlayerId!);
            print('Added local player $networkPlayerId to dead players set');
          }
          
          // Remove player from the map visually (both single player and multiplayer)
          player.removeFromParent();
          print('Player removed from own screen.');
          
          // Broadcast player death in multiplayer
          if (_networkEnabled && networkClient != null && networkRoomId != null && networkPlayerId != null) {
            print('Broadcasting death to all other players...');
            print('Room ID: $networkRoomId, Player ID: $networkPlayerId');
            _dispatchNetworkCall(
              networkClient!.sendPlayerDeath(networkRoomId!, networkPlayerId!),
              'sendPlayerDeath',
            );
            print('Death broadcast sent!');
          }

          // Check if game is over
          if (_networkEnabled) {
            // Multiplayer: Game ends when only 1 player left
            if (alivePlayers == 1) {
              _gameOver();
            } else {
              // Local player died but game continues - enter spectator mode
              print('Local player died. Entering spectator mode. $alivePlayers players remaining.');
            }
          } else {
            // Single player: Game ends when player dies (alivePlayers == 0)
            print('Single player died. Game over.');
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
          // Apply powerup to player with standard +1 bonus (both single and multiplayer)
          final multiplier = 1;
          
          // Log current stats before applying
          print('=== POWERUP COLLECTION ===');
          print('Type: ${powerup.type.name}');
          print('Multiplier: $multiplier (should always be 1)');
          print('Player health BEFORE: ${player.playerHealth}');
          print('Player maxBombs BEFORE: ${player.maxBombs}');
          print('Player explosionRadius BEFORE: ${player.explosionRadius}');
          
          powerup.applyToPlayer(player, multiplier: multiplier);
          
          print('Player health AFTER: ${player.playerHealth}');
          print('Player maxBombs AFTER: ${player.maxBombs}');
          print('Player explosionRadius AFTER: ${player.explosionRadius}');
          print('Network enabled: $_networkEnabled');
          print('=========================');
          
          // Broadcast powerup collection in multiplayer
          if (_networkJoined && networkClient != null && networkRoomId != null && networkPlayerId != null) {
            _dispatchNetworkCall(
              networkClient!.sendItemCollected(
                networkRoomId!,
                itemId: powerup.id,
                playerId: networkPlayerId!,
              ),
              'sendItemCollected',
            );
          }
          
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
    
    // In multiplayer, don't pause when game ends - let players continue spectating
    // In single player, pause the game
    if (!_networkEnabled) {
      paused = true;
    }
    
    // Find the winner among all players (local + remote)
    if (_networkEnabled) {
      // Multiplayer: Find the last player standing
      print('=== GAME OVER - FINDING WINNER ===');
      print('Alive players count: $alivePlayers');
      print('Local player health: ${players.isNotEmpty ? players.first.playerHealth : 0}');
      print('Remote players alive: ${_remotePlayers.keys.toList()}');
      print('Dead players: $_deadPlayers');
      
      // Check if local player is the winner (alive and not in dead set)
      if (players.isNotEmpty && 
          players.first.playerHealth > 0 && 
          networkPlayerId != null &&
          !_deadPlayers.contains(networkPlayerId)) {
        winner = players.first;
        _winnerPlayerNumber = players.first.playerNumber;
        _winnerNameFromBackend = _playerNames[networkPlayerId] ?? localPlayerName ?? 'Player $_winnerPlayerNumber';
        print('✓ Winner is local player (P$_winnerPlayerNumber)');
        print('  Network Player ID: $networkPlayerId');
        print('  Player Number (room position): ${players.first.playerNumber}');
        print('  Local Player Name: $localPlayerName');
        print('  Player name from _playerNames[networkPlayerId]: ${_playerNames[networkPlayerId]}');
        print('  Final Winner Name (_winnerNameFromBackend): $_winnerNameFromBackend');
        
        // Send winner data to backend
        if (_winnerPlayerNumber != null && networkPlayerId != null) {
          _sendGameEndToBackend(
            networkPlayerId!,
            _winnerPlayerNumber!,
            _winnerNameFromBackend,
          );
        }
        
        // Notify everyone - local player won
        onGameStateChanged(true, winner: winner);
      } else {
        // Local player is dead, find winner among remote players
        // The winner is the player NOT in the dead set
        int? winnerPlayerId;
        
        // Check all players in the room to find who's not dead
        for (var playerId in _playerIdToRoomPosition.keys) {
          if (!_deadPlayers.contains(playerId)) {
            winnerPlayerId = playerId;
            break;
          }
        }
        
        if (winnerPlayerId != null) {
          final winnerRoomPos = _playerIdToRoomPosition[winnerPlayerId] ?? 1;
          _winnerPlayerNumber = winnerRoomPos;
          final winnerName = _playerNames[winnerPlayerId] ?? 'Player $winnerRoomPos';
          _winnerNameFromBackend = winnerName; // Store the name
          print('✓ Winner is remote player $winnerPlayerId (P$winnerRoomPos)');
          print('  Winner name from _playerNames[$winnerPlayerId]: ${_playerNames[winnerPlayerId]}');
          print('  Final winner name (_winnerNameFromBackend): $_winnerNameFromBackend');
          print('  All playerIdToRoomPosition: $_playerIdToRoomPosition');
          print('  All playerNames: $_playerNames');
          // winner stays null for dead players, will use _winnerPlayerNumber in main.dart
        } else {
          print('⚠ Warning: Could not determine winner!');
          _winnerPlayerNumber = 1; // Fallback
        }
        
        // Notify dead players to show winning screen (1 player left = game over)
        print('Local player is dead. Showing winner screen to spectator.');
        onGameStateChanged(true, winner: winner);
      }
    } else {
      // Single player: Check if player is alive or dead
      if (players.isNotEmpty && players.first.playerHealth > 0) {
        // Player is alive and won (all bots defeated or game completed)
        winner = players.first;
      } else {
        // Player died - no winner, show game over
        winner = null;
      }
      onGameStateChanged(true, winner: winner); // Notify that game is over
    }
  }

  void restartGame() {
    isGameOver = false;
    paused = false;
    maxBombs = 1; // Reset to default
    score = 0;
    alivePlayers = selectedPlayers.length;
    winner = null; // Clear winner
    _winnerPlayerNumber = null; // Clear winner number
    _winnerNameFromBackend = null; // Clear backend winner name

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
        print('Broadcasting movement (joined=${_networkJoined}, players=${players.length}, remotes=${_remotePlayers.length})');
        _broadcastLocalMovement();
      }
    }
  }
}
