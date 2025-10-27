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
            colors: [Colors.blue, Colors.purple],
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onBack,
                    ),
                    const Expanded(
                      child: Text(
                        'SELECT PLAYERS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

              if (widget.multiplayerCode != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Room code: ${widget.multiplayerCode}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // Number of players selector
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    const Text(
                      'Number of Players',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final playerCount = index + 1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ChoiceChip(
                            label: Text('$playerCount'),
                            selected: numberOfPlayers == playerCount,
                            onSelected: (selected) {
                              setState(() {
                                numberOfPlayers = playerCount;
                                // Clear selections beyond new player count
                                for (int i = playerCount; i < 4; i++) {
                                  selectedCharacters[i] = null;
                                }
                              });
                            },
                            selectedColor: Colors.greenAccent,
                            labelStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: numberOfPlayers == playerCount
                                  ? Colors.black
                                  : Colors.white,
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
                child: ElevatedButton(
                  onPressed: _canStartGame()
                      ? () {
                          final players = selectedCharacters
                              .take(numberOfPlayers)
                              .where((c) => c != null)
                              .cast<PlayerCharacter>()
                              .toList();
                          widget.onStartGame(players);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: Colors.greenAccent,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: Text(widget.startButtonLabel),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Player $playerNumber',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          ? character.fallbackColor.withOpacity(0.3)
                          : Colors.grey[200],
                      border: Border.all(
                        color: isSelected
                            ? character.fallbackColor
                            : Colors.grey[400]!,
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: character == PlayerCharacter.character1
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          character.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
      ),
    );
  }
}
