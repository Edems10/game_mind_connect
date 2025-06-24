import 'game_state.dart';

class MatchTick {
  final String type;
  final int second;
  final String matchId;
  final GameState gameState;

  MatchTick({
    required this.type,
    required this.second,
    required this.matchId,
    required this.gameState,
  });

  factory MatchTick.fromJson(Map<String, dynamic> json) {
    return MatchTick(
      type: json['type'] ?? '',
      second: json['second'] ?? 0,
      matchId: json['match_id'] ?? '',
      gameState: GameState.fromJson(json['game_state'] ?? {}),
    );
  }
}
