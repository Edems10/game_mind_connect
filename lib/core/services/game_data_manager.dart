import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/match_tick.dart';
import '../models/position.dart';

class GameDataManager extends ChangeNotifier {
  Map<String, List<Position>> heroPositions = {};
  Map<String, List<Position>> buildingPositions = {};
  Map<String, List<Position>> creepPositions = {};

  Map<String, Color> heroColors = {};
  Map<String, Color> buildingColors = {};
  Map<String, Color> creepColors = {};

  Map<String, int> buildingDeathTimes = {};
  Map<String, int> creepDeathTimes = {};

  int maxFrames = 0;
  bool isConnected = false;
  String? connectionError;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;

  void connectWebSocket(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));      isConnected = true;
      connectionError = null;

      _channel!.stream.listen(
        (data) {
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          connectionError = 'Connection error: $error';
          isConnected = false;
          notifyListeners();
        },
        onDone: () {
          isConnected = false;
          notifyListeners();
        },
      );

      _channel!.sink.add(jsonEncode({
        'type': 'connection_established',
        'client': 'game_map'
      }));

      _startHeartbeat();
      notifyListeners();
    } catch (e) {
      connectionError = 'Failed to connect: $e';
      isConnected = false;
      notifyListeners();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'heartbeat'}));
      }
    });
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final jsonData = jsonDecode(data);
      if (jsonData['type'] == 'heartbeat') {
        _channel!.sink.add(jsonEncode({'type': 'heartbeat_response'}));
      } else if (jsonData['type'] == 'match_tick') {
        _processTickData(MatchTick.fromJson(jsonData));
      }
    } catch (e) {
      print('Error processing WebSocket message: $e');
    }
  }

  void _processTickData(MatchTick tick) {
    final second = tick.second;
    final gameState = tick.gameState;

    gameState.heroes.forEach((heroName, heroData) {
      if (heroData.position != null) {
        heroPositions.putIfAbsent(heroName, () => []).add(heroData.position!);
        heroColors[heroName] = heroData.teamNum == 2
            ? const Color(0xFF2AC500)
            : const Color(0xFFC50000);
      }
    });

    gameState.buildings.forEach((buildingId, buildingData) {
      if (!buildingData.isAlive) {
        buildingDeathTimes[buildingId] = second;
        return;
      }
      if (buildingData.position != null) {
        buildingPositions.putIfAbsent(buildingId, () => []).add(buildingData.position!);
        buildingColors[buildingId] = buildingData.teamNum == 2
            ? const Color(0xFF2AC500)
            : const Color(0xFFC50000);
      }
    });

    gameState.creeps.forEach((creepId, creepData) {
      if (!creepData.isAlive) {
        creepDeathTimes[creepId] = second;
        return;
      }
      if (creepData.position != null) {
        creepPositions.putIfAbsent(creepId, () => []).add(creepData.position!);
        creepColors[creepId] = creepData.teamNum == 2
            ? const Color(0xFF2AC500)
            : const Color(0xFFC50000);
      }
    });

    if (second > maxFrames) {
      maxFrames = second;
    }

    notifyListeners();
  }

  Map<String, Map<String, Position>>? getPositionsAtFrame(int frame) {
    if (maxFrames == 0) return null;

    final heroPositionsAtFrame = <String, Position>{};
    final buildingPositionsAtFrame = <String, Position>{};
    final creepPositionsAtFrame = <String, Position>{};

    heroPositions.forEach((heroName, positions) {
      if (positions.length > frame) {
        heroPositionsAtFrame[heroName] = positions[frame];
      }
    });

    buildingPositions.forEach((buildingId, positions) {
      if (buildingDeathTimes[buildingId] != null &&
          buildingDeathTimes[buildingId]! <= frame) {
        return;
      }
      if (positions.length > frame) {
        buildingPositionsAtFrame[buildingId] = positions[frame];
      }
    });

    creepPositions.forEach((creepId, positions) {
      if (creepDeathTimes[creepId] != null &&
          creepDeathTimes[creepId]! <= frame) {
        return;
      }
      if (positions.length > frame) {
        creepPositionsAtFrame[creepId] = positions[frame];
      }
    });

    return {
      'heroes': heroPositionsAtFrame,
      'buildings': buildingPositionsAtFrame,
      'creeps': creepPositionsAtFrame,
    };
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
