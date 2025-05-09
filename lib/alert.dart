import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'sensor_page.dart';
import 'info.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  late final TextEditingController thresholdController;
  String? selectedAlarme;
  String? selectedFlash;
  String? selectedNotif;

  final List<String> alarmoptions = [
    'Alarm 1',
    'Alarm 2',
    'Alarm 3',
    'Alarm 4'
  ];

  final List<String> flashoptions = [
    'Enable',
    'Disable'
  ];

  final List<String> notifoptions = [
    'Enable',
    'Disable'
  ];


  @override
  void initState() {
    super.initState();
    thresholdController = TextEditingController();
  }

  @override
  void dispose() {
    thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Alert"),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildInputCard(
            const Icon(Icons.warning_rounded, size: 40, color: Color(0xFF012169)),
            "Threshold for roll period",
            "in degres",
            thresholdController,
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

          const Spacer(),
          // Vous pouvez ajouter une image ici si nécessaire
          // Padding(
          //   padding: const EdgeInsets.only(bottom: 20.0),
          //   child: Image.asset('assets/alert.png', height: 180),
          // )
        ],
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