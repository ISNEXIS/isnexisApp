import '../game/components/bot_player.dart';
import '../game/components/player_character.dart';

class PlayerSelectionData {
  final PlayerCharacter character;
  final bool isBot;
  final BotDifficulty? botDifficulty;

  PlayerSelectionData({
    required this.character,
    this.isBot = false,
    this.botDifficulty,
  });
}
