// storage_manager.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageManager {
  static Future<void> saveList<T>({
    required String key,
    required List<T> items,
    required Map<String, dynamic> Function(T) toMap,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      json.encode(items.map((item) => toMap(item)).toList()),
    );
  }

  static Future<List<T>> loadList<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(key);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((item) => fromMap(item)).toList();
    }
    return [];
  }

  static Future<void> saveCurrent<T>({
    required String key,
    required T item,
    required Map<String, dynamic> Function(T) toMap,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(toMap(item)));
  }

  static Future<T?> loadCurrent<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(key);
    if (jsonString != null) {
      return fromMap(json.decode(jsonString));
    }
    return null;
  }
}