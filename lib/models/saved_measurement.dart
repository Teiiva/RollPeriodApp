// saved_measurement.dart

import 'vessel_profile.dart';
import 'navigation_info.dart';
import 'loading_condition.dart';

// saved_measurement.dart
class SavedMeasurement {
  final DateTime timestamp;
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;
  final NavigationInfo navigationInfo;
  final double? rollPeriodFFT;
  final Map<String, double> predictedRollPeriods; // Nouveau champ pour stocker toutes les prédictions

  SavedMeasurement({
    required this.timestamp,
    required this.vesselProfile,
    required this.loadingCondition,
    required this.navigationInfo,
    this.rollPeriodFFT,
    Map<String, double>? predictedRollPeriods, // Nouveau paramètre optionnel
  }) : predictedRollPeriods = predictedRollPeriods ?? {};

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'vesselProfile': vesselProfile.toMap(),
      'loadingCondition': loadingCondition.toMap(),
      'navigationInfo': navigationInfo.toJson(),
      'rollPeriodFFT': rollPeriodFFT,
      'predictedRollPeriods': predictedRollPeriods, // Ajouté pour la sérialisation
    };
  }

  factory SavedMeasurement.fromMap(Map<String, dynamic> map) {
    return SavedMeasurement(
      timestamp: DateTime.parse(map['timestamp']),
      vesselProfile: VesselProfile.fromMap(map['vesselProfile']),
      loadingCondition: LoadingCondition.fromMap(map['loadingCondition']),
      navigationInfo: NavigationInfo.fromJson(map['navigationInfo']),
      rollPeriodFFT: map['rollPeriodFFT'],
      predictedRollPeriods: Map<String, double>.from(map['predictedRollPeriods'] ?? {}), // Désérialisation
    );
  }
}