import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/bomb_game.dart';
import 'game/components/player.dart';
import 'screens/game_over_screen.dart';
import 'screens/game_screen.dart';
import 'screens/main_menu.dart';
import 'screens/multiplayer_setup_screen.dart';
import 'screens/player_selection_screen.dart';
import 'screens/settings_screen.dart';
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
  bool showPlayerSelection = false;
  bool showMultiplayerSetup = false;
  bool _playerSelectionForMultiplayer = false;
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
                  WinningScreen(
                    onPlayAgain: _restartGame,
                    onMainMenu: _goToMainMenu,
                    playerNumber: winningPlayer?.playerNumber ?? 1,
                  ),
              ],
            );
          } else if (showMultiplayerSetup) {
            return MultiplayerSetupScreen(
              onContinue: _handleMultiplayerSetup,
              onCancel: () {
                setState(() {
                  showMultiplayerSetup = false;
                  _playerSelectionForMultiplayer = false;
                  _pendingMultiplayerConfig = null;
                });
              },
            );
          } else if (showPlayerSelection) {
            return PlayerSelectionScreen(
              onBack: () {
                setState(() {
                  showPlayerSelection = false;
                  if (_playerSelectionForMultiplayer) {
                    showMultiplayerSetup = true;
                  }
                });
              },
              onStartGame: (selectedPlayers) {
                _startNewGame(selectedPlayers);
              },
              startButtonLabel: _playerSelectionForMultiplayer
                  ? 'JOIN MATCH'
                  : 'START GAME',
              multiplayerCode: _playerSelectionForMultiplayer
                  ? _pendingMultiplayerConfig?.joinCode
                  : null,
            );
          } else {
            return MainMenu(
              onStart: () {
                setState(() {
                  showPlayerSelection = true;
                  showMultiplayerSetup = false;
                  _playerSelectionForMultiplayer = false;
                  _pendingMultiplayerConfig = null;
                });
              },
              onMultiplayer: () {
                setState(() {
                  showPlayerSelection = false;
                  showMultiplayerSetup = true;
                  _playerSelectionForMultiplayer = true;
                });
              },
              onSettings: () => _showSettings(context),
              onExit: () => _exitGame(context),
            );
          }
        },
      ),
    );
  }

  void _startNewGame(List<PlayerSelectionData> selectedPlayers) {
    GameHubClient? hubClient;
    int? roomId;
    int? playerId;
    final pendingConfig = _pendingMultiplayerConfig;

    if (_playerSelectionForMultiplayer && pendingConfig != null) {
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
            // Determine if it's game over or winning
            if (winner != null && winner.playerHealth > 0) {
              showWinning = true;
              showGameOver = false;
            } else {
              showGameOver = true;
              showWinning = false;
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
      showPlayerSelection = false;
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
    _playerSelectionForMultiplayer = false;
  }

  void _restartGame() {
    gameInstance.restartGame();
    setState(() {
      showGameOver = false;
      showWinning = false;
    });
  }

  void _goToMainMenu() {
    setState(() {
      showGame = false;
      showGameOver = false;
      showWinning = false;
      showPlayerSelection = false;
      showMultiplayerSetup = false;
      _playerSelectionForMultiplayer = false;
    });

    final client = _activeHubClient;
    if (client != null) {
      _activeHubClient = null;
      Future.microtask(client.dispose);
    }
  }

  void _showSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
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

  void _handleMultiplayerSetup(MultiplayerSetupResult result) {
    setState(() {
      _pendingMultiplayerConfig = result;
      showMultiplayerSetup = false;
      showPlayerSelection = true;
      _playerSelectionForMultiplayer = true;
    });
  }

  @override
  void dispose() {
    _activeHubClient?.dispose();
    super.dispose();
  }
}
