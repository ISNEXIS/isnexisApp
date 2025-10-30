import 'dart:async';

import 'package:logging/logging.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';

typedef JsonMap = Map<String, dynamic>;

class GameHubClient {
  GameHubClient({required this.baseUrl, Logger? logger})
    : _logger = logger ?? Logger('GameHubClient');

  final String baseUrl;
  final Logger _logger;
  HubConnection? _connection;
  Completer<void>? _startCompleter;
  bool _disposed = false;

  final _connectionStateController =
      StreamController<HubConnectionState>.broadcast();
  final _roomRosterController =
      StreamController<RoomRosterEvent>.broadcast();
  final _playerJoinedController = StreamController<PlayerSummary>.broadcast();
  final _playerLeftController = StreamController<PlayerSummary>.broadcast();
  final _playerDisconnectedController =
      StreamController<PlayerSummary>.broadcast();
  final _playerReadyController = 
      StreamController<PlayerReadyEvent>.broadcast();
  final _characterSelectedController =
      StreamController<CharacterSelectedEvent>.broadcast();
  final _gameStartController = 
      StreamController<GameStartEvent>.broadcast();
  final _playerMovementController =
      StreamController<PlayerMovementEvent>.broadcast();
  final _bombPlacedController = StreamController<BombPlacedEvent>.broadcast();
  final _explosionController = StreamController<ExplosionEvent>.broadcast();
  final _itemCollectedController =
      StreamController<ItemCollectedEvent>.broadcast();
  final _playerDiedController = StreamController<int>.broadcast();
  final _gameEndedController = StreamController<GameEndedEvent>.broadcast();

  Stream<HubConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<RoomRosterEvent> get roomRosterStream =>
      _roomRosterController.stream;
  Stream<PlayerSummary> get playerJoinedStream =>
      _playerJoinedController.stream;
  Stream<PlayerSummary> get playerLeftStream => _playerLeftController.stream;
  Stream<PlayerSummary> get playerDisconnectedStream =>
      _playerDisconnectedController.stream;
  Stream<PlayerReadyEvent> get playerReadyStream =>
      _playerReadyController.stream;
  Stream<CharacterSelectedEvent> get characterSelectedStream =>
      _characterSelectedController.stream;
  Stream<GameStartEvent> get gameStartStream =>
      _gameStartController.stream;
  Stream<PlayerMovementEvent> get playerMovementStream =>
      _playerMovementController.stream;
  Stream<BombPlacedEvent> get bombPlacedStream => _bombPlacedController.stream;
  Stream<ExplosionEvent> get explosionStream => _explosionController.stream;
  Stream<ItemCollectedEvent> get itemCollectedStream =>
      _itemCollectedController.stream;
  Stream<int> get playerDiedStream => _playerDiedController.stream;
  Stream<GameEndedEvent> get gameEndedStream => _gameEndedController.stream;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> ensureConnected() async {
    _throwIfDisposed();

    _connection ??= _buildConnection();

    final connection = _connection!;

    if (connection.state == HubConnectionState.Connected) {
      return;
    }

    if (connection.state == HubConnectionState.Connecting) {
      if (_startCompleter != null) {
        await _startCompleter!.future;
      }
      return;
    }

    _startCompleter ??= Completer<void>();
    try {
      _connectionStateController.add(HubConnectionState.Connecting);
      await connection.start();
      _connectionStateController.add(HubConnectionState.Connected);
      _startCompleter?.complete();
    } catch (error, stackTrace) {
      _startCompleter?.completeError(error, stackTrace);
      rethrow;
    } finally {
      _startCompleter = null;
    }
  }

  Future<void> disconnect() async {
    _throwIfDisposed();
    final connection = _connection;
    if (connection == null ||
        connection.state == HubConnectionState.Disconnected) {
      return;
    }

    await connection.stop();
    _connectionStateController.add(HubConnectionState.Disconnected);
  }

  Future<void> joinRoom(int roomId, int playerId) async {
    await _invoke('JoinRoom', args: [roomId, playerId]);
  }

  Future<void> leaveRoom(int roomId) async {
    await _invoke('LeaveRoom', args: [roomId]);
  }

  Future<void> setPlayerReady(int roomId, int playerId, bool isReady) async {
    // Note: Server API might not support this yet
    await _invoke('SetPlayerReady', args: [roomId, playerId, isReady]);
  }

  Future<void> selectCharacter(int roomId, int playerId, int characterIndex) async {
    print('Invoking SelectCharacter: roomId=$roomId, playerId=$playerId, characterIndex=$characterIndex');
    _logger.info('Invoking SelectCharacter: roomId=$roomId, playerId=$playerId, characterIndex=$characterIndex');
    await _invoke('SelectCharacter', args: [roomId, playerId, characterIndex]);
    print('SelectCharacter invoked successfully');
    _logger.info('SelectCharacter invoked successfully');
  }

  Future<void> startGame(int roomId) async {
    print('Invoking StartGame: roomId=$roomId');
    _logger.info('Invoking StartGame: roomId=$roomId');
    await _invoke('StartGame', args: [roomId]);
    print('StartGame invoked successfully');
    _logger.info('StartGame invoked successfully');
  }

  Future<void> sendGameStartWithCharacters(int roomId, JsonMap playerCharacters) async {
    print('Invoking SendGameStartWithCharacters: roomId=$roomId, characters=$playerCharacters');
    _logger.info('Invoking SendGameStartWithCharacters: roomId=$roomId, characters=$playerCharacters');
    await _invoke('SendGameStartWithCharacters', args: [roomId, playerCharacters]);
    print('SendGameStartWithCharacters invoked successfully');
    _logger.info('SendGameStartWithCharacters invoked successfully');
  }

  Future<void> sendPlayerMovement(int roomId, JsonMap position) async {
    await _invoke('SendPlayerMovement', args: [roomId, position]);
  }

  Future<void> sendBombPlaced(int roomId, JsonMap bomb) async {
    await _invoke('SendBombPlaced', args: [roomId, bomb]);
  }

  Future<void> sendExplosion(int roomId, JsonMap explosion) async {
    await _invoke('SendExplosion', args: [roomId, explosion]);
  }

  Future<void> sendItemCollected(
    int roomId, {
    required int itemId,
    required int playerId,
  }) async {
    await _invoke('SendItemCollected', args: [roomId, itemId, playerId]);
  }

  Future<void> sendPlayerDeath(int roomId, int playerId) async {
    await _invoke('SendPlayerDeath', args: [roomId, playerId]);
  }

  Future<void> sendGameEnd(int roomId, JsonMap summary) async {
    await _invoke('SendGameEnd', args: [roomId, summary]);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await disconnect();

    await Future.wait([
      _connectionStateController.close(),
      _roomRosterController.close(),
      _playerJoinedController.close(),
      _playerLeftController.close(),
      _playerDisconnectedController.close(),
      _playerReadyController.close(),
      _characterSelectedController.close(),
      _gameStartController.close(),
      _playerMovementController.close(),
      _bombPlacedController.close(),
      _explosionController.close(),
      _itemCollectedController.close(),
      _playerDiedController.close(),
      _gameEndedController.close(),
    ]);
  }

  Future<void> _invoke(String methodName, {List<Object?>? args}) async {
    _throwIfDisposed();
    await ensureConnected();

    final connection = _connection;
    if (connection == null) {
      throw StateError('Hub connection has not been created.');
    }

    try {
      final preparedArgs = args == null
          ? const <Object>[]
          : List<Object>.from(args);
      await connection.invoke(methodName, args: preparedArgs);
    } catch (error, stackTrace) {
      _logger.severe('Error invoking method $methodName', error, stackTrace);
      rethrow;
    }
  }

  HubConnection _buildConnection() {
    final sanitizedBaseUrl = baseUrl.trim();
    if (sanitizedBaseUrl.isEmpty) {
      throw StateError('GameHubClient baseUrl must not be empty.');
    }
    final connection = HubConnectionBuilder()
        .withUrl('${sanitizedBaseUrl.replaceAll(RegExp(r'/+$'), '')}/gamehub')
        .withAutomaticReconnect()
        .build();

    connection.onclose(({error}) {
      _connectionStateController.add(HubConnectionState.Disconnected);
      if (error != null) {
        _logger.warning('SignalR connection closed unexpectedly.', error);
      }
    });

    connection.onreconnected(({connectionId}) {
      _connectionStateController.add(HubConnectionState.Connected);
      _logger.info('SignalR reconnected with connectionId=$connectionId');
    });

    connection.onreconnecting(({error}) {
      _connectionStateController.add(HubConnectionState.Reconnecting);
      if (error != null) {
        _logger.warning('SignalR reconnecting due to error', error);
      }
    });

    _registerHandlers(connection);
    
    // Debug: Log all incoming events
    connection.serverTimeoutInMilliseconds = 30000;
    
    return connection;
  }

  void _registerHandlers(HubConnection connection) {
    connection.on('RoomRoster', (args) {
      final rosterEvent = _parseRoomRoster(args);
      if (rosterEvent != null) {
        _roomRosterController.add(rosterEvent);
      }
    });

    connection.on('PlayerJoined', (args) {
      final summary = _parsePlayerSummary(
        args != null && args.isNotEmpty ? args.first : null,
      );
      if (summary != null) {
        _playerJoinedController.add(summary);
      }
    });

    connection.on('PlayerLeft', (args) {
      final summary = _parsePlayerSummary(
        args != null && args.isNotEmpty ? args.first : null,
      );
      if (summary != null) {
        _playerLeftController.add(summary);
      }
    });

    connection.on('PlayerDisconnected', (args) {
      final summary = _parsePlayerSummary(
        args != null && args.isNotEmpty ? args.first : null,
      );
      if (summary != null) {
        _playerDisconnectedController.add(summary);
      }
    });

    connection.on('PlayerReady', (args) {
      if (args != null && args.length >= 2) {
        final playerId = args[0] as int?;
        final isReady = args[1] as bool?;
        if (playerId != null && isReady != null) {
          _playerReadyController.add(PlayerReadyEvent(
            playerId: playerId,
            isReady: isReady,
          ));
        }
      }
    });

    connection.on('CharacterSelected', (args) {
      print('>>> CharacterSelected event received from server <<<');
      print('Args: $args');
      _logger.info('>>> CharacterSelected event received from server <<<');
      _logger.info('Args: $args');
      if (args != null && args.length >= 2) {
        final playerId = args[0] as int?;
        final characterIndex = args[1] as int?;
        print('Parsed: playerId=$playerId, characterIndex=$characterIndex');
        _logger.info('Parsed: playerId=$playerId, characterIndex=$characterIndex');
        if (playerId != null && characterIndex != null) {
          _characterSelectedController.add(CharacterSelectedEvent(
            playerId: playerId,
            characterIndex: characterIndex,
          ));
          print('CharacterSelectedEvent added to stream');
          _logger.info('CharacterSelectedEvent added to stream');
        } else {
          print('WARNING: playerId or characterIndex is null');
          _logger.warning('playerId or characterIndex is null');
        }
      } else {
        print('WARNING: CharacterSelected args invalid: $args');
        _logger.warning('CharacterSelected args invalid: $args');
      }
    });

    connection.on('GameStarted', (args) {
      print('>>> GameStarted event received from server <<<');
      print('Args: $args');
      _logger.info('>>> GameStarted event received from server <<<');
      _logger.info('Args: $args');
      if (args != null && args.isNotEmpty) {
        final roomId = args[0] as int?;
        final playerCharacters = args.length > 1 ? _parseMap(args[1]) : null;
        print('Parsed roomId: $roomId, playerCharacters: $playerCharacters');
        _logger.info('Parsed roomId: $roomId, playerCharacters: $playerCharacters');
        if (roomId != null) {
          _gameStartController.add(GameStartEvent(
            roomId: roomId,
            playerCharacters: playerCharacters,
          ));
          print('GameStartEvent added to stream');
          _logger.info('GameStartEvent added to stream');
        } else {
          print('WARNING: roomId is null');
          _logger.warning('roomId is null');
        }
      } else {
        print('WARNING: GameStarted args invalid: $args');
        _logger.warning('GameStarted args invalid: $args');
      }
    });

    connection.on('PlayerMoved', (args) {
      final payload = _parseMovementEvent(args);
      if (payload != null) {
        _playerMovementController.add(payload);
      }
    });

    connection.on('BombPlaced', (args) {
      final payload = _parseBombEvent(args);
      if (payload != null) {
        _bombPlacedController.add(payload);
      }
    });

    connection.on('Explosion', (args) {
      final payload = _parseExplosionEvent(args);
      if (payload != null) {
        _explosionController.add(payload);
      }
    });

    connection.on('ItemCollected', (args) {
      final payload = _parseItemCollected(args);
      if (payload != null) {
        _itemCollectedController.add(payload);
      }
    });

    connection.on('PlayerDied', (args) {
      final playerId = _parseIntArg(args);
      if (playerId != null) {
        _playerDiedController.add(playerId);
      }
    });

    connection.on('GameEnded', (args) {
      final payload = _parseGameEnded(args);
      if (payload != null) {
        _gameEndedController.add(payload);
      }
    });
  }

  PlayerMovementEvent? _parseMovementEvent(List<Object?>? args) {
    if (args == null || args.length < 2) {
      return null;
    }

    final position = _parseMap(args[0]);
    final playerId = _toInt(args[1]);
    if (playerId == null) {
      return null;
    }

    return PlayerMovementEvent(playerId: playerId, payload: position);
  }

  BombPlacedEvent? _parseBombEvent(List<Object?>? args) {
    if (args == null || args.length < 2) {
      return null;
    }
    final payload = _parseMap(args[0]);
    final playerId = _toInt(args[1]);
    if (playerId == null) {
      return null;
    }
    return BombPlacedEvent(playerId: playerId, payload: payload);
  }

  ExplosionEvent? _parseExplosionEvent(List<Object?>? args) {
    if (args == null || args.isEmpty) {
      return null;
    }
    final payload = _parseMap(args[0]);
    final playerId = args.length > 1 ? _toInt(args[1]) : null;
    return ExplosionEvent(playerId: playerId, payload: payload);
  }

  ItemCollectedEvent? _parseItemCollected(List<Object?>? args) {
    if (args == null || args.length < 2) {
      return null;
    }

    final itemId = _toInt(args[0]);
    final playerId = _toInt(args[1]);

    if (itemId == null || playerId == null) {
      return null;
    }

    return ItemCollectedEvent(itemId: itemId, playerId: playerId);
  }

  GameEndedEvent? _parseGameEnded(List<Object?>? args) {
    if (args == null || args.isEmpty) {
      return null;
    }

    final winnerId = _toInt(args[0]);
    final summary = args.length > 1 ? _parseMap(args[1]) : null;
    
    // Extract winner details from summary if available
    String? winnerName;
    int? winnerRoomPosition;
    
    if (summary != null) {
      winnerName = summary['winnerName']?.toString();
      winnerRoomPosition = _toInt(summary['winnerRoomPosition']);
    }

    return GameEndedEvent(
      winnerId: winnerId,
      summary: summary,
      winnerName: winnerName,
      winnerRoomPosition: winnerRoomPosition,
    );
  }

  RoomRosterEvent? _parseRoomRoster(List<Object?>? args) {
    if (args == null || args.isEmpty) {
      return null;
    }

    // First element is the list of players
    final first = args.first;
    List<PlayerSummary>? players;
    
    if (first is Iterable) {
      players = first
          .map(_parsePlayerSummary)
          .whereType<PlayerSummary>()
          .toList(growable: false);
    }

    if (players == null || players.isEmpty) {
      return null;
    }

    // Second element (if exists) might contain additional data like hostPlayerId
    int? hostPlayerId;
    if (args.length > 1) {
      final secondArg = args[1];
      if (secondArg is Map) {
        final map = _parseMap(secondArg);
        hostPlayerId = map != null ? _toInt(map['hostPlayerId']) : null;
      } else {
        // If the second argument is directly an int, it's the hostPlayerId
        hostPlayerId = _toInt(secondArg);
      }
    }

    return RoomRosterEvent(players: players, hostPlayerId: hostPlayerId);
  }

  List<PlayerSummary>? _parsePlayerSummaryList(List<Object?>? args) {
    if (args == null || args.isEmpty) {
      return null;
    }

    final first = args.first;
    if (first is Iterable) {
      return first
          .map(_parsePlayerSummary)
          .whereType<PlayerSummary>()
          .toList(growable: false);
    }

    return null;
  }

  PlayerSummary? _parsePlayerSummary(Object? value) {
    final map = _parseMap(value);
    if (map == null) {
      return null;
    }

    final playerId = _toInt(map['playerId']);
    // Prioritize playerName from backend, fallback to displayName
    final name = map['playerName']?.toString() ?? map['displayName']?.toString();
    if (playerId == null || name == null || name.isEmpty) {
      return null;
    }

    return PlayerSummary(playerId: playerId, displayName: name);
  }

  int? _parseIntArg(List<Object?>? args) {
    if (args == null || args.isEmpty) {
      return null;
    }
    return _toInt(args.first);
  }

  JsonMap? _parseMap(Object? value) {
    if (value is JsonMap) {
      return value;
    }

    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('GameHubClient has been disposed.');
    }
  }
}

class PlayerMovementEvent {
  PlayerMovementEvent({required this.playerId, required this.payload});

  final int playerId;
  final JsonMap? payload;
}

class BombPlacedEvent {
  BombPlacedEvent({required this.playerId, required this.payload});

  final int playerId;
  final JsonMap? payload;
}

class ExplosionEvent {
  ExplosionEvent({required this.playerId, required this.payload});

  final int? playerId;
  final JsonMap? payload;
}

class ItemCollectedEvent {
  ItemCollectedEvent({required this.itemId, required this.playerId});

  final int itemId;
  final int playerId;
}

class GameEndedEvent {
  GameEndedEvent({
    required this.winnerId,
    required this.summary,
    this.winnerName,
    this.winnerRoomPosition,
  });

  final int? winnerId;
  final JsonMap? summary;
  final String? winnerName;
  final int? winnerRoomPosition;
}

class PlayerReadyEvent {
  PlayerReadyEvent({required this.playerId, required this.isReady});

  final int playerId;
  final bool isReady;
}

class GameStartEvent {
  GameStartEvent({
    required this.roomId,
    this.playerCharacters,
  });

  final int roomId;
  final JsonMap? playerCharacters; // Map of playerId -> characterIndex
}

class CharacterSelectedEvent {
  CharacterSelectedEvent({required this.playerId, required this.characterIndex});

  final int playerId;
  final int characterIndex;
}

class PlayerSummary {
  PlayerSummary({required this.playerId, required this.displayName});

  final int playerId;
  final String displayName;
}

class RoomRosterEvent {
  RoomRosterEvent({required this.players, this.hostPlayerId});

  final List<PlayerSummary> players;
  final int? hostPlayerId;
}
