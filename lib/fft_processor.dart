import 'dart:math';

class FFTProcessor {
  // Cache pour les fenêtres de Hann pré-calculées
  static final _hannWindowCache = <int, List<double>>{};

  static List<double> _getHannWindow(int n) {
    return _hannWindowCache.putIfAbsent(n, () {
      return List<double>.generate(n, (i) {
        return 0.5 - 0.5 * cos(2 * pi * i / (n - 1));
      });
    });
  }

  // Version optimisée avec FFT réelle
  static List<double> computePowerSpectrum(List<double> samples) {
    final n = samples.length;
    final window = _getHannWindow(n);
    final spectrum = List<double>.filled(n ~/ 2, 0.0);

    // FFT réelle optimisée pour les signaux réels
    for (var k = 0; k < n ~/ 2; k++) {
      var sumReal = 0.0;
      var sumImag = 0.0;

      for (var t = 0; t < n; t++) {
        final angle = -2 * pi * k * t / n;
        final windowedSample = samples[t] * window[t];
        sumReal += windowedSample * cos(angle);
        sumImag += windowedSample * sin(angle);
      }

      spectrum[k] = sumReal * sumReal + sumImag * sumImag;
    }

    return spectrum;
  }

  // Spécialisé pour la détection de période de roulis maritime
  static double? findRollingPeriod(List<double> rollAngles, int sampleRate) {
    if (rollAngles.length < 256 || sampleRate <= 0) return null;

    // Filtrage passe-bas simple pour le roulis maritime (typiquement 0.1-0.5Hz)
    final filteredSamples = _lowPassFilter(rollAngles, sampleRate, cutoffFreq: 0.6);

    final spectrum = computePowerSpectrum(filteredSamples);
    final freqResolution = sampleRate / rollAngles.length;

    // Plage de fréquences pertinentes pour le roulis maritime (0.1Hz à 0.5Hz)
    final minIndex = max(1, (0.1 / freqResolution).round());
    final maxIndex = min((0.5 / freqResolution).round(), spectrum.length - 1);

    // Recherche du pic avec vérification de la qualité
    var maxPower = 0.0;
    var peakIndex = minIndex;

    for (var i = minIndex; i <= maxIndex; i++) {
      if (spectrum[i] > maxPower) {
        maxPower = spectrum[i];
        peakIndex = i;
      }
    }

    // Seuil de qualité (20% du max théorique)
    if (maxPower < 0.2 * rollAngles.length * rollAngles.length / 16) {
      return null;
    }

    // Interpolation parabolique pour précision
    final alpha = spectrum[peakIndex - 1];
    final beta = spectrum[peakIndex];
    final gamma = spectrum[peakIndex + 1];
    final delta = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma);

    final estimatedFreq = (peakIndex + delta) * freqResolution;
    return estimatedFreq > 0 ? 1.0 / estimatedFreq : null;
  }

  static List<double> _lowPassFilter(List<double> samples, int sampleRate, {double cutoffFreq = 0.5}) {
    final rc = 1.0 / (2 * pi * cutoffFreq);
    final dt = 1.0 / sampleRate;
    final alpha = dt / (rc + dt);

    final filtered = List<double>.filled(samples.length, 0.0);
    filtered[0] = samples[0];

    for (var i = 1; i < samples.length; i++) {
      filtered[i] = filtered[i-1] + alpha * (samples[i] - filtered[i-1]);
    }

    return filtered;
  }
}