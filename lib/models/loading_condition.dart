// loading_condition.dart
class LoadingCondition {
  final String name;
  final double gm;
  final double vcg;

  LoadingCondition({
    required this.name,
    required this.gm,
    required this.vcg,
  });

  LoadingCondition copyWith({
    String? name,
    double? gm,
    double? vcg,
  }) {
    return LoadingCondition(
      name: name ?? this.name,
      gm: gm ?? this.gm,
      vcg: vcg ?? this.vcg,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gm': gm,
      'vcg': vcg,
    };
  }

  factory LoadingCondition.fromMap(Map<String, dynamic> map) {
    return LoadingCondition(
      name: map['name'],
      gm: map['gm'],
      vcg: map['vcg'],
    );
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is LoadingCondition &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              gm == other.gm &&
              vcg == other.vcg;

  @override
  int get hashCode => name.hashCode ^ gm.hashCode ^ vcg.hashCode;

}