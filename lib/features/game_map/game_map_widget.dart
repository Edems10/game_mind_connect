import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/game_data_manager.dart';

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

  double _convertX(double y) {
    return ((y - 6650) / 19000) * 800;
  }

  double _convertY(double x) {
    return 800 - ((x - 6700) / 19500) * 800;
  }

  @override
  Widget build(BuildContext context) {
    final currentPositions = widget.gameDataManager.getPositionsAtFrame(_currentFrame);
    final hasGameData = widget.gameDataManager.maxFrames > 0;

    return Column(
      children: [
        // Controls
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
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
              const SizedBox(height: 12),

              // Playback Controls
              Row(
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

        // Game Map
        Expanded(
          child: SizedBox(
            width: 800,
            height: 800,
            child: Stack(
              children: [
                // Background Map
                Container(
                  width: 800,
                  height: 800,
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
                  ...currentPositions['buildings']!.entries.map((entry) {
                    final building = entry.value;
                    final color = widget.gameDataManager.buildingColors[entry.key] ?? Colors.grey;

                    return Positioned(
                      left: _convertX(building.y) - 13,
                      top: _convertY(building.x) - 13,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          border: Border.all(color: Colors.black, width: 1.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),

                  // Creeps
                  ...currentPositions['creeps']!.entries.map((entry) {
                    final creep = entry.value;
                    final color = widget.gameDataManager.creepColors[entry.key] ?? Colors.grey;

                    return Positioned(
                      left: _convertX(creep.y) - 5,
                      top: _convertY(creep.x) - 5,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          border: Border.all(color: Colors.black),
                        ),
                      ),
                    );
                  }),

                  // Heroes
                  ...currentPositions['heroes']!.entries.map((entry) {
                    final hero = entry.value;
                    final color = widget.gameDataManager.heroColors[entry.key] ?? Colors.grey;
                    final heroName = entry.key.replaceAll('CDOTA_Unit_Hero_', '');

                    return Positioned(
                      left: _convertX(hero.y) - 15,
                      top: _convertY(hero.x) - 15,
                      child: GestureDetector(
                        onTapDown: (details) {
                          setState(() {
                            _hoveredHero = heroName;
                            _tooltipPosition = details.globalPosition;
                          });
                        },
                        onTapUp: (details) {
                          setState(() {
                            _hoveredHero = null;
                          });
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(color: Colors.black, width: 1.5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              heroName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
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

                // Connection Indicator
                if (widget.gameDataManager.isConnected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
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
                  ),

                // No Data Overlay
                if (!hasGameData)
                  Container(
                    width: 800,
                    height: 800,
                    color: Colors.white.withOpacity(0.7),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.gameDataManager.isConnected
                              ? 'Waiting for game data...'
                              : 'Connect to WebSocket to receive game data',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.gameDataManager.removeListener(_onGameDataChanged);
    _animationTimer?.cancel();
    super.dispose();
  }
}
