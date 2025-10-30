import 'dart:async';

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

  const MultiplayerLobbyScreen({
    super.key,
    required this.onBack,
    required this.onStartGame,
    this.joinCode,
    this.hubClient,
    this.roomId,
    this.localPlayerId,
    this.localPlayerName,
  });

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  PlayerCharacter selectedCharacter = PlayerCharacter.character1;
  final List<Map<String, dynamic>> lobbyPlayers = [];
  final Map<int, PlayerCharacter> playerCharacters = {}; // Store character selections locally
  StreamSubscription? _rosterSubscription;
  StreamSubscription? _playerJoinedSubscription;
  StreamSubscription? _playerLeftSubscription;
  StreamSubscription? _playerDisconnectedSubscription;
  StreamSubscription? _playerMovementSubscription;
  StreamSubscription? _characterSelectedSubscription;
  StreamSubscription? _gameStartSubscription;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    // Initialize local player's character selection
    final localPlayerId = widget.localPlayerId;
    if (localPlayerId != null) {
      playerCharacters[localPlayerId] = selectedCharacter;
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
        _rosterSubscription = hubClient.roomRosterStream.listen((players) {
          print('>>> ROOM ROSTER EVENT RECEIVED <<<');
          print('Number of players in roster: ${players.length}');
          for (var player in players) {
            print('  - Player: ${player.displayName} (ID: ${player.playerId})');
          }
          setState(() {
            lobbyPlayers.clear();
            for (var player in players) {
              final isMe = player.playerId == localPlayerId;
              lobbyPlayers.add({
                'playerId': player.playerId,
                'name': isMe ? '${player.displayName} (You)' : player.displayName,
                'character': PlayerCharacter.character1,
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
            
            print('Lobby players list updated: ${lobbyPlayers.length} players');
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
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: character.fallbackColor,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
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
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF306230),
                                border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (player['character'] as PlayerCharacter).fallbackColor,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      player['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'Courier',
                                        color: Color(0xFF9BBC0F),
                                        fontWeight: FontWeight.bold,
                                      ),
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
                  text: 'START GAME',
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
    // At least 2 players required
    return lobbyPlayers.length >= 2;
  }

  void _startGame() async {
    final hubClient = widget.hubClient;
    final roomId = widget.roomId;
    final localPlayerId = widget.localPlayerId;
    
    if (hubClient != null && roomId != null && localPlayerId != null) {
      try {
        print('Broadcasting game start to room $roomId...');
        
        // Send game start message that includes our character selection
        await hubClient.sendPlayerMovement(roomId, {
          'type': 'game_start',
          'playerId': localPlayerId,
          'roomId': roomId,
          'characterIndex': selectedCharacter.index, // Include character in game start
        });
        
        print('Game start broadcast sent successfully via movement event');
        
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
    final players = lobbyPlayers.map((player) {
      final playerId = player['playerId'] as int;
      // Use stored character selection if available, otherwise use lobby display character
      final character = playerCharacters[playerId] ?? (player['character'] as PlayerCharacter);
      print('Player $playerId using character: ${character.displayName}');
      return PlayerSelectionData(
        character: character,
        isBot: false, // No bots in multiplayer
      );
    }).toList();
    print('Starting game with ${players.length} players');
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
