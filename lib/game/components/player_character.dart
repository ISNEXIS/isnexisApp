import 'package:flutter/material.dart';

/// Enum representing different playable characters
enum PlayerCharacter {
  character1, // Your custom drawn character
  character2, // Temporary square (red)
  character3, // Temporary square (green)
  character4, // Temporary square (yellow)
}

extension PlayerCharacterExtension on PlayerCharacter {
  /// Get the asset path for this character's sprite
  String get spritePath {
    switch (this) {
      case PlayerCharacter.character1:
        return 'assets/images/characters/character1.png';
      case PlayerCharacter.character2:
        return 'assets/images/characters/character2.png';
      case PlayerCharacter.character3:
        return 'assets/images/characters/character3.png';
      case PlayerCharacter.character4:
        return 'assets/images/characters/character4.png';
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
        return 'Character 1';
      case PlayerCharacter.character2:
        return 'Character 2';
      case PlayerCharacter.character3:
        return 'Character 3';
      case PlayerCharacter.character4:
        return 'Character 4';
    }
  }
}
