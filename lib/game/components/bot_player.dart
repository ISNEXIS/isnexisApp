import 'dart:math';

import 'package:flame/components.dart';

import 'player.dart';
import 'tile_type.dart';

class BotPlayer extends Player {
  final Random _random = Random();
  
  // AI state
  Vector2? targetPosition;
  double thinkTimer = 0.0;
  double thinkInterval = 0.15; // Hard difficulty: Lightning fast reactions
  double bombPlaceTimer = 0.0;
  double bombPlaceInterval = 0.9; // Hard difficulty: Very aggressive bomb placement
  bool isRunningFromBomb = false;
  Vector2? dangerPosition;
  List<Vector2> dangerZones = []; // All dangerous positions
  
  // Advanced AI state
  Vector2? targetEnemy; // Track enemy players
  bool isHunting = false;
  bool isSafeAfterBomb = true;
  Vector2? bombEscapeRoute;
  int consecutiveWallHits = 0;
  
  // Callback for bomb placement
  void Function()? onBombPlaceRequest;
  
  // Reference to get all players (for enemy tracking)
  List<Player> Function()? getOtherPlayers;
  
  // Pathfinding
  List<Vector2>? currentPath;
  int pathStep = 0;
  
  BotPlayer({
    required super.gridPosition,
    required super.color,
    required super.character,
    required super.playerNumber,
    required super.tileSize,
    required super.gridWidth,
    required super.gridHeight,
    required super.getGameMap,
    required super.getIsGameOver,
    required super.getJoystickDirection,
    required super.isBombAtPosition,
    this.onBombPlaceRequest,
    this.getOtherPlayers,
  }) {
    thinkTimer = thinkInterval;
    bombPlaceTimer = bombPlaceInterval;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (getIsGameOver()) return;
    
    // Update AI timers
    thinkTimer -= dt;
    bombPlaceTimer -= dt;
    
    // Advanced danger detection with blast radius prediction
    _detectDangerZones();
    
    // Make strategic decisions
    if (thinkTimer <= 0) {
      _makeStrategicDecision();
      thinkTimer = thinkInterval + (_random.nextDouble() * 0.1 - 0.05);
    }
    
    // Intelligent bomb placement
    if (bombPlaceTimer <= 0 && !isRunningFromBomb) {
      _strategicBombPlacement();
      bombPlaceTimer = bombPlaceInterval + (_random.nextDouble() * 0.3);
    }
    
    // Execute movement
    _executeMovement(dt);
  }

  void _detectDangerZones() {
    dangerZones.clear();
    isRunningFromBomb = false;
    dangerPosition = null;
    
    final gameMap = getGameMap();
    
    // Check for bombs and calculate their blast zones
    final checkRadius = explosionRadius + 3; // Check beyond explosion radius
    for (int dy = -checkRadius; dy <= checkRadius; dy++) {
      for (int dx = -checkRadius; dx <= checkRadius; dx++) {
        final checkPos = Vector2(
          gridPosition.x + dx,
          gridPosition.y + dy,
        );
        
        if (isBombAtPosition(checkPos)) {
          // Add bomb position as highly dangerous
          dangerZones.add(checkPos);
          
          // Calculate blast zone with wall blocking
          final blastRadius = explosionRadius;
          
          // Horizontal blast (right)
          for (int i = 1; i <= blastRadius; i++) {
            final blastPos = Vector2(checkPos.x + i, checkPos.y);
            final x = blastPos.x.toInt();
            final y = blastPos.y.toInt();
            if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
              dangerZones.add(blastPos);
              // Stop at walls
              if (gameMap[y][x] != TileType.empty) break;
            }
          }
          
          // Horizontal blast (left)
          for (int i = 1; i <= blastRadius; i++) {
            final blastPos = Vector2(checkPos.x - i, checkPos.y);
            final x = blastPos.x.toInt();
            final y = blastPos.y.toInt();
            if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
              dangerZones.add(blastPos);
              if (gameMap[y][x] != TileType.empty) break;
            }
          }
          
          // Vertical blast (down)
          for (int i = 1; i <= blastRadius; i++) {
            final blastPos = Vector2(checkPos.x, checkPos.y + i);
            final x = blastPos.x.toInt();
            final y = blastPos.y.toInt();
            if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
              dangerZones.add(blastPos);
              if (gameMap[y][x] != TileType.empty) break;
            }
          }
          
          // Vertical blast (up)
          for (int i = 1; i <= blastRadius; i++) {
            final blastPos = Vector2(checkPos.x, checkPos.y - i);
            final x = blastPos.x.toInt();
            final y = blastPos.y.toInt();
            if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
              dangerZones.add(blastPos);
              if (gameMap[y][x] != TileType.empty) break;
            }
          }
          
          // Check if bot is currently in danger
          if (dangerZones.any((d) => 
              d.x.toInt() == gridPosition.x.toInt() && 
              d.y.toInt() == gridPosition.y.toInt())) {
            isRunningFromBomb = true;
            dangerPosition = checkPos;
          }
        }
      }
    }
  }

  void _makeStrategicDecision() {
    if (isRunningFromBomb && dangerPosition != null) {
      // PRIORITY 1: Escape from danger
      _findSafeEscapeRoute();
    } else {
      // Hard difficulty: Aggressive and intelligent - prioritizes combat and positioning
      final otherPlayers = getOtherPlayers?.call() ?? [];
      final aliveEnemies = otherPlayers.where((p) => p.playerHealth > 0 && p != this).toList();
      
      final action = _random.nextDouble();
      if (aliveEnemies.isNotEmpty && action < 0.55) {
        _huntEnemy(aliveEnemies);
      } else if (action < 0.8) {
        _findStrategicPosition();
      } else {
        _findDestructibleWall();
      }
    }
  }

  void _findSafeEscapeRoute() {
    final gameMap = getGameMap();
    Vector2? bestEscape;
    double maxSafety = 0;
    
    // Evaluate all nearby positions
    for (int dy = -3; dy <= 3; dy++) {
      for (int dx = -3; dx <= 3; dx++) {
        final testPos = Vector2(
          gridPosition.x + dx,
          gridPosition.y + dy,
        );
        
        if (!_isValidPosition(testPos, gameMap)) continue;
        
        // Calculate safety score (distance from all danger zones)
        double safety = 0;
        for (final danger in dangerZones) {
          safety += testPos.distanceTo(danger);
        }
        
        // Bonus for positions that lead to open areas
        if (_hasEscapeRoute(testPos, gameMap)) {
          safety *= 1.5;
        }
        
        if (safety > maxSafety) {
          maxSafety = safety;
          bestEscape = testPos;
        }
      }
    }
    
    targetPosition = bestEscape ?? _findAnyOpenSpace();
  }

  bool _hasEscapeRoute(Vector2 pos, List<List<TileType>> gameMap) {
    // Check if there are open paths from this position
    int openDirections = 0;
    final directions = [
      Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0),
    ];
    
    for (final dir in directions) {
      final checkPos = pos + dir;
      if (_isValidPosition(checkPos, gameMap)) {
        openDirections++;
      }
    }
    
    return openDirections >= 2; // At least 2 escape routes
  }

  Vector2? _findAnyOpenSpace() {
    final gameMap = getGameMap();
    for (int y = 1; y < gridHeight - 1; y++) {
      for (int x = 1; x < gridWidth - 1; x++) {
        final pos = Vector2(x.toDouble(), y.toDouble());
        if (_isValidPosition(pos, gameMap) && !dangerZones.contains(pos)) {
          return pos;
        }
      }
    }
    return null;
  }

  void _huntEnemy(List<Player> enemies) {
    isHunting = true;
    Player? target;
    double bestScore = 0;
    
    for (final enemy in enemies) {
      final distance = gridPosition.distanceTo(enemy.gridPosition);
      // Score based on proximity and vulnerability
      final score = (10 - distance) + (_isEnemyVulnerable(enemy) ? 5 : 0);
      
      if (score > bestScore) {
        bestScore = score;
        target = enemy;
      }
    }
    
    if (target != null) {
      _moveTowardsEnemy(target.gridPosition);
    } else {
      _findStrategicPosition();
    }
  }

  bool _isEnemyVulnerable(Player enemy) {
    // Check if enemy is near walls or in a corner
    final gameMap = getGameMap();
    int wallsNearby = 0;
    
    final directions = [
      Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0),
    ];
    
    for (final dir in directions) {
      final checkPos = enemy.gridPosition + dir;
      final x = checkPos.x.toInt();
      final y = checkPos.y.toInt();
      
      if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
        if (gameMap[y][x] != TileType.empty) {
          wallsNearby++;
        }
      }
    }
    
    return wallsNearby >= 2; // Trapped in corner or narrow space
  }

  void _moveTowardsEnemy(Vector2 enemyPos) {
    final gameMap = getGameMap();
    
    // Find position adjacent to enemy
    final directions = [
      Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0),
    ];
    
    Vector2? bestPos;
    double minDistance = double.infinity;
    
    for (final dir in directions) {
      final pos = enemyPos + dir;
      if (_isValidPosition(pos, gameMap)) {
        final distance = gridPosition.distanceTo(pos);
        if (distance < minDistance) {
          minDistance = distance;
          bestPos = pos;
        }
      }
    }
    
    targetPosition = bestPos ?? gridPosition;
  }

  void _findStrategicPosition() {
    final gameMap = getGameMap();
    Vector2? bestPosition;
    double bestScore = 0;
    
    // Find positions with good strategic value
    for (int y = 1; y < gridHeight - 1; y++) {
      for (int x = 1; x < gridWidth - 1; x++) {
        if (gameMap[y][x] == TileType.empty) {
          final pos = Vector2(x.toDouble(), y.toDouble());
          final score = _evaluatePositionStrength(pos, gameMap);
          
          if (score > bestScore) {
            bestScore = score;
            bestPosition = pos;
          }
        }
      }
    }
    
    if (bestPosition != null) {
      targetPosition = bestPosition;
    } else {
      _randomWalk();
    }
  }

  double _evaluatePositionStrength(Vector2 pos, List<List<TileType>> gameMap) {
    double score = 0;
    
    // Nearby destructible walls (opportunity)
    int destructiblesNearby = 0;
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final x = (pos.x + dx).toInt();
        final y = (pos.y + dy).toInt();
        
        if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
          if (gameMap[y][x] == TileType.destructible) {
            destructiblesNearby++;
          }
        }
      }
    }
    score += destructiblesNearby * 2;
    
    // Open space (mobility)
    if (_hasEscapeRoute(pos, gameMap)) {
      score += 5;
    }
    
    // Center of map (better control)
    final centerX = gridWidth / 2;
    final centerY = gridHeight / 2;
    final distanceFromCenter = Vector2(centerX, centerY).distanceTo(pos);
    score += (20 - distanceFromCenter) * 0.5;
    
    return score;
  }

  void _randomWalk() {
    final gameMap = getGameMap();
    final directions = [
      Vector2(0, -1), // Up
      Vector2(0, 1),  // Down
      Vector2(-1, 0), // Left
      Vector2(1, 0),  // Right
    ];
    
    // Shuffle directions
    directions.shuffle(_random);
    
    // Find first valid direction
    for (final dir in directions) {
      final newPos = gridPosition + dir;
      if (_isValidPosition(newPos, gameMap)) {
        targetPosition = newPos;
        return;
      }
    }
  }

  void _findDestructibleWall() {
    final gameMap = getGameMap();
    Vector2? nearestWall;
    double minDistance = double.infinity;
    
    // Find nearest destructible wall
    for (int y = 1; y < gridHeight - 1; y++) {
      for (int x = 1; x < gridWidth - 1; x++) {
        if (gameMap[y][x] == TileType.destructible) {
          final wallPos = Vector2(x.toDouble(), y.toDouble());
          final distance = gridPosition.distanceTo(wallPos);
          if (distance < minDistance) {
            minDistance = distance;
            nearestWall = wallPos;
          }
        }
      }
    }
    
    if (nearestWall != null) {
      // Find adjacent empty tile to the wall
      final adjacentPositions = [
        nearestWall + Vector2(0, -1), // Above
        nearestWall + Vector2(0, 1),  // Below
        nearestWall + Vector2(-1, 0), // Left
        nearestWall + Vector2(1, 0),  // Right
      ];
      
      for (final pos in adjacentPositions) {
        if (_isValidPosition(pos, gameMap)) {
          targetPosition = pos;
          return;
        }
      }
    }
    
    // No walls found, just wander
    _randomWalk();
  }

  bool _isValidPosition(Vector2 pos, List<List<TileType>> gameMap) {
    final x = pos.x.toInt();
    final y = pos.y.toInt();
    
    if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) {
      return false;
    }
    
    if (gameMap[y][x] != TileType.empty) {
      return false;
    }
    
    if (isBombAtPosition(pos)) {
      return false;
    }
    
    return true;
  }

  void _executeMovement(double dt) {
    if (targetPosition == null) {
      // No target, idle with occasional micro-adjustments for realism
      if (_random.nextDouble() < 0.02) {
        velocity = Vector2.zero();
      }
      return;
    }
    
    // Calculate direction to target (grid-based movement)
    final currentGridX = gridPosition.x.toInt();
    final currentGridY = gridPosition.y.toInt();
    final targetGridX = targetPosition!.x.toInt();
    final targetGridY = targetPosition!.y.toInt();
    
    // Already at target grid position
    if (currentGridX == targetGridX && currentGridY == targetGridY) {
      targetPosition = null;
      velocity = Vector2.zero();
      return;
    }
    
    // Calculate pixel positions
    final currentPixelPos = Vector2(
      currentGridX * tileSize + tileSize / 2,
      currentGridY * tileSize + tileSize / 2,
    );
    final targetPixelPos = Vector2(
      targetGridX * tileSize + tileSize / 2,
      targetGridY * tileSize + tileSize / 2,
    );
    
    final direction = targetPixelPos - currentPixelPos;
    
    // Close enough to snap to grid
    if (direction.length < tileSize * 0.4) {
      targetPosition = null;
      velocity = Vector2.zero();
      return;
    }
    
    // Move in one direction at a time (more natural grid movement)
    if (direction.x.abs() > direction.y.abs()) {
      // Move horizontally
      velocity = Vector2(direction.x > 0 ? Player.moveSpeed : -Player.moveSpeed, 0);
    } else {
      // Move vertically
      velocity = Vector2(0, direction.y > 0 ? Player.moveSpeed : -Player.moveSpeed);
    }
    
    // Hard difficulty: Move faster when hunting
    if (isHunting) {
      velocity *= 1.1;
    }
  }

  void _strategicBombPlacement() {
    if (!canPlaceBomb()) return;
    
    final gameMap = getGameMap();
    final currentX = gridPosition.x.toInt();
    final currentY = gridPosition.y.toInt();
    
    // Check strategic value of placing bomb here
    int destructiblesInRange = 0;
    int enemiesInRange = 0;
    bool hasEscapeRoute = false;
    int escapeRoutes = 0;
    
    // Count destructibles in blast radius (with wall blocking)
    final directions = [
      Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
    ];
    
    for (final dir in directions) {
      for (int i = 1; i <= explosionRadius; i++) {
        final pos = Vector2(currentX.toDouble(), currentY.toDouble()) + (dir * i.toDouble());
        final x = pos.x.toInt();
        final y = pos.y.toInt();
        
        if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) break;
        
        if (gameMap[y][x] == TileType.destructible) {
          destructiblesInRange++;
          break; // Wall blocks further blast
        } else if (gameMap[y][x] != TileType.empty) {
          break; // Solid wall blocks
        }
      }
    }
    
    // Check for enemies in blast range (hard difficulty always checks)
    final otherPlayers = getOtherPlayers?.call() ?? [];
    for (final enemy in otherPlayers) {
      if (enemy.playerHealth <= 0 || enemy == this) continue;
      
      final enemyX = enemy.gridPosition.x.toInt();
      final enemyY = enemy.gridPosition.y.toInt();
      
      // Check if enemy is in cross pattern within blast radius
      if (enemyX == currentX && (enemyY - currentY).abs() <= explosionRadius) {
        // Verify no walls block the blast
        bool blocked = false;
        final start = currentY < enemyY ? currentY : enemyY;
        final end = currentY > enemyY ? currentY : enemyY;
        for (int y = start + 1; y < end; y++) {
          if (gameMap[y][currentX] != TileType.empty) {
            blocked = true;
            break;
          }
        }
        if (!blocked) enemiesInRange++;
      } else if (enemyY == currentY && (enemyX - currentX).abs() <= explosionRadius) {
        bool blocked = false;
        final start = currentX < enemyX ? currentX : enemyX;
        final end = currentX > enemyX ? currentX : enemyX;
        for (int x = start + 1; x < end; x++) {
          if (gameMap[currentY][x] != TileType.empty) {
            blocked = true;
            break;
          }
        }
        if (!blocked) enemiesInRange++;
      }
    }
    
    // Find ALL escape routes and pick the best one
    Vector2? bestEscapeRoute;
    double bestEscapeScore = 0;
    
    for (final dir in directions) {
      Vector2? escapePos;
      bool canEscape = true;
      double escapeScore = 0;
      
      // Check if we can move beyond blast range in this direction
      for (int i = 1; i <= explosionRadius + 2; i++) {
        final testPos = gridPosition + (dir * i.toDouble());
        if (!_isValidPosition(testPos, gameMap)) {
          canEscape = false;
          break;
        }
        if (i > explosionRadius) {
          escapePos = testPos;
          // Score based on openness
          escapeScore = _evaluatePositionStrength(testPos, gameMap);
        }
      }
      
      if (canEscape && escapePos != null) {
        escapeRoutes++;
        if (escapeScore > bestEscapeScore) {
          bestEscapeScore = escapeScore;
          bestEscapeRoute = escapePos;
          hasEscapeRoute = true;
        }
      }
    }
    
    // Decision logic - Hard difficulty: Aggressive placement, willing to take risks
    bool shouldPlaceBomb = false;
    
    shouldPlaceBomb = (destructiblesInRange >= 1 && hasEscapeRoute) ||
                     (enemiesInRange >= 1 && (hasEscapeRoute || _random.nextDouble() < 0.3)) || // Risky trap
                     (destructiblesInRange >= 2 && escapeRoutes >= 1); // Multi-wall break
    
    if (shouldPlaceBomb) {
      onBombPlaceRequest?.call();
      
      // Immediately start escaping if we placed a bomb
      if (bestEscapeRoute != null) {
        targetPosition = bestEscapeRoute;
        bombEscapeRoute = bestEscapeRoute;
        isRunningFromBomb = true;
      }
    }
  }
  
  @override
  Vector2 Function() get getJoystickDirection {
    // Override joystick to return bot's calculated velocity
    return () => velocity.normalized();
  }
}
