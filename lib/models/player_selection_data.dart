import '../game/components/player_character.dart';

class PlayerSelectionData {
  final PlayerCharacter character;
  final bool isBot;

  PlayerSelectionData({
    required this.character,
    this.isBot = false,
  });
}
