import 'dart:math';
import 'dart:io';
import 'package:fftea/fftea.dart';

class FFTProcessor {
  static final _fftCache = <int, FFT>{};
  static final _hannWindowCache = <int, List<double>>{};

  static FFT _getFFT(int n) {
    print('[FFT] Initialisation FFT pour taille=$n');
    return FFT(n); // Supposant que fftea gère les tailles arbitraires
  }

  static List<double> _getHannWindow(int n) {
    print('[HANN] Calcul de la fenêtre de Hann pour n=$n');
    return _hannWindowCache.putIfAbsent(n, () {
      final window = List<double>.generate(n, (i) {
        final value = 0.5 - 0.5 * cos(2 * pi * i / (n - 1));
        return value;
      });
      print('[HANN] Fenêtre générée : premiers éléments: ${window.take(5).toList()}');
      return window;
    });
  }

  static List<double> computePowerSpectrum(List<double> samples, {bool applyWindow = true}) {
    if (samples.isEmpty) return [];

    print('[SPECTRE] Taille originale conservée : ${samples.length}');

    final windowed = applyWindow ? _applyHannWindow(samples) : samples;

    // Utilise une FFT qui supporte les tailles arbitraires
    final fft = _getFFT(windowed.length);
    final spectrum = fft.realFft(windowed);

    final powerSpectrum = List.generate(spectrum.length ~/ 2, (i) {
      final complex = spectrum[i];
      return complex.x * complex.x + complex.y * complex.y;
    });

    return powerSpectrum;
  }

  static List<double> _applyHannWindow(List<double> samples) {
    final window = _getHannWindow(samples.length);
    return List.generate(samples.length, (i) => samples[i] * window[i]);
  }

  static double? _parabolicInterpolation(double y1, double y2, double y3) {
    final denom = y1 - 2 * y2 + y3;
    final delta = denom.abs() > 1e-10 ? 0.5 * (y1 - y3) / denom : 0.0;
    print('[PARABOLE] Interpolation : y1=$y1, y2=$y2, y3=$y3, delta=$delta');
    return delta;
  }

  static double? findDominantFrequency(List<double> powerSpectrum, double sampleRate, double signalLength, {
    double minFreq = 0.02,
    double maxFreq = 0.5,
  }) {
    if (powerSpectrum.isEmpty || sampleRate <= 0 || signalLength <= 0) {
      print('[FREQ] Paramètres invalides');
      return null;
    }

    final freqResolution = sampleRate / signalLength;
    final minIdx = (minFreq / freqResolution).floor();
    final maxIdx = (maxFreq / freqResolution).ceil();

    print('[FREQ] Résolution fréquentielle: $freqResolution Hz');
    print('[FREQ] Plage de recherche : indices $minIdx à $maxIdx');

    int peakIdx = minIdx;
    double maxPower = 0.0;

    for (int i = minIdx; i < maxIdx.clamp(0, powerSpectrum.length - 1); i++) {
      if (powerSpectrum[i] > maxPower) {
        maxPower = powerSpectrum[i];
        peakIdx = i;
      }
    }

    print('[FREQ] Pic brut trouvé à l’indice $peakIdx avec puissance $maxPower');

    if (peakIdx <= 0 || peakIdx >= powerSpectrum.length - 1) return null;

    final delta = _parabolicInterpolation(
        powerSpectrum[peakIdx - 1],
        powerSpectrum[peakIdx],
        powerSpectrum[peakIdx + 1]);

    final safeDelta = delta ?? 0.0;
    final dominantFreq = (peakIdx + safeDelta) * freqResolution;

    print('[FREQ] Fréquence dominante raffinée : $dominantFreq Hz');
    return dominantFreq;
  }

  static double? findRollingPeriod(List<double> rollAngles, int sampleRate) {
    print('[PERIODE] Début du traitement du signal');
    if (rollAngles.length < 512 || sampleRate <= 0) {
      print('[PERIODE] Signal trop court ou sampleRate invalide');
      return null;
    }

    final filtered = _lowPassFilter(rollAngles, sampleRate, cutoffFreq: 0.8);
    final time = List.generate(filtered.length, (i) => i / sampleRate.toDouble());
    final detrended = _polyDetrend(time, filtered);
    final cleaned = _removeOutliers(detrended, 3.0);

    print('[PERIODE] Signal nettoyé. Longueur: ${cleaned.length}');

    final spectrum = computePowerSpectrum(cleaned);
    final dominantFreq = findDominantFrequency(
      spectrum,
      sampleRate.toDouble(),
      cleaned.length.toDouble(),
    );

    if (dominantFreq != null && dominantFreq > 0) {
      final period = 1.0 / dominantFreq;
      print('[PERIODE] Période de roulis estimée : $period s');
      return period;
    } else {
      print('[PERIODE] Aucune fréquence dominante trouvée');
      return null;
    }
  }

  static List<double> _polyDetrend(List<double> x, List<double> y) {
    final n = x.length;
    if (n < 3) return y;

    final sums = _calculatePolySums(x, y);
    final coeffs = _solvePolySystem(sums, n);
    print('[DETREND] Coefficients du polynôme : $coeffs');

    return List.generate(n, (i) {
      final xi = x[i];
      return y[i] - (coeffs[0] * xi * xi + coeffs[1] * xi + coeffs[2]);
    });
  }

  static List<double> _calculatePolySums(List<double> x, List<double> y) {
    double sumX = 0, sumX2 = 0, sumX3 = 0, sumX4 = 0;
    double sumY = 0, sumXY = 0, sumX2Y = 0;

    for (int i = 0; i < x.length; i++) {
      final xi = x[i];
      final xi2 = xi * xi;
      final yi = y[i];

      sumX += xi;
      sumX2 += xi2;
      sumX3 += xi2 * xi;
      sumX4 += xi2 * xi2;
      sumY += yi;
      sumXY += xi * yi;
      sumX2Y += xi2 * yi;
    }

    return [sumX4, sumX3, sumX2, sumX, sumY, sumXY, sumX2Y];
  }

  static List<double> _solvePolySystem(List<double> sums, int n) {
    final A = [
      [sums[0], sums[1], sums[2]],
      [sums[1], sums[2], sums[3]],
      [sums[2], sums[3], n.toDouble()]
    ];
    final B = [sums[6], sums[5], sums[4]];

    final det = _matrixDet3(A);
    if (det.abs() < 1e-12) {
      print('[DETREND] Système mal conditionné, détection impossible');
      return [0, 0, 0];
    }

    final inv = _matrixInv3(A, det);
    final coeffs = _matrixMultiply(inv, B);
    return coeffs;
  }

  static double _matrixDet3(List<List<double>> m) {
    return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  }

  static List<List<double>> _matrixInv3(List<List<double>> m, double det) {
    return [
      [
        (m[1][1] * m[2][2] - m[1][2] * m[2][1]) / det,
        -(m[0][1] * m[2][2] - m[0][2] * m[2][1]) / det,
        (m[0][1] * m[1][2] - m[0][2] * m[1][1]) / det,
      ],
      [
        -(m[1][0] * m[2][2] - m[1][2] * m[2][0]) / det,
        (m[0][0] * m[2][2] - m[0][2] * m[2][0]) / det,
        -(m[0][0] * m[1][2] - m[0][2] * m[1][0]) / det,
      ],
      [
        (m[1][0] * m[2][1] - m[1][1] * m[2][0]) / det,
        -(m[0][0] * m[2][1] - m[0][1] * m[2][0]) / det,
        (m[0][0] * m[1][1] - m[0][1] * m[1][0]) / det,
      ],
    ];
  }

  static List<double> _matrixMultiply(List<List<double>> m, List<double> v) {
    return [
      m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
      m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
      m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ];
  }

  static List<double> _removeOutliers(List<double> signal, double threshold) {
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final std = sqrt(signal.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / signal.length);
    final cleaned = signal.map((v) => v.clamp(mean - threshold * std, mean + threshold * std)).toList();
    print('[NETTOYAGE] Moyenne=$mean, Écart-type=$std, Seuil=$threshold');
    return cleaned;
  }

  static List<double> _lowPassFilter(List<double> samples, int sampleRate, {double cutoffFreq = 0.5}) {
    final rc = 1.0 / (2 * pi * cutoffFreq);
    final dt = 1.0 / sampleRate;
    final alpha = dt / (rc + dt);
    print('[FILTRE] RC=$rc, dt=$dt, alpha=$alpha');

    final filtered = List<double>.filled(samples.length, 0.0);
    filtered[0] = samples[0];

    for (var i = 1; i < samples.length; i++) {
      filtered[i] = filtered[i - 1] + alpha * (samples[i] - filtered[i - 1]);
    }

    print('[FILTRE] Filtrage terminé');
    return filtered;
  }
}
