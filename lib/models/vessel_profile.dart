// vessel_profile.dart
import 'loading_condition.dart';

const List<String> shipTypes = [
  'Container vessel',
  'General Cargo',
  'Heavy Cargo',
  'Bulk carrier',
  'Tanker Crude',
  'Tanker Product',
  'Tanker Gas',
  'Car carrier',
  'Ferry / RoPax',
  'Cruise vessel',
  'Offshore',
  'Navy',
  'Tug',
  'Yacht',
  'Fishing vessel',
  'Other',
];

class VesselProfile {
  final String name;
  final double length;
  final double beam;
  final double depth;
  final List<LoadingCondition> loadingConditions;
  final int? iso;
  final String? shiptype;

  VesselProfile({
    required this.name,
    required this.length,
    required this.beam,
    required this.depth,
    List<LoadingCondition>? loadingConditions,
    this.iso,
    this.shiptype,
  }) : loadingConditions = loadingConditions ?? [];

  VesselProfile copyWith({
    String? name,
    double? length,
    double? beam,
    double? depth,
    List<LoadingCondition>? loadingConditions,
    int? iso,
    String? shiptype,
  }) {
    return VesselProfile(
      name: name ?? this.name,
      length: length ?? this.length,
      beam: beam ?? this.beam,
      depth: depth ?? this.depth,
      loadingConditions: loadingConditions ?? this.loadingConditions,
      iso: iso ?? this.iso,
      shiptype: shiptype ?? this.shiptype,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'length': length,
      'beam': beam,
      'depth': depth,
      'loadingConditions': loadingConditions.map((lc) => lc.toMap()).toList(),
      if (iso != null) 'iso': iso,
      if (shiptype != null) 'shiptypes': shiptype,
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
      iso: map['iso'] as int?,
      shiptype: map['shiptypes'] as String?,
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

  static final VesselProfile defaultVessel = VesselProfile(
    name: '__add_new__',
    length: 0,
    beam: 0,
    depth: 0,
    loadingConditions: const [],
    iso: 0, shiptype: "Other"
  );
}