import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/extensions.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

import '../game/components/player_character.dart';
import '../models/player_selection_data.dart';
import '../services/game_hub_client.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(List<PlayerSelectionData>) onStartGame;
  final String? joinCode;
  final GameHubClient? hubClient;
  final int? roomId;
  final int? localPlayerId;
  final String? localPlayerName;
  final bool createdRoom; // Whether this player created the room (is host)

  const MultiplayerLobbyScreen({
    super.key,
    required this.onBack,
    required this.onStartGame,
    this.joinCode,
    this.hubClient,
    this.roomId,
    this.localPlayerId,
    this.localPlayerName,
    this.createdRoom = false,
  });

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  static const int _previewFrameIndex = 10;
  static const double _spriteFramePixels = 16;
  static final ui.Paint _previewPaint =
      ui.Paint()..filterQuality = ui.FilterQuality.none;
  static final Map<PlayerCharacter, Future<Sprite>> _spriteFutures = {};

  PlayerCharacter selectedCharacter = PlayerCharacter.character1;
  final List<Map<String, dynamic>> lobbyPlayers = [];
  final Map<int, PlayerCharacter> playerCharacters = {}; // Store character selections locally
  int? _hostPlayerId; // Track the current host (room creator or next player if host leaves)
  StreamSubscription? _rosterSubscription;
  StreamSubscription? _playerJoinedSubscription;
  StreamSubscription? _playerLeftSubscription;
  StreamSubscription? _playerDisconnectedSubscription;
  StreamSubscription? _playerMovementSubscription;
  StreamSubscription? _characterSelectedSubscription;
  StreamSubscription? _gameStartSubscription;
  bool _isConnecting = true;

  Future<Sprite> _getSprite(PlayerCharacter character) {
    return _spriteFutures.putIfAbsent(character, () {
      final spritePath = character.animatedSpritePath ??
          character.spritePath.replaceFirst('assets/images/', '');
      return Sprite.load(
        spritePath,
        srcPosition: Vector2(_spriteFramePixels * _previewFrameIndex, 0),
        srcSize: Vector2.all(_spriteFramePixels),
      );
    });
  }

  Widget _buildCharacterPreview(
    PlayerCharacter character, {
    Color borderColor = Colors.black,
    double borderWidth = 2,
    double size = 40,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: character.fallbackColor,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: FutureBuilder<Sprite>(
        future: _getSprite(character),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: _spriteFramePixels,
                height: _spriteFramePixels,
                child: SpriteWidget(
                  sprite: snapshot.data!,
                  paint: _previewPaint,
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            debugPrint(
              'Failed to load lobby preview for $character: ${snapshot.error}',
            );
          }
          return const SizedBox.expand();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize local player's character selection
    final localPlayerId = widget.localPlayerId;
    if (localPlayerId != null) {
      playerCharacters[localPlayerId] = selectedCharacter;
      
      // If this player created the room, they are the host
      if (widget.createdRoom) {
        _hostPlayerId = localPlayerId;
        print('=== LOBBY INITIALIZED ===');
        print('Local player ID: $localPlayerId');
        print('✓ You created the room - YOU ARE THE HOST');
      } else {
        print('=== LOBBY INITIALIZED ===');
        print('Local player ID: $localPlayerId');
        print('Waiting for backend to identify host...');
      }
    }
    _initializeMultiplayer();
  }

  Future<void> _initializeMultiplayer() async {
    final hubClient = widget.hubClient;
    final roomId = widget.roomId;
    final localPlayerId = widget.localPlayerId ?? 0;
    
    // Add yourself immediately to the lobby
    _addPlayerToLobby(
      localPlayerId,
      widget.localPlayerName ?? 'You',
      selectedCharacter,
      false,
    );
    
    if (hubClient != null && roomId != null) {
      try {
        print('=== MULTIPLAYER LOBBY INIT ===');
        print('Hub client connection state: ${hubClient.isConnected}');
        print('Room ID: $roomId');
        print('Local player ID: $localPlayerId');
        
        // Set up listeners BEFORE joining the room
        // Listen for room roster updates (full player list)
        _rosterSubscription = hubClient.roomRosterStream.listen((rosterEvent) {
          print('>>> ROOM ROSTER EVENT RECEIVED <<<');
          print('Number of players in roster: ${rosterEvent.players.length}');
          print('Host player ID from backend: ${rosterEvent.hostPlayerId}');
          for (var player in rosterEvent.players) {
            print('  - Player: ${player.displayName} (ID: ${player.playerId})');
          }
          setState(() {
            // Update host from backend if provided
            if (rosterEvent.hostPlayerId != null) {
              final previousHost = _hostPlayerId;
              _hostPlayerId = rosterEvent.hostPlayerId;
              if (previousHost != _hostPlayerId) {
                print('=== HOST UPDATED FROM BACKEND ===');
                print('Previous host: $previousHost');
                print('New host from backend: $_hostPlayerId');
                if (_hostPlayerId == localPlayerId) {
                  print('✓✓✓ YOU ARE THE HOST! ✓✓✓');
                }
              } else {
                print('✓ Host confirmed from backend: $_hostPlayerId');
              }
            }
            
            lobbyPlayers.clear();
            for (var player in rosterEvent.players) {
              final isMe = player.playerId == localPlayerId;
              // Use stored character selection if available, otherwise use character1 as default
              final character = playerCharacters[player.playerId] ?? PlayerCharacter.character1;
              lobbyPlayers.add({
                'playerId': player.playerId,
                'name': isMe ? '${player.displayName} (You)' : player.displayName,
                'character': character,
                'isLocal': isMe,
              });
            }
            
            // Ensure local player is always in the list
            final hasLocalPlayer = lobbyPlayers.any((p) => p['playerId'] == localPlayerId);
            if (!hasLocalPlayer) {
              print('Local player not in roster, adding manually');
              lobbyPlayers.insert(0, {
                'playerId': localPlayerId,
                'name': '${widget.localPlayerName ?? "You"} (You)',
                'character': selectedCharacter,
                'isLocal': true,
              });
            }
            
            // Fallback: Update host if current host left (only if backend didn't provide host)
            if (rosterEvent.hostPlayerId == null) {
              _updateHost();
            }
            
            print('Lobby players list updated: ${lobbyPlayers.length} players');
            print('Current host: $_hostPlayerId');
          });
        }, onError: (error) {
          print('ERROR in roomRosterStream: $error');
        });
        
        // Listen for individual player joins
        _playerJoinedSubscription = hubClient.playerJoinedStream.listen((player) {
          print('>>> PLAYER JOINED EVENT RECEIVED <<<');
          print('Player joined: ${player.displayName} (ID: ${player.playerId})');
          setState(() {
            // Check if player already exists
            final exists = lobbyPlayers.any((p) => p['playerId'] == player.playerId);
            if (!exists) {
              final isMe = player.playerId == localPlayerId;
              lobbyPlayers.add({
                'playerId': player.playerId,
                'name': isMe ? '${player.displayName} (You)' : player.displayName,
                'character': PlayerCharacter.character1,
                'isLocal': isMe,
              });
              print('Added player to lobby. Total players: ${lobbyPlayers.length}');
            } else {
              print('Player already exists in lobby, skipping');
            }
          });
        }, onError: (error) {
          print('ERROR in playerJoinedStream: $error');
        });
        
        // Listen for player leaves
        _playerLeftSubscription = hubClient.playerLeftStream.listen((player) {
          print('>>> PLAYER LEFT EVENT RECEIVED <<<');
          print('Player left: ${player.displayName} (ID: ${player.playerId})');
          setState(() {
            lobbyPlayers.removeWhere((p) => p['playerId'] == player.playerId);
            playerCharacters.remove(player.playerId);
            
            // Update host if the leaving player was the host
            _updateHost();
            
            print('Removed player from lobby. Total players: ${lobbyPlayers.length}');
          });
        }, onError: (error) {
          print('ERROR in playerLeftStream: $error');
        });
        
        // Listen for player disconnections
        _playerDisconnectedSubscription = hubClient.playerDisconnectedStream.listen((player) {
          print('>>> PLAYER DISCONNECTED EVENT RECEIVED <<<');
          print('Player disconnected: ${player.displayName} (ID: ${player.playerId})');
          setState(() {
            lobbyPlayers.removeWhere((p) => p['playerId'] == player.playerId);
            playerCharacters.remove(player.playerId);
            
            // Update host if the disconnected player was the host
            _updateHost();
            
            print('Removed disconnected player from lobby. Total players: ${lobbyPlayers.length}');
          });
        }, onError: (error) {
          print('ERROR in playerDisconnectedStream: $error');
        });
        
        // Listen for game start
        _gameStartSubscription = hubClient.gameStartStream.listen((event) {
          print('>>> GAME START EVENT RECEIVED <<<');
          print('Game starting for room: ${event.roomId}');
          if (event.roomId == roomId) {
            _handleGameStart();
          }
        }, onError: (error) {
          print('ERROR in gameStartStream: $error');
        });

        // Listen for character selection changes
        _characterSelectedSubscription = hubClient.characterSelectedStream.listen((event) {
          print('>>> CHARACTER SELECTED EVENT RECEIVED <<<');
          print('Player ${event.playerId} selected character index ${event.characterIndex}');
          setState(() {
            final playerIndex = lobbyPlayers.indexWhere((p) => p['playerId'] == event.playerId);
            if (playerIndex >= 0) {
              // Convert character index to PlayerCharacter enum
              if (event.characterIndex >= 0 && event.characterIndex < PlayerCharacter.values.length) {
                lobbyPlayers[playerIndex]['character'] = PlayerCharacter.values[event.characterIndex];
                print('Updated player ${event.playerId} character to ${PlayerCharacter.values[event.characterIndex].displayName}');
              }
            }
          });
        }, onError: (error) {
          print('ERROR in characterSelectedStream: $error');
        });

        // WORKAROUND: Listen for PlayerMoved events to detect character selections and game start
        // Since server doesn't support SelectCharacter or StartGame, we send them via movement events
        _playerMovementSubscription = hubClient.playerMovementStream.listen((event) {
          final payload = event.payload;
          if (payload != null) {
            final messageType = payload['type'];
            
            // Handle character selection
            if (messageType == 'character_selection') {
              final playerId = payload['playerId'] as int?;
              final characterIndex = payload['characterIndex'] as int?;
              if (playerId != null && characterIndex != null) {
                print('>>> CHARACTER SELECTION via MOVEMENT EVENT <<<');
                print('Player $playerId selected character index $characterIndex');
                setState(() {
                  // Store character selection
                  if (characterIndex >= 0 && characterIndex < PlayerCharacter.values.length) {
                    final character = PlayerCharacter.values[characterIndex];
                    playerCharacters[playerId] = character;
                    
                    // Update lobby display
                    final playerIndex = lobbyPlayers.indexWhere((p) => p['playerId'] == playerId);
                    if (playerIndex >= 0) {
                      lobbyPlayers[playerIndex]['character'] = character;
                      print('Updated player $playerId character to ${character.displayName}');
                    }
                  }
                });
              }
            }
            // Handle game start
            else if (messageType == 'game_start') {
              final gameRoomId = payload['roomId'] as int?;
              final playerId = payload['playerId'] as int?;
              final characterIndex = payload['characterIndex'] as int?;
              
              // Extract character from game_start message if present
              if (playerId != null && characterIndex != null) {
                print('>>> CHARACTER from GAME_START: Player $playerId, char $characterIndex');
                if (characterIndex >= 0 && characterIndex < PlayerCharacter.values.length) {
                  final character = PlayerCharacter.values[characterIndex];
                  playerCharacters[playerId] = character;
                  print('Stored character ${character.displayName} for player $playerId');
                }
              }
              
              if (gameRoomId == roomId) {
                print('>>> GAME START via MOVEMENT EVENT <<<');
                print('Game starting for room: $gameRoomId');
                _handleGameStart();
              }
            }
          }
        }, onError: (error) {
          print('ERROR in playerMovementStream: $error');
        });
        
        print('Stream listeners set up successfully');
        
        // NOW join the room (after listeners are set up)
        print('Calling joinRoom($roomId, $localPlayerId)...');
        await hubClient.joinRoom(roomId, localPlayerId);
        print('joinRoom() completed successfully');
        
        // Send our character selection to all players
        print('Sending character selection: ${selectedCharacter.index}');
        await hubClient.sendPlayerMovement(roomId, {
          'type': 'character_selection',
          'playerId': localPlayerId,
          'characterIndex': selectedCharacter.index,
        });
        print('Character selection sent');
        
        setState(() {
          _isConnecting = false;
        });
        
        print('=== MULTIPLAYER LOBBY INIT COMPLETE ===');
      } catch (e, stackTrace) {
        print('!!! ERROR INITIALIZING MULTIPLAYER !!!');
        print('Error: $e');
        print('Stack trace: $stackTrace');
        setState(() {
          _isConnecting = false;
        });
      }
    } else {
      // No hub client provided
      print('WARNING: No hub client or room ID provided');
      print('Hub client: $hubClient');
      print('Room ID: $roomId');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _addPlayerToLobby(int playerId, String name, PlayerCharacter character, bool isReady) {
    setState(() {
      lobbyPlayers.add({
        'playerId': playerId,
        'name': name,
        'character': character,
        'isLocal': playerId == widget.localPlayerId,
      });
    });
  }

  void _updateHost() {
    print('=== UPDATE HOST CHECK ===');
    print('Current host ID: $_hostPlayerId');
    print('Lobby players: ${lobbyPlayers.map((p) => 'ID ${p['playerId']}').join(', ')}');
    
    // If current host still exists in lobby, keep them
    if (_hostPlayerId != null && 
        lobbyPlayers.any((p) => p['playerId'] == _hostPlayerId)) {
      print('✓ Host $_hostPlayerId still in lobby - no change needed');
      return;
    }
    
    // Host left - assign new host (first player in lobby = first who joined)
    // The first player in lobbyPlayers is the earliest joiner (since roster is in join order)
    if (lobbyPlayers.isNotEmpty) {
      final newHostId = lobbyPlayers.first['playerId'] as int;
      final previousHost = _hostPlayerId;
      _hostPlayerId = newHostId;
      print('=== HOST TRANSFER ===');
      print('Previous host: $previousHost (left the room)');
      print('New host: $_hostPlayerId (next player in join order)');
      print('Is local player the new host? ${_hostPlayerId == widget.localPlayerId}');
      if (_hostPlayerId == widget.localPlayerId) {
        print('✓✓✓ YOU ARE NOW THE HOST! ✓✓✓');
      }
    } else {
      _hostPlayerId = null;
      print('⚠ No players left in lobby - host cleared');
      print('No players left, host cleared');
    }
  }

  bool _isLocalPlayerHost() {
    return _hostPlayerId != null && _hostPlayerId == widget.localPlayerId;
  }

  @override
  void dispose() {
    // Leave the room when disposing
    final hubClient = widget.hubClient;
    final roomId = widget.roomId;
    if (hubClient != null && roomId != null) {
      print('Leaving room $roomId...');
      hubClient.leaveRoom(roomId).catchError((error) {
        print('Error leaving room: $error');
      });
    }
    
    _rosterSubscription?.cancel();
    _playerJoinedSubscription?.cancel();
    _playerLeftSubscription?.cancel();
    _playerDisconnectedSubscription?.cancel();
    _playerMovementSubscription?.cancel();
    _characterSelectedSubscription?.cancel();
    _gameStartSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F380F), // Dark green (Game Boy style)
              Color(0xFF306230), // Medium green
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Retro back button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF9BBC0F)),
                        onPressed: () async {
                          // Leave room before going back
                          final hubClient = widget.hubClient;
                          final roomId = widget.roomId;
                          if (hubClient != null && roomId != null) {
                            try {
                              print('Leaving room via back button...');
                              await hubClient.leaveRoom(roomId);
                              print('Left room successfully');
                            } catch (e) {
                              print('Error leaving room: $e');
                            }
                          }
                          widget.onBack();
                        },
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          // Shadow
                          Text(
                            '🌐 WAITING ROOM 🌐',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 2
                                ..color = Colors.black,
                            ),
                          ),
                          // Main text
                          const Text(
                            '🌐 WAITING ROOM 🌐',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: Color(0xFFFFFF00),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

              // Join code display
              if (widget.joinCode != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ROOM CODE: ',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Courier',
                          color: Color(0xFF9BBC0F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9BBC0F),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Text(
                          widget.joinCode!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontFamily: 'Courier',
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Your character selection
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR CHARACTER',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Courier',
                        color: Color(0xFFFFFF00),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: PlayerCharacter.values.map((character) {
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCharacter = character;
                                // Store character selection locally
                                final localPlayerId = widget.localPlayerId;
                                if (localPlayerId != null) {
                                  playerCharacters[localPlayerId] = character;
                                  print('Stored character ${character.displayName} for player $localPlayerId');
                                }
                                // Update local player's character in lobby display
                                final localPlayerIndex = lobbyPlayers.indexWhere(
                                  (p) => p['playerId'] == widget.localPlayerId
                                );
                                if (localPlayerIndex >= 0) {
                                  lobbyPlayers[localPlayerIndex]['character'] = character;
                                  print('Updated local player character to ${character.displayName}');
                                }
                              });
                              
                              // NOTE: Character selection broadcast via SendPlayerMovement as workaround
                              // Server doesn't support SelectCharacter, so we use movement events
                              final hubClient = widget.hubClient;
                              final roomId = widget.roomId;
                              final localPlayerId = widget.localPlayerId;
                              if (hubClient != null && roomId != null && localPlayerId != null) {
                                try {
                                  final characterIndex = PlayerCharacter.values.indexOf(character);
                                  // Send as a special "movement" with character data
                                  hubClient.sendPlayerMovement(roomId, {
                                    'type': 'character_selection',
                                    'playerId': localPlayerId,
                                    'characterIndex': characterIndex,
                                  }).catchError((e) {
                                    print('Could not broadcast character selection: $e');
                                  });
                                } catch (e) {
                                  print('Error sending character selection: $e');
                                }
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedCharacter == character
                                    ? const Color(0xFF9BBC0F)
                                    : const Color(0xFF306230),
                                border: Border.all(
                                  color: const Color(0xFF9BBC0F),
                                  width: selectedCharacter == character ? 3 : 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildCharacterPreview(
                                    character,
                                    borderColor: Colors.black,
                                    borderWidth: 2,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    character.displayName.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'Courier',
                                      color: selectedCharacter == character
                                          ? Colors.black
                                          : const Color(0xFF9BBC0F),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Players in lobby
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'PLAYERS IN LOBBY',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Courier',
                              color: Color(0xFFFFFF00),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${lobbyPlayers.length}/4',
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Courier',
                              color: Color(0xFF9BBC0F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isConnecting
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color(0xFF9BBC0F),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'CONNECTING...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'Courier',
                                        color: Color(0xFF9BBC0F),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : lobbyPlayers.isEmpty
                                ? const Center(
                                    child: Text(
                                      'WAITING FOR PLAYERS...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'Courier',
                                        color: Color(0xFF9BBC0F),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                          itemCount: lobbyPlayers.length,
                          itemBuilder: (context, index) {
                            final player = lobbyPlayers[index];
                            final playerId = player['playerId'] as int;
                            final isHost = playerId == _hostPlayerId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF306230),
                                border: Border.all(
                                  color: isHost 
                                      ? const Color(0xFFFFFF00) // Yellow border for host
                                      : const Color(0xFF9BBC0F),
                                  width: isHost ? 3 : 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildCharacterPreview(
                                    player['character'] as PlayerCharacter,
                                    borderColor: Colors.black,
                                    borderWidth: 2,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontFamily: 'Courier',
                                            color: Color(0xFF9BBC0F),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isHost)
                                          const Text(
                                            '👑 HOST',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'Courier',
                                              color: Color(0xFFFFFF00),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Start button
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildRetroButton(
                  text: _isLocalPlayerHost() 
                      ? 'START GAME' 
                      : 'WAITING FOR HOST...',
                  onPressed: _canStartGame() ? _startGame : null,
                  color: const Color(0xFF9BBC0F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canStartGame() {
    // Only host can start, and need at least 2 players
    return _isLocalPlayerHost() && lobbyPlayers.length >= 2;
  }

  void _startGame() async {
    final hubClient = widget.hubClient;
    final roomId = widget.roomId;
    final localPlayerId = widget.localPlayerId;
    
    if (hubClient != null && roomId != null && localPlayerId != null) {
      try {
        print('Broadcasting game start to room $roomId...');
        
        // Build character map for all players in lobby
        final characterMap = <String, dynamic>{};
        for (final player in lobbyPlayers) {
          final playerId = player['playerId'] as int;
          final character = playerCharacters[playerId] ?? (player['character'] as PlayerCharacter);
          characterMap[playerId.toString()] = character.index;
          print('Player $playerId -> Character ${character.displayName} (index ${character.index})');
        }
        
        // Try to send game start with character data (proper way if server supports it)
        try {
          await hubClient.sendGameStartWithCharacters(roomId, characterMap);
          print('Game start with characters sent successfully');
        } catch (e) {
          print('sendGameStartWithCharacters failed (server may not support it): $e');
        }
        
        // FALLBACK: Also send via movement event to ensure all clients receive it
        // This is critical because server might not support SendGameStartWithCharacters
        print('Sending game_start via movement event as fallback...');
        await hubClient.sendPlayerMovement(roomId, {
          'type': 'game_start',
          'playerId': localPlayerId,
          'roomId': roomId,
          'characterIndex': selectedCharacter.index,
        });
        print('Game start sent via movement event');
        
        // Start game locally immediately (don't wait for echo back)
        _handleGameStart();
        
      } catch (e) {
        print('Error broadcasting game start: $e');
        // If broadcast fails, still start locally
        _handleGameStart();
      }
    } else {
      print('ERROR: Cannot start game - no hub client or room ID');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot start game - not connected to server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleGameStart() {
    print('Handling game start - creating player list');
    print('Lobby players order (JOIN ORDER):');
    for (int i = 0; i < lobbyPlayers.length; i++) {
      final player = lobbyPlayers[i];
      final playerId = player['playerId'] as int;
      final character = playerCharacters[playerId] ?? (player['character'] as PlayerCharacter);
      print('  Join Position ${i + 1}: Player ID $playerId -> ${character.displayName}');
    }
    
    final players = lobbyPlayers.map((player) {
      final playerId = player['playerId'] as int;
      // Use stored character selection if available, otherwise use lobby display character
      final character = playerCharacters[playerId] ?? (player['character'] as PlayerCharacter);
      return PlayerSelectionData(
        character: character,
        isBot: false, // No bots in multiplayer
        playerId: playerId, // Include player ID for proper spawn positioning
      );
    }).toList();
    print('Starting game with ${players.length} players');
    print('Player data being sent to game:');
    for (int i = 0; i < players.length; i++) {
      print('  Index $i: PlayerID ${players[i].playerId} -> ${players[i].character.displayName}');
    }
    widget.onStartGame(players);
  }

  Widget _buildRetroButton({
    required String text,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isEnabled ? color : const Color(0xFF306230),
          border: Border.all(
            color: const Color(0xFF9BBC0F),
            width: 4,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF9BBC0F).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Courier',
            color: isEnabled ? Colors.black : const Color(0xFF9BBC0F).withOpacity(0.5),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
