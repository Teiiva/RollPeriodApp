import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class AndroidAlertWidgetProvider {
  static const String widgetChannelName = 'com.example.marin/widget';
  static const MethodChannel _channel = MethodChannel('com.example.marin/widget');
  // Méthode pour initialiser la communication avec le widget
  static void initializeWidgetCommunication() {
    // Implémentation spécifique à la plateforme sera nécessaire
  }

  // Méthode pour obtenir les données d'alerte à afficher dans le widget
  static Future<List<Map<String, dynamic>>> getAlertDataForWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('alertHistoryData');

    if (historyJson != null) {
      try {
        final historyData = jsonDecode(historyJson);
        final loadedHistory = (historyData['alertHistory'] as List).map((item) {
          return {
            'time': item['time']?.toString() ?? '--:--:--',
            'date': item['date']?.toString() ?? '----/--/--',
            'rollPeriod': item['rollPeriod']?.toString() ?? 'N/A',
          };
        }).toList();

        return loadedHistory;
      } catch (e) {
        debugPrint('Erreur lors du chargement des données pour le widget: $e');
      }
    }

    return [];
  }

  static Future<void> updateWidget() async {
    try {
      await _channel.invokeMethod('updateWidget');
    } on PlatformException catch (e) {
      debugPrint("Failed to update widget: '${e.message}'.");
    }
  }
}