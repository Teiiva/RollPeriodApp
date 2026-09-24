import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/custom_app_bar.dart';
import 'fft_processor.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
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
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'tutorial.dart';

class SensorPage extends StatefulWidget {
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;
  final Function(VesselProfile, LoadingCondition) onValuesChanged;

  const SensorPage({
    super.key,
    required this.vesselProfile,
    required this.loadingCondition,
    required this.onValuesChanged,
  });

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
  Timer? _updateTimer;
  final Queue<DateTime> _timestampQueue = Queue<DateTime>();
  int _powerIndex = 4;
  final List<int> _powersOfTwo  = [256, 512, 1024, 2048, 4096, 8192];
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
  final GlobalKey _vesselButtonKey = GlobalKey();
  final GlobalKey _loadingButtonKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String? _importedFileName;
  String? _getImportedFileName() {
    return _importedFileName;
  }
  late TextStyle titleStyle;
  late TextStyle subtitleStyle;
  late TextStyle maxSubtitleStyle;
  late TextStyle angleStyle;
  late TextStyle startStyle;
  late TextStyle clearImportStyle;
  late TextStyle chartlabel;
  late double iconsize;
  late double iconsleftgap;
  late double horizontalPaddingIntern;
  late double verticalPaddingIntern;
  late double barVerticalPaddingIntern;
  late double barHeight;
  late double margin;
  late double chartsize;
  late double sidechartpadding;
  late double axechartpadding;
  late double axereservedsize;
  late double edgepadding;
  late double radius;
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  double _visibleMinX = 0;
  double _visibleMaxX = 60;
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
    const basscreenWidth = 411.42857142857144;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final ratio = screenWidth/basscreenWidth;

    setState(() {
      titleStyle = TextStyle(
        fontSize: 16.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      maxSubtitleStyle = TextStyle(
        fontSize: 14.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      );
      subtitleStyle = TextStyle(
        fontSize: 14.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      );
      angleStyle = TextStyle(
        fontSize: 24.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      startStyle = TextStyle(
        fontSize: 16.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      clearImportStyle = TextStyle(
        fontSize: 16.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF012169),
      );
      iconsize = 40.0 * ratio;
      iconsleftgap = 8.0 * ratio;
      horizontalPaddingIntern = 12.0 * ratio;
      verticalPaddingIntern = 6 * ratio;
      barHeight= 50 * ratio;
      margin= 4 * ratio;
      barVerticalPaddingIntern = 12 * ratio;
      chartsize = 0.4623 * screenHeight -62.58;
      sidechartpadding = 30 * (ratio*ratio);
      axechartpadding = 10 * ratio;
      axereservedsize = 25 * ratio;
      chartlabel = TextStyle(
        fontSize: 10.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );
      edgepadding = 10 * ratio;
      radius = 12 * ratio;
    });

  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
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

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
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
    _stopDataCollection();
    if (mounted) {
      setState(() {
        _isCollectingData = false;
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

    if (_powersOfTwo.contains(_rollData.length)) {
      _computeFFTPeriod();
    }

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
    if (mounted) {
      setState(() {
        _hasDataToShare = _rollData.isNotEmpty;
      });
    }
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
    if (_fftRollSamples.isNotEmpty) {
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
      final vessel = context.read<VesselSelectionProvider>().currentVesselProfile!;
      final loading = context.read<VesselSelectionProvider>().currentLoadingCondition!;

      final predictedPeriods = <String, double>{};
      for (final method in predictionMethods) {
        predictedPeriods[method] = calculateRollPeriod(
          loading.gm,
          method,
          vessel.beam,
          vessel.depth,
          loading.vcg,
          loading.draft,
        );
      }
      final measurement = SavedMeasurement(
          timestamp: DateTime.now(),
          vesselProfile: vessel,
          loadingCondition: loading,
          rollPeriodFFT: _fftRollPeriod,
          pitchPeriodFFT: _fftPitchPeriod,
          predictedRollPeriods: predictedPeriods,
          maxRoll: maxRoll,
          maxPitch: maxPitch,
          rmsRoll: rmsRoll,
          rmsPitch: rmsPitch,
          duration: duration,
          dataroll: _rollData,
          datapitch: _pitchData
      );

      final sharedData = Provider.of<SharedData>(context, listen: false);
      await sharedData.addMeasurement(measurement);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurement saved internally')),
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

  Future<void> _exportRollDataAndShare() async {
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
      final vessel = context.read<VesselSelectionProvider>().currentVesselProfile!;
      final loading = context.read<VesselSelectionProvider>().currentLoadingCondition!;

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
        'Voyage Condition: ${loading.name}',
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
          line += metadata[i];
        }

        buffer.writeln(line);
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sensor_data_${now.millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'Exported Sensor Data', subject: 'Sensor Data Export');
      }
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No CSV file selected')),
          );
        }
        return;
      }
      final List<FlSpot> importedRollData = [];
      final List<FlSpot> importedPitchData = [];
      double? firstTimestamp;

      final file = File(result.files.single.path!);
      final contents = await file.readAsString();
      final lines = contents.split('\n');

      for (final line in lines.skip(1)) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 3) {
          try {
            final timestamp = double.parse(parts[0]);
            final roll = double.parse(parts[1]);
            final pitch = double.parse(parts[2]);
            firstTimestamp ??= timestamp;
            importedRollData.add(FlSpot(timestamp - (firstTimestamp), roll));
            importedPitchData.add(FlSpot(timestamp - (firstTimestamp), pitch));
          } catch (e) {
            debugPrint('Error parsing line : $line, error : $e');
          }
        }
      }

      if (importedRollData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid roll data found in CSV')),
          );
        }
        return;
      }
      setState(() {
        _importedFileName = result.files.single.name;
        _hasDataToShare = importedRollData.isNotEmpty;
      });
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
          _resetChartZoom();
          _useBaseChart = false;
          _hasDataToShare = true;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import success: ${importedRollData.length} points from ${file.path.split('/').last}')),
        );
      }
    } catch (e) {
      debugPrint('Import failed : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed : $e')),
        );
      }
    }
  }

  void _calculatePeriodFromImportedData() {
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

    if (_fftRollSamples.isNotEmpty && _fftPitchSamples.isNotEmpty) {
      _computeFFTPeriod();
    }
  }
  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    bool firstLaunch = prefs.getBool('first_launch') ?? true;

    if (firstLaunch) {
      await prefs.setBool('first_launch', false);
      setState(() {
        _showTutorial = true;
      });
      _createTutorial();
      if (mounted) {
        tutorialCoachMark.show(context: context);
      }
    }
  }
  void _createTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      /*onClickTarget: (target) {
        _handleTargetScroll(target.identify);
      },*/
      targets: _createTargets(),
      colorShadow: Colors.black.withValues(alpha: 0.8),
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

  // Tutorial but in another file : tutorial.dart
  // We send him data he need to complete
  List<TargetFocus> _createTargets() {
    return createTutorialTargets(
      startButtonKey: _startButtonKey,
      chartKey: _chartKey,
      clearButtonKey: _clearButtonKey,
      importButtonKey: _importButtonKey,
      rollAngleButtonKey: _rollAngleButtonKey,
      pitchAngleButtonKey: _pitchAngleButtonKey,
      sampleButtonKey: _sampleButtonKey,
      rollFftButtonKey: _rollFftButtonKey,
      pitchFftButtonKey: _pitchFftButtonKey,
      vesselButtonKey: _vesselButtonKey,
      loadingButtonKey: _loadingButtonKey,
      onTargetScroll: _handleTargetScroll,
      onGoToStep: (index) => tutorialCoachMark.goTo(index),
      radius: radius,
    );
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
          padding: EdgeInsets.symmetric(horizontal: horizontalPaddingIntern*0.5,vertical: verticalPaddingIntern*1.5),
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
                height: barHeight,
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
                      style: angleStyle,
                    ),
                    Text(
                      'Max: ${maxRoll.toStringAsFixed(1)}°',
                      style: maxSubtitleStyle,
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
          padding: EdgeInsets.symmetric(horizontal: horizontalPaddingIntern*0.5,vertical: verticalPaddingIntern*1.5),
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
                height: barHeight,
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
                      style: angleStyle,
                    ),
                    Text(
                      'Max: ${maxPitch.toStringAsFixed(1)}°',
                      style:maxSubtitleStyle,
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
  Widget sampleTile() {
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
            contentPadding: EdgeInsets.symmetric(horizontal: horizontalPaddingIntern,vertical: verticalPaddingIntern),
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
          contentPadding: EdgeInsets.symmetric(horizontal: horizontalPaddingIntern,vertical: verticalPaddingIntern),
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
    final List<int> availableSizes = [256, 512, 1024, 2048, 4096, 8192]; // Add less than one minute and remove 1h
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
                    'Recommended measurement time is 15min or longer',
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
                      String formatTimeRounded(int totalSeconds) {
                        // Round the measurement
                        final double totalMinutes = totalSeconds / 60.0;

                        const List<int> niceMinutes = [
                          1, 2, 3, 4, 5, 7, 10, 15, 20, 30, 40, 60 ];

                        final int roundedMinutes = niceMinutes.firstWhere(
                              (m) => m >= totalMinutes,
                          orElse: () => niceMinutes.last,
                        );

                        if (roundedMinutes >= 60) {
                          final int hours = roundedMinutes ~/ 60;
                          final int mins = roundedMinutes % 60;
                          return mins == 0 ? '${hours}h' : '${hours}h${mins}min';
                        }

                        return '${roundedMinutes}min';
                      }

                      final timeEstimate = _dynamicSampleRate != null && _dynamicSampleRate! > 0
                          ? ' ${formatTimeRounded((value / _dynamicSampleRate!).ceil())}'
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

    final rollFFTSpots = FFTProcessor.computePowerSpectrum(_rollData.map((spot) => spot.y).toList())
        .asMap().entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();

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
    return InkWell(
      // Add Roll period spectrum graph
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        _computeFFTPeriod();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Roll Spectrum'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.4,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildFFTChart(rollFFTSpots, Colors.deepPurple, label: 'Roll'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      child:Card(
        margin: EdgeInsets.all(margin),
        color: rollColor,
        child: ListTile(
          key: key,
          minLeadingWidth: 0,
          horizontalTitleGap: iconsleftgap,
          contentPadding: EdgeInsets.symmetric(horizontal: horizontalPaddingIntern,vertical: verticalPaddingIntern),
          leading: Image.asset(
              'assets/icons/roll.png',
              width: iconsize,
              height: iconsize,
              color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.deepPurple : Colors.grey) : Colors.white),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Roll Period', style: titleStyle.copyWith(color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.deepPurple : Colors.grey) : Colors.white)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isCollectingData && _collectedSamples == 0 && _fftRollPeriod == null)
                    Text('...',
                        style: subtitleStyle.copyWith(color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.deepPurple : Colors.grey) : Colors.white)),
                  if ((_isCollectingData || _collectedSamples > 0) && _fftRollPeriod == null)
                    Text('Calculating...',
                        style: subtitleStyle.copyWith(color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.deepPurple : Colors.grey) : Colors.white)),
                  if (_fftRollPeriod != null)
                    Text('${_fftRollPeriod!.toStringAsFixed(1)} s',
                        style: subtitleStyle.copyWith(color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.deepPurple : const Color(0xFF505050)) : Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget fftPitchPeriodTile({Key? key}) {
    final pitchFFTSpots = FFTProcessor.computePowerSpectrum(_pitchData.map((spot) => spot.y).toList())
        .asMap().entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
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


    return InkWell(
      // Add Pitch period spectrum graph
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        _computeFFTPeriod();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pitch Spectrum'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.4,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildFFTChart(pitchFFTSpots, Colors.teal, label: 'Pitch'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
      child:Card(
        margin: EdgeInsets.all(margin),
        color: pitchColor,
        child: ListTile(
          key: key,
          minLeadingWidth: 0,
          horizontalTitleGap: iconsleftgap,
          contentPadding: EdgeInsets.symmetric(horizontal: horizontalPaddingIntern,vertical: verticalPaddingIntern),
          leading: Image.asset(
              'assets/icons/pitch.png',
              width: iconsize,
              height: iconsize,
              color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F)) : Colors.white),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pitch Period', style: titleStyle.copyWith(color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F)) : Colors.white)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isCollectingData && _collectedSamples == 0 && _fftRollPeriod == null)
                    Text('...',
                        style: subtitleStyle.copyWith(color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F)) : Colors.white)),
                  if ((_isCollectingData || _collectedSamples > 0) && _fftPitchPeriod == null)
                    Text('Calculating...',
                        style: subtitleStyle.copyWith(color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F)) : Colors.white)),
                  if (_fftPitchPeriod != null)
                    Text('${_fftPitchPeriod!.toStringAsFixed(1)} s',
                        style: subtitleStyle.copyWith(color: isDarkMode ? (_isCollectingData || _collectedSamples==0 ? Colors.teal : const Color(0xFF6F6F6F)) : Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildFFTChart(List<FlSpot> data, Color color, {String label = ''}) {
    // Convert
    data = data.map((spot) => FlSpot(spot.x / (2 * pi), spot.y)).toList();
    //Graph for spectrum
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final gridColor = isDarkMode ? Colors.grey[700]!.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1);
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.withValues(alpha: 0.2);
    final textColor = isDarkMode ? Colors.grey[300]! : Colors.grey;

    //final maxX = data.isNotEmpty ? data.map((e) => e.x).reduce(max) : 1.0;
    final maxX = 7.0;
    final minX = maxX * 0.0;
    final displayedData = data.where((spot) => spot.x >= minX).toList();
    final maxY = displayedData.isNotEmpty ? displayedData.map((e) => e.y).reduce(max) * 1.2 : 1.0;
    final peakSpot = displayedData.isNotEmpty
        ? displayedData.reduce((a, b) => a.y > b.y ? a : b)
        : null;

    return Card(
      color: backgroundColor,
      margin: EdgeInsets.all(margin),
      child: SizedBox(
        width: double.infinity,
        height: chartsize,
        child: Padding(
          padding: EdgeInsets.only(
            left: axechartpadding,
            top: sidechartpadding,
            right: sidechartpadding,
            bottom: axechartpadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: data.isEmpty
                    ? Center(
                  child: Text(
                    'No data',
                    style: chartlabel.copyWith(color: textColor),
                  ),
                )
                    : LineChart(
                  LineChartData(
                    minX: minX,
                    maxX: maxX,
                    minY: 0,
                    maxY: maxY,
                    clipData: const FlClipData.all(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data,
                        color: color,
                        barWidth: 2,
                        isCurved: false,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withValues(alpha: 0.2),
                              color.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      if (peakSpot != null)
                        LineChartBarData(
                          spots: [peakSpot],
                          isCurved: false,
                          color: color,
                          barWidth: 0,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: color,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                        ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        /*axisNameWidget: Text(
                          'Deg/s',
                          style: chartlabel.copyWith(color: textColor, fontWeight: FontWeight.bold),
                        ),*/
                        /*axisNameSize: 20,
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: maxY > 0 ? maxY / 3 : 1,
                          reservedSize: axereservedsize,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(2),
                            style: chartlabel.copyWith(color: textColor),
                          ),
                        ),*/
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: Text(
                          'Hz',
                          style: chartlabel.copyWith(color: textColor, fontWeight: FontWeight.bold),
                        ),
                        axisNameSize: 20,
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: maxX > 0 ? maxX / 5 : 1,
                          reservedSize: axereservedsize,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(2),
                            textAlign: TextAlign.center,
                            style: chartlabel.copyWith(color: textColor),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: maxY > 0 ? maxY / 3 : 1,
                      verticalInterval: maxX > 0 ? maxX / 5 : 1,
                      getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 1),
                      getDrawingVerticalLine: (value) => FlLine(color: gridColor, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.x.toStringAsFixed(2)} Hz\n${(spot.y/1000).toStringAsFixed(0)}k',
                              TextStyle(color: isDarkMode ? Colors.black : Colors.white),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    final gridColor = isDarkMode ? Colors.grey[700]!.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1);
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.withValues(alpha: 0.2);
    final textColor = isDarkMode ? Colors.grey[300]! : Colors.grey;

    final visibleData = [
      if (_showRollData) ...rollChartData,
      if (_showPitchData) ...pitchChartData,
    ];

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
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: pitchChartData,
                    color: pitchColor,
                    barWidth: 2,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: rollChartData,
                    color: rollColor,
                    barWidth: 2,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
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
                        const epsilon = 0.01;

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
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                lineTouchData: const LineTouchData(
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
        ? Colors.grey[700]!.withValues(alpha: 0.3)
        : Colors.grey.withValues(alpha: 0.1);
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.withValues(alpha: 0.2);
    final textColor = isDarkMode ? Colors.grey[300]! : Colors.grey;

    final visibleData = [
      if (_showRollData) ...rollChartData,
      if (_showPitchData) ...pitchChartData,
    ];

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
          _visibleMinX = max(0, _visibleMinX);
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
            }
          });
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
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: pitchChartData,
                    color: pitchColor,
                    barWidth: 2,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: rollChartData,
                    color: rollColor,
                    barWidth: 2,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
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
                      interval: (_visibleMaxX - _visibleMinX) / 5,
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
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                lineTouchData: const LineTouchData(enabled: false),
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
    if (angle == null) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[700]
          : const Color(0xFF012169);
    }
    double absAngle = angle.abs().clamp(0, 90);
    if (absAngle <= 40) {
      return Color.lerp(Colors.green, Colors.orange, absAngle / 40);
    } else if (absAngle <= 70) {return Color.lerp(Colors.orange, Colors.red, (absAngle - 40) / 30);}
    else {return Colors.red;}
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

  void _finishCollection() async {
    if (!_isCollectingData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can only finish during data capture')),
      );
      return;
    }

    final int currentCount = _rollData.length;

    if (currentCount < _powersOfTwo.first) {
      final int targetSampleCount = _powersOfTwo.first;
      final double sampleInterval = (_dynamicSampleRate != null && _dynamicSampleRate! > 0)
          ? 1.0 / _dynamicSampleRate!
          : 0.2;

      double lastTimestamp = _rollData.isNotEmpty
          ? _rollData.last.x
          : _stopwatch.elapsedMilliseconds / 1000.0;

      final int remaining = targetSampleCount - currentCount;

      for (int i = 0; i < remaining; i++) {
        lastTimestamp += sampleInterval;
        _rollData.add(FlSpot(lastTimestamp, 0.0));
        _pitchData.add(FlSpot(lastTimestamp, 0.0));

        _fftRollSamples.add(0.0);
        _fftPitchSamples.add(0.0);

        if (_fftRollSamples.length > _fftWindowSize) {
          _fftRollSamples.removeAt(0);
        }
        if (_fftPitchSamples.length > _fftWindowSize) {
          _fftPitchSamples.removeAt(0);
        }
      }

      if (mounted) {
        setState(() {
          _collectedSamples = targetSampleCount;
          _hasReachedSampleCount = true;
          _rollAngle = 0.0;
          _pitchAngle = 0.0;
          _hasDataToShare = _rollData.isNotEmpty;
          _isCollectingData = false;
          _useBaseChart = false;
        });
      }

      _computeFFTPeriod();
      _stopDataCollection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Collection manually finished — $remaining sample(s) completed with 0')),
        );
      }
      return;
    }

    final int targetSampleCount = _powersOfTwo.lastWhere(
          (v) => v <= currentCount,
      orElse: () => _powersOfTwo.first,
    );

    final int removedCount = currentCount - targetSampleCount;

    if (removedCount > 0) {
      _rollData.removeRange(targetSampleCount, currentCount);
      _pitchData.removeRange(targetSampleCount, currentCount);
    }

    if (mounted) {
      setState(() {
        _collectedSamples = targetSampleCount;
        _hasReachedSampleCount = true;
        _rollAngle = 0.0;
        _pitchAngle = 0.0;
        _hasDataToShare = _rollData.isNotEmpty;
        _isCollectingData = false;
        _useBaseChart = false;
      });
    }

    _computeFFTPeriod();
    _stopDataCollection();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collection manually finished — $removedCount sample(s) discarded to keep $targetSampleCount')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        vesselButtonKey: _vesselButtonKey,
        loadingButtonKey: _loadingButtonKey,
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
                sampleTile(),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDarkMode ? Colors.grey[850] : Colors.white,
                            padding: EdgeInsets.symmetric(vertical: barVerticalPaddingIntern),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                          child: Text('Clear', style: clearImportStyle.copyWith(color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169))),
                        ),
                      ),
                      SizedBox(width: margin*2),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _hasReachedSampleCount
                              ? _savefunction
                              : _toggleDataCollection,
                          key: _startButtonKey,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasReachedSampleCount
                                ? Colors.green
                                : Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[700]
                                : const Color(0xFF012169),
                            padding: EdgeInsets.symmetric(vertical: barVerticalPaddingIntern),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                          child: Text(
                            _hasReachedSampleCount
                                ? 'Save'
                                : (_isCollectingData ? 'Pause' : 'Start'),
                            style: startStyle,
                          ),
                        ),
                      ),
                      SizedBox(width: margin*2),
                      Expanded(
                        child: ElevatedButton(
                          //onPressed: _hasDataToShare ? (_isCollectingData? _FinishCollection : _shareData)  : _handleImport,
                          onPressed: _hasDataToShare ? _finishCollection  : _handleImport,
                          key: _importButtonKey,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDarkMode ? Colors.grey[850] : Colors.white,
                            padding: EdgeInsets.symmetric(vertical: barVerticalPaddingIntern),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                          child: Text(
                            //_hasDataToShare ? (_isCollectingData? 'Finish' : 'Share') : 'Import',
                              _hasDataToShare ? 'Finish' : 'Import',
                              style: clearImportStyle.copyWith(
                                  color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)
                              )
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
