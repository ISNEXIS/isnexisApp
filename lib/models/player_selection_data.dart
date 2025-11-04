import '../game/components/player_character.dart';

class PlayerSelectionData {
  final PlayerCharacter character;
  final bool isBot;
  final int? playerId; // Player ID for multiplayer, null for single player

  PlayerSelectionData({
    required this.character,
    this.isBot = false,
    this.playerId,
  });
}
