import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/custom_app_bar.dart';
import 'fft_processor.dart';
import 'alert.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'models/navigation_info.dart';

/// Page principale pour l'affichage et l'analyse des données des capteurs
class SensorPage extends StatefulWidget {
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;
  final NavigationInfo navigationInfo;

  const SensorPage({
    Key? key,
    required this.vesselProfile,
    required this.loadingCondition,
    required this.navigationInfo,
  }) : super(key: key);

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  // =============================================
  // CONSTANTES ET VARIABLES D'ÉTAT
  // =============================================

  // Constantes
  static const int _maxDataPoints = 512; // Nombre max de points de données
  static const int _fftWindowSize = 512; // Taille de la fenêtre FFT
  static const int _maxPeriods = 5; // Nombre max de périodes à conserver

  // Données des capteurs
  AccelerometerEvent? _accelerometer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // États de l'application
  bool _isCollectingData = false;
  bool _showRollData = true;
  bool _showPitchData = true;

  // Angles calculés
  double? _rollAngle;
  double? _pitchAngle;

  // Données pour les graphiques
  List<FlSpot> _rollData = [];
  List<FlSpot> _pitchData = [];

  // Calcul des périodes (méthode passage par zéro)
  List<double> _Rollperiods = [];
  double? _RolllastZeroCrossingTime;
  double? _RollaveragePeriod;
  double _previousRoll = 0.0;

  List<double> _Pitchperiods = [];
  double? _PitchlastZeroCrossingTime;
  double? _PitchaveragePeriod;
  double _previousPitch = 0.0;

  // Calcul des périodes (méthode FFT)
  double? _fftRollPeriod;
  double? _fftPitchPeriod;
  final List<double> _fftRollSamples = [];
  final List<double> _fftPitchSamples = [];
  double? _dynamicSampleRate = 20;

  // Timers et contrôleurs
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _fftTimer;
  Timer? _updateTimer;
  final Queue<DateTime> _timestampQueue = Queue<DateTime>();

  // Contrôleurs de page
  late PageController _pageController;
  int _currentPage = 0;
  late PageController _fftPageController;
  int _currentFftPage = 0;

  int _powerIndex = 0;
  final List<double> _powersOfTwo = [512, 1024, 2048, 4096, 8192, 16384, 32768, 65536]; // exemple

  bool _hasReachedSampleCount = false;

  // =============================================
  // LIFECYCLE METHODS
  // =============================================

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fftPageController = PageController();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _fftTimer?.cancel();
    _pageController.dispose();
    _fftPageController.dispose();
    super.dispose();
  }

  // =============================================
  // GESTION DE LA COLLECTE DE DONNÉES
  // =============================================

  /// Active ou désactive la collecte de données
  void _toggleDataCollection() {
    setState(() => _isCollectingData = !_isCollectingData);

    if (_isCollectingData) {
      _startDataCollection();
    } else {
      _stopDataCollection();
    }
  }

  /// Lance la collecte de données
  void _startDataCollection() {
    _rollData.clear();
    _pitchData.clear();
    _stopwatch.reset();
    _stopwatch.start();
    _timestampQueue.clear();
    _dynamicSampleRate = 20.0;

    // Timer pour la mise à jour périodique de l'interface
    _updateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_accelerometer != null && mounted) {
        _processAccelerometerData(_accelerometer!);
      }
    });

    // Abonnement aux événements de l'accéléromètre
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _accelerometer = event;
    });
  }

  /// Arrête la collecte de données
  void _stopDataCollection() {
    _updateTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _stopwatch.stop();
  }

  /// Réinitialise toutes les données
  void _clearData() {
    if (mounted) {
      setState(() {
        _rollData.clear();
        _pitchData.clear();
        _rollAngle = null;
        _pitchAngle = null;

        // Réinitialisation des calculs de période (roll)
        _RollaveragePeriod = null;
        _RolllastZeroCrossingTime = null;
        _previousRoll = 0.0;
        _Rollperiods.clear();

        // Réinitialisation des calculs de période (pitch)
        _PitchaveragePeriod = null;
        _PitchlastZeroCrossingTime = null;
        _previousPitch = 0.0;
        _Pitchperiods.clear();

        _clearFFTData();
        _dynamicSampleRate = 20;
        _showRollData = true;
        _showPitchData = true;
      });
    }
  }

  // =============================================
  // TRAITEMENT DES DONNÉES DES CAPTEURS
  // =============================================

  /// Traite les données de l'accéléromètre
  void _processAccelerometerData(AccelerometerEvent event) {
    _updateSampleRate();

    final timestamp = _stopwatch.elapsedMilliseconds / 1000.0;
    _rollAngle = calculateRoll(event);
    _pitchAngle = calculatePitch(event);

    if (_rollAngle == null || _pitchAngle == null) return;

    // Vérifie les alertes
    alertPageKey.currentState?.checkForAlert(rollAngle: _rollAngle);

    // Arrête la collecte si on a assez de points
    if (_rollData.length >= _powersOfTwo[_powerIndex]) {
      if (_isCollectingData) {
        setState(() {
          _hasReachedSampleCount = true;
        });
        _toggleDataCollection();
        debugPrint("512 samples collected, data collection stopped.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('512 samples collected - Stopping data collection')),
          );
        }
      }
      return;
    }

    // Ajoute les données aux listes
    _rollData.add(FlSpot(timestamp, _rollAngle!));
    _pitchData.add(FlSpot(timestamp, _pitchAngle!));

    // Calcul des périodes par passage à zéro
    _calculateZeroCrossingPeriods(timestamp);

    // Préparation des données pour la FFT
    _prepareFFTData();

    if (mounted) setState(() {});
  }

  /// Met à jour le taux d'échantillonnage dynamique
  void _updateSampleRate() {
    final now = DateTime.now();
    _timestampQueue.add(now);

    if (_timestampQueue.length > 100) {
      final first = _timestampQueue.first;
      final last = _timestampQueue.last;
      final duration = last.difference(first).inMilliseconds / 1000.0;
      final rate = _timestampQueue.length / duration;
      debugPrint('Average sampling rate: ${rate.toStringAsFixed(2)} Hz');
      _timestampQueue.clear();
      _dynamicSampleRate = rate;
    }
  }

  /// Calcule les périodes par détection de passage à zéro
  void _calculateZeroCrossingPeriods(double timestamp) {
    // Détection du passage à zéro pour Roll
    if (_previousRoll < 0 && _rollAngle! >= 0) {
      if (_RolllastZeroCrossingTime != null) {
        double period = timestamp - _RolllastZeroCrossingTime!;
        _Rollperiods.add(period);
        if (_Rollperiods.length > _maxPeriods) {
          _Rollperiods.removeAt(0);
        }
        _RollaveragePeriod = _Rollperiods.reduce((a, b) => a + b) / _Rollperiods.length;
      }
      _RolllastZeroCrossingTime = timestamp;
    }
    _previousRoll = _rollAngle!;

    // Détection du passage à zéro pour Pitch
    if (_previousPitch < 0 && _pitchAngle! >= 0) {
      if (_PitchlastZeroCrossingTime != null) {
        double pitchPeriod = timestamp - _PitchlastZeroCrossingTime!;
        _Pitchperiods.add(pitchPeriod);
        if (_Pitchperiods.length > _maxPeriods) {
          _Pitchperiods.removeAt(0);
        }
        _PitchaveragePeriod = _Pitchperiods.reduce((a, b) => a + b) / _Pitchperiods.length;
      }
      _PitchlastZeroCrossingTime = timestamp;
    }
    _previousPitch = _pitchAngle!;
  }

  /// Prépare les données pour le calcul FFT
  void _prepareFFTData() {
    _fftRollSamples.add(_rollAngle!);
    _fftPitchSamples.add(_pitchAngle!);

    if (_fftRollSamples.length > _fftWindowSize) {
      _fftRollSamples.removeAt(0);
    }

    if (_fftPitchSamples.length > _fftWindowSize) {
      _fftPitchSamples.removeAt(0);
    }

    if (_fftRollSamples.length == _fftWindowSize && _fftRollPeriod == null) {
      _computeFFTPeriod();
    }
  }

  // =============================================
  // CALCULS D'ANGLES ET DE PÉRIODES
  // =============================================

  /// Calcule l'angle de roulis (roll) à partir des données de l'accéléromètre
  double? calculateRoll(AccelerometerEvent acc) {
    try {
      if (acc.x == 0 && acc.z == 0) return null;
      return atan2(acc.x, acc.z) * 180 / pi;
    } catch (e) {
      debugPrint('Error calculating roll: $e');
      return null;
    }
  }

  /// Calcule l'angle de tangage (pitch) à partir des données de l'accéléromètre
  double? calculatePitch(AccelerometerEvent acc) {
    try {
      if (acc.y == 0 && acc.z == 0) return null;
      return atan2(acc.y, acc.z) * 180 / pi;
    } catch (e) {
      debugPrint('Error calculating pitch: $e');
      return null;
    }
  }

  /// Calcule les périodes avec la FFT
  void _computeFFTPeriod() async {
    if (_fftRollSamples.length >= _fftWindowSize) {
      final rollperiod = await compute(_backgroundFFTCalculation, {
        'samples': _fftRollSamples,
        'sampleRate': _dynamicSampleRate,
      });

      final pitchperiod = await compute(_backgroundFFTCalculation, {
        'samples': _fftPitchSamples,
        'sampleRate': _dynamicSampleRate,
      });

      if (mounted) {
        setState(() {
          _fftRollPeriod = rollperiod;
          _fftPitchPeriod = pitchperiod;
          debugPrint(" ${_fftRollPeriod}, ${_fftPitchPeriod}");
        });
      }
    }
  }

  /// Fonction de calcul FFT exécutée dans un isolate séparé
  static double? _backgroundFFTCalculation(Map<String, dynamic> params) {
    debugPrint('_backgroundFFTCalculation');
    final samples = List<double>.from(params['samples']);
    final sampleRate = (params['sampleRate'] as num).toDouble();
    return FFTProcessor.findRollingPeriod(samples, sampleRate);
  }

  /// Réinitialise les données FFT
  void _clearFFTData() {
    _fftRollSamples.clear();
    _fftPitchSamples.clear();
    if (mounted) {
      setState(() {
        _fftRollPeriod = null;
        _fftPitchPeriod = null;
        _hasReachedSampleCount = false;
      });
    }
  }

  // =============================================
  // IMPORT/EXPORT DE DONNÉES
  // =============================================

  void _savefunction(){
    debugPrint('hello');
  }


  /// Exporte les données vers le dossier de téléchargements
  Future<void> _exportRollDataToDownloads() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission denied')),
            );
          }
          return;
        }
      }
    }

    try {
      final buffer = StringBuffer();

      // Données fixes
      final now = DateTime.now();
      final wavePeriod = widget.navigationInfo.wavePeriod;
      final direction = widget.navigationInfo.direction;
      final sampleRate = _dynamicSampleRate?.toStringAsFixed(2);
      final rollCount = _rollData.length;
      final rollPeriodZero = _RollaveragePeriod?.toStringAsFixed(2);
      final rollPeriodFFT = _fftRollPeriod?.toStringAsFixed(2);
      final pitchPeriodZero = _PitchaveragePeriod?.toStringAsFixed(2);
      final pitchPeriodFFT = _fftPitchPeriod?.toStringAsFixed(2);
      final vessel = widget.vesselProfile;
      final loading = widget.loadingCondition;
      final nav = widget.navigationInfo;

      // Liste des métadonnées (clé: valeur)
      final metadata = [
        'Export Time: ${now.toIso8601String()}',
        'Sample Rate (Hz): $sampleRate',
        'Samples Count: $rollCount',
        'Roll Period (Zero Crossing)(s): $rollPeriodZero',
        'Roll Period (FFT)(s): $rollPeriodFFT',
        'Pitch Period (Zero Crossing)(s): $pitchPeriodZero',
        'Pitch Period (FFT)(s): $pitchPeriodFFT',
        'Vessel Profile: ${vessel.name}',
        'Length (m): ${vessel.length}',
        'Beam (m): ${vessel.beam}',
        'Depth (m): ${vessel.depth}',
        'Loading Condition: ${loading.name}',
        'GM (m): ${loading.gm}',
        'VCG (m): ${loading.vcg}',
        'Speed (kts): ${nav.speed}',
        'Course (°): ${nav.course}',
        'Wave Period (s): $wavePeriod',
        'Wave Direction (°): $direction',
      ];

      // En-tête
      buffer.writeln('time (s),roll (deg),pitch (deg),metadata');

      // Calcul du max entre données et métadonnées
      final int maxLines = _rollData.length > metadata.length ? _rollData.length : metadata.length;

      for (int i = 0; i < maxLines; i++) {
        String line = '';

        if (i < _rollData.length) {
          final rollSpot = _rollData[i];
          final pitchSpot = i < _pitchData.length ? _pitchData[i] : FlSpot(rollSpot.x, 0);
          line += '${rollSpot.x.toStringAsFixed(3)},'
              '${rollSpot.y.toStringAsFixed(3)},'
              '${pitchSpot.y.toStringAsFixed(3)}';
        } else {
          // Pas de données capteur pour cette ligne
          line += ',,';
        }

        // Ajout de la métadonnée dans la colonne 4 si elle existe
        if (i < metadata.length) {
          line += ',${metadata[i]}';
        }

        buffer.writeln(line);
      }

      final directory = Directory('/storage/emulated/0/Download');
      final file = File('${directory.path}/sensor_data_${now.millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }



  /// Importe des données depuis un fichier CSV
  void _handleImport() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage permission denied')),
              );
            }
            return;
          }
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun fichier CSV sélectionné')),
          );
        }
        return;
      }

      final file = File(result.files.single.path!);
      final contents = await file.readAsString();

      final lines = contents.split('\n');
      final List<FlSpot> importedRollData = [];
      final List<FlSpot> importedPitchData = [];
      double? firstTimestamp;

      for (final line in lines.skip(1)) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 3) {
          try {
            final timestamp = double.parse(parts[0]);
            final roll = double.parse(parts[1]);
            final pitch = double.parse(parts[2]);
            firstTimestamp ??= timestamp;
            importedRollData.add(FlSpot(timestamp - (firstTimestamp ?? 0), roll));
            importedPitchData.add(FlSpot(timestamp - (firstTimestamp ?? 0), pitch));
          } catch (e) {
            debugPrint('Erreur parsing ligne : $line, erreur : $e');
          }
        }
      }

      if (importedRollData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun roll valide trouvée dans le CSV')),
          );
        }
        return;
      }

      if (importedRollData.length > 1) {
        double totalTime = importedRollData.last.x - importedRollData.first.x;
        _dynamicSampleRate = (importedRollData.length - 1) / totalTime;
        debugPrint('Calculated sample rate from CSV: ${_dynamicSampleRate!.toStringAsFixed(2)} Hz');
      }

      if (mounted) {
        setState(() {
          _rollData = importedRollData;
          _pitchData = importedPitchData;
          _isCollectingData = false;
          _updateTimer?.cancel();
          _stopDataCollection();
          _calculatePeriodFromImportedData();
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import réussi : ${importedRollData.length} points depuis ${file.path.split('/').last}')),
        );
      }
    } catch (e) {
      debugPrint('Import échoué : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import échoué : $e')),
        );
      }
    }
  }

  /// Calcule les périodes à partir des données importées
  void _calculatePeriodFromImportedData() {
    // Réinitialisation des calculs
    _Rollperiods.clear();
    _RolllastZeroCrossingTime = null;
    _RollaveragePeriod = null;
    _previousRoll = 0.0;

    _Pitchperiods.clear();
    _PitchlastZeroCrossingTime = null;
    _PitchaveragePeriod = null;
    _previousPitch = 0.0;

    _stopwatch.reset();
    if (_rollData.isNotEmpty) {
      _stopwatch.elapsedMicroseconds + (_rollData.last.x * 1000000).toInt();
    }

    // Calcul des périodes pour les données importées
    for (final spot in _rollData) {
      final timestamp = spot.x;
      final roll = spot.y;
      final pitch = _pitchData.isNotEmpty ? _pitchData[_rollData.indexOf(spot)].y : 0.0;

      // Calcul pour le roll
      if (_previousRoll < 0 && roll >= 0) {
        if (_RolllastZeroCrossingTime != null) {
          double period = timestamp - _RolllastZeroCrossingTime!;
          _Rollperiods.add(period);
          if (_Rollperiods.length > _maxPeriods) {
            _Rollperiods.removeAt(0);
          }
          _RollaveragePeriod = _Rollperiods.reduce((a, b) => a + b) / _Rollperiods.length;
        }
        _RolllastZeroCrossingTime = timestamp;
      }
      _previousRoll = roll;

      // Calcul pour le pitch
      if (_previousPitch < 0 && pitch >= 0) {
        if (_PitchlastZeroCrossingTime != null) {
          double period = timestamp - _PitchlastZeroCrossingTime!;
          _Pitchperiods.add(period);
          if (_Pitchperiods.length > _maxPeriods) {
            _Pitchperiods.removeAt(0);
          }
          _PitchaveragePeriod = _Pitchperiods.reduce((a, b) => a + b) / _Pitchperiods.length;
        }
        _PitchlastZeroCrossingTime = timestamp;
      }
      _previousPitch = pitch;
    }

    // Préparation des données pour la FFT
    _fftRollSamples.clear();
    _fftPitchSamples.clear();
    _fftRollPeriod = null;
    _fftPitchPeriod = null;

    for (final spot in _rollData) {
      _fftRollSamples.add(spot.y);
    }
    for (final spot in _pitchData) {
      _fftPitchSamples.add(spot.y);
    }

    if (_fftRollSamples.length >= _fftWindowSize && _fftPitchSamples.length >= _fftWindowSize) {
      _computeFFTPeriod();
    }
  }

  // =============================================
  // WIDGETS DE L'INTERFACE UTILISATEUR
  // =============================================

  /// Affiche les tuiles Roll et Pitch côte à côte
  Widget rollAndPitchTiles() {
    return Row(
      children: [
        Expanded(child: rollTile(_rollAngle)),
        Expanded(child: pitchTile(_pitchAngle)),
      ],
    );
  }

  /// Tuile d'affichage pour l'angle de roulis (roll)
  Widget rollTile(double? angle) {
    return Card(
      color: getSmoothColorForAngle(angle),
      child: InkWell(
        onTap: () => setState(() => _showRollData = !_showRollData),
        child: ListTile(
          leading: const Icon(Icons.straighten, color: Colors.white, size: 40),
          title: const Text('Roll', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text(
            angle != null ? '${angle.toStringAsFixed(2)}°' : 'Press Start',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// Tuile d'affichage pour l'angle de tangage (pitch)
  Widget pitchTile(double? angle) {
    return Card(
      color: getSmoothColorForAngle(angle),
      child: InkWell(
        onTap: () => setState(() => _showPitchData = !_showPitchData),
        child: ListTile(
          leading: Transform.rotate(
            angle: 90 * 3.1415926535 / 180,
            child: const Icon(Icons.straighten, color: Colors.white, size: 40),
          ),
          title: const Text('Pitch', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text(
            angle != null ? '${angle.toStringAsFixed(2)}°' : 'Press Start',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget RateAndSampleTiles() {
    return Row(
      children: [
        Expanded(child: SampleRateTile()),
        Expanded(child: SampleTile()),
      ],
    );
  }

  /// Tuile d'affichage du taux d'échantillonnage
  Widget SampleRateTile() {
    return Card(
      color: Colors.blueGrey,
      child: ListTile(
        leading: const Icon(Icons.speed, color: Colors.white, size: 40),
        title: const Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          _dynamicSampleRate != null ? '${_dynamicSampleRate!.toStringAsFixed(2)} Hz' : 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  /// Tuile d'affichage du taux d'échantillonnage
  Widget SampleTile() {
    return Card(
      color: Colors.blueGrey,
      child: InkWell(
        onTap: () {
          setState(() {
            _powerIndex = (_powerIndex + 1) % _powersOfTwo.length;
          });
        },
        onLongPress: () {
          setState(() {
            _powerIndex = 0;
          });
        },
        child: ListTile(
          leading: const Icon(Icons.bar_chart_outlined, color: Colors.white, size: 40),
          title: const Text('Nb Sample', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text(
            _powersOfTwo[_powerIndex] != null ? '${_powersOfTwo[_powerIndex].toStringAsFixed(0)}' : 'N/A',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }


  /// Tuile d'affichage des périodes calculées par passage à zéro
  Widget rollingPeriodTile(double? Rollperiod, double? Pitchperiod) {
    return Card(
      color: Colors.teal,
      child: SizedBox(
        height: 70,
        child: Row(
          children: [
            Expanded(
              child: PageView(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.white, size: 40),
                    title: const Text('Rolling Period (s)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(
                      Rollperiod != null ? '${Rollperiod.toStringAsFixed(2)} s' : 'Calculating...',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.white, size: 40),
                    title: const Text('Pitch Period (s)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(
                      Pitchperiod != null ? '${Pitchperiod.toStringAsFixed(2)} s' : 'Calculating...',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(2, (int index) {
                  return Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tuile d'affichage des périodes calculées par FFT
  Widget fftPeriodTile() {
    int nb_sample=_powersOfTwo[_powerIndex].toInt();
    return Card(
      color: Colors.deepPurple,
      child: SizedBox(
        height: 70,
        child: Row(
          children: [
            Expanded(
              child: PageView(
                scrollDirection: Axis.vertical,
                controller: _fftPageController,
                onPageChanged: (int page) => setState(() => _currentFftPage = page),
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync, color: Colors.white, size: 40),
                    title: const Text('Roll Period (FFT)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: _fftRollPeriod != null
                        ? Text('${_fftRollPeriod!.toStringAsFixed(2)} s', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                        : _fftRollSamples.length == _fftWindowSize
                        ? const Text('Calculating...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                        : Text('Collecting (${_fftRollSamples.length}/$nb_sample)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync, color: Colors.white, size: 40),
                    title: const Text('Pitch Period (FFT)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: _fftPitchPeriod != null
                        ? Text('${_fftPitchPeriod!.toStringAsFixed(2)} s', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                        : _fftPitchSamples.length == _fftWindowSize
                        ? const Text('Calculating...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                        : Text('Collecting (${_fftPitchSamples.length}/$nb_sample)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(2, (int index) {
                  return Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentFftPage == index ? Colors.white : Colors.white.withOpacity(0.4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit le graphique des données
  Widget buildChart() {
    final rollChartData = _showRollData ? _rollData : <FlSpot>[];
    final pitchChartData = _showPitchData ? _pitchData : <FlSpot>[];

    final visibleData = [
      if (_showRollData) rollChartData,
      if (_showPitchData) pitchChartData,
    ].expand((x) => x).toList();

    final maxAbsY = visibleData.isNotEmpty
        ? visibleData.map((e) => e.y.abs()).reduce(max) * 1.2
        : 30;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 270,
        child: LineChart(
          LineChartData(
            minX: _getminVisibleDuration(),
            maxX: _getmaxVisibleDuration(),
            minY: -maxAbsY.toDouble(),
            maxY: maxAbsY.toDouble(),
            clipData: FlClipData.all(),
            lineBarsData: [
              LineChartBarData(
                spots: rollChartData,
                color: Colors.blue,
                barWidth: 2,
                isCurved: false,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
              LineChartBarData(
                spots: pitchChartData,
                color: Colors.green,
                barWidth: 2,
                isCurved: false,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: ((maxAbsY * 2) / 3).toDouble(),
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}°',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: _getTimeInterval().toDouble(),
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}s',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: (maxAbsY / 3).toDouble(),
              verticalInterval: _getTimeInterval().toDouble(),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((spot) {
                    final text = spot.barIndex == 0
                        ? 'Roll: ${spot.y.toStringAsFixed(2)}°'
                        : 'Pitch: ${spot.y.toStringAsFixed(2)}°';
                    return LineTooltipItem(
                      text,
                      TextStyle(
                        color: spot.barIndex == 0 ? Colors.blue : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =============================================
  // FONCTIONS UTILITAIRES
  // =============================================

  /// Retourne une couleur en fonction de l'angle (pour le dégradé)
  Color getSmoothColorForAngle(double? angle) {
    if (angle == null) return const Color(0xFF012169);
    double absAngle = angle.abs().clamp(0, 90);
    if (absAngle <= 40) return Color.lerp(Colors.green, Colors.orange, absAngle / 40)!;
    else if (absAngle <= 70) return Color.lerp(Colors.orange, Colors.red, (absAngle - 40) / 30)!;
    else return Colors.red;
  }

  /// Calcule l'intervalle de temps pour l'axe X du graphique
  double _getTimeInterval() {
    double totalSeconds = _rollData.isNotEmpty ? _rollData.last.x : 0;
    if (totalSeconds < 10) return 2.0;
    int lowerTen = (totalSeconds ~/ 10) * 10;
    return lowerTen / 5.0;
  }

  /// Retourne le temps minimum visible sur le graphique
  double _getminVisibleDuration() {
    if (_showRollData && _rollData.isNotEmpty) return _rollData.first.x;
    if (_showPitchData && _pitchData.isNotEmpty) return _pitchData.first.x;
    return 0;
  }

  /// Retourne le temps maximum visible sur le graphique
  double _getmaxVisibleDuration() {
    if (_showRollData && _rollData.isNotEmpty) return _rollData.last.x;
    if (_showPitchData && _pitchData.isNotEmpty) return _pitchData.last.x;
    return 10.0;
  }

  // =============================================
  // BUILD PRINCIPAL
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                rollAndPitchTiles(),
                RateAndSampleTiles(),
                rollingPeriodTile(_RollaveragePeriod,_PitchaveragePeriod),
                fftPeriodTile(),
                buildChart(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Clear button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearData,
                    child: const Text('Clear',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF012169))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0), // <<< AJOUT ICI
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Start/Pause button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasReachedSampleCount ? _savefunction : _toggleDataCollection,
                    child: Text(
                      _hasReachedSampleCount ? 'Save' : (_isCollectingData ? 'Pause' : 'Start'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _hasReachedSampleCount ? Colors.white : Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasReachedSampleCount ? Colors.green : const Color(0xFF012169),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Import/Export buttons
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.24),
                          blurRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        InkWell(
                          onTap: _handleImport,
                          child: const Icon(Icons.download,
                              color: Color(0xFF012169), size: 24),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: const Color(0xFF012169),
                        ),
                        InkWell(
                          onTap: _exportRollDataToDownloads,
                          child: const Icon(Icons.upload,
                              color: Color(0xFF012169), size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )

        ],
      ),
    );
  }
}