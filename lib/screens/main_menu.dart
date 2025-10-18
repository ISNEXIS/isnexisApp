import 'package:flutter/material.dart';

class MainMenu extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSettings;
  final VoidCallback onExit;

  const MainMenu({
    super.key,
    required this.onStart,
    required this.onSettings,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ISNEXIS',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 50),
              _MenuButton(
                text: 'START GAME',
                onPressed: onStart,
              ),
              const SizedBox(height: 20),
              _MenuButton(
                text: 'SETTINGS',
                onPressed: onSettings,
              ),
              const SizedBox(height: 20),
              _MenuButton(
                text: 'EXIT',
                onPressed: onExit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        textStyle: const TextStyle(fontSize: 18),
      ),
      child: Text(text),
    );
  }
}