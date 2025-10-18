import 'package:flutter/material.dart';

class StatsSidebar extends StatelessWidget {
  final int health;
  final int explosionRadius;
  final int activeBombs;
  final int score;

  const StatsSidebar({
    super.key,
    required this.health,
    required this.explosionRadius,
    required this.activeBombs,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.9),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Center(
            child: Text(
              '📊 STATS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          // Health
          _buildStatRow('❤️ Health', health.toString()),
          const SizedBox(height: 15),
          
          // Explosion Radius
          _buildStatRow('💥 Radius', explosionRadius.toString()),
          const SizedBox(height: 15),
          
          // Active Bombs
          _buildStatRow('💣 Bombs', activeBombs.toString()),
          const SizedBox(height: 15),
          
          // Score
          _buildStatRow('⭐ Score', score.toString()),
          
          const Spacer(),
          
          // Controls hint
          const Center(
            child: Text(
              '🎮 CONTROLS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'WASD/Touch\n  to Move',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Space/Button\n  for Bomb',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
