import 'position.dart';

class HeroData {
  final int teamNum;
  final Position? position;

  HeroData({required this.teamNum, this.position});

  factory HeroData.fromJson(Map<String, dynamic> json) {
    return HeroData(
      teamNum: json['teamNum'] ?? 2,
      position: json['position'] != null ? Position.fromJson(json['position']) : null,
    );
  }
}
