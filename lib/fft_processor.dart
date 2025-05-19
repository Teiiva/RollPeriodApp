import 'dart:math';
import 'package:fftea/fftea.dart';
import 'package:flutter/cupertino.dart';

class FFTProcessor {
  static final _fftCache = <int, FFT>{};
  static final _hannWindowCache = <int, List<double>>{};

  // Flag pour activer/désactiver les logs de debug
  static bool debug = false;

  static void log(String message) {
    if (debug) print(message);
  }

  // Récupère une FFT mise en cache pour la taille n
  static FFT _getFFT(int n) {
    return _fftCache.putIfAbsent(n, () {
      log('[FFT] Initialisation FFT pour taille=$n');
      return FFT(n);
    });
  }

  // Calcule (et met en cache) la fenêtre de Hann de taille n
  static List<double> _getHannWindow(int n) {
    return _hannWindowCache.putIfAbsent(n, () {
      log('[HANN] Calcul de la fenêtre de Hann pour n=$n');
      final window = List<double>.generate(n, (i) {
        return 0.5 - 0.5 * cos(2 * pi * i / (n - 1));
      });
      log('[HANN] Fenêtre générée : premiers éléments: ${window.take(5).toList()}');
      return window;
    });
  }

  // Applique la fenêtre de Hann IN PLACE sur la liste de samples
  static void applyHannWindowInPlace(List<double> samples) {
    final window = _getHannWindow(samples.length);
    for (int i = 0; i < samples.length; i++) {
      samples[i] *= window[i];
    }
  }

  // Calcule le spectre de puissance avec option d'appliquer ou non la fenêtre
  static List<double> computePowerSpectrum(List<double> samples, {bool applyWindow = true}) {
    if (samples.isEmpty) return [];

    final workingSamples = List<double>.from(samples);
    if (applyWindow) {
      applyHannWindowInPlace(workingSamples);
    }

    final fft = _getFFT(workingSamples.length);
    final spectrum = fft.realFft(workingSamples);

    // spectre de puissance = |complex|^2 pour chaque composante
    final powerSpectrum = List<double>.generate(spectrum.length ~/ 2, (i) {
      final c = spectrum[i];
      return c.x * c.x + c.y * c.y;
    });

    return powerSpectrum;
  }

  // Interpolation parabolique pour raffiner la localisation du pic
  static double _parabolicInterpolation(double y1, double y2, double y3) {
    final denom = y1 - 2 * y2 + y3;
    if (denom.abs() < 1e-10) return 0.0;
    return 0.5 * (y1 - y3) / denom;
  }

  // Recherche de la fréquence dominante dans le spectre
  static double? findDominantFrequency(
      List<double> powerSpectrum,
      double sampleRate,
      double signalLength, {
        double minFreq = 0.02,
        double maxFreq = 0.5,
      }) {
    if (powerSpectrum.isEmpty || sampleRate <= 0 || signalLength <= 0) {
      log('[FREQ] Paramètres invalides');
      return null;
    }

    final freqResolution = sampleRate / signalLength;
    final minIdx = (minFreq / freqResolution).floor().clamp(0, powerSpectrum.length - 1);
    final maxIdx = (maxFreq / freqResolution).ceil().clamp(0, powerSpectrum.length - 1);

    log('[FREQ] Résolution fréquentielle: $freqResolution Hz');
    log('[FREQ] Plage de recherche : indices $minIdx à $maxIdx');

    // Recherche indice max dans la plage
    final subSpectrum = powerSpectrum.sublist(minIdx, maxIdx + 1);
    if (subSpectrum.isEmpty) return null;

    int peakIdxRelative = 0;
    double maxPower = subSpectrum[0];
    for (int i = 1; i < subSpectrum.length; i++) {
      if (subSpectrum[i] > maxPower) {
        maxPower = subSpectrum[i];
        peakIdxRelative = i;
      }
    }
    final peakIdx = peakIdxRelative + minIdx;

    log('[FREQ] Pic brut trouvé à l’indice $peakIdx avec puissance $maxPower');

    if (peakIdx <= 0 || peakIdx >= powerSpectrum.length - 1) return null;

    final delta = _parabolicInterpolation(
      powerSpectrum[peakIdx - 1],
      powerSpectrum[peakIdx],
      powerSpectrum[peakIdx + 1],
    );

    final refinedFreq = (peakIdx + delta) * freqResolution;
    log('[FREQ] Fréquence dominante raffinée : $refinedFreq Hz');

    return refinedFreq;
  }

  // Filtrage passe-bas simple
  static List<double> _lowPassFilter(List<double> samples, double sampleRate, {double cutoffFreq = 0.5}) {
    if (samples.isEmpty) return [];

    final rc = 1.0 / (2 * pi * cutoffFreq);
    final dt = 1.0 / sampleRate;
    final alpha = dt / (rc + dt);

    log('[FILTRE] RC=$rc, dt=$dt, alpha=$alpha');

    final filtered = List<double>.filled(samples.length, 0.0);
    filtered[0] = samples[0];
    for (var i = 1; i < samples.length; i++) {
      filtered[i] = filtered[i - 1] + alpha * (samples[i] - filtered[i - 1]);
    }

    log('[FILTRE] Filtrage terminé');
    return filtered;
  }

  // Suppression des outliers par clamp autour de la moyenne ± seuil*écart-type
  static List<double> _removeOutliers(List<double> signal, double threshold) {
    if (signal.isEmpty) return [];

    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final variance = signal.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / signal.length;
    final std = sqrt(variance);

    final cleaned = signal.map((v) => v.clamp(mean - threshold * std, mean + threshold * std)).toList();

    log('[NETTOYAGE] Moyenne=$mean, Écart-type=$std, Seuil=$threshold');
    return cleaned;
  }

  // Detrending polynomial 2nd degré (x² + x + c) par moindres carrés
  static List<double> _polyDetrend(List<double> x, List<double> y) {
    final n = x.length;
    if (n < 3) return y;

    final sums = _calculatePolySums(x, y);
    final coeffs = _solvePolySystem(sums, n);
    log('[DETREND] Coefficients du polynôme : $coeffs');

    return List.generate(n, (i) {
      final xi = x[i];
      return y[i] - (coeffs[0] * xi * xi + coeffs[1] * xi + coeffs[2]);
    });
  }

  // Calcul des sommes nécessaires au système polynomial
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

  // Résolution système 3x3 par inversion matricielle simple
  static List<double> _solvePolySystem(List<double> sums, int n) {
    final A = [
      [sums[0], sums[1], sums[2]],
      [sums[1], sums[2], sums[3]],
      [sums[2], sums[3], n.toDouble()]
    ];
    final B = [sums[6], sums[5], sums[4]];

    final det = _matrixDet3(A);
    if (det.abs() < 1e-12) {
      log('[DETREND] Système mal conditionné, détection impossible');
      return [0, 0, 0];
    }

    final inv = _matrixInv3(A, det);
    return _matrixMultiply(inv, B);
  }

  // Déterminant matrice 3x3
  static double _matrixDet3(List<List<double>> m) {
    return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  }

  // Inverse matrice 3x3
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

  // Multiplication matrice 3x3 par vecteur 3x1
  static List<double> _matrixMultiply(List<List<double>> m, List<double> v) {
    return [
      m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
      m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
      m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ];
  }

  // Fonction principale pour trouver la période de roulis
  static double? findRollingPeriod(List<double> rollAngles, double sampleRate) {
    debugPrint('${sampleRate}');
    log('[PERIODE] Début du traitement du signal');
    if (rollAngles.length < 512 || sampleRate <= 0) {
      log('[PERIODE] Signal trop court ou sampleRate invalide');
      return null;
    }

    final filtered = _lowPassFilter(rollAngles, sampleRate, cutoffFreq: 0.8);
    final time = List.generate(filtered.length, (i) => i / sampleRate.toDouble());
    final detrended = _polyDetrend(time, filtered);
    final cleaned = _removeOutliers(detrended, 3.0);

    log('[PERIODE] Signal nettoyé. Longueur: ${cleaned.length}');

    final spectrum = computePowerSpectrum(cleaned);
    final dominantFreq = findDominantFrequency(
      spectrum,
      sampleRate.toDouble(),
      cleaned.length.toDouble(),
    );

    if (dominantFreq != null && dominantFreq > 0) {
      final period = 1.0 / dominantFreq;
      log('[PERIODE] Période de roulis estimée : $period s');
      return period;
    } else {
      log('[PERIODE] Aucune fréquence dominante trouvée');
      return null;
    }
  }
}
