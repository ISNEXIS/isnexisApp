import 'package:flutter/material.dart';

/// Enum representing different playable characters
enum PlayerCharacter {
  character1, // Your custom drawn character
  character2, // Temporary square (red)
  character3, // Temporary square (green)
  character4, // Temporary square (yellow)
}

extension PlayerCharacterExtension on PlayerCharacter {
  /// Get the animated sprite sheet path for this character (if available)
  /// Returns null if the character doesn't have an animated sprite sheet
  String? get animatedSpritePath {
    switch (this) {
      case PlayerCharacter.character1:
        return 'characters/KawinPlayable.png';
      case PlayerCharacter.character2:
        return 'characters/EiraPlayable.png';
      case PlayerCharacter.character3:
        return 'characters/AnsiaPlayable.png'; 
      case PlayerCharacter.character4:
        return 'characters/PavoPlayable.png'; 
    }
  }

  /// Get the asset path for this character's sprite
  String get spritePath {
    switch (this) {
      case PlayerCharacter.character1:
        return 'assets/images/characters/KawinPlayable.png';
      case PlayerCharacter.character2:
        return 'assets/images/characters/EiraPlayable.png';
      case PlayerCharacter.character3:
        return 'assets/images/characters/AnsiaPlayable.png';
      case PlayerCharacter.character4:
        return 'assets/images/characters/PavoPlayable.png';
    }
  }

  /// Get the fallback color if sprite is not available
  Color get fallbackColor {
    switch (this) {
      case PlayerCharacter.character1:
        return const Color(0xFF2196F3); // Blue
      case PlayerCharacter.character2:
        return const Color(0xFFF44336); // Red
      case PlayerCharacter.character3:
        return const Color(0xFF4CAF50); // Green
      case PlayerCharacter.character4:
        return const Color(0xFFFFEB3B); // Yellow
    }
  }

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case PlayerCharacter.character1:
        return 'Kawin';
      case PlayerCharacter.character2:
        return 'Eira';
      case PlayerCharacter.character3:
        return 'Ansia';
      case PlayerCharacter.character4:
        return 'Pavo';
    }
  }

  /// Get the bomb sprite path for this character
  String get bombSpritePath {
    switch (this) {
      case PlayerCharacter.character1:
        return 'bombs/bomb_character1.png';
      case PlayerCharacter.character2:
        return 'bombs/bomb_character2.png';
      case PlayerCharacter.character3:
        return 'bombs/bomb_character3.png';
      case PlayerCharacter.character4:
        return 'bombs/bomb_character4.png';
    }
  }
}
