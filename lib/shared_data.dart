import 'package:flutter/material.dart';
import 'models/saved_measurement.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


class SharedData extends ChangeNotifier {
  List<SavedMeasurement> _savedMeasurements = [];

  List<SavedMeasurement> get savedMeasurements => _savedMeasurements;

  SharedData() {
    loadMeasurements();
  }

  Future<void> loadMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    final measurementsJson = prefs.getStringList('savedMeasurements') ?? [];
    _savedMeasurements = measurementsJson.map((json) {
      try {
        return SavedMeasurement.fromMap(jsonDecode(json));
      } catch (e) {
        debugPrint('Error parsing measurement: $e');
        return null;
      }
    }).whereType<SavedMeasurement>().toList();
    notifyListeners();
  }

  Future<void> addMeasurement(SavedMeasurement measurement) async {
    final prefs = await SharedPreferences.getInstance();
    final measurementsJson = prefs.getStringList('savedMeasurements') ?? [];
    measurementsJson.insert(0, jsonEncode(measurement.toMap()));
    await prefs.setStringList('savedMeasurements', measurementsJson);
    await loadMeasurements();
  }

  Future<void> deleteMeasurement(SavedMeasurement measurement) async {
    final prefs = await SharedPreferences.getInstance();
    final measurementsJson = prefs.getStringList('savedMeasurements') ?? [];
    measurementsJson.removeWhere((json) {
      try {
        final map = jsonDecode(json);
        return DateTime.parse(map['timestamp']) == measurement.timestamp;
      } catch (e) {
        return false;
      }
    });
    await prefs.setStringList('savedMeasurements', measurementsJson);
    await loadMeasurements();
  }
}