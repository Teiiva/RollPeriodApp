import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';  // Import du package geolocator
import 'package:vibration/vibration.dart';
import 'package:torch_light/torch_light.dart';  // Import torch_light package
import 'widgets/custom_app_bar.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'android_widget_provider.dart';
import 'package:flutter/services.dart';


// 🔑 Clé globale pour accéder à l'état de AlertPage
final GlobalKey<_AlertPageState> alertPageKey = GlobalKey<_AlertPageState>();

class AlertPage extends StatefulWidget {
  AlertPage({Key? key}) : super(key: alertPageKey);

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  late final TextEditingController thresholdController;
  String? selectedAlarme;
  String? selectedVibration;
  String? selectedFlash;
  DateTime? _lastAlertTime; // Pour le cooldown
  Position? _currentPosition; // Position actuelle de l'utilisateur

  final List<String> alarmoptions = ['Disable','Alarm 1', 'Alarm 2', 'Alarm 3', 'Alarm 4'];
  final List<String> vibrationoptions = ['Enable', 'Disable'];
  final List<String> flashoptions = ['Enable', 'Disable'];
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isVibrationEnabled = false;
  final List<Map<String, String>> alertHistory = [];
  final List<FlSpot> _rollData = []; // Ajout du tableau de données pour l'export


  @override
  void initState() {
    super.initState();
    thresholdController = TextEditingController(text: "200");
    selectedVibration = 'Disable';
    selectedFlash = 'Disable';
    selectedAlarme = alarmoptions.first;
    _getCurrentLocation();  // Récupère la position dès que l'app démarre
    _loadAlertHistory(); // Charger l'historique au démarrage
  }

  Future<void> _saveAlertHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode({
      'alertHistory': alertHistory,
      'rollData': _rollData.map((spot) => {'x': spot.x, 'y': spot.y}).toList(),
    });
    await prefs.setString('alertHistoryData', historyJson);

    // Appel plus robuste pour mettre à jour le widget
    try {
      await MethodChannel('com.example.marin/widget').invokeMethod('updateWidget');
    } catch (e) {
      print('Error updating widget: $e');
    }
  }

  Future<void> _loadAlertHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('alertHistoryData');
    debugPrint("History : ${historyJson}");

    if (historyJson != null) {
      try {
        final historyData = jsonDecode(historyJson);

        // Conversion sécurisée des données d'alerte
        final loadedHistory = (historyData['alertHistory'] as List).map((item) {
          return {
            'time': item['time']?.toString() ?? '--:--:--',
            'date': item['date']?.toString() ?? '----/--/--',
            'rollPeriod': item['rollPeriod']?.toString() ?? 'N/A',
            'latitude': item['latitude']?.toString() ?? 'N/A',
            'longitude': item['longitude']?.toString() ?? 'N/A',
          };
        }).toList();

        // Conversion des données de roulis
        final loadedRollData = (historyData['rollData'] as List).map((spot) {
          return FlSpot(
            (spot['x'] as num).toDouble(),
            (spot['y'] as num).toDouble(),
          );
        }).toList();

        setState(() {
          alertHistory.clear();
          alertHistory.addAll(loadedHistory);

          _rollData.clear();
          _rollData.addAll(loadedRollData);
        });
      } catch (e) {
        print('Erreur lors du chargement de l\'historique: $e');
      }
    }
  }


  @override
  void dispose() {
    _audioPlayer.dispose();
    thresholdController.dispose();
    super.dispose();
  }

  // Méthode pour récupérer la position actuelle
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifie si les services de localisation sont activés
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Si non, afficher un message d'erreur
      print("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Si l'utilisateur n'accorde pas les permissions, afficher un message
        print("Location permissions are denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Si les permissions sont définitivement refusées, afficher un message
      print("Location permissions are permanently denied");
      return;
    }

    // Récupère la position actuelle de l'utilisateur
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
    });
  }

  // Modifie cette méthode pour inclure la position dans l'historique des alertes
  void checkForAlert({
    required rollAngle,
  }) {
    final threshold = double.tryParse(thresholdController.text) ?? 0;
    final now = DateTime.now();

    // Récupérer le dernier roll enregistré
    double? lastAlertRoll;
    if (alertHistory.isNotEmpty) {
      lastAlertRoll = double.tryParse(alertHistory.first['rollPeriod']?.replaceAll('°', '') ?? '0');
    }

    // Vérifier si le roll actuel dépasse de 30% le dernier roll enregistré
    final isSignificantRoll = lastAlertRoll != null &&
        rollAngle.abs() > (lastAlertRoll.abs() * 1.2);

    // Vérifier le cooldown de 30 secondes (sauf si roll significatif)
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < Duration(seconds: 10) &&
        !isSignificantRoll) {
      return; // Ignorer l'alerte si le cooldown n'est pas écoulé et que le roll n'est pas significatif
    }

    if (rollAngle.abs() > threshold) {
      _lastAlertTime = now; // Enregistrer le moment de l'alerte

      // Ajouter les informations de position à l'historique des alertes
      setState(() {
        alertHistory.insert(0, {
          'time': "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
          'date': "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
          'rollPeriod': "${rollAngle.toStringAsFixed(1)}°",
          'latitude': _currentPosition?.latitude.toString() ?? 'N/A',
          'longitude': _currentPosition?.longitude.toString() ?? 'N/A',
        });
        _rollData.add(FlSpot(now.second.toDouble(), rollAngle));
      });

      if (selectedVibration == 'Enable') {
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 500);
          }
        });
      }

      if (selectedAlarme != null && selectedAlarme != 'Disable') {
        playAlarm(selectedAlarme!);
      }

      if (selectedFlash == 'Enable') {
        _toggleFlash();
      }
      _saveAlertHistory(); // Sauvegarder après ajout
    }
  }

  void playAlarm(String alarmName) async {
    String? soundPath;

    switch (alarmName) {
      case 'Alarm 1':
        soundPath = 'sounds/alarm1.mp3';
        break;
      case 'Alarm 2':
        soundPath = 'sounds/alarm2.mp3';
        break;
      case 'Alarm 3':
        soundPath = 'sounds/alarm3.mp3';
        break;
      case 'Alarm 4':
        soundPath = 'sounds/alarm4.mp3';
        break;
      default:
        return;
    }

    try {
      await _audioPlayer.stop(); // Stop any previous alarm
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      print("Erreur lors de la lecture de l'alarme: $e");
    }
  }

  void _toggleFlash() async {
    for (int i = 0; i < 3; i++) {
      await TorchLight.enableTorch();  // Allume le flash
      await Future.delayed(const Duration(milliseconds: 500));  // Attend 500ms
      await TorchLight.disableTorch(); // Éteint le flash
      await Future.delayed(const Duration(milliseconds: 500));  // Attend 500ms avant de recommencer
    }
  }

  // Modifiez les méthodes de suppression pour sauvegarder après
  void _deleteAllAlerts() {
    setState(() {
      alertHistory.clear();
      _rollData.clear();
    });
    _saveAlertHistory(); // Sauvegarder après suppression
    AndroidAlertWidgetProvider.updateWidget();
  }

  void _deleteAlertAtIndex(int index) {
    setState(() {
      alertHistory.removeAt(index);
      if (index < _rollData.length) {
        _rollData.removeAt(index);
      }
    });
    _saveAlertHistory(); // Sauvegarder après suppression
    AndroidAlertWidgetProvider.updateWidget();
  }


  Future<void> _exportRollDataToDownloads() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;

      if (!status.isGranted) {
        bool shouldRequest = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission requise'),
            content: const Text(
              'Cette application a besoin de l\'accès au stockage pour exporter les données dans le dossier "Download". Souhaitez-vous autoriser cette permission ?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Annuler')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Autoriser')),
            ],
          ),
        ) ??
            false;

        if (shouldRequest) {
          status = await Permission.manageExternalStorage.request();
        }

        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Permission de stockage refusée')),
          );
          return;
        }
      }
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln(
          'jour,mois,année,heure,minute,seconde,longitude,latitude,roll (deg)');

      // On suppose ici que alertHistory et _rollData sont synchrones
      for (int i = 0; i < alertHistory.length && i < _rollData.length; i++) {
        final alert = alertHistory[i];
        final roll = _rollData[i];

        final dateParts = alert['date']?.split('-') ?? ['----', '--', '--'];
        final timeParts = alert['time']?.split(':') ?? ['--', '--', '--'];
        final longitude = alert['longitude'] ?? 'N/A';
        final latitude = alert['latitude'] ?? 'N/A';
        final rollDeg = roll.y.toStringAsFixed(1);

        final jour = dateParts[2];
        final mois = dateParts[1];
        final annee = dateParts[0];
        final heure = timeParts[0];
        final minute = timeParts[1];
        final seconde = timeParts[2];

        buffer.writeln(
            '$jour,$mois,$annee,$heure,$minute,$seconde,$longitude,$latitude,$rollDeg');
      }

      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File(
          '${directory.path}/alert_data_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Données exportées : ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'export : $e')),
      );
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildInputCard(
              const Icon(Icons.warning_rounded, size: 40, color: Color(0xFF012169)),
              "Threshold for\nroll angle",
              "",
              thresholdController,
            ),
            _buildDropdownCard(
              const Icon(Icons.vibration, size: 40, color: Color(0xFF002868)),
              "Vibration",
              selectedVibration,
              vibrationoptions,
                  (value) {
                setState(() {
                  selectedVibration = value;
                });
              },
            ),
            _buildDropdownCard(
              const Icon(Icons.notifications_active, size: 40, color: Color(0xFF002868)),
              "Alarm",
              selectedAlarme,
              alarmoptions,
                  (value) {
                setState(() {
                  selectedAlarme = value;
                });
              },
            ),
            _buildDropdownCard(
              const Icon(Icons.flash_on, size: 40, color: Color(0xFF002868)),
              "Flash",
              selectedFlash,
              flashoptions,
                  (value) {
                setState(() {
                  selectedFlash = value;
                });
              },
            ),

            // Section Alert History
            Padding(
              padding: const EdgeInsets.only(top: 30, left: 40, right: 20, bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 40, color: Color(0xFF012169)),
                  const SizedBox(width: 10),
                  Text(
                    'Alert History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            _buildAlertHistoryTable(),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _exportRollDataToDownloads,
              child: const Text(
                'Extract',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF012169)),
              ),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(Colors.white), // Couleur de fond
                padding: MaterialStateProperty.all<EdgeInsetsGeometry>(EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0)), // Padding
                foregroundColor: MaterialStateProperty.all<Color>(Color(0xFF012169)), // Couleur du texte
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertHistoryTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // En-tête du tableau
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF012169).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text('Date/Time', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text('Position', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text('Roll angle', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFF012169)),
                      tooltip: 'Tout supprimer',
                      onPressed: _deleteAllAlerts, // Utilise la nouvelle méthode
                    ),
                  ],
                ),
              ),

              // Contenu du tableau
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alertHistory.length,
                itemBuilder: (context, index) {
                  final alert = alertHistory[index];
                  final rollPeriod = alert['rollPeriod'] ?? 'N/A';
                  final rollPeriodValue = double.tryParse(rollPeriod.replaceAll('°', '')) ?? 0;

                  return Column(
                    children: [
                      Divider(height: 1, color: Colors.grey[300]),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Date/Heure
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert['time'] ?? '--:--:--',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,

                                    ),
                                  ),
                                  Text(
                                    alert['date'] ?? '----/--/--',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Position
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Lat: ${alert['latitude'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 12,),
                                    textAlign: TextAlign.center, // Centrer le texte horizontalement
                                  ),
                                  Text(
                                    'Lon: ${alert['longitude'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center, // Centrer le texte horizontalement
                                  ),
                                ],
                              ),
                            ),

                            // Roll Period
                            Expanded(
                              flex: 2,
                              child:Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: rollPeriodValue.abs() > 25
                                        ? Colors.red.withOpacity(0.2)
                                        : Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    rollPeriod,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: rollPeriodValue.abs() > 25
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                                ),
                              ),
                            ),


                            // Bouton de suppression
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF012169)),
                              tooltip: 'Supprimer',
                              onPressed: () => _deleteAlertAtIndex(index), // Utilise la nouvelle méthode
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(
      Widget iconWidget,
      String label,
      String hint,
      TextEditingController controller,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: hint,
                            border: InputBorder.none,
                            suffixText: '°',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownCard(
      Widget iconWidget,
      String label,
      String? currentValue,
      List<String> items,
      ValueChanged<String?> onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: currentValue,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: Text(
                            'Select',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          items: items.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
