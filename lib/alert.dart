import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';  // Import du package geolocator
import 'package:vibration/vibration.dart';
import 'package:torch_light/torch_light.dart';  // Import torch_light package
import 'widgets/custom_app_bar.dart';
import 'package:audioplayers/audioplayers.dart';

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
  String? selectedNotif;
  DateTime? _lastAlertTime; // Pour le cooldown
  Position? _currentPosition; // Position actuelle de l'utilisateur

  final List<String> alarmoptions = ['Disable','Alarm 1', 'Alarm 2', 'Alarm 3', 'Alarm 4'];
  final List<String> vibrationoptions = ['Enable', 'Disable'];
  final List<String> flashoptions = ['Enable', 'Disable'];
  final List<String> notifoptions = ['Enable', 'Disable'];
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isVibrationEnabled = false;
  final List<Map<String, String>> alertHistory = [];

  @override
  void initState() {
    super.initState();
    thresholdController = TextEditingController(text: "200");
    selectedVibration = 'Enable';
    selectedFlash = 'Enable';
    selectedNotif = 'Enable';
    selectedAlarme = alarmoptions.first;
    _getCurrentLocation();  // Récupère la position dès que l'app démarre
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
        rollAngle.abs() > (lastAlertRoll.abs() * 1.3);

    // Vérifier le cooldown de 30 secondes (sauf si roll significatif)
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < Duration(seconds: 30) &&
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



      // Flash & Notification à implémenter plus tard
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildInputCard(
              const Icon(Icons.warning_rounded, size: 40, color: Color(0xFF012169)),
              "Threshold for roll period",
              "in degres",
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
            _buildDropdownCard(
              const Icon(Icons.mail_outline_outlined, size: 40, color: Color(0xFF002868)),
              "Notification",
              selectedNotif,
              notifoptions,
                  (value) {
                setState(() {
                  selectedNotif = value;
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
          ],
        ),
      ),
    );
  }

  Widget _buildAlertHistoryTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 2,
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
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('Date/Time', style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Position', style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('Roll Period', style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ),
                    SizedBox(width: 40), // espace pour l'icône de suppression
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
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Supprimer',
                              onPressed: () {
                                setState(() {
                                  alertHistory.removeAt(index);
                                });
                              },
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
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
