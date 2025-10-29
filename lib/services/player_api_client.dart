import 'dart:convert';

import 'package:http/http.dart' as http;

class RoomInfo {
  final int id;
  final String name;
  final String joinCode;
  final int maxPlayers;

  const RoomInfo({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.maxPlayers,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    final idValue = json['roomId'] ?? json['id'] ?? 0;
    final nameValue = json['roomName'] ?? json['name'] ?? '';
    final codeValue = json['joinCode'] ?? '';
    final maxPlayersValue = json['maxPlayers'] ?? 0;
    return RoomInfo(
      id: parseInt(idValue),
      name: nameValue.toString(),
      joinCode: codeValue.toString().toUpperCase(),
      maxPlayers: parseInt(maxPlayersValue),
    );
  }

  static int parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class RoomJoinResult {
  final RoomInfo room;
  final int playerId;
  final String playerName;

  const RoomJoinResult({
    required this.room,
    required this.playerId,
    required this.playerName,
  });

  factory RoomJoinResult.fromJson(Map<String, dynamic> json) {
    return RoomJoinResult(
      room: RoomInfo.fromJson(json),
      playerId: RoomInfo.parseInt(json['playerId'] ?? 0),
      playerName: json['playerName']?.toString() ?? 'Player',
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? innerError;

  const ApiException(this.message, {this.statusCode, this.innerError});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class PlayerApiClient {
  PlayerApiClient({required String baseUrl})
    : _baseUri = _normalizeBaseUrl(baseUrl);

  final Uri _baseUri;

  static Uri _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Must not be empty');
    }
    final uri = Uri.parse(trimmed);
    if (uri.hasScheme) {
      return uri;
    }
    return Uri.parse('http://$trimmed');
  }

  Future<RoomJoinResult> hostRoom({
    required String displayName,
    String? roomName,
    int maxPlayers = 4,
  }) async {
    final client = http.Client();
    try {
      final trimmedName = roomName?.trim() ?? '';
      final effectiveName = trimmedName.isEmpty
          ? 'Room ${DateTime.now().millisecondsSinceEpoch % 1000}'
          : trimmedName;
      final clampedPlayers = maxPlayers.clamp(2, 8).toInt();

      print('Attempting to create room at: ${_resolve('/api/rooms')}');
      print('Request body: roomName=$effectiveName, maxPlayers=$clampedPlayers, hostName=${displayName.trim()}');

      final response = await client.post(
        _resolve('/api/rooms'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'roomName': effectiveName,
          'maxPlayers': clampedPlayers,
          'hostName': displayName.trim(),
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw ApiException(
            'Connection timeout. Please check your server URL and ensure the server is running.',
            statusCode: 408,
          );
        },
      );

      print('Room creation response status: ${response.statusCode}');
      print('Room creation response body: ${response.body}');

      if (response.statusCode == 201) {
        return RoomJoinResult.fromJson(_decodeJson(response.body));
      }

      throw ApiException(
        response.body.isNotEmpty
            ? response.body
            : 'Failed to create room (status ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } finally {
      client.close();
    }
  }

  Future<RoomJoinResult> joinRoomByCode({
    required String joinCode,
    required String displayName,
  }) async {
    final client = http.Client();
    try {
      final normalizedCode = joinCode.trim().toUpperCase();
      if (normalizedCode.length != 3) {
        throw ApiException('Join code must be three characters.');
      }

      final response = await client.post(
        _resolve('/api/rooms/join-by-code'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'joinCode': normalizedCode,
          'displayName': displayName.trim(),
        }),
      );

      if (response.statusCode == 200) {
        return RoomJoinResult.fromJson(_decodeJson(response.body));
      }

      if (response.statusCode == 404) {
        throw ApiException(
          'Room code not found or inactive.',
          statusCode: response.statusCode,
        );
      }

      if (response.statusCode == 400) {
        throw ApiException(
          response.body.isNotEmpty ? response.body : 'Unable to join room.',
          statusCode: response.statusCode,
        );
      }

      throw ApiException(
        'Failed to join room (status ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('Unexpected response from server.');
  }

  Uri _resolve(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.resolve(normalizedPath);
  }
}
