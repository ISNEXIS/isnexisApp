import 'dart:math';

import 'package:flame/components.dart';

import 'player.dart';
import 'tile_type.dart';

enum BotDifficulty {
  easy,
  medium,
  hard,
}

class BotPlayer extends Player {
  final BotDifficulty difficulty;
  final Random _random = Random();
  
  // AI state
  Vector2? targetPosition;
  double thinkTimer = 0.0;
  double thinkInterval = 0.0;
  double bombPlaceTimer = 0.0;
  double bombPlaceInterval = 0.0;
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
    this.difficulty = BotDifficulty.medium,
    this.onBombPlaceRequest,
    this.getOtherPlayers,
  }) {
    _setDifficultyParameters();
  }

  void _setDifficultyParameters() {
    switch (difficulty) {
      case BotDifficulty.easy:
        thinkInterval = 0.8; // Slower reactions
        bombPlaceInterval = 3.5; // Rarely places bombs
        break;
      case BotDifficulty.medium:
        thinkInterval = 0.4; // Quick reactions
        bombPlaceInterval = 1.8; // Places bombs strategically
        break;
      case BotDifficulty.hard:
        thinkInterval = 0.2; // Very fast reactions
        bombPlaceInterval = 1.2; // Aggressive bomb placement
        break;
    }
    
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
    
    // Check for bombs and calculate their blast zones
    final checkRadius = explosionRadius + 3; // Check beyond explosion radius
    for (int dy = -checkRadius; dy <= checkRadius; dy++) {
      for (int dx = -checkRadius; dx <= checkRadius; dx++) {
        final checkPos = Vector2(
          gridPosition.x + dx,
          gridPosition.y + dy,
        );
        
        if (isBombAtPosition(checkPos)) {
          // Add bomb position
          dangerZones.add(checkPos);
          
          // Calculate blast zone (cross pattern)
          final blastRadius = explosionRadius; // Assume standard blast
          
          // Horizontal blast
          for (int i = -blastRadius; i <= blastRadius; i++) {
            dangerZones.add(Vector2(checkPos.x + i, checkPos.y));
          }
          
          // Vertical blast
          for (int i = -blastRadius; i <= blastRadius; i++) {
            dangerZones.add(Vector2(checkPos.x, checkPos.y + i));
          }
          
          // Mark as in danger
          if (!isRunningFromBomb) {
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
      // Strategic decision based on difficulty
      final otherPlayers = getOtherPlayers?.call() ?? [];
      final aliveEnemies = otherPlayers.where((p) => p.playerHealth > 0 && p != this).toList();
      
      switch (difficulty) {
        case BotDifficulty.easy:
          // Easy: Just destroy walls, avoid enemies
          if (_random.nextDouble() < 0.7) {
            _findDestructibleWall();
          } else {
            _randomWalk();
          }
          break;
          
        case BotDifficulty.medium:
          // Medium: Mix of wall destruction and enemy tracking
          if (aliveEnemies.isNotEmpty && _random.nextDouble() < 0.4) {
            _trackNearestEnemy(aliveEnemies);
          } else if (_random.nextDouble() < 0.7) {
            _findStrategicPosition();
          } else {
            _findDestructibleWall();
          }
          break;
          
        case BotDifficulty.hard:
          // Hard: Aggressive enemy hunting and strategic positioning
          if (aliveEnemies.isNotEmpty && _random.nextDouble() < 0.6) {
            _huntEnemy(aliveEnemies);
          } else {
            _findStrategicPosition();
          }
          break;
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

  void _trackNearestEnemy(List<Player> enemies) {
    Player? nearest;
    double minDistance = double.infinity;
    
    for (final enemy in enemies) {
      final distance = gridPosition.distanceTo(enemy.gridPosition);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = enemy;
      }
    }
    
    if (nearest != null) {
      // Move towards general area but maintain safe distance
      final safeDistance = 3.0;
      if (minDistance > safeDistance) {
        targetEnemy = nearest.gridPosition;
        _moveTowardsEnemy(nearest.gridPosition);
      } else {
        // Too close, maintain distance
        _findStrategicPosition();
      }
    }
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
    if (targetPosition == null) return;
    
    // Calculate direction to target
    final targetPixelPos = Vector2(
      targetPosition!.x * tileSize + tileSize * 0.1,
      targetPosition!.y * tileSize + tileSize * 0.1,
    );
    
    final direction = targetPixelPos - position;
    
    // If close enough to target, pick new target
    if (direction.length < tileSize * 0.3) {
      targetPosition = null;
      velocity = Vector2.zero();
      return;
    }
    
    // Move towards target
    direction.normalize();
    velocity = direction * Player.moveSpeed;
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
    
    // Count destructibles in blast radius
    for (int i = 1; i <= explosionRadius; i++) {
      // Check all 4 directions
      final positions = [
        Vector2((currentX + i).toDouble(), currentY.toDouble()),
        Vector2((currentX - i).toDouble(), currentY.toDouble()),
        Vector2(currentX.toDouble(), (currentY + i).toDouble()),
        Vector2(currentX.toDouble(), (currentY - i).toDouble()),
      ];
      
      for (final pos in positions) {
        final x = pos.x.toInt();
        final y = pos.y.toInt();
        
        if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
          if (gameMap[y][x] == TileType.destructible) {
            destructiblesInRange++;
          }
        }
      }
    }
    
    // Check for enemies in blast range (for hard difficulty)
    if (difficulty == BotDifficulty.hard) {
      final otherPlayers = getOtherPlayers?.call() ?? [];
      for (final enemy in otherPlayers) {
        if (enemy.playerHealth <= 0 || enemy == this) continue;
        
        final enemyX = enemy.gridPosition.x.toInt();
        final enemyY = enemy.gridPosition.y.toInt();
        
        // Check if enemy is in cross pattern
        if ((enemyX == currentX && (enemyY - currentY).abs() <= explosionRadius) ||
            (enemyY == currentY && (enemyX - currentX).abs() <= explosionRadius)) {
          enemiesInRange++;
        }
      }
    }
    
    // Verify escape route exists
    final escapeDirections = [
      Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0),
    ];
    
    for (final dir in escapeDirections) {
      Vector2 escapePos = gridPosition;
      bool canEscape = true;
      
      // Check if we can move at least 2 tiles in this direction
      for (int i = 1; i <= explosionRadius + 1; i++) {
        escapePos = gridPosition + (dir * i.toDouble());
        if (!_isValidPosition(escapePos, gameMap)) {
          canEscape = false;
          break;
        }
      }
      
      if (canEscape) {
        hasEscapeRoute = true;
        bombEscapeRoute = escapePos;
        break;
      }
    }
    
    // Decision logic based on difficulty
    bool shouldPlaceBomb = false;
    
    switch (difficulty) {
      case BotDifficulty.easy:
        // Only place if there are walls AND escape route
        shouldPlaceBomb = destructiblesInRange >= 1 && 
                         hasEscapeRoute && 
                         _random.nextDouble() < 0.4;
        break;
        
      case BotDifficulty.medium:
        // Place if strategic AND escape exists
        shouldPlaceBomb = (destructiblesInRange >= 1 || enemiesInRange >= 1) && 
                         hasEscapeRoute && 
                         _random.nextDouble() < 0.7;
        break;
        
      case BotDifficulty.hard:
        // Aggressive: place if ANY advantage exists
        shouldPlaceBomb = ((destructiblesInRange >= 1 || enemiesInRange >= 1) && hasEscapeRoute) ||
                         (enemiesInRange >= 1 && _random.nextDouble() < 0.5); // Risk it for enemy trap
        break;
    }
    
    if (shouldPlaceBomb) {
      onBombPlaceRequest?.call();
      
      // Immediately start escaping if we placed a bomb
      if (bombEscapeRoute != null) {
        targetPosition = bombEscapeRoute;
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
