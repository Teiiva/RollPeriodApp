import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'package:vibration/vibration.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {

  late final TextEditingController thresholdController;
  String? selectedAlarme;
  String? selectedVibration;
  String? selectedFlash;
  String? selectedNotif;

  final List<String> alarmoptions = ['Alarm 1', 'Alarm 2', 'Alarm 3', 'Alarm 4'];
  final List<String> vibrationoptions = ['Enable', 'Disable'];
  final List<String> flashoptions = ['Enable', 'Disable'];
  final List<String> notifoptions = ['Enable', 'Disable'];

  bool isVibrationEnabled = false;

  // Données pour l'historique des alertes
  final List<Map<String, String>> alertHistory = [

  ];

  @override
  void initState() {
    super.initState();
    thresholdController = TextEditingController(text: "200");

    // Initialiser uniquement avec des valeurs présentes dans les options
    selectedVibration = 'Enable';
    selectedFlash = 'Enable';
    selectedNotif = 'Enable';
    selectedAlarme = alarmoptions.first; // "Alarm 1"
  }


  @override
  void dispose() {
    thresholdController.dispose();
    super.dispose();
  }

  void checkForAlert({

    required String latitude,
    required String longitude,
  }) {
    final threshold = double.tryParse(thresholdController.text) ?? 0;

    if (_rollAngle > threshold) {
      final now = DateTime.now();

      // Ajouter une entrée dans l'historique
      setState(() {
        alertHistory.insert(0, {
          'time': "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
          'date': "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
          'latitude': latitude,
          'longitude': longitude,
          'rollPeriod': "${rollPeriod.toStringAsFixed(1)}°"
        });
      });

      // Vibration
      if (selectedVibration == 'Enable') {
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 500);
          }
        });
      }

      // Flash (à implémenter avec le package flash si besoin)

      // Notification (à implémenter avec flutter_local_notifications)

      // Jouer l’alarme selon sélection
      if (selectedAlarme != null) {
        playAlarm(selectedAlarme!);
      }
    }
  }

  void playAlarm(String alarmName) {
    // Simule un son selon le nom d'alarme sélectionné
    // Utilise par exemple `assets/audio/alarm1.mp3` via audioplayers
    print("Playing: $alarmName"); // Remplace par audio réelle
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Alert"),
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
                      child: Text('Date/Time', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Position', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('Roll Period', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          children: [
                            // Colonne Date/Heure
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
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Colonne Position
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lat: ${alert['latitude'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    'Long: ${alert['longitude'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),

                            // Colonne Roll Period
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: rollPeriodValue > 25
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  rollPeriod,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: rollPeriodValue > 25
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ),
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