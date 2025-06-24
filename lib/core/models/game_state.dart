import 'hero_data.dart';
import 'building_data.dart';
import 'creep_data.dart';

class GameState {
  final Map<String, HeroData> heroes;
  final Map<String, BuildingData> buildings;
  final Map<String, CreepData> creeps;

  GameState({
    required this.heroes,
    required this.buildings,
    required this.creeps,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      heroes: (json['heroes'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, HeroData.fromJson(value)),
      ) ?? {},
      buildings: (json['buildings'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, BuildingData.fromJson(value)),
      ) ?? {},
      creeps: (json['creeps'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, CreepData.fromJson(value)),
      ) ?? {},
    );
  }
}
