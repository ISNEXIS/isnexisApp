import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/bomb_game.dart';
import '../widgets/virtual_joystick.dart';

class GameScreen extends StatefulWidget {
  final BombGame game;
  final VoidCallback onGameOver;
  final VoidCallback onBackToMenu;

  const GameScreen({
    super.key,
    required this.game,
    required this.onGameOver,
    required this.onBackToMenu,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Update stats periodically
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.game.players;
    final firstPlayer = players.isNotEmpty ? players.first : null;

    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;

    // Map grid: 17×15 tiles (15×13 playable + 1 border on each side)
    const int gridWidth = 17;
    const int gridHeight = 15;

    // Calculate tile size to fit screen (ensuring 1:1 ratio - square tiles)
    final tileWidth = screenSize.width / gridWidth;
    final tileHeight = screenSize.height / gridHeight;

    // Use the smaller dimension to ensure tiles are square (1:1 ratio)
    final tileSize = tileWidth < tileHeight ? tileWidth : tileHeight;

    // Calculate actual map size based on SQUARE tiles (1:1 ratio guaranteed)
    final double gameWidth = gridWidth * tileSize; // All tiles use same size
    final double gameHeight = gridHeight * tileSize; // All tiles use same size

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Center - Game map (constrained to actual map size with 1:1 ratio tiles)
          Center(
            child: SizedBox(
              width: gameWidth,
              height: gameHeight,
              child: GameWidget(game: widget.game),
            ),
          ),

          // Top Left - Pause Button
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              onPressed: () {
                widget.game.paused = !widget.game.paused;
                setState(() {});
              },
              icon: Icon(
                widget.game.paused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 32,
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.9),
                padding: const EdgeInsets.all(12),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
          ),

          // Top Right - All Stats in One Box
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Status',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Divider
                  Container(height: 1, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  Text(
                    '👥 Alive: ${widget.game.alivePlayers}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (firstPlayer != null)
                    Text(
                      '❤️ P1: ${firstPlayer.playerHealth}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '⭐ : ${widget.game.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💥 : ${firstPlayer?.explosionRadius.toInt() ?? 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💣 : ${firstPlayer?.maxBombs ?? 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Left - Virtual Joystick
          Positioned(
            bottom: 40,
            left: 40,
            child: VirtualJoystick(
              size: 150,
              onDirectionChanged: (offset) {
                widget.game.updateJoystickDirection(offset);
              },
            ),
          ),

          // Bottom Right - Bomb Button
          Positioned(
            bottom: 40,
            right: 40,
            child: SizedBox(
              width: 150,
              height: 150,
              child: ElevatedButton(
                onPressed: () => widget.game.placeBomb(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('💣', style: TextStyle(fontSize: 50)),
              ),
            ),
          ),

          // Pause Overlay
          if (widget.game.paused)
            Container(
              color: const Color(0xFF0F380F).withOpacity(0.9),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9BBC0F),
                    border: Border.all(
                      color: const Color(0xFF0F380F),
                      width: 6,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pixel art pause icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF0F380F), width: 3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 18,
                              height: 50,
                              color: const Color(0xFF0F380F),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              width: 18,
                              height: 50,
                              color: const Color(0xFF0F380F),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '║║ PAUSED ║║',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: Color(0xFF0F380F),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Resume Button
                      SizedBox(
                        width: 240,
                        height: 60,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              widget.game.paused = false;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              border: Border.all(color: const Color(0xFF0F380F), width: 4),
                            ),
                            child: const Center(
                              child: Text(
                                '▶ RESUME ▶',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Back to Menu Button
                      SizedBox(
                        width: 240,
                        height: 60,
                        child: GestureDetector(
                          onTap: () {
                            // Unpause and go back to menu
                            widget.game.paused = false;
                            widget.onBackToMenu();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF306230),
                              border: Border.all(color: const Color(0xFF0F380F), width: 4),
                            ),
                            child: const Center(
                              child: Text(
                                '⌂ MAIN MENU ⌂',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9BBC0F),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
