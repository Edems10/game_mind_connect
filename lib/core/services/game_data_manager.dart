import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Timer? _dataStreamTimer;
  Map<String, dynamic>? _dummyData;
  List<String> _sortedTicks = [];
  int _currentTickIndex = 0;
  bool _isStreaming = false;

  int minTickOffset = 0;
  Map<String, dynamic>? dummyData;

  Future<void> connectWebSocket(String url) async {
    try {
      await _loadDummyData();
      isConnected = true;
      connectionError = null;
      notifyListeners();
    } catch (e) {
      connectionError = 'Failed to load dummy data: $e';
      isConnected = false;
      notifyListeners();
    }
  }

  Future<void> _loadDummyData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/dummy_data.json');
      _dummyData = jsonDecode(jsonString);
      
      // Extract all tick keys and sort them
      _sortedTicks = _dummyData!['combatLog'].keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      
      // Process all ticks to build the complete dataset
      _processAllTicks();
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load dummy data: $e');
    }
  }

  void _processAllTicks() {
    // Clear existing data
    heroPositions.clear();
    buildingPositions.clear();
    creepPositions.clear();
    heroColors.clear();
    buildingColors.clear();
    creepColors.clear();
    buildingDeathTimes.clear();
    creepDeathTimes.clear();
    maxFrames = 0;

    // Find minimum tick index across all entity types
    int minTick = 0;
    List<int> allTicks = [];
    if (_dummyData != null && _dummyData!.containsKey('heroes')) {
      allTicks.addAll((_dummyData!['heroes'] as Map<String, dynamic>).keys.map((k) => int.tryParse(k) ?? 0));
    }
    if (_dummyData != null && _dummyData!.containsKey('buildings')) {
      allTicks.addAll((_dummyData!['buildings'] as Map<String, dynamic>).keys.map((k) => int.tryParse(k) ?? 0));
    }
    if (_dummyData != null && _dummyData!.containsKey('creeps')) {
      allTicks.addAll((_dummyData!['creeps'] as Map<String, dynamic>).keys.map((k) => int.tryParse(k) ?? 0));
    }
    if (allTicks.isNotEmpty) {
      minTick = allTicks.reduce((a, b) => a < b ? a : b);
    }

    // Get all ticks in order
    final allTickSet = <int>{};
    if (_dummyData != null && _dummyData!.containsKey('heroes')) {
      allTickSet.addAll((_dummyData!['heroes'] as Map<String, dynamic>).keys.map((k) => int.tryParse(k) ?? 0));
    }
    if (_dummyData != null && _dummyData!.containsKey('buildings')) {
      allTickSet.addAll((_dummyData!['buildings'] as Map<String, dynamic>).keys.map((k) => int.tryParse(k) ?? 0));
    }
    if (_dummyData != null && _dummyData!.containsKey('creeps')) {
      allTickSet.addAll((_dummyData!['creeps'] as Map<String, dynamic>).keys.map((k) => int.tryParse(k) ?? 0));
    }
    final sortedTicks = allTickSet.toList()..sort();
    final maxListIdx = sortedTicks.isNotEmpty ? (sortedTicks.last - minTick) : 0;

    // HEROES
    final Map<String, Position?> heroLastPos = {};
    if (_dummyData != null && _dummyData!.containsKey('heroes')) {
      final heroesByTick = _dummyData!['heroes'] as Map<String, dynamic>;
      for (final tick in sortedTicks) {
        final tickKey = tick.toString();
        final listIdx = tick - minTick;
        final heroesAtTick = heroesByTick.containsKey(tickKey)
            ? heroesByTick[tickKey] as Map<String, dynamic>
            : <String, dynamic>{};
        for (final heroName in heroLastPos.keys.toSet().union(heroesAtTick.keys.toSet())) {
          final heroData = heroesAtTick[heroName] as Map<String, dynamic>?;
          if (heroData != null && heroData['position'] != null) {
            final pos = heroData['position'];
            final position = Position(
              x: (pos['x'] as num).toDouble(),
              y: (pos['y'] as num).toDouble(),
            );
            heroLastPos[heroName] = position;
            heroPositions.putIfAbsent(heroName, () => []);
            // Assign color only from tick -1
            if (tick == -1 && !heroColors.containsKey(heroName)) {
              final teamNum = heroData['teamNum'] ?? 0;
              heroColors[heroName] = teamNum == 2
                  ? const Color(0xFF2AC500)
                  : teamNum == 3
                      ? const Color(0xFFC50000)
                      : const Color(0xFF32FF6A);
            }
          }
          // Carry forward last known position
          if (heroLastPos[heroName] != null) {
            heroPositions.putIfAbsent(heroName, () => []);
            while (heroPositions[heroName]!.length < listIdx) {
              heroPositions[heroName]!.add(heroLastPos[heroName]!);
            }
            if (heroPositions[heroName]!.length == listIdx) {
              heroPositions[heroName]!.add(heroLastPos[heroName]!);
            } else {
              heroPositions[heroName]![listIdx] = heroLastPos[heroName]!;
            }
          }
        }
        if (listIdx > maxFrames) maxFrames = listIdx;
      }
    }

    // BUILDINGS
    final Map<String, Position?> buildingLastPos = {};
    final Map<String, bool> buildingDead = {};
    if (_dummyData != null && _dummyData!.containsKey('buildings')) {
      final buildingsByTick = _dummyData!['buildings'] as Map<String, dynamic>;
      for (final tick in sortedTicks) {
        final tickKey = tick.toString();
        final listIdx = tick - minTick;
        final buildingsAtTick = buildingsByTick.containsKey(tickKey)
            ? buildingsByTick[tickKey] as Map<String, dynamic>
            : <String, dynamic>{};
        for (final buildingName in buildingLastPos.keys.toSet().union(buildingsAtTick.keys.toSet())) {
          if (buildingDead[buildingName] == true) continue;
          final buildingData = buildingsAtTick[buildingName] as Map<String, dynamic>?;
          if (buildingData != null && buildingData['position'] != null) {
            final pos = buildingData['position'];
            final position = Position(
              x: (pos['x'] as num).toDouble(),
              y: (pos['y'] as num).toDouble(),
            );
            buildingLastPos[buildingName] = position;
            buildingPositions.putIfAbsent(buildingName, () => []);
            // Assign color only from tick -1
            if (tick == -1 && !buildingColors.containsKey(buildingName)) {
              final teamNum = buildingData['teamNum'] ?? 0;
              buildingColors[buildingName] = teamNum == 2
                  ? const Color(0xFF2AC500)
                  : teamNum == 3
                      ? const Color(0xFFC50000)
                      : const Color(0xFF32FF6A);
            }
            final lifeState = buildingData['lifeState'] ?? 0;
            if (lifeState != 0) {
              buildingDead[buildingName] = true;
              buildingDeathTimes[buildingName] = listIdx;
            }
          }
          // Carry forward last known position
          if (buildingLastPos[buildingName] != null && buildingDead[buildingName] != true) {
            buildingPositions.putIfAbsent(buildingName, () => []);
            while (buildingPositions[buildingName]!.length < listIdx) {
              buildingPositions[buildingName]!.add(buildingLastPos[buildingName]!);
            }
            if (buildingPositions[buildingName]!.length == listIdx) {
              buildingPositions[buildingName]!.add(buildingLastPos[buildingName]!);
            } else {
              buildingPositions[buildingName]![listIdx] = buildingLastPos[buildingName]!;
            }
          }
        }
        if (listIdx > maxFrames) maxFrames = listIdx;
      }
    }

    // CREEPS
    final Map<String, Position?> creepLastPos = {};
    final Map<String, bool> creepDead = {};
    if (_dummyData != null && _dummyData!.containsKey('creeps')) {
      final creepsByTick = _dummyData!['creeps'] as Map<String, dynamic>;
      for (final tick in sortedTicks) {
        final tickKey = tick.toString();
        final listIdx = tick - minTick;
        final creepsAtTick = creepsByTick.containsKey(tickKey)
            ? creepsByTick[tickKey] as Map<String, dynamic>
            : <String, dynamic>{};
        for (final creepName in creepLastPos.keys.toSet().union(creepsAtTick.keys.toSet())) {
          if (creepDead[creepName] == true) continue;
          final creepData = creepsAtTick[creepName] as Map<String, dynamic>?;
          if (creepData != null && creepData['position'] != null) {
            final pos = creepData['position'];
            final position = Position(
              x: (pos['x'] as num).toDouble(),
              y: (pos['y'] as num).toDouble(),
            );
            creepLastPos[creepName] = position;
            creepPositions.putIfAbsent(creepName, () => []);
            // Assign color only from tick -1
            if (tick == -1 && !creepColors.containsKey(creepName)) {
              final teamNum = creepData['teamNum'] ?? 0;
              creepColors[creepName] = teamNum == 2
                  ? const Color(0xFF2AC500)
                  : teamNum == 3
                      ? const Color(0xFFC50000)
                      : const Color(0xFF32FF6A);
            }
            final lifeState = creepData['lifeState'] ?? 0;
            if (lifeState != 0) {
              creepDead[creepName] = true;
              creepDeathTimes[creepName] = listIdx;
            }
          }
          // Carry forward last known position
          if (creepLastPos[creepName] != null && creepDead[creepName] != true) {
            creepPositions.putIfAbsent(creepName, () => []);
            while (creepPositions[creepName]!.length < listIdx) {
              creepPositions[creepName]!.add(creepLastPos[creepName]!);
            }
            if (creepPositions[creepName]!.length == listIdx) {
              creepPositions[creepName]!.add(creepLastPos[creepName]!);
            } else {
              creepPositions[creepName]![listIdx] = creepLastPos[creepName]!;
            }
          }
        }
        if (listIdx > maxFrames) maxFrames = listIdx;
      }
    }
    // Store minTick for use in getPositionsAtFrame
    minTickOffset = minTick;
    dummyData = _dummyData;
  }

  void startDataStream() {
    if (_isStreaming) return;
    
    _isStreaming = true;
    _currentTickIndex = 0;
    
    _dataStreamTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentTickIndex < _sortedTicks.length) {
        final tickKey = _sortedTicks[_currentTickIndex];
        final tickData = _dummyData!['combatLog'][tickKey];
        
        // Process this tick's data
        final second = int.parse(tickKey);
        _processTickData(tickData, second);
        
        _currentTickIndex++;
        
        if (_currentTickIndex >= _sortedTicks.length) {
          // Loop back to start
          _currentTickIndex = 0;
        }
      }
    });
  }

  void _processTickData(Map<String, dynamic> tickData, int second) {
    // This method simulates the real-time processing of tick data
    // In this implementation, we're just notifying listeners to update the UI
    notifyListeners();
  }

  void stopDataStream() {
    _dataStreamTimer?.cancel();
    _dataStreamTimer = null;
    _isStreaming = false;
  }

  @override
  Map<String, Map<String, Position>>? getPositionsAtFrame(int frame) {
    if (maxFrames == 0) return null;
    final adjustedFrame = frame;
    final heroPositionsAtFrame = <String, Position>{};
    final buildingPositionsAtFrame = <String, Position>{};
    final creepPositionsAtFrame = <String, Position>{};

    heroPositions.forEach((heroName, positions) {
      if (positions.length > adjustedFrame) {
        heroPositionsAtFrame[heroName] = positions[adjustedFrame];
      }
    });

    buildingPositions.forEach((buildingId, positions) {
      if (buildingDeathTimes[buildingId] != null &&
          buildingDeathTimes[buildingId]! <= adjustedFrame) {
        return;
      }
      if (positions.length > adjustedFrame) {
        buildingPositionsAtFrame[buildingId] = positions[adjustedFrame];
      }
    });

    creepPositions.forEach((creepId, positions) {
      if (creepDeathTimes[creepId] != null &&
          creepDeathTimes[creepId]! <= adjustedFrame) {
        return;
      }
      if (positions.length > adjustedFrame) {
        creepPositionsAtFrame[creepId] = positions[adjustedFrame];
      }
    });

    return {
      'heroes': heroPositionsAtFrame,
      'buildings': buildingPositionsAtFrame,
      'creeps': creepPositionsAtFrame,
    };
  }

  void disconnect() {
    stopDataStream();
    isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
