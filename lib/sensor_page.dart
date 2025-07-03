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
import 'models/saved_measurement.dart';
import 'package:provider/provider.dart';
import 'shared_data.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Page principale pour l'affichage et l'analyse des données des capteurs
class SensorPage extends StatefulWidget {
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;
  final NavigationInfo navigationInfo;
  final Function(VesselProfile, LoadingCondition, NavigationInfo) onValuesChanged;

  const SensorPage({
    Key? key,
    required this.vesselProfile,
    required this.loadingCondition,
    required this.navigationInfo,
    required this.onValuesChanged,
  }) : super(key: key);

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  // =============================================
  // CONSTANTES ET VARIABLES D'ÉTAT
  // =============================================

  // Données des capteurs
  AccelerometerEvent? _accelerometer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // États de l'application
  bool _isCollectingData = false;
  int _collectedSamples = 0; // Ajoutez cette ligne dans la section des variables d'état
  bool _showRollData = true;
  bool _showPitchData = true;

  // Angles calculés
  double? _rollAngle;
  double? _pitchAngle;

  // Données pour les graphiques
  List<FlSpot> _rollData = [];
  List<FlSpot> _pitchData = [];


  // Calcul des périodes (méthode FFT)
  double? _fftRollPeriod;
  double? _fftPitchPeriod;
  final List<double> _fftRollSamples = [];
  final List<double> _fftPitchSamples = [];
  double? _dynamicSampleRate = 5;

  // Timers et contrôleurs
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _fftTimer;
  Timer? _updateTimer;
  final Queue<DateTime> _timestampQueue = Queue<DateTime>();

  int _powerIndex = 3;
  final List<int> _powersOfTwo  = [512, 1024, 2048, 4096, 8192, 16384]; // Supprimer les autres options
  int get _fftWindowSize => _powersOfTwo[_powerIndex];
  bool _hasReachedSampleCount = false;

  late TutorialCoachMark tutorialCoachMark;
  bool _showTutorial = false;
  final GlobalKey _chartKey = GlobalKey();
  final GlobalKey _startButtonKey = GlobalKey();
  final GlobalKey _clearButtonKey = GlobalKey();
  final GlobalKey _importButtonKey = GlobalKey();
  final GlobalKey _rollAngleButtonKey = GlobalKey();
  final GlobalKey _pitchAngleButtonKey = GlobalKey();
  final GlobalKey _sampleButtonKey = GlobalKey();
  final GlobalKey _rollFftButtonKey = GlobalKey();
  final GlobalKey _pitchFftButtonKey = GlobalKey();



  final ScrollController _scrollController = ScrollController();

  List<TargetFocus> _targets = [];


  String? _importedFileName;
  String? _getImportedFileName() {
    return _importedFileName;
  }


  late TextStyle titleStyle;
  late TextStyle subtitleStyle;
  late TextStyle MaxsubtitleStyle;
  late TextStyle AngleStyle;
  late TextStyle StartStyle;
  late TextStyle clear_importStyle;
  late TextStyle chartlabel;
  late double iconsize;
  late double iconsleftgap;
  late double Horizontalpaddingintern;
  late double Verticalpaddingintern;
  late double BarVerticalpaddingintern;
  late double BarHeight;
  late double margin;
  late double chartsize;
  late double sidechartpadding;
  late double axechartpadding;
  late double axereservedsize;
  late double edgepadding;
  late double radius;
  late double screenHeight;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  // =============================================
  // LIFECYCLE METHODS
  // =============================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLaunch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStyles(); // ici, context est disponible
  }

  // Méthode pour mettre à jour les styles si nécessaire
  void _updateStyles() {
    print('Page Measure');
    final basscreenWidth = 411.42857142857144;
    final screenWidth = MediaQuery.of(context).size.width;
    print('screenWidth: ${screenWidth}');
    final screenHeight = MediaQuery.of(context).size.height;
    print('screenHeight: ${screenHeight}');
    final ratio = screenWidth/basscreenWidth;
    print('ratio: ${ratio}');
    setState(() {
      titleStyle = TextStyle(
        fontSize: 16.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      print('Title font size: ${titleStyle.fontSize}');
      MaxsubtitleStyle = TextStyle(
        fontSize: 14.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.white70,
      );
      print('MaxsubtitleStyle font size: ${MaxsubtitleStyle.fontSize}');
      subtitleStyle = TextStyle(
        fontSize: 14.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      );
      print('subtitleStyle font size: ${subtitleStyle.fontSize}');
      AngleStyle = TextStyle(
        fontSize: 24.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      print('AngleStyle font size: ${AngleStyle.fontSize}');
      StartStyle = TextStyle(
        fontSize: 16.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      print('StartStyle font size: ${StartStyle.fontSize}');
      clear_importStyle = TextStyle(
        fontSize: 16.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Color(0xFF012169),
      );
      print('clear_importStyle font size: ${clear_importStyle.fontSize}');
      iconsize = 40.0 * ratio;
      print('iconsize : ${iconsize}');
      iconsleftgap = 8.0 * ratio;
      print('iconsleftgap: ${iconsleftgap}');
      Horizontalpaddingintern = 12.0 * ratio;
      print('Horizontalpaddingintern: ${Horizontalpaddingintern}');
      Verticalpaddingintern = 6 * ratio;
      print('Verticalpaddingintern: ${Verticalpaddingintern}');
      BarHeight= 50 * ratio;
      print('BarHeight: ${BarHeight}');
      margin= 4 * ratio;
      print('margin: ${margin}');
      BarVerticalpaddingintern = 12 * ratio;
      print('BarVerticalpaddingintern: ${BarVerticalpaddingintern}');
      chartsize = 0.4623 * screenHeight -62.58;
      print('ChartSize: ${chartsize}');
      sidechartpadding = 30 * (ratio*ratio);
      print('sidechartpadding: ${sidechartpadding}');
      axechartpadding = 10 * ratio;
      print('axechartpadding: ${axechartpadding}');
      axereservedsize = 25 * ratio;
      print('axereservedsize: ${axereservedsize}');
      chartlabel = TextStyle(
        fontSize: 10.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );
      print('chartlabel font size: ${chartlabel.fontSize}');
      edgepadding = 10 * ratio;
      print('edgepadding: ${edgepadding}');
      radius = 12 * ratio;
      print('radius: ${radius}');
    });

  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _fftTimer?.cancel();
    super.dispose();
    _scrollController.dispose();
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
    _stopwatch.start();
    _timestampQueue.clear();
    _dynamicSampleRate = 5;

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

    // Démarrer le calcul FFT immédiatement si on a assez de données
    if (_fftRollSamples.length >= _fftWindowSize) {
      _computeFFTPeriod();
    }
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
        _collectedSamples = 0; // Ajoutez cette ligne
        _rollData.clear();
        _pitchData.clear();
        _rollAngle = null;
        _pitchAngle = null;
        _clearFFTData();
        _dynamicSampleRate = 5;
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
    _collectedSamples++; // Ajoutez cette ligne

    final timestamp = _stopwatch.elapsedMilliseconds / 1000.0;
    _rollAngle = calculateRoll(event);
    _pitchAngle = calculatePitch(event);

    if (_rollAngle == null || _pitchAngle == null) return;

    // Vérifie les alertes
    alertPageKey.currentState?.checkForAlert(
      rollAngle: _rollAngle!,
      vesselProfile: widget.vesselProfile,
      loadingCondition: widget.loadingCondition,
    );

    // Arrête la collecte si on a assez de points
    if (_rollData.length >= _powersOfTwo[_powerIndex]) {
      if (_isCollectingData) {
        setState(() {
          _hasReachedSampleCount = true;
        });
        _toggleDataCollection();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_powersOfTwo[_powerIndex]} samples collected - Stopping data collection')),
          );
        }
      }
      return;
    }

    // Ajoute les données aux listes
    _rollData.add(FlSpot(timestamp, _rollAngle!));
    _pitchData.add(FlSpot(timestamp, _pitchAngle!));


    // Préparation des données pour la FFT
    _prepareFFTData();

    if (mounted) setState(() {});
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


    // Calcul FFT final quand on a assez d'échantillons
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
      return null;
    }
  }

  /// Calcule l'angle de tangage (pitch) à partir des données de l'accéléromètre
  double? calculatePitch(AccelerometerEvent acc) {
    try {
      if (acc.y == 0 && acc.z == 0) return null;
      return atan2(acc.y, acc.z) * 180 / pi;
    } catch (e) {
      return null;
    }
  }

  /// Calcule les périodes avec la FFT
  void _computeFFTPeriod() async {
    debugPrint("---------------------------------------------------------- Compute fft period  ---------------------------------------------------");
    if (_fftRollSamples.length > 0) {
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
        });
      }
    }
  }

  /// Fonction de calcul FFT exécutée dans un isolate séparé
  static double? _backgroundFFTCalculation(Map<String, dynamic> params) {
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

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes}min ${remainingSeconds}s';
  }

  // =============================================
  // IMPORT/EXPORT DE DONNÉES
  // =============================================


  // sensor_page.dart
  void _savefunction() async {
    await _exportRollDataToDownloads();
    try {
      if (_fftRollPeriod == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No roll data to save')),
        );
        return;
      }

      final predictionMethods = ['Roll Coefficient','Doyere','JSRA','Beam','ITTC','Grin',];

      final predictedPeriods = <String, double>{};
      for (final method in predictionMethods) {
        predictedPeriods[method] = calculateRollPeriod(
          widget.loadingCondition.gm,
          method,
          widget.vesselProfile.beam,
          widget.vesselProfile.depth,
          widget.loadingCondition.vcg,
          widget.loadingCondition.draft,
        );
      }

      final measurement = SavedMeasurement(
        timestamp: DateTime.now(),
        vesselProfile: widget.vesselProfile,
        loadingCondition: widget.loadingCondition,
        navigationInfo: widget.navigationInfo,
        rollPeriodFFT: _fftRollPeriod,
        predictedRollPeriods: predictedPeriods,
      );

      // Utilisez Provider pour ajouter la mesure
      final sharedData = Provider.of<SharedData>(context, listen: false);
      await sharedData.addMeasurement(measurement);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurement saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save measurement: $e')),
        );
      }
    }
  }

// Ajoutez cette fonction utilitaire dans sensor_page.dart
  double calculateRollPeriod(double gm, String method, double beam, double depth, double vcg, double draft) {
    if (gm <= 0) return 0;

    switch (method) {
      case 'Roll Coefficient':
        const k = 0.4;
        return 2 * k * beam / sqrt(gm);
      case 'Doyere':
        const c = 0.29;
        return 2 * c * sqrt((pow(beam, 2) + 4 * pow(vcg, 2)) / gm);
      case 'JSRA':
        final k = 0.3437 + 0.024 * (beam / depth);
        return 2 * k * beam / sqrt(gm);
      case 'Beam':
        const k = 0.36;
        return 2 * k * sqrt((pow(beam, 2) + pow(depth, 2)) / gm);
      case 'ITTC':
        final kxx = sqrt((0.4 * pow(beam + depth, 2) + 0.6 * (pow(beam, 2) + pow(depth, 2) - pow(2 * depth / 2 - vcg, 2)) / 12));
        final axx = 0.05 * pow(beam, 2) / depth;
        return 2 * sqrt((pow(kxx, 2) + pow(axx, 2)) / sqrt(gm));
      case 'Grin':
        const beta = 11.0;
        final kxx = sqrt((pow(beam, 2) + pow(depth, 2)) / beta + pow(depth / 2 - vcg, 2));
        return 2 * kxx / sqrt(gm);
      default:
        return 0;
    }
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

      // Calcul du spectre de puissance si nécessaire
      List<double> powerSpectrum = [];
      if (_fftRollSamples.isNotEmpty) {
        powerSpectrum = FFTProcessor.computePowerSpectrum(_fftRollSamples);
      }
      // Données fixes
      final now = DateTime.now();
      final wavePeriod = widget.navigationInfo.wavePeriod;
      final direction = widget.navigationInfo.direction;
      final sampleRate = _dynamicSampleRate;
      final rollCount = _rollData.length;
      final rollPeriodFFT = _fftRollPeriod?.toStringAsFixed(2);
      final pitchPeriodFFT = _fftPitchPeriod?.toStringAsFixed(2);
      final vessel = widget.vesselProfile;
      final loading = widget.loadingCondition;
      final nav = widget.navigationInfo;

      final duration = (sampleRate != null && sampleRate != 0)
          ? (rollCount / sampleRate).toStringAsFixed(2)
          : 'N/A';

      // Fréquences pour le spectre
      List<double> frequencies = [];
      if (powerSpectrum.isNotEmpty && sampleRate != null) {
        frequencies = List<double>.generate(
          powerSpectrum.length,
              (i) => i * sampleRate / (2 * powerSpectrum.length),
        );
      }

      // Liste des métadonnées (clé: valeur)
      final metadata = [
        'Export Time: ${now.toIso8601String()}',
        'Sample Rate (Hz): $sampleRate',
        'Samples Count: $rollCount',
        'Duration (s): $duration',
        'Roll Period (FFT)(s): $rollPeriodFFT',
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

      // En-tête avec les nouvelles colonnes pour le spectre
      buffer.writeln('time (s),roll (deg),pitch (deg),frequency (Hz),power_spectrum,metadata');

      // Calcul du max entre toutes les données
      final int maxLines = [
        _rollData.length,
        powerSpectrum.length,
        metadata.length
      ].reduce(max);

      for (int i = 0; i < maxLines; i++) {
        String line = '';

        // Données temporelles (time, roll, pitch)
        if (i < _rollData.length) {
          final rollSpot = _rollData[i];
          final pitchSpot = i < _pitchData.length ? _pitchData[i] : FlSpot(rollSpot.x, 0);
          line += '${rollSpot.x.toStringAsFixed(3)},'
              '${rollSpot.y.toStringAsFixed(3)},'
              '${pitchSpot.y.toStringAsFixed(3)},';
        } else {
          line += ',,,'; // Pas de données temporelles pour cette ligne
        }

        // Données du spectre (fréquence, puissance)
        if (i < powerSpectrum.length) {
          line += '${frequencies[i].toStringAsFixed(4)},'
              '${powerSpectrum[i].toStringAsFixed(6)},';
        } else {
          line += ',,'; // Pas de données spectrales pour cette ligne
        }

        // Ajout de la métadonnée dans la colonne 6 si elle existe
        if (i < metadata.length) {
          line += '${metadata[i]}';
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
      setState(() {
        _importedFileName = result.files.single.name;
      });

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
          _hasReachedSampleCount = true;
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
    debugPrint("---------------------------------------------------------- IMPORT transfer au calcul ---------------------------------------------------");
    _stopwatch.reset();

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

    if (_fftRollSamples.length > 0 && _fftPitchSamples.length > 0) {
      _computeFFTPeriod();
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    bool firstLaunch = prefs.getBool('first_launch') ?? true;

    if (firstLaunch) {
      await prefs.setBool('first_launch', false);
      _showTutorial = true;
      _createTutorial();
      if (mounted) {
        tutorialCoachMark.show(context: context);
      }
    }
  }


  void _createTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      onClickTarget: (target) {
        debugPrint('onClickTarget: $target');
        _handleTargetScroll(target.identify);
      },
      targets: _createTargets(),
      colorShadow: Colors.black.withOpacity(0.8),
      paddingFocus: 0,
      opacityShadow: 0.8,
      focusAnimationDuration: const Duration(milliseconds: 600),
      unFocusAnimationDuration: const Duration(milliseconds: 400),
      onFinish: () {
        if (mounted) {
          setState(() {
            _showTutorial = false;
          });
        }
      },
    );
  }


  void _handleTargetScroll(String targetIdentify) {
    switch (targetIdentify) {
      case "start_button":
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      case "import_button":
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      case "clear_button":
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
    // Ajoutez d'autres cas au besoin
    }
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // Étape 1: Bouton Start
    targets.add(
      TargetFocus(
        identify: "start_button",
        keyTarget: _startButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Récupération du target courant via identify
              final target = targets.firstWhere((t) => t.identify == "start_button");
              final currentTargetIndex = targets.indexOf(target);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Press here to start collecting sensor data and display the roll and pitch curves.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Vérification qu'on ne dépasse pas la liste
                      if (currentTargetIndex < targets.length) {
                        _handleTargetScroll(targets[currentTargetIndex].identify);
                      }
                      controller.next();
                    },
                    child: const Text("Next"),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
      ),
    );

    //

    //Etape 2 : courbes
    targets.add(
      TargetFocus(
        identify: "chart",
        keyTarget: _chartKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "This chart displays the roll angles (blue) and pitch angles (green) in real time.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => controller.previous(),
                        child: const Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () => controller.next(),
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
        enableOverlayTab: true, // Permet de cliquer sur l'overlay
      ),
    );

    // Étape 3: Bouton clear
    targets.add(
      TargetFocus(
        identify: "clear_button",
        keyTarget: _clearButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Récupération du target courant via identify
              final target = targets.firstWhere((t) => t.identify == "clear_button");
              final currentTargetIndex = targets.indexOf(target);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Press here to clear the curves.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify, // Ajout de cette ligne
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Vérification qu'on ne dépasse pas la liste
                          if (currentTargetIndex < targets.length) {
                            _handleTargetScroll(targets[currentTargetIndex].identify);
                          }
                          controller.previous();
                        },
                        child: const Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.next();
                        },
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
      ),
    );


    // Étape 5: Bouton import
    targets.add(
      TargetFocus(
        identify: "import_button",
        keyTarget: _importButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              final target = targets.firstWhere((t) => t.identify == "import_button");
              final currentTargetIndex = targets.indexOf(target);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Press here to import data from a CSV file. The file must contain the following columns in this exact order: time (s), roll (°), and pitch (°) in the first three columns.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify, // Ajout de cette ligne
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          controller.previous();
                        },
                        child: const Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Vérification qu'on ne dépasse pas la liste
                          if (currentTargetIndex < targets.length) {
                            _handleTargetScroll(targets[currentTargetIndex].identify);
                          }
                          controller.next();
                        },
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
      ),
    );


    // Étape 6 : Roll angle
    targets.add(
      TargetFocus(
        identify: "roll_angle",
        keyTarget: _rollAngleButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Displays the live roll angle; press the button to show or hide the roll curve.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify, // Ajout de cette ligne
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          controller.previous(); // Retour à l'étape précédente
                        },
                        child: const Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.next(); // Passe à l'étape suivante (pitch)
                        },
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
      ),
    );

    // Étape 7: Pitch Angle
    targets.add(
      TargetFocus(
        identify: "pitch_tile",
        keyTarget: _pitchAngleButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              final target = targets.firstWhere((t) => t.identify == "pitch_tile");
              final currentTargetIndex = targets.indexOf(target);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Displays the live pitch angle; press the button to show or hide the pitch curve.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          controller.previous();
                        },
                        child: const Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.next();
                        },
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
      ),
    );



    // Étape 9 : sample
    targets.add(
      TargetFocus(
        identify: "sample_tile",
        keyTarget: _sampleButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Click to open a menu for selecting the number of samples, which determines the FFT measurement duration.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify, // Ajout de cette ligne
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          controller.previous(); // Retour à l'étape précédente
                        },
                        child: const Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.next(); // Termine le tutoriel
                        },
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
      ),
    );


// Étape 11 : Roll Pitch fft
    targets.add(
      TargetFocus(
        identify: "roll_fft",
        keyTarget: _rollFftButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Displays the actual rolling period value using spectral analysis.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify, // Ajout de cette ligne
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          controller.previous(); // Retour à l'étape précédente
                        },
                        child: const Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.next(); // Termine le tutoriel
                        },
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
      ),
    );

    // Étape 12 :  Pitch fft
    targets.add(
      TargetFocus(
        identify: "pitch_fft",
        keyTarget: _pitchFftButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Displays the actual pitch period value using spectral analysis.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify, // Ajout de cette ligne
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          controller.previous(); // Retour à l'étape précédente
                        },
                        child: const Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.skip(); // Termine le tutoriel
                        },
                        child: const Text("End"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: radius,
      ),
    );

    return targets;
  }

  // =============================================
  // WIDGETS DE L'INTERFACE UTILISATEUR
  // =============================================

  /// Affiche les tuiles Roll et Pitch côte à côte
  Widget rollAndPitchTiles() {
    return Row(
      children: [
        Expanded(child: rollTile(_rollAngle, key: _rollAngleButtonKey)),
        Expanded(child: pitchTile(_pitchAngle, key: _pitchAngleButtonKey)),
      ],
    );
  }

  /// Tuile d'affichage pour l'angle de roulis (roll)
  Widget rollTile(double? angle, {Key? key}) {
    double maxRoll = _rollData.isNotEmpty
        ? _rollData.map((spot) => spot.y.abs()).reduce(max)
        : 0.0;

    return Card(
      margin: EdgeInsets.all(margin),
      color: getSmoothColorForAngle(angle, _showRollData),
      child: InkWell(
        key: key,
        onTap: () => setState(() => _showRollData = !_showRollData),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Horizontalpaddingintern*0.5,vertical: Verticalpaddingintern*1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Texte à gauche
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Roll',
                        style: titleStyle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),

              // Barre verticale au centre
              Container(
                width: 1,
                height: BarHeight,
                color: Colors.white30,
              ),

              const SizedBox(width: 12),

              // Valeurs à droite
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showRollData
                          ? (angle != null ? '${angle.toStringAsFixed(1)}°' : "0.0°")
                          : 'OFF',
                      style: AngleStyle,
                    ),
                    Text(
                      'Max: ${maxRoll.toStringAsFixed(1)}°',
                      style: MaxsubtitleStyle,
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

  Widget pitchTile(double? angle, {Key? key}) {
    double maxPitch = _pitchData.isNotEmpty
        ? _pitchData.map((spot) => spot.y.abs()).reduce(max)
        : 0.0;

    return Card(
      margin: EdgeInsets.all(margin),
      color: getSmoothColorForAngle(angle, _showPitchData),
      child: InkWell(
        key: key,
        onTap: () => setState(() => _showPitchData = !_showPitchData),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Horizontalpaddingintern*0.5,vertical: Verticalpaddingintern*1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Texte à gauche
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Pitch',
                        style: titleStyle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              // Barre verticale au centre
              Container(
                width: 1,
                height: BarHeight,
                color: Colors.white30,
              ),

              const SizedBox(width: 12),

              // Valeurs à droite
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showPitchData
                          ? (angle != null ? '${angle.toStringAsFixed(1)}°' : "0.0°")
                          : 'OFF',
                      style: AngleStyle,
                    ),
                    Text(
                      'Max: ${maxPitch.toStringAsFixed(1)}°',
                      style:MaxsubtitleStyle,
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




  /// Tuile d'affichage du taux d'échantillonnage
  Widget SampleTile() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Cas d'un import de fichier
    if (_hasReachedSampleCount && _rollData.isNotEmpty && !_isCollectingData) {
      final fileName = _getImportedFileName();
      final sampleCount = _rollData.length;
      String timeEstimate = '';

      if (_dynamicSampleRate != null && _dynamicSampleRate! > 0) {
        final totalSeconds = (sampleCount / _dynamicSampleRate!).ceil();
        timeEstimate = ' (${_formatTime(totalSeconds)})';
      }

      return Card(
        margin: EdgeInsets.all(margin),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.blueGrey,
        child: InkWell(
          onTap: () {
            _showSampleSizeDialog(context);
          },
          child: ListTile(
            minLeadingWidth: 0, // ⬅️ Par exemple pour supprimer l’espace inutile
            horizontalTitleGap: iconsleftgap,
            key: _sampleButtonKey,
            contentPadding: EdgeInsets.symmetric(horizontal: Horizontalpaddingintern,vertical: Verticalpaddingintern),
            leading: Icon(Icons.file_upload, color: isDarkMode ? Colors.grey[300] : Colors.white, size: iconsize),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName ?? 'Imported Data',
                  style: titleStyle.copyWith(color: isDarkMode ? Colors.grey[300] : Colors.white),
                ),
                Text(
                  '$sampleCount samples$timeEstimate',
                  style: subtitleStyle.copyWith(color: isDarkMode ? Colors.grey[300] : Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Cas normal (mesure en direct)
    int totalSamples = _powersOfTwo[_powerIndex];
    int collectedSamples = _collectedSamples;
    String timeText = '';

    if (_dynamicSampleRate != null && _dynamicSampleRate! > 0) {
      if (_isCollectingData || (_collectedSamples > 0 && !_isCollectingData)) {
        // Pendant la collecte ou après pause
        final remainingSamples = totalSamples - collectedSamples;
        final remainingTime = (remainingSamples / _dynamicSampleRate!).ceil();
        timeText = ' (${_formatTime(remainingTime)})';
      } else {
        // Avant démarrage
        final estimatedTime = (totalSamples / _dynamicSampleRate!).ceil();
        timeText = ' (${_formatTime(estimatedTime)})';
      }
    }

    return Card(
      margin: EdgeInsets.all(margin),
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.blueGrey,
      child: InkWell(
        onTap: () {
          _showSampleSizeDialog(context);
        },
        child: ListTile(
          minLeadingWidth: 0,
          horizontalTitleGap: iconsleftgap,
          contentPadding: EdgeInsets.symmetric(horizontal: Horizontalpaddingintern,vertical: Verticalpaddingintern),
          key: _sampleButtonKey,
          leading: Icon(Icons.settings, color: isDarkMode ? Colors.grey[300] : Colors.white, size: iconsize),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sample Size', style: titleStyle.copyWith(color: isDarkMode ? Colors.grey[300] : Colors.white)),
              Text(
                '${_isCollectingData || _collectedSamples > 0 ? '$collectedSamples/$totalSamples' : totalSamples.toString()} samples$timeText',
                style: subtitleStyle.copyWith(color: isDarkMode ? Colors.grey[300] : Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSampleSizeDialog(BuildContext context) {
    final List<int> availableSizes = [512, 1024, 2048, 4096, 8192, 16384];
    int selectedValue = _powersOfTwo[_powerIndex];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Sample Size'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'We recommend keeping 4096 samples (about 15 minutes) for optimal FFT accuracy.',
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Changing this value will affect FFT calculation precision.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 20),
                  if (_dynamicSampleRate != null && _dynamicSampleRate! > 0)
                    Text(
                      'Current sampling rate: ${_dynamicSampleRate!.toStringAsFixed(2)} Hz',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 20),
                  DropdownButton<int>(
                    value: selectedValue,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedValue = newValue; // Met à jour visuellement
                        });
                      }
                    },
                    items: availableSizes.map<DropdownMenuItem<int>>((int value) {
                      final timeEstimate = _dynamicSampleRate != null && _dynamicSampleRate! > 0
                          ? ' (~${_formatTime((value / _dynamicSampleRate!).ceil())})'
                          : '';

                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value samples$timeEstimate',
                            style: const TextStyle(fontSize: 14)), // << taille définie ici),

                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {
                  _powerIndex = availableSizes.indexOf(selectedValue);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  Widget rollPeriodAndPitchPeriodTiles() {
    return Row(
      children: [
        Expanded(child: fftRollPeriodTile(key: _rollFftButtonKey)),
        Expanded(child: fftPitchPeriodTile(key: _pitchFftButtonKey)),
      ],
    );
  }



  Widget fftRollPeriodTile({Key? key}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Couleurs conditionnelles
    Color rollColor;
    if (_rollData.isEmpty) {
      rollColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]!
          : Colors.deepPurple;
    } else {
      rollColor = (_isCollectingData || _hasReachedSampleCount)
          ? (Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]!
          : Colors.deepPurple)
          : Colors.grey[850]!;
    }



    return Card(
      margin: EdgeInsets.all(margin),
      color: rollColor,
      child: ListTile(
        key: key,
        minLeadingWidth: 0, // ⬅️ Par exemple pour supprimer l’espace inutile
        horizontalTitleGap: iconsleftgap,
        contentPadding: EdgeInsets.symmetric(horizontal: Horizontalpaddingintern,vertical: Verticalpaddingintern),
        leading: Image.asset(
          'assets/icons/roll.png',
          width: iconsize,
          height: iconsize,
            color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.deepPurple : Colors.grey : Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roll Period', style: titleStyle.copyWith(color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.deepPurple : Colors.grey : Colors.white)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isCollectingData && _collectedSamples == 0 && _fftRollPeriod == null)
                  Text('...',
                      style: subtitleStyle.copyWith(color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.deepPurple : Colors.grey : Colors.white)),
                if ((_isCollectingData || _collectedSamples > 0) && _fftRollPeriod == null)
                  Text('Calculating...',
                      style: subtitleStyle.copyWith(color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.deepPurple : Colors.grey : Colors.white)),
                if (_fftRollPeriod != null)
                  Text('${_fftRollPeriod!.toStringAsFixed(1)} s',
                      style: subtitleStyle.copyWith(color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.deepPurple : const Color(0xFF505050) : Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget fftPitchPeriodTile({Key? key}) {
    // Couleurs conditionnelles
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color pitchColor;
    if (_rollData.isEmpty) {
      pitchColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]!
          : Colors.teal;
    } else {
      pitchColor = _isCollectingData || _hasReachedSampleCount
          ? (Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]!
          : Colors.teal)
          : Colors.grey[850]!;
    }


    return Card(
      margin: EdgeInsets.all(margin),
      color: pitchColor,
      child: ListTile(
        key: key,
        minLeadingWidth: 0, // ⬅️ Par exemple pour supprimer l’espace inutile
        horizontalTitleGap: iconsleftgap,
        contentPadding: EdgeInsets.symmetric(horizontal: Horizontalpaddingintern,vertical: Verticalpaddingintern),
        leading: Image.asset(
          'assets/icons/pitch.png',
          width: iconsize,
          height: iconsize,
            color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F) : Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pitch Period', style: titleStyle.copyWith(color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F) : Colors.white)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isCollectingData && _collectedSamples == 0 && _fftRollPeriod == null)
                  Text('...',
                      style: subtitleStyle.copyWith(color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F) : Colors.white)),
                if ((_isCollectingData || _collectedSamples > 0) && _fftPitchPeriod == null)
                  Text('Calculating...',
                      style: subtitleStyle.copyWith(color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F) : Colors.white)),
                if (_fftPitchPeriod != null)
                  Text('${_fftPitchPeriod!.toStringAsFixed(1)} s',
                      style: subtitleStyle.copyWith(color: isDarkMode ? _isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F) : Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construit le graphique des données dans une Card
  Widget buildChart() {
    final rollChartData = _showRollData ? _rollData : <FlSpot>[];
    final pitchChartData = _showPitchData ? _pitchData : <FlSpot>[];

    // Détecter le mode sombre
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Couleurs conditionnelles
    final rollColor = _isCollectingData || _hasReachedSampleCount
        ? Colors.deepPurple
        : Colors.grey;
    final pitchColor = _isCollectingData || _hasReachedSampleCount
        ? Colors.teal
        : const Color(0xFF6F6F6F);


    // Couleurs pour le mode sombre
    final backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final gridColor = isDarkMode ? Colors.grey[700]!.withOpacity(0.3) : Colors.grey.withOpacity(0.1);
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.withOpacity(0.2);
    final textColor = isDarkMode ? Colors.grey[300]! : Colors.grey;

    final visibleData = [
      if (_showRollData) rollChartData,
      if (_showPitchData) pitchChartData,
    ].expand((x) => x).toList();

    final maxAbsY = visibleData.isNotEmpty
        ? visibleData.map((e) => e.y.abs()).reduce(max) * 1.2
        : 30;

    return Card(
      color: backgroundColor, // Utiliser la couleur de fond en fonction du mode
      margin: EdgeInsets.all(margin),
      child: Padding(
        key: _chartKey,
        padding: EdgeInsets.only(
          left: axechartpadding,
          top: sidechartpadding,
          right: sidechartpadding,
          bottom: axechartpadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: chartsize,
              child: LineChart(
                LineChartData(
                  minX: _getminVisibleDuration(),
                  maxX: _getmaxVisibleDuration(),
                  minY: -maxAbsY.toDouble(),
                  maxY: maxAbsY.toDouble(),
                  clipData: FlClipData.all(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: pitchChartData,
                      color: pitchColor,
                      barWidth: 2,
                      isCurved: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: rollChartData,
                      color: rollColor,
                      barWidth: 2,
                      isCurved: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: ((maxAbsY * 2) / 3).toDouble(),
                        reservedSize: axereservedsize,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}°',
                          style: chartlabel.copyWith(color: textColor), // Ajouter la couleur du texte
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _getTimeInterval().toDouble(),
                        reservedSize: axereservedsize,
                        getTitlesWidget: (value, meta) {
                          final maxX = _getmaxVisibleDuration();
                          final epsilon = 0.01;

                          if ((value - maxX).abs() < epsilon) {
                            return const SizedBox.shrink();
                          }

                          int totalSeconds = value.toInt();
                          if (totalSeconds < 60) {
                            return Text(
                              '${totalSeconds}s',
                              textAlign: TextAlign.center,
                              style: chartlabel.copyWith(color: textColor), // Ajouter la couleur du texte
                            );
                          } else {
                            int minutes = totalSeconds ~/ 60;
                            int seconds = totalSeconds % 60;
                            return Text(
                              '${minutes}min\n ${seconds}s',
                              textAlign: TextAlign.center,
                              style: chartlabel.copyWith(color: textColor), // Ajouter la couleur du texte
                            );
                          }
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: (maxAbsY / 3).toDouble(),
                    verticalInterval: _getTimeInterval().toDouble(),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: gridColor, // Utiliser la couleur de grille en fonction du mode
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: gridColor, // Utiliser la couleur de grille en fonction du mode
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: borderColor, // Utiliser la couleur de bordure en fonction du mode
                      width: 1,
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // =============================================
  // FONCTIONS UTILITAIRES
  // =============================================

  /// Retourne une couleur en fonction de l'angle (pour le dégradé)
  Color? getSmoothColorForAngle(double? angle, bool isVisible) {
    if (!isVisible) return Colors.grey[850]; // Gris quand désactivé
    if (angle == null) return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]
        : Color(0xFF012169);
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

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Clear'),
          content: const Text('Are you sure you want to clear all data? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _clearData();
              },
            ),
          ],
        );
      },
    );
  }


  // =============================================
  // BUILD PRINCIPAL
  // =============================================

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              setState(() {
                _showTutorial = true;
                _createTutorial();
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ).then((_) {
                  if (mounted) {
                    tutorialCoachMark.show(context: context);
                  }
                });
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.all(edgepadding),
              children: [
                rollAndPitchTiles(),
                SampleTile(),
                rollPeriodAndPitchPeriodTiles(),
                buildChart(),
                Container(
                  margin: EdgeInsets.all(margin),
                  child: Row(
                    children: [
                      // Clear button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showClearConfirmationDialog,
                          key: _clearButtonKey,
                          child: Text('Clear', style: clear_importStyle.copyWith(color: isDarkMode ? Colors.grey[300] : Color(0xFF012169))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDarkMode ? Colors.grey[850] : Colors.white,
                            padding: EdgeInsets.symmetric(vertical: BarVerticalpaddingintern),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: margin*2),
                      // Start/Pause button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _hasReachedSampleCount
                              ? _savefunction
                              : _toggleDataCollection,
                          key: _startButtonKey,
                          child: Text(
                            _hasReachedSampleCount
                                ? 'Save'
                                : (_isCollectingData ? 'Pause' : 'Start'),
                            style: StartStyle,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasReachedSampleCount
                                ? Colors.green
                                : Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[700]
                                : const Color(0xFF012169),
                            padding: EdgeInsets.symmetric(vertical: BarVerticalpaddingintern),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: margin*2),
                      // Import button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleImport,
                          key: _importButtonKey,
                          child: Text('Import', style: clear_importStyle.copyWith(color: isDarkMode ? Colors.grey[300] : Color(0xFF012169))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDarkMode ? Colors.grey[850] : Colors.white,
                            padding: EdgeInsets.symmetric(vertical: BarVerticalpaddingintern),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius),
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

        ],
      ),
    );
  }
}