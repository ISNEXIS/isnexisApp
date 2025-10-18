import 'package:flutter/material.dart';

import 'virtual_joystick.dart';

class ControlsPanel extends StatelessWidget {
  final VoidCallback onBombPressed;
  final Function(Offset) onJoystickChanged;

  const ControlsPanel({
    super.key,
    required this.onBombPressed,
    required this.onJoystickChanged,
  });

  @override
  Widget build(BuildContext context) {
    const double controlSize = 150.0; // Same size for both joystick and button
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.9),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side - Virtual joystick
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: VirtualJoystick(
              size: controlSize,
              onDirectionChanged: onJoystickChanged,
            ),
          ),
          
          // Center - Instructions
          const Expanded(
            child: Center(
              child: Text(
                'Use WASD or touch to move',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          // Right side - Bomb button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: controlSize,
              height: controlSize,
              child: ElevatedButton(
                onPressed: onBombPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  '💣',
                  style: TextStyle(fontSize: 50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
