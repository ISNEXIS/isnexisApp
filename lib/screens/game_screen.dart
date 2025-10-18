import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/bomb_game.dart';
import '../widgets/virtual_joystick.dart';

class GameScreen extends StatefulWidget {
  final BombGame game;
  final VoidCallback onGameOver;

  const GameScreen({
    super.key,
    required this.game,
    required this.onGameOver,
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
    final player = widget.game.player;
    
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
    final double gameWidth = gridWidth * tileSize;   // All tiles use same size
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
                  Text(
                    '❤️ Health: ${widget.game.playerHealth}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⭐ Score: ${widget.game.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💥 Radius: ${player?.explosionRadius.toInt() ?? 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💣 Bombs: ${widget.game.bombs.length}',
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
                child: const Text(
                  '💣',
                  style: TextStyle(fontSize: 50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
