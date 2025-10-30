# 💣 ISNEXIS - Bomberman Game

A modern, retro-styled Bomberman game built with Flutter and Flame engine, featuring both single-player and real-time multiplayer modes.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.8.1-0175C2?logo=dart)

## ✨ Features

### 🎮 Game Modes
- **Single Player**: Battle against AI bots (2-4 players total)
- **Multiplayer**: Real-time online multiplayer with SignalR backend
  - Host-based room creation
  - Room code system for easy joining
  - Real-time synchronization of all game elements
  - Automatic host migration when host leaves

### 🎯 Gameplay Elements
- **Classic Bomberman Mechanics**: Place bombs, destroy blocks, eliminate opponents
- **Powerups System**:
  - 💚 Extra Life - Gain additional health
  - 💣 Extra Bomb - Increase simultaneous bomb capacity
  - 🔥 Explosion Range - Extend bomb blast radius
- **AI Bots**: Smart bot opponents in single-player mode
- **Multiple Characters**: Choose from 4 different character skins
- **Grid-Based Movement**: Classic 17×15 tile grid (15×13 playable area)
- **Retro Game Boy Aesthetic**: Green color palette with pixel-style UI

### 🌐 Multiplayer Features
- Real-time player movement synchronization
- Synchronized bomb placement and explosions
- Shared powerup spawning and collection
- Winner determination and broadcast
- Character selection synchronization
- Spectator mode when eliminated
- 2-4 players per room

### 🎨 Visual Features
- Retro Game Boy-inspired color scheme
- Pixel grid background
- Explosion effects
- Character customization
- Responsive UI design
- Game Boy-style borders and buttons

## 🛠️ Technology Stack

- **Frontend**: Flutter
- **Game Engine**: Flame
- **Backend**: C# + ASP.NET Core

## 🚀 Getting Started

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ISNEXIS/isnexisApp.git
   cd isnexisApp
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   # For web (Chrome)
   flutter run -d chrome
   
   # For Windows
   flutter run -d windows
   
   # For Android
   flutter run -d android
   
   # For iOS
   flutter run -d ios
   ```

### Backend Setup (for Multiplayer)

To enable multiplayer mode, you need a SignalR backend server running with the following endpoints:

- `/gamehub` - Main game hub for real-time communication
- Game events: `JoinRoom`, `LeaveRoom`, `SendPlayerMovement`, `SendBombPlaced`, `SendExplosion`, `SendPlayerDeath`, `SendItemCollected`, `SendGameStart`, `SendGameEnd`

## 🎮 How to Play

### Controls
- **Arrow Keys / WASD**: Move player
- **Space**: Place bomb
- **Virtual Joystick**: Touch controls (mobile)

### Single Player Mode
1. Select "START GAME" from main menu
2. Choose number of players (2-4)
3. Select your character (Player 1 is always human)
4. Other players will be AI bots
5. Survive and eliminate all opponents to win!

### Multiplayer Mode
1. Select "MULTIPLAYER" from main menu
2. **Create Room**: Enter your name and backend URL
3. **Join Room**: Enter room code, name, and backend URL
4. Wait for host to start the game
5. Battle against real players in real-time!

### Gameplay Tips
- 💣 Bombs explode after ~3 seconds
- 🧱 Destroy destructible blocks to find powerups
- ⚡ Powerups give +1 bonus to stats
- 🎯 Strategic placement is key to victory
- 🛡️ 2 seconds of invincibility after taking damage

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── game/
│   ├── bomb_game.dart                 # Core game engine
│   ├── components/
│   │   ├── bomb.dart                  # Bomb entity
│   │   ├── bot_player.dart            # AI bot logic
│   │   ├── explosion_effect.dart      # Explosion visuals
│   │   ├── map_tile.dart              # Grid tile component
│   │   ├── player.dart                # Player entity
│   │   ├── player_character.dart      # Character definitions
│   │   ├── powerup.dart               # Powerup items
│   │   ├── remote_player.dart         # Multiplayer player
│   │   └── tile_type.dart             # Tile type enum
│   └── widgets/
│       ├── controls_panel.dart        # Game controls UI
│       ├── stats_sidebar.dart         # Player stats display
│       └── virtual_joystick.dart      # Touch controls
├── screens/
│   ├── main_menu.dart                 # Main menu screen
│   ├── game_screen.dart               # Game container
│   ├── game_over_screen.dart          # Game over overlay
│   ├── winning_screen.dart            # Victory overlay
│   ├── player_selection_screen.dart   # Character selection
│   ├── multiplayer_setup_screen.dart  # MP room creation
│   └── multiplayer_lobby_screen.dart  # MP waiting room
├── services/
│   └── game_hub_client.dart           # SignalR client
└── models/
    └── player_selection_data.dart     # Player data model
```

## 🎯 Game Rules

1. **Objective**: Be the last player standing
2. **Bomb Mechanics**:
   - Place bombs to destroy blocks and opponents
   - Bombs explode in 4 directions (up, down, left, right)
   - Explosion stops at walls and destructible blocks
3. **Powerups**:
   - Spawn with 20% chance when destroying blocks
   - Each powerup gives +1 bonus
   - Maximum 1 powerup per bomb explosion
4. **Health System**:
   - Start with 1 health (can increase with powerups)
   - 2 seconds invincibility after damage
5. **Victory Conditions**:
   - Single Player: Eliminate all bots or player dies
   - Multiplayer: Last player alive wins

## 🔧 Configuration

### Grid Configuration
Modify in `bomb_game.dart`:
```dart
late int gridWidth;  // Currently: 17
late int gridHeight; // Currently: 15
```

### Powerup Drop Rate
Adjust in `bomb_game.dart`:
```dart
if (shouldSpawnPowerups && _random.nextDouble() < 0.20) // 20% chance
```

## 🐛 Known Issues & Limitations

- Multiplayer requires active backend server connection
- Browser cache may require clearing after updates
- Hot reload may not work for all changes (use hot restart)
- Single player mode requires minimum 2 players (1 human + 1 bot)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is private and not published to pub.dev.

## 👥 Authors

- **ISNEXIS** - [GitHub](https://github.com/ISNEXIS)

## 🙏 Acknowledgments

- Inspired by classic Bomberman games
- Built with Flutter and Flame engine
- Retro Game Boy aesthetic
- SignalR for real-time multiplayer

## 📞 Support

For issues and questions, please open an issue on the GitHub repository.

---

**Enjoy the game! 💣💥**
