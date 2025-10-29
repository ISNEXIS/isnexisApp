import 'package:flutter/material.dart';

import '../game/components/player_character.dart';
import '../models/player_selection_data.dart';

class SinglePlayerSelectionScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(List<PlayerSelectionData>) onStartGame;

  const SinglePlayerSelectionScreen({
    super.key,
    required this.onBack,
    required this.onStartGame,
  });

  @override
  State<SinglePlayerSelectionScreen> createState() => _SinglePlayerSelectionScreenState();
}

class _SinglePlayerSelectionScreenState extends State<SinglePlayerSelectionScreen> {
  int numberOfPlayers = 2;
  final List<PlayerSelectionData?> selectedPlayers = [null, null, null, null];

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
                            '🎮 SINGLE PLAYER 🎮',
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
                            '🎮 SINGLE PLAYER 🎮',
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

              // Player count selector
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
                      'PLAYERS: ',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Courier',
                        color: Color(0xFF9BBC0F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (int i = 1; i <= 4; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => numberOfPlayers = i),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: numberOfPlayers == i ? const Color(0xFF9BBC0F) : Colors.black,
                              border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$i',
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'Courier',
                                color: numberOfPlayers == i ? Colors.black : const Color(0xFF9BBC0F),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Player selection cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: numberOfPlayers,
                  itemBuilder: (context, index) {
                    return _PlayerCharacterSelector(
                      playerNumber: index + 1,
                      selectedData: selectedPlayers[index],
                      onChanged: (data) {
                        setState(() {
                          selectedPlayers[index] = data;
                        });
                      },
                    );
                  },
                ),
              ),

              // Start button
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildRetroButton(
                  text: 'START GAME',
                  onPressed: _canStartGame() ? _startGame : null,
                  isEnabled: _canStartGame(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canStartGame() {
    for (int i = 0; i < numberOfPlayers; i++) {
      if (selectedPlayers[i] == null) return false;
    }
    return true;
  }

  void _startGame() {
    final players = selectedPlayers.sublist(0, numberOfPlayers).cast<PlayerSelectionData>();
    widget.onStartGame(players);
  }

  Widget _buildRetroButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isEnabled,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFF9BBC0F) : const Color(0xFF306230),
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
            fontSize: 24,
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

class _PlayerCharacterSelector extends StatefulWidget {
  final int playerNumber;
  final PlayerSelectionData? selectedData;
  final Function(PlayerSelectionData) onChanged;

  const _PlayerCharacterSelector({
    required this.playerNumber,
    required this.selectedData,
    required this.onChanged,
  });

  @override
  State<_PlayerCharacterSelector> createState() => _PlayerCharacterSelectorState();
}

class _PlayerCharacterSelectorState extends State<_PlayerCharacterSelector> {
  PlayerCharacter selectedCharacter = PlayerCharacter.character1;
  bool isBot = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedData != null) {
      selectedCharacter = widget.selectedData!.character;
      isBot = widget.selectedData!.isBot;
    } else if (widget.playerNumber > 1) {
      // Default to bot for players 2+
      isBot = true;
    }
    _notifyChange();
  }

  void _notifyChange() {
    widget.onChanged(PlayerSelectionData(
      character: selectedCharacter,
      isBot: isBot,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player header with bot toggle
          Row(
            children: [
              Text(
                'PLAYER ${widget.playerNumber}',
                style: const TextStyle(
                  fontSize: 20,
                  fontFamily: 'Courier',
                  color: Color(0xFFFFFF00),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Human/Bot toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    isBot = !isBot;
                    _notifyChange();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isBot ? const Color(0xFF306230) : const Color(0xFF9BBC0F),
                    border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
                  ),
                  child: Text(
                    isBot ? '🤖 BOT' : '👤 HUMAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Courier',
                      color: isBot ? const Color(0xFF9BBC0F) : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Character selection
          Row(
            children: PlayerCharacter.values.map((character) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCharacter = character;
                      _notifyChange();
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
    );
  }
}
