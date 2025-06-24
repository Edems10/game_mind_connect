import 'position.dart';

class CreepData {
  final int teamNum;
  final Position? position;
  final bool isAlive;

  CreepData({required this.teamNum, this.position, this.isAlive = true});

  factory CreepData.fromJson(Map<String, dynamic> json) {
    return CreepData(
      teamNum: json['teamNum'] ?? 2,
      position: json['position'] != null ? Position.fromJson(json['position']) : null,
      isAlive: json['is_alive'] ?? true,
    );
  }
}
