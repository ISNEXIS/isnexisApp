import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/bomb_game.dart';
import 'screens/game_over_screen.dart';
import 'screens/game_screen.dart';
import 'screens/main_menu.dart';
import 'screens/settings_screen.dart';

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
  late BombGame gameInstance;

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
                ),
                // Game over overlay modal
                if (showGameOver)
                  GameOverScreen(
                    onPlayAgain: _restartGame,
                    onMainMenu: _goToMainMenu,
                  ),
              ],
            );
          } else {
            return MainMenu(
              onStart: _startNewGame,
              onSettings: () => _showSettings(context),
              onExit: () => _exitGame(context),
            );
          }
        },
      ),
    );
  }

  void _startNewGame() {
    gameInstance = BombGame(
      onGameStateChanged: (isGameOver) {
        if (isGameOver) {
          setState(() {
            showGameOver = true;
          });
        }
      },
    );
    setState(() {
      showGame = true;
      showGameOver = false;
    });
  }

  void _restartGame() {
    gameInstance.restartGame();
    setState(() {
      showGameOver = false;
    });
  }

  void _goToMainMenu() {
    setState(() {
      showGame = false;
      showGameOver = false;
    });
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
}
