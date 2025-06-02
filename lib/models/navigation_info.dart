// lib/models/navigation_info.dart
class NavigationInfo {
  final double wavePeriod;
  final double direction;
  final double speed;
  final double course;

  NavigationInfo({
    required this.wavePeriod,
    required this.direction,
    required this.speed,
    required this.course,
  });

  NavigationInfo copyWith({
    double? wavePeriod,
    double? direction,
    double? speed,
    double? course,
  }) {
    return NavigationInfo(
      wavePeriod: wavePeriod ?? this.wavePeriod,
      direction: direction ?? this.direction,
      speed: speed ?? this.speed,
      course: course ?? this.course,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wavePeriod': wavePeriod,
      'direction': direction,
      'speed': speed,
      'course': course,
    };
  }

  factory NavigationInfo.fromJson(Map<String, dynamic> json) {
    return NavigationInfo(
      wavePeriod: json['wavePeriod'] as double,
      direction: json['direction'] as double,
      speed: json['speed'] as double,
      course: json['course'] as double,
    );
  }
}