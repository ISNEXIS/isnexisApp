import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final Function(Offset) onDirectionChanged;
  final double size;

  const VirtualJoystick({
    super.key,
    required this.onDirectionChanged,
    this.size = 200,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knobPosition = Offset.zero;
  bool _isDragging = false;

  void _updateJoystick(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;
    final distance = delta.distance;
    final maxDistance = widget.size / 2; // Leave room for knob

    if (distance > maxDistance) {
      // Clamp to circle boundary
      _knobPosition = Offset(
        maxDistance * delta.dx / distance,
        maxDistance * delta.dy / distance,
      );
    } else {
      _knobPosition = delta;
    }

    // Normalize to -1 to 1 range
    final normalizedX = _knobPosition.dx / maxDistance;
    final normalizedY = _knobPosition.dy / maxDistance;
    
    widget.onDirectionChanged(Offset(normalizedX, normalizedY));
  }

  void _resetJoystick() {
    setState(() {
      _knobPosition = Offset.zero;
      _isDragging = false;
    });
    widget.onDirectionChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
        });
        _updateJoystick(details.localPosition);
      },
      onPanUpdate: (details) {
        setState(() {
          _updateJoystick(details.localPosition);
        });
      },
      onPanEnd: (details) {
        _resetJoystick();
      },
      onPanCancel: () {
        _resetJoystick();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.3),
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            // Knob
            Transform.translate(
              offset: _knobPosition,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDragging ? Colors.white : Colors.white.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
