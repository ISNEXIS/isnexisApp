import 'package:flutter/material.dart';

class WinningScreen extends StatelessWidget {
  final VoidCallback onPlayAgain;
  final VoidCallback onMainMenu;
  final String? winnerName;
  final int playerNumber;

  const WinningScreen({
    super.key,
    required this.onPlayAgain,
    required this.onMainMenu,
    this.winnerName,
    this.playerNumber = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F380F).withOpacity(0.95),
              const Color(0xFF306230).withOpacity(0.95),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Trophy icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFFFFD700), width: 4),
                ),
                child: const Text(
                  '🏆',
                  style: TextStyle(fontSize: 80),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Victory Title with retro effect
              Stack(
                children: [
                  // Shadow layer
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Text(
                      'VICTORY!',
                      style: TextStyle(
                        fontSize: 72,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 8
                          ..color = Colors.black,
                      ),
                    ),
                  ),
                  // Main text
                  Text(
                    'VICTORY!',
                    style: const TextStyle(
                      fontSize: 72,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Color(0xFFFFD700), // Gold color
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Winner info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFF9BBC0F), width: 3),
                ),
                child: Column(
                  children: [
                    Text(
                      winnerName ?? 'PLAYER $playerNumber',
                      style: const TextStyle(
                        fontSize: 28,
                        fontFamily: 'Courier',
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '>> WINNER! <<',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Courier',
                        color: Color(0xFF9BBC0F),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Congratulations message
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF306230),
                  border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
                ),
                child: const Text(
                  '★ CONGRATULATIONS! ★',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Courier',
                    color: Color(0xFF9BBC0F),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 50),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play Again Button
                  _buildRetroButton(
                    label: '▶ PLAY AGAIN',
                    color: const Color(0xFF9BBC0F),
                    onPressed: onPlayAgain,
                  ),
                  const SizedBox(width: 30),
                  
                  // Main Menu Button
                  _buildRetroButton(
                    label: '⌂ MAIN MENU',
                    color: const Color(0xFF306230),
                    onPressed: onMainMenu,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRetroButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
