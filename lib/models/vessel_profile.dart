// vessel_profile.dart
import 'loading_condition.dart';

class VesselProfile {
  final String name;
  final double length;
  final double beam;
  final double depth;
  final List<LoadingCondition> loadingConditions;

  VesselProfile({
    required this.name,
    required this.length,
    required this.beam,
    required this.depth,
    List<LoadingCondition>? loadingConditions,
  }) : loadingConditions = loadingConditions ?? [];

  VesselProfile copyWith({
    String? name,
    double? length,
    double? beam,
    double? depth,
    List<LoadingCondition>? loadingConditions,
  }) {
    return VesselProfile(
      name: name ?? this.name,
      length: length ?? this.length,
      beam: beam ?? this.beam,
      depth: depth ?? this.depth,
      loadingConditions: loadingConditions ?? this.loadingConditions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'length': length,
      'beam': beam,
      'depth': depth,
      'loadingConditions': loadingConditions.map((lc) => lc.toMap()).toList(),
    };
  }

  factory VesselProfile.fromMap(Map<String, dynamic> map) {
    return VesselProfile(
      name: map['name'],
      length: map['length'],
      beam: map['beam'],
      depth: map['depth'],
      loadingConditions: (map['loadingConditions'] as List?)
          ?.map((lc) => LoadingCondition.fromMap(lc))
          .toList() ?? [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is VesselProfile &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              length == other.length &&
              beam == other.beam &&
              depth == other.depth;

  @override
  int get hashCode =>
      name.hashCode ^ length.hashCode ^ beam.hashCode ^ depth.hashCode;
}