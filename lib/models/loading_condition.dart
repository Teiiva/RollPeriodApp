// loading_condition.dart
class LoadingCondition {
  final String name;
  final double gm;
  final double vcg;
  final double draft;

  LoadingCondition({
    required this.name,
    required this.gm,
    required this.vcg,
    this.draft = 0.0,
  });

  LoadingCondition copyWith({
    String? name,
    double? gm,
    double? vcg,
    double? draft,
  }) {
    return LoadingCondition(
      name: name ?? this.name,
      gm: gm ?? this.gm,
      vcg: vcg ?? this.vcg,
      draft: draft ?? this.draft,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gm': gm,
      'vcg': vcg,
      'draft': draft,
    };
  }

  factory LoadingCondition.fromMap(Map<String, dynamic> map) {
    return LoadingCondition(
      name: map['name'],
      gm: map['gm'],
      vcg: map['vcg'],
      draft: map['draft'] ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is LoadingCondition &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              gm == other.gm &&
              vcg == other.vcg &&
              draft == other.draft;

  @override
  int get hashCode => name.hashCode ^ gm.hashCode ^ vcg.hashCode ^ draft.hashCode;
}