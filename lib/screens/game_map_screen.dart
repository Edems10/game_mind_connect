import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/services/game_data_manager.dart';
import '../widgets/notification_widget.dart';
import '../features/game_map/game_map_widget.dart';


class GameMapScreen extends StatefulWidget {
  const GameMapScreen({super.key});

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen> {
  final GameDataManager _gameDataManager = GameDataManager();
  String _notification = '';
  String? _matchId;

  // HTTP POSTs for roster selection
  Future<void> selectRoster(int userId, List<int> selectedGameMinds) async {
    final response = await ApiService.selectRoster(userId, selectedGameMinds);
    setState(() {
      _notification = 'Select Roster User $userId: ${response.body}';
    });
  }

  // HTTP POSTs for joining match
  Future<void> joinMatch(int userId) async {
    final response = await ApiService.joinLobby(userId);
    setState(() {
      _notification = 'Join Match User $userId: ${response.body}';
      final data = response.body;
      final matchId = RegExp(r'"match_id"\s*:\s*"([^"]+)"').firstMatch(data)?.group(1);
      if (matchId != null) {
        _matchId = matchId;
      }
    });
  }

  // Connect to WebSocket using matchId
  Future<void> connectToWebSocket() async {
    if (_matchId == null) {
      setState(() {
        _notification = 'No match_id available. Join match first!';
      });
      return;
    }
    try {
      await _gameDataManager.connectWebSocket('dummy_url');
      setState(() {
        _notification = 'Dummy data loaded successfully for match $_matchId';
      });
    } catch (e) {
      setState(() {
        _notification = 'Failed to load dummy data: $e';
      });
    }
  }

  @override
  void dispose() {
    _gameDataManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // You can use your GameMapWidget here and pass _gameDataManager to it
    return Scaffold(
      appBar: AppBar(title: const Text('Dota 2 Game Map')),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => selectRoster(1, [1, 1, 1, 1, 1]),
                  child: const Text('Select Roster User 1'),
                ),
                ElevatedButton(
                  onPressed: () => selectRoster(2, [2, 2, 2, 2, 2]),
                  child: const Text('Select Roster User 2'),
                ),
                ElevatedButton(
                  onPressed: () => joinMatch(1),
                  child: const Text('Join Match User 1'),
                ),
                ElevatedButton(
                  onPressed: () => joinMatch(2),
                  child: const Text('Join Match User 2'),
                ),
                ElevatedButton(
                  onPressed: connectToWebSocket,
                  child: const Text('Load Dummy Data'),
                ),
              ],
            ),
          ),
          NotificationWidget(message: _notification),
          const SizedBox(height: 10),
          // The map and playback UI
          Expanded(child: GameMapWidget(gameDataManager: _gameDataManager)),
        ],
      ),
    );
  }
}
