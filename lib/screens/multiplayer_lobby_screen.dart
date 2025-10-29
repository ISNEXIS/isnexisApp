import 'package:flutter/material.dart';

import '../game/components/player_character.dart';
import '../models/player_selection_data.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(List<PlayerSelectionData>) onStartGame;
  final String? joinCode;

  const MultiplayerLobbyScreen({
    super.key,
    required this.onBack,
    required this.onStartGame,
    this.joinCode,
  });

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  PlayerCharacter selectedCharacter = PlayerCharacter.character1;
  final List<Map<String, dynamic>> lobbyPlayers = [];
  bool isReady = false;

  @override
  void initState() {
    super.initState();
    // Add yourself to lobby
    _addPlayerToLobby('You', selectedCharacter, true);
  }

  void _addPlayerToLobby(String name, PlayerCharacter character, bool isReady) {
    setState(() {
      lobbyPlayers.add({
        'name': name,
        'character': character,
        'isReady': isReady,
      });
    });
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
                        onPressed: widget.onBack,
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
                                // Update in lobby
                                if (lobbyPlayers.isNotEmpty) {
                                  lobbyPlayers[0]['character'] = character;
                                }
                              });
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
                        child: ListView.builder(
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: player['isReady']
                                          ? const Color(0xFF9BBC0F)
                                          : Colors.black,
                                      border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
                                    ),
                                    child: Text(
                                      player['isReady'] ? 'READY' : 'WAITING',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Courier',
                                        color: player['isReady']
                                            ? Colors.black
                                            : const Color(0xFF9BBC0F),
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

              // Ready/Start buttons
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildRetroButton(
                        text: isReady ? 'NOT READY' : 'READY',
                        onPressed: () {
                          setState(() {
                            isReady = !isReady;
                            if (lobbyPlayers.isNotEmpty) {
                              lobbyPlayers[0]['isReady'] = isReady;
                            }
                          });
                        },
                        color: isReady ? const Color(0xFF306230) : const Color(0xFF9BBC0F),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRetroButton(
                        text: 'START GAME',
                        onPressed: _canStartGame() ? _startGame : null,
                        color: const Color(0xFF9BBC0F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canStartGame() {
    // All players must be ready and at least 2 players
    return lobbyPlayers.length >= 2 &&
        lobbyPlayers.every((player) => player['isReady'] == true);
  }

  void _startGame() {
    final players = lobbyPlayers.map((player) {
      return PlayerSelectionData(
        character: player['character'] as PlayerCharacter,
        isBot: false, // No bots in multiplayer
      );
    }).toList();
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
