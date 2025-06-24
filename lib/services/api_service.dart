import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const baseUrl = 'https://game-mind-api-959217497496.europe-west1.run.app';

  static Future<http.Response> selectRoster(int userId, List<int> selectedGameMinds) {
    return http.post(
      Uri.parse('$baseUrl/roster/select'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'selected_game_minds': selectedGameMinds,
      }),
    );
  }

  static Future<http.Response> joinLobby(int userId) {
    return http.post(
      Uri.parse('$baseUrl/match/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'game_name': 'dota2',
        'queue_type': 'blind',
        'format': 5,
      }),
    );
  }
}
