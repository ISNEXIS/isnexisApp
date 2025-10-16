import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/bomb_game.dart';
import '../widgets/controls_panel.dart';
import '../widgets/stats_sidebar.dart';

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
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Sidebar on the left
          StatsSidebar(
            health: widget.game.playerHealth,
            explosionRadius: player?.explosionRadius.toInt() ?? 1,
            activeBombs: widget.game.bombs.length,
            score: widget.game.score,
          ),
          // Game area (expands to fill remaining space)
          Expanded(
            child: Column(
              children: [
                // Game view
                Expanded(
                  child: GameWidget(game: widget.game),
                ),
                // Controls at bottom
                ControlsPanel(
                  onBombPressed: () => widget.game.placeBomb(),
                  onJoystickChanged: (offset) {
                    // Update player movement based on joystick direction
                    widget.game.updateJoystickDirection(offset);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
