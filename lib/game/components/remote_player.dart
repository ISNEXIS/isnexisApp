import 'package:flame/components.dart';
import 'package:flutter/material.dart';

typedef JsonMap = Map<String, dynamic>;

class RemotePlayer extends PositionComponent {
  RemotePlayer({
    required this.playerId,
    required this.displayName,
    required double tileSize,
    required Color color,
  }) : _color = color {
    anchor = Anchor.center;
    _circle = CircleComponent(
      radius: tileSize * 0.4,
      paint: Paint()..color = color,
    );
    add(_circle);
    size = Vector2.all(tileSize * 0.8);
  }

  final int playerId;
  String displayName;
  final Color _color;
  late final CircleComponent _circle;

  void updateTileSize(double tileSize) {
    size = Vector2.all(tileSize * 0.8);
    _circle.radius = tileSize * 0.4;
    _circle.paint.color = _color;
  }

  void applyMovement(JsonMap? payload, double tileSize) {
    if (payload == null) {
      return;
    }

    final pixelX = payload['pixelX'] as num?;
    final pixelY = payload['pixelY'] as num?;
    if (pixelX != null && pixelY != null) {
      position = Vector2(pixelX.toDouble(), pixelY.toDouble());
      return;
    }

    final gridX = payload['gridX'] as num?;
    final gridY = payload['gridY'] as num?;
    if (gridX != null && gridY != null) {
      position = Vector2(
        gridX.toDouble() * tileSize,
        gridY.toDouble() * tileSize,
      );
    }
  }
}
