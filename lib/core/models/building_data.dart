import 'position.dart';

class BuildingData {
  final int teamNum;
  final Position? position;
  final bool isAlive;

  BuildingData({required this.teamNum, this.position, this.isAlive = true});

  factory BuildingData.fromJson(Map<String, dynamic> json) {
    return BuildingData(
      teamNum: json['teamNum'] ?? 2,
      position: json['position'] != null ? Position.fromJson(json['position']) : null,
      isAlive: json['is_alive'] ?? true,
    );
  }
}
