import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/notification_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _notification = '';
  String? _matchId;
  String _wsMessage = '';
  final WebSocketService _webSocketService = WebSocketService();

  Future<void> selectRoster(int userId, List<int> selectedGameMinds) async {
    try {
      final response = await ApiService.selectRoster(userId, selectedGameMinds);
      setState(() {
        if (response.statusCode == 200) {
          _notification = 'Select Roster User $userId: ${response.body}';
        } else {
          _notification = 'Failed to select roster for user $userId. Status: ${response.statusCode}';
        }
      });
    } catch (e) {
      setState(() {
        _notification = 'Error: $e';
      });
    }
  }

  Future<void> joinLobby(int userId) async {
    try {
      final response = await ApiService.joinLobby(userId);
      setState(() {
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['match_id'] != null) {
            _matchId = responseData['match_id'];
          }
          _notification = 'Join Lobby User $userId: ${response.body}';
        } else {
          _notification = 'Failed to join lobby for user $userId. Status: ${response.statusCode}';
        }
      });
    } catch (e) {
      setState(() {
        _notification = 'Error: $e';
      });
    }
  }

  void joinWebSocket() {
    if (_matchId == null) {
      setState(() {
        _notification = 'No match_id available. Join lobby first!';
      });
      return;
    }
    
    _webSocketService.connect(_matchId!);
    _webSocketService.stream.listen(
      (message) => setState(() => _wsMessage = message),
      onError: (error) => setState(() => _wsMessage = 'WebSocket error: $error'),
      onDone: () => setState(() => _wsMessage = 'WebSocket connection closed'),
    );

    setState(() => _notification = 'WebSocket connected to match $_matchId');
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Mind'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => selectRoster(1, [1, 1, 1, 1, 1]),
              child: const Text('Select Roster User 1'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => selectRoster(2, [2, 2, 2, 2, 2]),
              child: const Text('Select Roster User 2'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => joinLobby(1),
              child: const Text('Join Lobby User 1'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => joinLobby(2),
              child: const Text('Join Lobby User 2'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: joinWebSocket,
              child: const Text('Join WebSocket'),
            ),
            const SizedBox(height: 30),
            NotificationWidget(message: _notification),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'WebSocket Stream: $_wsMessage',
                style: const TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
