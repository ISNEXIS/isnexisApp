import 'package:flutter/material.dart';

import '../game/components/player_character.dart';

class PlayerSelectionScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(List<PlayerCharacter>) onStartGame;
  final String startButtonLabel;
  final String? multiplayerCode;

  const PlayerSelectionScreen({
    super.key,
    required this.onBack,
    required this.onStartGame,
    this.startButtonLabel = 'START GAME',
    this.multiplayerCode,
  });

  @override
  State<PlayerSelectionScreen> createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  int numberOfPlayers = 1;
  final List<PlayerCharacter?> selectedCharacters = [null, null, null, null];

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
                      child: Text(
                        '⚡ SELECT PLAYERS ⚡',
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
                    ),
                    Expanded(
                      child: Text(
                        '⚡ SELECT PLAYERS ⚡',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Color(0xFFFFFF00),
                        ),
                      ),
                    ),
                    const SizedBox(width: 60), // Balance the back button
                  ],
                ),
              ),

              if (widget.multiplayerCode != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
                    ),
                    child: Text(
                      'ROOM CODE: ${widget.multiplayerCode}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9BBC0F),
                        letterSpacing: 3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],

              // Number of players selector
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
                      ),
                      child: const Text(
                        '>> NUMBER OF PLAYERS <<',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9BBC0F),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final playerCount = index + 1;
                        final isSelected = numberOfPlayers == playerCount;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                numberOfPlayers = playerCount;
                                // Clear selections beyond new player count
                                for (int i = playerCount; i < 4; i++) {
                                  selectedCharacters[i] = null;
                                }
                              });
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF9BBC0F) : Colors.black,
                                border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
                              ),
                              child: Center(
                                child: Text(
                                  '$playerCount',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontFamily: 'Courier',
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.black : const Color(0xFF9BBC0F),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // Character selection for each player
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: numberOfPlayers,
                  itemBuilder: (context, playerIndex) {
                    return _PlayerCharacterSelector(
                      playerNumber: playerIndex + 1,
                      selectedCharacter: selectedCharacters[playerIndex],
                      onCharacterSelected: (character) {
                        setState(() {
                          selectedCharacters[playerIndex] = character;
                        });
                      },
                    );
                  },
                ),
              ),

              // Start Game Button
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GestureDetector(
                  onTap: _canStartGame()
                      ? () {
                          final players = selectedCharacters
                              .take(numberOfPlayers)
                              .where((c) => c != null)
                              .cast<PlayerCharacter>()
                              .toList();
                          widget.onStartGame(players);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    decoration: BoxDecoration(
                      color: _canStartGame() ? const Color(0xFF9BBC0F) : Colors.grey[800],
                      border: Border.all(
                        color: _canStartGame() ? const Color(0xFF9BBC0F) : Colors.grey,
                        width: 4,
                      ),
                      boxShadow: _canStartGame() ? [
                        BoxShadow(
                          color: const Color(0xFF9BBC0F).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ] : null,
                    ),
                    child: Text(
                      widget.startButtonLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: _canStartGame() ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
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
      if (selectedCharacters[i] == null) {
        return false;
      }
    }
    return true;
  }
}

class _PlayerCharacterSelector extends StatelessWidget {
  final int playerNumber;
  final PlayerCharacter? selectedCharacter;
  final Function(PlayerCharacter) onCharacterSelected;

  const _PlayerCharacterSelector({
    required this.playerNumber,
    required this.selectedCharacter,
    required this.onCharacterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '▶ PLAYER $playerNumber',
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              color: Color(0xFF9BBC0F),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: PlayerCharacter.values.map((character) {
              final isSelected = selectedCharacter == character;
              return GestureDetector(
                onTap: () => onCharacterSelected(character),
                child: Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF9BBC0F)
                        : const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: const Color(0xFF9BBC0F),
                      width: isSelected ? 4 : 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Character preview (colored square as fallback)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: character.fallbackColor,
                          border: Border.all(
                            color: isSelected ? Colors.black : const Color(0xFF9BBC0F),
                            width: 2,
                          ),
                        ),
                        child: character == PlayerCharacter.character1
                            ? Icon(
                                Icons.person,
                                color: isSelected ? Colors.black : Colors.white,
                                size: 30,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        character.displayName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : const Color(0xFF9BBC0F),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
