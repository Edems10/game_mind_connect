import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/game_data_manager.dart';

Color getTeamColor(int? teamNum) {
  if (teamNum == 2) return const Color(0xFF2AC500);
  if (teamNum == 3) return const Color(0xFFC50000);
  return const Color.fromARGB(255, 255, 173, 50);
}

class GameMapWidget extends StatefulWidget {
  final GameDataManager gameDataManager;
  const GameMapWidget({super.key, required this.gameDataManager});

  @override
  State<GameMapWidget> createState() => _GameMapWidgetState();
}

class _GameMapWidgetState extends State<GameMapWidget> {
  int _currentFrame = 0;
  bool _isPlaying = false;
  double _currentPlaybackSpeed = 1.0;
  Timer? _animationTimer;

  final List<double> _playbackSpeeds = [0.5, 1.0, 2.0, 4.0, 8.0];

  String? _hoveredHero;
  Offset _tooltipPosition = Offset.zero;
  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.gameDataManager.addListener(_onGameDataChanged);
  }

  void _onGameDataChanged() {
    setState(() {});
  }

  void _togglePlay() {
    if (widget.gameDataManager.maxFrames == 0) return;

    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    });
  }

  void _startAnimation() {
    _animationTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _currentPlaybackSpeed).round()),
      (timer) {
        setState(() {
          _currentFrame = (_currentFrame + 1) % widget.gameDataManager.maxFrames;
          if (_currentFrame == widget.gameDataManager.maxFrames - 1) {
            _stopAnimation();
          }
        });
      },
    );
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
    setState(() {
      _isPlaying = false;
    });
  }

  void _resetAnimation() {
    _stopAnimation();
    setState(() {
      _currentFrame = 0;
    });
  }

  void _setPlaybackSpeed(double speed) {
    setState(() {
      _currentPlaybackSpeed = speed;
      if (_isPlaying) {
        _stopAnimation();
        _startAnimation();
      }
    });
  }

  // Updated conversion functions that take map size as parameter
  double _convertX(double y, double mapSize) {
    return ((y - 6650) / 19000) * mapSize;
  }

  double _convertY(double x, double mapSize) {
    return mapSize - ((x - 6700) / 19500) * mapSize;
  }

  @override
  Widget build(BuildContext context) {
    final currentPositions = widget.gameDataManager.getPositionsAtFrame(_currentFrame);
    final hasGameData = widget.gameDataManager.maxFrames > 0;

    // Helper to assign and store color if not present
    Color ensureColor(Map<String, Color> colorMap, String id, int? teamNum) {
      if (!colorMap.containsKey(id) && teamNum != null) {
        colorMap[id] = getTeamColor(teamNum);
      }
      return colorMap[id] ?? getTeamColor(teamNum);
    }

    return Column(
      children: [
        // Controls at the top
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            children: [
              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: hasGameData ? _togglePlay : null,
                    child: Text(_isPlaying ? 'Pause' : 'Play'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: hasGameData ? _resetAnimation : null,
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<double>(
                    onSelected: _setPlaybackSpeed,
                    itemBuilder: (context) => _playbackSpeeds
                        .map((speed) => PopupMenuItem(
                              value: speed,
                              child: Text('${speed}x'),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Speed ${_currentPlaybackSpeed}x'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Frame Slider
              if (hasGameData) ...[
                Slider(
                  value: _currentFrame.toDouble(),
                  min: 0,
                  max: (widget.gameDataManager.maxFrames - 1).toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _currentFrame = value.round();
                      _stopAnimation();
                    });
                  },
                ),
                Text(
                  'Game Time: ${(_currentFrame / 60).floor()}:${(_currentFrame % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),

        // Game Map - Now responsive and square
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the size to make it square, using the smaller dimension
              final availableWidth = constraints.maxWidth;
              final availableHeight = constraints.maxHeight;
              final mapSize = availableWidth < availableHeight ? availableWidth : availableHeight;
              
              // Calculate scaling factors for unit sizes
              final baseMapSize = 800.0; // Original map size
              final scaleFactor = mapSize / baseMapSize;
              
              // Scale unit sizes based on map size
              final buildingSize = 26 * scaleFactor;
              final creepSize = 10 * scaleFactor;
              final heroSize = 30 * scaleFactor;
              final heroFontSize = 12 * scaleFactor;

              return Center(
                child: SizedBox(
                  width: mapSize,
                  height: mapSize,
                  child: Stack(
                    key: _mapKey,
                    children: [
                      // Background Map
                      Container(
                        width: mapSize,
                        height: mapSize,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          image: const DecorationImage(
                            image: AssetImage('assets/map/dota_map.webp'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Game Elements
                      if (currentPositions != null) ...[
                        // Buildings
                        ...(() {
                          final buildingsToRender = <Widget>[];
                          final buildingsByTick = widget.gameDataManager.dummyData?['buildings'] as Map<String, dynamic>?;
                          if (buildingsByTick != null) {
                            // Collect all building IDs that have ever appeared up to this frame
                            final Set<String> allBuildingIds = {};
                            for (int t = 0; t <= _currentFrame; t++) {
                              final tickKey = (t + widget.gameDataManager.minTickOffset).toString();
                              final tickBuildings = buildingsByTick[tickKey] as Map<String, dynamic>?;
                              if (tickBuildings != null) {
                                allBuildingIds.addAll(tickBuildings.keys);
                              }
                            }
                            for (final buildingId in allBuildingIds) {
                              // Look back for last known state up to current frame
                              int? teamNum;
                              Offset? lastPos;
                              bool isDeleted = false;
                              for (int t = 0; t <= _currentFrame; t++) {
                                final tickKey = (t + widget.gameDataManager.minTickOffset).toString();
                                final tickBuildings = buildingsByTick[tickKey] as Map<String, dynamic>?;
                                final buildingData = tickBuildings != null ? tickBuildings[buildingId] as Map<String, dynamic>? : null;
                                if (buildingData != null) {
                                  if (buildingData['deleted'] == true) {
                                    isDeleted = true;
                                  }
                                  if (buildingData['teamNum'] != null && !widget.gameDataManager.buildingColors.containsKey(buildingId)) {
                                    teamNum = buildingData['teamNum'] as int?;
                                    widget.gameDataManager.buildingColors[buildingId] = getTeamColor(teamNum);
                                  }
                                  if (buildingData['position'] != null) {
                                    final pos = buildingData['position'];
                                    lastPos = Offset((pos['x'] as num).toDouble(), (pos['y'] as num).toDouble());
                                  }
                                }
                              }
                              if (!isDeleted && lastPos != null) {
                                final color = widget.gameDataManager.buildingColors[buildingId] ?? getTeamColor(teamNum);
                                buildingsToRender.add(Positioned(
                                  left: _convertX(lastPos.dy, mapSize) - buildingSize / 2,
                                  top: _convertY(lastPos.dx, mapSize) - buildingSize / 2,
                                  child: Container(
                                    width: buildingSize,
                                    height: buildingSize,
                                    decoration: BoxDecoration(
                                      color: color,
                                      border: Border.all(color: Colors.black, width: 1.5 * scaleFactor),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/LightRook.webp',
                                        width: buildingSize * 0.7,
                                        height: buildingSize * 0.7,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ));
                              }
                            }
                          }
                          return buildingsToRender;
                        })(),

                        // Creeps
                        ...(() {
                          final creepsToRender = <Widget>[];
                          final creepsByTick = widget.gameDataManager.dummyData?['creeps'] as Map<String, dynamic>?;
                          if (creepsByTick != null) {
                            // Collect all creep IDs that have ever appeared up to this frame
                            final Set<String> allCreepIds = {};
                            for (int t = 0; t <= _currentFrame; t++) {
                              final tickKey = (t + widget.gameDataManager.minTickOffset).toString();
                              final tickCreeps = creepsByTick[tickKey] as Map<String, dynamic>?;
                              if (tickCreeps != null) {
                                allCreepIds.addAll(tickCreeps.keys);
                              }
                            }
                            for (final creepId in allCreepIds) {
                              // Look back for last known state up to current frame
                              int? teamNum;
                              Offset? lastPos;
                              bool isDeleted = false;
                              for (int t = 0; t <= _currentFrame; t++) {
                                final tickKey = (t + widget.gameDataManager.minTickOffset).toString();
                                final tickCreeps = creepsByTick[tickKey] as Map<String, dynamic>?;
                                final creepData = tickCreeps != null ? tickCreeps[creepId] as Map<String, dynamic>? : null;
                                if (creepData != null) {
                                  if (creepData['deleted'] == true) {
                                    isDeleted = true;
                                  }
                                  if (creepData['teamNum'] != null && !widget.gameDataManager.creepColors.containsKey(creepId)) {
                                    teamNum = creepData['teamNum'] as int?;
                                    widget.gameDataManager.creepColors[creepId] = getTeamColor(teamNum);
                                  }
                                  if (creepData['position'] != null) {
                                    final pos = creepData['position'];
                                    lastPos = Offset((pos['x'] as num).toDouble(), (pos['y'] as num).toDouble());
                                  }
                                }
                              }
                              if (!isDeleted && lastPos != null) {
                                final color = widget.gameDataManager.creepColors[creepId] ?? getTeamColor(teamNum);
                                creepsToRender.add(Positioned(
                                  left: _convertX(lastPos.dy, mapSize) - creepSize / 2,
                                  top: _convertY(lastPos.dx, mapSize) - creepSize / 2,
                                  child: Container(
                                    width: creepSize,
                                    height: creepSize,
                                    decoration: BoxDecoration(
                                      color: color,
                                      border: Border.all(color: Colors.black, width: 1 * scaleFactor),
                                    ),
                                  ),
                                ));
                              }
                            }
                          }
                          return creepsToRender;
                        })(),

                        // Heroes
                        ...currentPositions['heroes']!.entries.map((entry) {
                          final hero = entry.value;
                          int? teamNum;
                          final tickKey = (_currentFrame + widget.gameDataManager.minTickOffset).toString();
                          final heroesByTick = widget.gameDataManager.dummyData?['heroes'] as Map<String, dynamic>?;
                          if (heroesByTick != null && heroesByTick.containsKey(tickKey)) {
                            final heroData = heroesByTick[tickKey][entry.key] as Map<String, dynamic>?;
                            if (heroData != null && heroData['teamNum'] != null) {
                              teamNum = heroData['teamNum'] as int?;
                            }
                          }
                          final color = ensureColor(widget.gameDataManager.heroColors, entry.key, teamNum);
                          final heroName = entry.key;
                          final heroDisplayName = heroName.replaceAll('CDOTA_Unit_Hero_', '');
                          Widget heroIconWidget;
                          try {
                            heroIconWidget = Image.asset(
                              'assets/minimap_icons/$heroName.png',
                              width: heroSize * 0.9,
                              height: heroSize * 0.9,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // fallback to single letter if icon is missing
                                return Center(
                                  child: Text(
                                    heroDisplayName.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: heroFontSize,
                                    ),
                                  ),
                                );
                              },
                            );
                          } catch (_) {
                            heroIconWidget = Center(
                              child: Text(
                                heroDisplayName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: heroFontSize,
                                ),
                              ),
                            );
                          }
                          return Positioned(
                            left: _convertX(hero.y, mapSize) - heroSize / 2,
                            top: _convertY(hero.x, mapSize) - heroSize / 2,
                            child: MouseRegion(
                              onEnter: (event) {
                                final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
                                if (box != null) {
                                  final local = box.globalToLocal(event.position);
                                  setState(() {
                                    _hoveredHero = heroDisplayName;
                                    _tooltipPosition = _clampTooltip(local, mapSize);
                                  });
                                }
                              },
                              onHover: (event) {
                                final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
                                if (box != null) {
                                  final local = box.globalToLocal(event.position);
                                  setState(() {
                                    _tooltipPosition = _clampTooltip(local, mapSize);
                                  });
                                }
                              },
                              onExit: (event) {
                                setState(() {
                                  _hoveredHero = null;
                                });
                              },
                              child: GestureDetector(
                                onTapDown: (details) {
                                  final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
                                  if (box != null) {
                                    final local = box.globalToLocal(details.globalPosition);
                                    setState(() {
                                      _hoveredHero = heroDisplayName;
                                      _tooltipPosition = _clampTooltip(local, mapSize);
                                    });
                                  }
                                },
                                onTapUp: (details) {
                                  setState(() {
                                    _hoveredHero = null;
                                  });
                                },
                                child: Container(
                                  width: heroSize,
                                  height: heroSize,
                                  decoration: BoxDecoration(
                                    color: color,
                                    border: Border.all(color: Colors.black, width: 1.5 * scaleFactor),
                                    shape: BoxShape.circle,
                                  ),
                                  child: heroIconWidget,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],

                      // Hero Tooltip
                      if (_hoveredHero != null)
                        Positioned(
                          left: _tooltipPosition.dx + 10,
                          top: _tooltipPosition.dy + 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _hoveredHero!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                      // No Data Overlay
                      if (!hasGameData)
                        Container(
                          width: mapSize,
                          height: mapSize,
                          color: Colors.white.withOpacity(0.7),
                          child: Center(
                            child: Container(
                              padding: EdgeInsets.all(20 * scaleFactor),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8 * scaleFactor),
                              ),
                              child: Text(
                                widget.gameDataManager.isConnected
                                    ? 'Waiting for game data...'
                                    : 'Connect to WebSocket to receive game data',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16 * scaleFactor,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Connection Status at the bottom
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Connection Status
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: widget.gameDataManager.isConnected
                      ? Colors.green[100]
                      : Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.gameDataManager.isConnected
                      ? 'Connected'
                      : widget.gameDataManager.connectionError ?? 'Disconnected',
                  style: TextStyle(
                    color: widget.gameDataManager.isConnected
                        ? Colors.green[800]
                        : Colors.red[800],
                  ),
                ),
              ),

              // Live Indicator
              if (widget.gameDataManager.isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Live',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Offset _clampTooltip(Offset pos, double mapSize) {
    // Clamp tooltip to stay within the map area
    const double tooltipWidth = 80;
    const double tooltipHeight = 28;
    double dx = pos.dx;
    double dy = pos.dy;
    if (dx + tooltipWidth > mapSize) dx = mapSize - tooltipWidth;
    if (dy + tooltipHeight > mapSize) dy = mapSize - tooltipHeight;
    if (dx < 0) dx = 0;
    if (dy < 0) dy = 0;
    return Offset(dx, dy);
  }

  @override
  void dispose() {
    widget.gameDataManager.removeListener(_onGameDataChanged);
    _animationTimer?.cancel();
    super.dispose();
  }
}
