class VesselProfile {
  final String name;
  final double length;
  final double beam;
  final double depth;

  VesselProfile({
    required this.name,
    required this.length,
    required this.beam,
    required this.depth,
  });

  VesselProfile copyWith({
    String? name,
    double? length,
    double? beam,
    double? depth,
  }) {
    return VesselProfile(
      name: name ?? this.name,
      length: length ?? this.length,
      beam: beam ?? this.beam,
      depth: depth ?? this.depth,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'length': length,
      'beam': beam,
      'depth': depth,
    };
  }

  factory VesselProfile.fromMap(Map<String, dynamic> map) {
    return VesselProfile(
      name: map['name'],
      length: map['length'],
      beam: map['beam'],
      depth: map['depth'],
    );
  }
}
