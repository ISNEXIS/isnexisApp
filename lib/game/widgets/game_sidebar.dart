import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GameSidebar extends PositionComponent {
  final Function() getPlayerHealth;
  final Function() getExplosionRadius;
  final Function() getBombCount;
  final Function() getScore;
  final Color bgColor;
  final double width;
  
  late TextComponent titleText;
  late TextComponent healthText;
  late TextComponent radiusText;
  late TextComponent bombText;
  late TextComponent scoreText;
  late RectangleComponent bgRect;
  
  GameSidebar({
    required Vector2 position,
    required this.width,
    required this.getPlayerHealth,
    required this.getExplosionRadius,
    required this.getBombCount,
    required this.getScore,
    this.bgColor = const Color(0xFF1A1A1A),
  }) : super(
          position: position,
          size: Vector2(width, 0), // Height will be set to match screen
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Background
    bgRect = RectangleComponent(
      size: size,
      paint: Paint()..color = bgColor.withOpacity(0.9),
    );
    add(bgRect);
    
    // Border
    add(RectangleComponent(
      size: size,
      paint: Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    ));
    
    // Title
    titleText = TextComponent(
      text: 'STATISTICS',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      position: Vector2(width / 2, 20),
      anchor: Anchor.topCenter,
    );
    add(titleText);
    
    // Health
    healthText = TextComponent(
      text: '❤️ Health: ${getPlayerHealth()}',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      position: Vector2(10, 60),
      anchor: Anchor.topLeft,
    );
    add(healthText);
    
    // Explosion Radius
    radiusText = TextComponent(
      text: '💥 Radius: ${getExplosionRadius()}',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      position: Vector2(10, 85),
      anchor: Anchor.topLeft,
    );
    add(radiusText);
    
    // Active Bombs
    bombText = TextComponent(
      text: '💣 Bombs: ${getBombCount()}',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      position: Vector2(10, 110),
      anchor: Anchor.topLeft,
    );
    add(bombText);
    
    // Score
    scoreText = TextComponent(
      text: '⭐ Score: ${getScore()}',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      position: Vector2(10, 135),
      anchor: Anchor.topLeft,
    );
    add(scoreText);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update text with current values
    healthText.text = '❤️ Health: ${getPlayerHealth()}';
    radiusText.text = '💥 Radius: ${getExplosionRadius()}';
    bombText.text = '💣 Bombs: ${getBombCount()}';
    scoreText.text = '⭐ Score: ${getScore()}';
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Update sidebar height to match screen height
    this.size.y = size.y;
    bgRect.size = this.size;
  }
}
