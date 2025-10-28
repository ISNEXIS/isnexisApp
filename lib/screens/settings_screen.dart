import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool soundEnabled = true;
  bool musicEnabled = true;
  String difficulty = 'Normal';
  double volume = 0.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⚙ SETTINGS ⚙',
          style: TextStyle(
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF0F380F),
        foregroundColor: const Color(0xFF9BBC0F),
        iconTheme: const IconThemeData(color: Color(0xFF9BBC0F)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F380F), Color(0xFF306230)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Audio Settings Card
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF9BBC0F),
                border: Border.all(color: const Color(0xFF0F380F), width: 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF0F380F),
                    child: const Text(
                      '♪ AUDIO SETTINGS ♪',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9BBC0F),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  _buildRetroSwitch(
                    label: 'SOUND FX',
                    value: soundEnabled,
                    onChanged: (value) => setState(() => soundEnabled = value),
                  ),
                  _buildRetroSwitch(
                    label: 'MUSIC',
                    value: musicEnabled,
                    onChanged: (value) => setState(() => musicEnabled = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOLUME: ${(volume * 100).round()}%',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F380F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: const Color(0xFF0F380F),
                            inactiveTrackColor: const Color(0xFF306230),
                            thumbColor: const Color(0xFF0F380F),
                            overlayColor: const Color(0xFF0F380F).withOpacity(0.2),
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: volume,
                            onChanged: (value) => setState(() => volume = value),
                            divisions: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Game Settings Card
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF9BBC0F),
                border: Border.all(color: const Color(0xFF0F380F), width: 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF0F380F),
                    child: const Text(
                      '⚔ GAME SETTINGS ⚔',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9BBC0F),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DIFFICULTY:',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F380F),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Easy', 'Normal', 'Hard', 'Expert'].map((diff) {
                            final isSelected = difficulty == diff;
                            return GestureDetector(
                              onTap: () => setState(() => difficulty = diff),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F380F) : const Color(0xFF306230),
                                  border: Border.all(color: const Color(0xFF0F380F), width: 3),
                                ),
                                child: Text(
                                  diff.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0xFF9BBC0F) : const Color(0xFF0F380F),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Controls Info Card
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF9BBC0F),
                border: Border.all(color: const Color(0xFF0F380F), width: 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF0F380F),
                    child: const Text(
                      '🎮 CONTROLS 🎮',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9BBC0F),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildControlRow('P1:', 'WASD + SPACE'),
                        _buildControlRow('P2:', 'ARROWS + ENTER'),
                        _buildControlRow('P3:', 'IJKL + U'),
                        _buildControlRow('P4:', 'NUMPAD + 0'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildRetroButton(
                    label: 'RESET',
                    icon: '↻',
                    color: const Color(0xFFFF6B35),
                    onPressed: () {
                      setState(() {
                        soundEnabled = true;
                        musicEnabled = true;
                        difficulty = 'Normal';
                        volume = 0.8;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'SETTINGS RESET!',
                            style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: const Color(0xFF0F380F),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRetroButton(
                    label: 'SAVE',
                    icon: '✓',
                    color: const Color(0xFF4CAF50),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'SAVED!',
                            style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: const Color(0xFF0F380F),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetroSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F380F),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 60,
              height: 30,
              decoration: BoxDecoration(
                color: value ? const Color(0xFF0F380F) : const Color(0xFF306230),
                border: Border.all(color: const Color(0xFF0F380F), width: 3),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(1),
                  color: const Color(0xFF9BBC0F),
                  child: Center(
                    child: Text(
                      value ? 'ON' : 'OF',
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F380F),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(String player, String keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              player,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F380F),
              ),
            ),
          ),
          Text(
            keys,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 12,
              color: Color(0xFF306230),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroButton({
    required String label,
    required String icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0xFF0F380F), width: 4),
        ),
        child: Center(
          child: Text(
            '$icon $label $icon',
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}