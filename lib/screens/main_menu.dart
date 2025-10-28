import 'package:flutter/material.dart';

class MainMenu extends StatefulWidget {
  final VoidCallback onStart;
  final VoidCallback onMultiplayer;
  final VoidCallback onSettings;
  final VoidCallback onExit;

  const MainMenu({
    super.key,
    required this.onStart,
    required this.onMultiplayer,
    required this.onSettings,
    required this.onExit,
  });

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int selectedIndex = 0;
  final List<String> menuItems = [
    'START GAME',
    'MULTIPLAYER',
    'SETTINGS',
    'EXIT',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F380F), // Dark green (Game Boy style)
              Color(0xFF306230), // Medium green
            ],
          ),
        ),
        child: Stack(
          children: [
            // Pixel grid background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: PixelGridPainter(),
              ),
            ),
            
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Retro title with shadow
                  Stack(
                    children: [
                      // Shadow
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Text(
                          '💣 ISNEXIS 💣',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Courier',
                            letterSpacing: 2,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 8
                              ..color = Colors.black,
                          ),
                        ),
                      ),
                      // Main text
                      Text(
                        '💣 ISNEXIS 💣',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Courier',
                          letterSpacing: 2,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                Color(0xFFFFFF00), // Yellow
                                Color(0xFFFF6600), // Orange
                              ],
                            ).createShader(const Rect.fromLTWH(0.0, 0.0, 400.0, 70.0)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
                    ),
                    child: const Text(
                      '< PRESS ARROW KEYS TO SELECT >',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Courier',
                        color: Color(0xFF9BBC0F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Menu items
                  ...List.generate(menuItems.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: _RetroMenuButton(
                        text: menuItems[index],
                        isSelected: selectedIndex == index,
                        onPressed: () => _selectMenuItem(index),
                        onHover: () => setState(() => selectedIndex = index),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 40),
                  
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
                    ),
                    child: const Text(
                      '© 2025 ISNEXIS - RETRO EDITION',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier',
                        color: Color(0xFF9BBC0F),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectMenuItem(int index) {
    setState(() => selectedIndex = index);
    
    // Add a small delay for visual feedback
    Future.delayed(const Duration(milliseconds: 150), () {
      switch (index) {
        case 0:
          widget.onStart();
          break;
        case 1:
          widget.onMultiplayer();
          break;
        case 2:
          widget.onSettings();
          break;
        case 3:
          widget.onExit();
          break;
      }
    });
  }
}

class _RetroMenuButton extends StatefulWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onPressed;
  final VoidCallback onHover;

  const _RetroMenuButton({
    required this.text,
    required this.isSelected,
    required this.onPressed,
    required this.onHover,
  });

  @override
  State<_RetroMenuButton> createState() => _RetroMenuButtonState();
}

class _RetroMenuButtonState extends State<_RetroMenuButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected || isHovered;
    
    return MouseRegion(
      onEnter: (_) {
        setState(() => isHovered = true);
        widget.onHover();
      },
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF9BBC0F) : Colors.black,
            border: Border.all(
              color: const Color(0xFF9BBC0F),
              width: 4,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color(0xFF9BBC0F).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: Row(
            children: [
              // Selector arrow
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isActive ? 1.0 : 0.0,
                child: Text(
                  '▶ ',
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: 'Courier',
                    color: isActive ? Colors.black : const Color(0xFF9BBC0F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              Expanded(
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Courier',
                    color: isActive ? Colors.black : const Color(0xFF9BBC0F),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              
              // Selector arrow (right)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isActive ? 1.0 : 0.0,
                child: Text(
                  ' ◀',
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: 'Courier',
                    color: isActive ? Colors.black : const Color(0xFF9BBC0F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Pixel grid background painter
class PixelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..strokeWidth = 1;

    const gridSize = 20.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
