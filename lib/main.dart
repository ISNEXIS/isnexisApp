import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/bomb_game.dart';
import 'game/components/player.dart';
import 'models/player_selection_data.dart';
import 'screens/game_over_screen.dart';
import 'screens/game_screen.dart';
import 'screens/main_menu.dart';
import 'screens/multiplayer_lobby_screen.dart';
import 'screens/multiplayer_setup_screen.dart';
import 'screens/player_selection_screen.dart';
import 'screens/winning_screen.dart';
import 'services/game_hub_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Enable fullscreen mode - hide status bar and navigation buttons
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  runApp(const Isnexis());
}

class Isnexis extends StatefulWidget {
  const Isnexis({super.key});

  @override
  State<Isnexis> createState() => _IsnexisState();
}

class _IsnexisState extends State<Isnexis> {
  bool showGame = false;
  bool showGameOver = false;
  bool showWinning = false;
  bool showSinglePlayerSelection = false;
  bool showMultiplayerLobby = false;
  bool showMultiplayerSetup = false;
  MultiplayerSetupResult? _pendingMultiplayerConfig;
  GameHubClient? _activeHubClient;
  late BombGame gameInstance;
  Player? winningPlayer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Isnexis - Bomb Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Builder(
        builder: (context) {
          if (showGame) {
            return Stack(
              children: [
                // Game screen with sidebar and controls
                GameScreen(
                  game: gameInstance,
                  onGameOver: () {
                    setState(() {
                      showGameOver = true;
                    });
                  },
                  onBackToMenu: _goToMainMenu,
                ),
                // Game over overlay modal
                if (showGameOver)
                  GameOverScreen(
                    onPlayAgain: _restartGame,
                    onMainMenu: _goToMainMenu,
                  ),
                // Winning overlay modal
                if (showWinning)
                  Builder(
                    builder: (context) {
                      final pNum = winningPlayer?.playerNumber ?? 
                                   gameInstance.winnerPlayerNumber ?? 1;
                      final wName = gameInstance.winnerName;
                      print('=== DISPLAYING WINNING SCREEN ===');
                      print('winningPlayer: $winningPlayer');
                      print('winningPlayer?.playerNumber: ${winningPlayer?.playerNumber}');
                      print('gameInstance.winnerPlayerNumber: ${gameInstance.winnerPlayerNumber}');
                      print('gameInstance.winnerName (from backend or local): $wName');
                      print('gameInstance._winnerNameFromBackend: Internal check');
                      print('Final playerNumber to display: $pNum');
                      print('Final winnerName to display: $wName');
                      print('Will show: ${wName ?? 'PLAYER $pNum'}');
                      return WinningScreen(
                        onPlayAgain: _restartGame,
                        onMainMenu: _goToMainMenu,
                        playerNumber: pNum,
                        winnerName: wName,
                      );
                    },
                  ),
              ],
            );
          } else if (showMultiplayerSetup) {
            return MultiplayerSetupScreen(
              onContinue: _handleMultiplayerSetup,
              onCancel: () {
                setState(() {
                  showMultiplayerSetup = false;
                  _pendingMultiplayerConfig = null;
                });
              },
            );
          } else if (showSinglePlayerSelection) {
            return PlayerSelectionScreen(
              onBack: () {
                setState(() {
                  showSinglePlayerSelection = false;
                });
              },
              onStartGame: (selectedPlayers) {
                _startNewGame(selectedPlayers, isMultiplayer: false);
              },
            );
          } else if (showMultiplayerLobby) {
            return MultiplayerLobbyScreen(
              onBack: () {
                setState(() {
                  showMultiplayerLobby = false;
                  showMultiplayerSetup = true;
                });
              },
              onStartGame: (selectedPlayers) {
                _startNewGame(selectedPlayers, isMultiplayer: true);
              },
              joinCode: _pendingMultiplayerConfig?.joinCode,
              hubClient: _activeHubClient,
              roomId: _pendingMultiplayerConfig?.roomId,
              localPlayerId: _pendingMultiplayerConfig?.playerId,
              localPlayerName: _pendingMultiplayerConfig?.displayName,
              createdRoom: _pendingMultiplayerConfig?.createdRoom ?? false,
            );
          } else {
            return MainMenu(
              onStart: () {
                setState(() {
                  showSinglePlayerSelection = true;
                  showMultiplayerSetup = false;
                  showMultiplayerLobby = false;
                  _pendingMultiplayerConfig = null;
                });
              },
              onMultiplayer: () {
                setState(() {
                  showSinglePlayerSelection = false;
                  showMultiplayerLobby = false;
                  showMultiplayerSetup = true;
                });
              },
              onExit: () => _exitGame(context),
            );
          }
        },
      ),
    );
  }

  void _startNewGame(List<PlayerSelectionData> selectedPlayers, {required bool isMultiplayer}) {
    GameHubClient? hubClient;
    int? roomId;
    int? playerId;
    final pendingConfig = _pendingMultiplayerConfig;

    if (isMultiplayer && pendingConfig != null) {
      _activeHubClient?.dispose();
      hubClient = GameHubClient(baseUrl: pendingConfig.baseUrl);
      roomId = pendingConfig.roomId;
      playerId = pendingConfig.playerId;
      _activeHubClient = hubClient;
    } else if (_activeHubClient != null) {
      _activeHubClient!.dispose();
      _activeHubClient = null;
    }

    gameInstance = BombGame(
      selectedPlayers: selectedPlayers,
      onGameStateChanged: (isGameOver, {Player? winner}) {
        if (isGameOver) {
          setState(() {
            winningPlayer = winner;
            
            // In multiplayer, NEVER show game over screen - only winning screen at the end
            final isMultiplayer = hubClient != null && roomId != null;
            
            if (isMultiplayer) {
              // In multiplayer, only show winning screen when callback is triggered
              // This happens when:
              // 1. Local player won (winner != null)
              // 2. Game ended and server sent gameEnded event (for dead players)
              showWinning = true;
              showGameOver = false;
              
              if (winningPlayer != null) {
                print('Local player won! Showing winning screen.');
              } else {
                print('Game ended. Dead player viewing winner screen. Winner is P${gameInstance.winnerPlayerNumber}');
              }
            } else {
              // Single player: Show winning screen if player survived, game over if died
              if (winner != null && winner.playerHealth > 0) {
                showWinning = true;
                showGameOver = false;
              } else {
                // Player died - show game over screen
                showGameOver = true;
                showWinning = false;
              }
            }
          });
        }
      },
      networkClient: hubClient,
      networkRoomId: roomId,
      networkPlayerId: playerId,
      localPlayerId: pendingConfig?.playerId,
      localPlayerName: pendingConfig?.displayName,
    );
    setState(() {
      showGame = true;
      showGameOver = false;
      showWinning = false;
      showSinglePlayerSelection = false;
      showMultiplayerLobby = false;
      showMultiplayerSetup = false;
    });

    if (pendingConfig != null && pendingConfig.createdRoom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final code = pendingConfig.joinCode;
        if (code.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share this room code with friends: $code')),
          );
        }
      });
    }

    _pendingMultiplayerConfig = null;
  }

  void _restartGame() async {
    // Check if this is a multiplayer game
    final multiplayerConfig = _pendingMultiplayerConfig;
    
    if (multiplayerConfig != null && _activeHubClient != null) {
      // Multiplayer: Return to lobby with same room
      print('Restarting multiplayer game - returning to lobby');
      
      setState(() {
        showGame = false;
        showGameOver = false;
        showWinning = false;
        showMultiplayerLobby = true;
      });
      
      // Note: The lobby screen will handle rejoining the same room
      // The room ID and player ID are still in _pendingMultiplayerConfig
    } else {
      // Single player: Just restart the game instance
      gameInstance.restartGame();
      setState(() {
        showGameOver = false;
        showWinning = false;
      });
    }
  }

  void _goToMainMenu() async {
    // Leave multiplayer room if in one
    final client = _activeHubClient;
    if (client != null && _pendingMultiplayerConfig != null) {
      try {
        print('Leaving multiplayer room from main menu...');
        await client.leaveRoom(_pendingMultiplayerConfig!.roomId);
        print('Left room successfully');
      } catch (e) {
        print('Error leaving room: $e');
      }
    }
    
    setState(() {
      showGame = false;
      showGameOver = false;
      showWinning = false;
      showSinglePlayerSelection = false;
      showMultiplayerLobby = false;
      showMultiplayerSetup = false;
    });

    if (client != null) {
      _activeHubClient = null;
      Future.microtask(client.dispose);
    }
    
    _pendingMultiplayerConfig = null;
  }

  void _exitGame(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Game'),
          content: const Text('Are you sure you want to exit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _activeHubClient?.dispose();
                _activeHubClient = null;
                if (Platform.isAndroid || Platform.isIOS) {
                  SystemNavigator.pop();
                } else {
                  exit(0);
                }
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  void _handleMultiplayerSetup(MultiplayerSetupResult result) async {
    print('=== HANDLING MULTIPLAYER SETUP ===');
    print('Base URL: ${result.baseUrl}');
    print('Room ID: ${result.roomId}');
    print('Player ID: ${result.playerId}');
    print('Display Name: ${result.displayName}');
    print('Join Code: ${result.joinCode}');
    print('Created Room: ${result.createdRoom}');
    
    // Create hub client and connect (but don't join room yet)
    _activeHubClient?.dispose();
    final hubClient = GameHubClient(baseUrl: result.baseUrl);
    
    try {
      print('Connecting to hub...');
      await hubClient.ensureConnected();
      _activeHubClient = hubClient;
      print('✓ Connected to hub successfully');
      print('Connection state: ${hubClient.isConnected}');
    } catch (e, stackTrace) {
      print('✗ Error connecting to multiplayer: $e');
      print('Stack trace: $stackTrace');
    }
    
    setState(() {
      _pendingMultiplayerConfig = result;
      showMultiplayerSetup = false;
      showMultiplayerLobby = true;
    });
    
    print('=== SETUP COMPLETE, SHOWING LOBBY ===');
  }

  @override
  void dispose() {
    _activeHubClient?.dispose();
    super.dispose();
  }
}
