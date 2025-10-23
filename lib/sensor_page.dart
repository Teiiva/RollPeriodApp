import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/custom_app_bar.dart';
import 'fft_processor.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'models/saved_measurement.dart';
import 'package:provider/provider.dart';
import 'shared_data.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart'; // For getTemporaryDirectory
import 'package:share_plus/share_plus.dart'; // For Share
import 'package:file_picker/file_picker.dart';  // ✅ Ajoute cet import

class SensorPage extends StatefulWidget {
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;
  final Function(VesselProfile, LoadingCondition) onValuesChanged;

  const SensorPage({
    Key? key,
    required this.vesselProfile,
    required this.loadingCondition,
    required this.onValuesChanged,
  }) : super(key: key);

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  AccelerometerEvent? _accelerometer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isCollectingData = false;
  int _collectedSamples = 0;
  bool _showRollData = true;
  bool _showPitchData = true;
  double? _rollAngle;
  double? _pitchAngle;
  List<FlSpot> _rollData = [];
  List<FlSpot> _pitchData = [];
  double? _fftRollPeriod;
  double? _fftPitchPeriod;
  final List<double> _fftRollSamples = [];
  final List<double> _fftPitchSamples = [];
  double? _dynamicSampleRate = 5;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _fftTimer;
  Timer? _updateTimer;
  final Queue<DateTime> _timestampQueue = Queue<DateTime>();
  int _powerIndex = 3;
  final List<int> _powersOfTwo  = [512, 1024, 2048, 4096, 8192, 16384];
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
  double _visibleMinX = 0;
  double _visibleMaxX = 60;
  bool _isInteracting = false;
  double _previousScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  double _lastScale = 1.0;
  bool _useBaseChart = true;
  bool _hasDataToShare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLaunch());
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStyles();
  }
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

  void _toggleDataCollection() {
    final currentMinX = _visibleMinX;
    final currentMaxX = _visibleMaxX;

    setState(() {
      _isCollectingData = !_isCollectingData;
      _useBaseChart = _isCollectingData;

      _visibleMinX = currentMinX;
      _visibleMaxX = currentMaxX;
    });

    if (_isCollectingData) {
      _startDataCollection();
    } else {
      _stopDataCollection();
    }
  }
  void _startDataCollection() {
    _stopwatch.start();
    _timestampQueue.clear();
    _dynamicSampleRate = 5;

    _updateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_accelerometer != null && mounted) {
        _processAccelerometerData(_accelerometer!);
      }
    });

    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _accelerometer = event;
    });

    if (_fftRollSamples.length >= _fftWindowSize) {
      _computeFFTPeriod();
    }
  }
  void _stopDataCollection() {
    _updateTimer?.cancel();
    _resetChartZoom();
    _accelerometerSubscription?.cancel();
    _stopwatch.stop();
  }
  void _clearData() {
    if (mounted) {
      setState(() {
        _collectedSamples = 0;
        _rollData.clear();
        _pitchData.clear();
        _rollAngle = null;
        _pitchAngle = null;
        _clearFFTData();
        _dynamicSampleRate = 5;
        _showRollData = true;
        _showPitchData = true;
        _visibleMinX = 0;
        _visibleMaxX = 10;
        _useBaseChart = true;
        _hasDataToShare = false;
      });
    }
  }
  void _processAccelerometerData(AccelerometerEvent event) {
    _collectedSamples++;

    final timestamp = _stopwatch.elapsedMilliseconds / 1000.0;
    _rollAngle = calculateRoll(event);
    _pitchAngle = calculatePitch(event);

    if (_rollAngle == null || _pitchAngle == null) return;

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
    _rollData.add(FlSpot(timestamp, _rollAngle!));
    _pitchData.add(FlSpot(timestamp, _pitchAngle!));
    _prepareFFTData();
    if (mounted) setState(() {
      _hasDataToShare = _rollData.isNotEmpty;
    });
  }
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
  double? calculateRoll(AccelerometerEvent acc) {
    try {
      if (acc.x == 0 && acc.z == 0) return null;
      return atan2(acc.x, acc.z) * 180 / pi;
    } catch (e) {
      return null;
    }
  }
  double? calculatePitch(AccelerometerEvent acc) {
    try {
      if (acc.y == 0 && acc.z == 0) return null;
      return atan2(acc.y, acc.z) * 180 / pi;
    } catch (e) {
      return null;
    }
  }
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
  static double? _backgroundFFTCalculation(Map<String, dynamic> params) {
    final samples = List<double>.from(params['samples']);
    final sampleRate = (params['sampleRate'] as num).toDouble();
    return FFTProcessor.findRollingPeriod(samples, sampleRate);
  }
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
  void _savefunction() async {
    await _exportRollDataToDownloads();
    try {
      if (_fftRollPeriod == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No roll data to save')),
        );
        return;
      }

      double maxRoll = _rollData.isNotEmpty
          ? _rollData.map((spot) => spot.y.abs()).reduce(max)
          : 0.0;
      double maxPitch = _pitchData.isNotEmpty
          ? _pitchData.map((spot) => spot.y.abs()).reduce(max)
          : 0.0;

      double rmsRoll = _rollData.isNotEmpty
          ? sqrt(_rollData.map((spot) => spot.y * spot.y).reduce((a, b) => a + b) / _rollData.length)
          : 0.0;

      double rmsPitch = _pitchData.isNotEmpty
          ? sqrt(_pitchData.map((spot) => spot.y * spot.y).reduce((a, b) => a + b) / _pitchData.length)
          : 0.0;

      double duration = _rollData.isNotEmpty
          ? _rollData.last.x
          : 0.0;

      final predictionMethods = ['Roll Coefficient'];

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
        rollPeriodFFT: _fftRollPeriod,
        pitchPeriodFFT: _fftPitchPeriod,
        predictedRollPeriods: predictedPeriods,
        maxRoll: maxRoll,
        maxPitch: maxPitch,
        rmsRoll: rmsRoll,
        rmsPitch: rmsPitch,
        duration: duration,
      );

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
  double calculateRollPeriod(double gm, String method, double beam, double depth, double vcg, double draft) {
    if (gm <= 0) return 0;

    switch (method) {
      case 'Roll Coefficient':
        const k = 0.4;
        return 2 * k * beam / sqrt(gm);
      default:
        return 0;
    }
  }
  Future<void> _exportRollDataToDownloads() async {
    try {
      final buffer = StringBuffer();
      List<double> powerSpectrum = [];
      if (_fftRollSamples.isNotEmpty) {
        powerSpectrum = FFTProcessor.computePowerSpectrum(_fftRollSamples);
      }
      final now = DateTime.now();
      final sampleRate = _dynamicSampleRate;
      final rollCount = _rollData.length;
      final rollPeriodFFT = _fftRollPeriod?.toStringAsFixed(2);
      final pitchPeriodFFT = _fftPitchPeriod?.toStringAsFixed(2);
      final vessel = widget.vesselProfile;
      final loading = widget.loadingCondition;

      final duration = (sampleRate != null && sampleRate != 0)
          ? (rollCount / sampleRate).toStringAsFixed(2)
          : 'N/A';

      List<double> frequencies = [];
      if (powerSpectrum.isNotEmpty && sampleRate != null) {
        frequencies = List<double>.generate(
          powerSpectrum.length,
              (i) => i * sampleRate / (2 * powerSpectrum.length),
        );
      }

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
      ];

      buffer.writeln('time (s),roll (deg),pitch (deg),frequency (Hz),power_spectrum,metadata');
      final int maxLines = [
        _rollData.length,
        powerSpectrum.length,
        metadata.length
      ].reduce(max);

      for (int i = 0; i < maxLines; i++) {
        String line = '';
        if (i < _rollData.length) {
          final rollSpot = _rollData[i];
          final pitchSpot = i < _pitchData.length ? _pitchData[i] : FlSpot(rollSpot.x, 0);
          line += '${rollSpot.x.toStringAsFixed(3)},'
              '${rollSpot.y.toStringAsFixed(3)},'
              '${pitchSpot.y.toStringAsFixed(3)},';
        } else {
          line += ',,,';
        }
        if (i < powerSpectrum.length) {
          line += '${frequencies[i].toStringAsFixed(4)},'
              '${powerSpectrum[i].toStringAsFixed(6)},';
        } else {
          line += ',,';
        }
        if (i < metadata.length) {
          line += '${metadata[i]}';
        }
        buffer.writeln(line);
      }

      // ✅ OPTION SIMPLE : Sauvegarde dans le dossier temporaire + partage
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/sensor_data_${now.millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      // ✅ OPTION 2 : Sauvegarde dans le dossier documents de l'app
      final appDir = await getApplicationDocumentsDirectory();
      final appFile = File('${appDir.path}/sensor_data_${now.millisecondsSinceEpoch}.csv');
      await appFile.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported to app storage')),
        );
      }

      // ✅ OPTION 3 : Proposer le partage directement
      await Share.shareFiles(
        [file.path],
        text: 'RollPeriodApp - Sensor Data Export\n'
            'Vessel: ${vessel.name}\n'
            'Loading: ${loading.name}\n'
            'Duration: ${duration}s\n'
            'Roll Period: ${rollPeriodFFT ?? "N/A"}s',
        subject: 'Sensor Data from RollPeriodApp',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _handleImport() async {
    try {
      // ✅ UTILISATION SIMPLE DE FILEPICKER - PAS DE PERMISSION NÉCESSAIRE
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun fichier sélectionné')),
          );
        }
        return;
      }

      PlatformFile platformFile = result.files.first;

      if (platformFile.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: Fichier inaccessible')),
          );
        }
        return;
      }

      final List<FlSpot> importedRollData = [];
      final List<FlSpot> importedPitchData = [];
      double? firstTimestamp;

      final file = File(platformFile.path!);
      final contents = await file.readAsString();
      final lines = contents.split('\n');

      int validLines = 0;
      bool hasHeader = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');

        // Détecter l'en-tête
        if (i == 0 && (line.toLowerCase().contains('time') ||
            line.toLowerCase().contains('roll') ||
            line.toLowerCase().contains('pitch'))) {
          hasHeader = true;
          continue;
        }

        if (parts.length >= 3) {
          try {
            final timestamp = double.tryParse(parts[0].trim());
            final roll = double.tryParse(parts[1].trim());
            final pitch = double.tryParse(parts[2].trim());

            if (timestamp != null && roll != null && pitch != null) {
              firstTimestamp ??= timestamp;
              importedRollData.add(FlSpot(timestamp - firstTimestamp, roll));
              importedPitchData.add(FlSpot(timestamp - firstTimestamp, pitch));
              validLines++;
            }
          } catch (e) {
            debugPrint('Erreur ligne ${i + 1}: $e');
          }
        }
      }

      if (importedRollData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune donnée valide trouvée dans le CSV')),
          );
        }
        return;
      }

      // Calculer le sample rate
      if (importedRollData.length > 1) {
        final totalTime = importedRollData.last.x - importedRollData.first.x;
        if (totalTime > 0) {
          _dynamicSampleRate = (importedRollData.length - 1) / totalTime;
          debugPrint('Sample rate calculé: ${_dynamicSampleRate!.toStringAsFixed(2)} Hz');
        }
      }

      // Mettre à jour l'état
      if (mounted) {
        setState(() {
          _importedFileName = platformFile.name;
          _rollData = importedRollData;
          _pitchData = importedPitchData;
          _isCollectingData = false;
          _hasReachedSampleCount = true;
          _hasDataToShare = true;
          _useBaseChart = false;
        });

        _calculatePeriodFromImportedData();
        _resetChartZoom();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import réussi: $validLines points de données')),
        );
      }

    } catch (e) {
      debugPrint('Erreur import: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur import: ${e.toString()}')),
        );
      }
    }
  }

  void _calculatePeriodFromImportedData() {
    debugPrint("---------------------------------------------------------- IMPORT transfer au calcul ---------------------------------------------------");
    _stopwatch.reset();
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
    }
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];
    targets.add(
      TargetFocus(
        identify: "start_button",
        keyTarget: _startButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
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
                    "This chart shows roll angles (blue) and pitch angles (green) in real time. "
                        "You can navigate the graph using pinch-to-zoom gestures. Double-tap to reset the view.",
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
        enableOverlayTab: true,
      ),
    );
    targets.add(
      TargetFocus(
        identify: "clear_button",
        keyTarget: _clearButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
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
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
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
                          controller.skip();
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

  Widget rollAndPitchTiles() {
    return Row(
      children: [
        Expanded(child: rollTile(_rollAngle, key: _rollAngleButtonKey)),
        Expanded(child: pitchTile(_pitchAngle, key: _pitchAngleButtonKey)),
      ],
    );
  }
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
              Container(
                width: 1,
                height: BarHeight,
                color: Colors.white30,
              ),

              const SizedBox(width: 12),
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
              Container(
                width: 1,
                height: BarHeight,
                color: Colors.white30,
              ),

              const SizedBox(width: 12),
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
  Widget SampleTile() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
            minLeadingWidth: 0,
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
    int totalSamples = _powersOfTwo[_powerIndex];
    int collectedSamples = _collectedSamples;
    String timeText = '';

    if (_dynamicSampleRate != null && _dynamicSampleRate! > 0) {
      if (_isCollectingData || (_collectedSamples > 0 && !_isCollectingData)) {
        final remainingSamples = totalSamples - collectedSamples;
        final remainingTime = (remainingSamples / _dynamicSampleRate!).ceil();
        timeText = ' ${_formatTime(remainingTime)}';
      } else {
        final estimatedTime = (totalSamples / _dynamicSampleRate!).ceil();
        timeText = ' ${_formatTime(estimatedTime)}';
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
              Text('Measurement time left : $timeText', style: titleStyle.copyWith(color: isDarkMode ? Colors.grey[300] : Colors.white)),
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
          title: const Text('Measurement Time'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'We recommend a measurement time of 13min 40s for best prediction of roll and pitch periods.',
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  DropdownButton<int>(
                    value: selectedValue,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedValue = newValue;
                        });
                      }
                    },
                    items: availableSizes.map<DropdownMenuItem<int>>((int value) {
                      final timeEstimate = _dynamicSampleRate != null && _dynamicSampleRate! > 0
                          ? ' ${_formatTime((value / _dynamicSampleRate!).ceil())}'
                          : '';

                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(timeEstimate,
                            style: const TextStyle(fontSize: 14)),

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
        minLeadingWidth: 0,
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
        minLeadingWidth: 0,
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

  Widget buildChartbase() {
    final rollChartData = _showRollData ? _rollData : <FlSpot>[];
    final pitchChartData = _showPitchData ? _pitchData : <FlSpot>[];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final rollColor = _isCollectingData || _hasReachedSampleCount
        ? Colors.deepPurple
        : Colors.grey;
    final pitchColor = _isCollectingData || _hasReachedSampleCount
        ? Colors.teal
        : const Color(0xFF6F6F6F);
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
      color: backgroundColor,
      margin: EdgeInsets.all(margin),
      child: GestureDetector(
        onDoubleTap: _resetChartZoom,
        child: SizedBox(
          width: double.infinity,
          height: chartsize,
          child: Padding(
            key: _chartKey,
            padding: EdgeInsets.only(
              left: axechartpadding,
              top: sidechartpadding,
              right: sidechartpadding,
              bottom: axechartpadding,
            ),
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
                        style: chartlabel.copyWith(color: textColor),
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
                            style: chartlabel.copyWith(color: textColor),
                          );
                        } else {
                          int minutes = totalSeconds ~/ 60;
                          int seconds = totalSeconds % 60;
                          return Text(
                            '${minutes}min\n ${seconds}s',
                            textAlign: TextAlign.center,
                            style: chartlabel.copyWith(color: textColor),
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
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget buildChart() {
    final rollChartData = _showRollData ? _optimizeData(_rollData) : <FlSpot>[];
    final pitchChartData = _showPitchData ? _optimizeData(_pitchData) : <FlSpot>[];

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final rollColor = _isCollectingData || _hasReachedSampleCount
        ? Colors.deepPurple
        : Colors.grey;
    final pitchColor = _isCollectingData || _hasReachedSampleCount
        ? Colors.teal
        : const Color(0xFF6F6F6F);
    final backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final gridColor = isDarkMode
        ? Colors.grey[700]!.withOpacity(0.3)
        : Colors.grey.withOpacity(0.1);
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.withOpacity(0.2);
    final textColor = isDarkMode ? Colors.grey[300]! : Colors.grey;

    final visibleData = [
      if (_showRollData) rollChartData,
      if (_showPitchData) pitchChartData,
    ].expand((x) => x).toList();

    final maxAbsY = visibleData.isNotEmpty
        ? visibleData.map((e) => e.y.abs()).reduce(max) * 1.2
        : 30;

    final maxY = maxAbsY;
    final minY = -maxAbsY;

    return Card(
      color: backgroundColor,
      margin: EdgeInsets.all(margin),
      child: GestureDetector(
        onDoubleTap: _resetChartZoom,
        onScaleStart: (details) {
          _lastFocalPoint = details.focalPoint;
          _lastScale = 1.0;
        },
        onScaleUpdate: (details) {
          setState(() {
            final currentRange = _visibleMaxX - _visibleMinX;
            const minRangeX = 5.0;
            final totalDuration = visibleData.isNotEmpty
                ? visibleData.last.x - visibleData.first.x
                : 60.0;
            if (details.scale != 1.0) {
              final zoomFactor = 1 + (1 - details.scale) * 0.2;
              var newRange = (currentRange * zoomFactor)
                  .clamp(minRangeX, totalDuration);
              final centerX = (_visibleMinX + _visibleMaxX) / 2;
              _visibleMinX = centerX - newRange / 2;
              _visibleMaxX = centerX + newRange / 2;
            } else {
              final dx = details.focalPoint.dx - _lastFocalPoint.dx;
              final delta = -dx * 5;
              _visibleMinX = max(0, _visibleMinX + delta);
              _visibleMaxX = max(_visibleMinX + 1, _visibleMaxX + delta);
            }
          });
          _lastFocalPoint = details.focalPoint;
        },
        child: SizedBox(
          width: double.infinity,
          height: chartsize,
          child: Padding(
            key: _chartKey,
            padding: EdgeInsets.only(
              left: axechartpadding,
              top: sidechartpadding,
              right: sidechartpadding,
              bottom: axechartpadding,
            ),
            child: LineChart(
              LineChartData(
                minX: max(0, _visibleMinX),
                maxX: _visibleMaxX,
                minY: minY.toDouble(),
                maxY: maxY.toDouble(),
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
                      interval: ((maxY * 2) / 3).toDouble(),
                      reservedSize: axereservedsize,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}°',
                        style: chartlabel.copyWith(color: textColor),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: axereservedsize,
                      interval: (_visibleMaxX - _visibleMinX) / 5, // 🔹 fixe 5 ticks
                      getTitlesWidget: (value, meta) {
                        if (value < 0) return const SizedBox.shrink();
                        final proportion = (value - meta.min) / (meta.max - meta.min);
                        final realTime = _visibleMinX + proportion * (_visibleMaxX - _visibleMinX);
                        int totalSeconds = realTime.toInt();
                        if (totalSeconds < 60) {
                          return Text(
                            '${totalSeconds}s',
                            textAlign: TextAlign.center,
                            style: chartlabel.copyWith(color: textColor),
                          );
                        } else {
                          int minutes = totalSeconds ~/ 60;
                          int seconds = totalSeconds % 60;
                          return Text(
                            '${minutes}min\n${seconds}s',
                            textAlign: TextAlign.center,
                            style: chartlabel.copyWith(color: textColor),
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
                  horizontalInterval: (maxY / 3).toDouble(),
                  verticalInterval: (_visibleMaxX - _visibleMinX) / 8,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                lineTouchData: LineTouchData(enabled: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _resetChartZoom() {
    setState(() {
      _visibleMinX = _getminVisibleDuration();
      _visibleMaxX = _getmaxVisibleDuration();
    });
  }
  List<FlSpot> _optimizeData(List<FlSpot> data) {
    if (data.length < 2000) return data;
    final step = (data.length / 1000).ceil();
    return [
      for (int i = 0; i < data.length; i += step) data[i]
    ];
  }
  Color? getSmoothColorForAngle(double? angle, bool isVisible) {
    if (!isVisible) return Colors.grey[850];
    if (angle == null) return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]
        : Color(0xFF012169);
    double absAngle = angle.abs().clamp(0, 90);
    if (absAngle <= 40) return Color.lerp(Colors.green, Colors.orange, absAngle / 40)!;
    else if (absAngle <= 70) return Color.lerp(Colors.orange, Colors.red, (absAngle - 40) / 30)!;
    else return Colors.red;
  }
  double _getTimeInterval() {
    double totalSeconds = _rollData.isNotEmpty ? _rollData.last.x : 0;
    if (totalSeconds < 10) return 2.0;
    int lowerTen = (totalSeconds ~/ 10) * 10;
    return lowerTen / 5.0;
  }
  double _getminVisibleDuration() {
    if (_showRollData && _rollData.isNotEmpty) return _rollData.first.x;
    if (_showPitchData && _pitchData.isNotEmpty) return _pitchData.first.x;
    return 0;
  }
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
  void _shareData() async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/sensor_data_${DateTime.now().millisecondsSinceEpoch}.csv');
      final buffer = StringBuffer();
      List<double> powerSpectrum = [];
      if (_fftRollSamples.isNotEmpty) {
        powerSpectrum = FFTProcessor.computePowerSpectrum(_fftRollSamples);
      }
      final now = DateTime.now();
      final sampleRate = _dynamicSampleRate;
      final rollCount = _rollData.length;
      final rollPeriodFFT = _fftRollPeriod?.toStringAsFixed(2);
      final pitchPeriodFFT = _fftPitchPeriod?.toStringAsFixed(2);
      final vessel = widget.vesselProfile;
      final loading = widget.loadingCondition;
      final duration = (sampleRate != null && sampleRate != 0)
          ? (rollCount / sampleRate).toStringAsFixed(2)
          : 'N/A';
      List<double> frequencies = [];
      if (powerSpectrum.isNotEmpty && sampleRate != null) {
        frequencies = List<double>.generate(
          powerSpectrum.length,
              (i) => i * sampleRate / (2 * powerSpectrum.length),
        );
      }
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
      ];
      buffer.writeln('time (s),roll (deg),pitch (deg),frequency (Hz),power_spectrum,metadata');
      final int maxLines = [
        _rollData.length,
        powerSpectrum.length,
        metadata.length
      ].reduce(max);
      for (int i = 0; i < maxLines; i++) {
        String line = '';
        if (i < _rollData.length) {
          final rollSpot = _rollData[i];
          final pitchSpot = i < _pitchData.length ? _pitchData[i] : FlSpot(rollSpot.x, 0);
          line += '${rollSpot.x.toStringAsFixed(3)},'
              '${rollSpot.y.toStringAsFixed(3)},'
              '${pitchSpot.y.toStringAsFixed(3)},';
        } else {
          line += ',,,';
        }
        if (i < powerSpectrum.length) {
          line += '${frequencies[i].toStringAsFixed(4)},'
              '${powerSpectrum[i].toStringAsFixed(6)},';
        } else {
          line += ',,';
        }
        if (i < metadata.length) {
          line += '${metadata[i]}';
        }
        buffer.writeln(line);
      }
      await file.writeAsString(buffer.toString());
      await Share.shareFiles(
        [file.path],
        text: 'Sensor data export',
        subject: 'Sensor data from ${vessel.name} - ${loading.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }
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
                _useBaseChart ? buildChartbase() : buildChart(),
                Container(
                  margin: EdgeInsets.all(margin),
                  child: Row(
                    children: [
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
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _hasDataToShare ? _shareData : _handleImport,
                          key: _importButtonKey,
                          child: Text(
                              _hasDataToShare ? 'Share' : 'Import',
                              style: clear_importStyle.copyWith(
                                  color: isDarkMode ? Colors.grey[300] : Color(0xFF012169)
                              )
                          ),
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