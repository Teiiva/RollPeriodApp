import 'dart:math';

class FFTProcessor {
  /// Applique une fenêtre de Hann pour réduire les artéfacts de bord.
  static List<double> applyHannWindow(List<double> samples) {
    final n = samples.length;
    return List.generate(n, (i) =>
    samples[i] * (0.5 - 0.5 * cos(2 * pi * i / (n - 1))));
  }

  /// Calcule le spectre de puissance (DFT) sur des données fenêtrées.
  static List<double> computePowerSpectrum(List<double> samples) {
    final n = samples.length;
    final spectrum = List<double>.filled(n ~/ 2, 0.0);

    for (var k = 0; k < n ~/ 2; k++) {
      var real = 0.0;
      var imag = 0.0;

      for (var t = 0; t < n; t++) {
        real += samples[t] * cos(2 * pi * k * t / n);
        imag -= samples[t] * sin(2 * pi * k * t / n);
      }

      spectrum[k] = sqrt(real * real + imag * imag);
    }

    return spectrum;
  }

  /// Trouve la fréquence dominante dans un signal échantillonné à [sampleRate] Hz.
  static double? findDominantFrequency(List<double> samples, int sampleRate) {
    if (samples.length < 64) return null;

    final windowed = applyHannWindow(samples);
    final spectrum = computePowerSpectrum(windowed);

    final minIndex = (0.2 * samples.length / sampleRate).round();
    final maxIndex = (5.0 * samples.length / sampleRate).round().clamp(0, spectrum.length - 1);

    var maxVal = 0.0;
    var dominantIndex = minIndex;

    for (var i = minIndex; i <= maxIndex; i++) {
      if (spectrum[i] > maxVal) {
        maxVal = spectrum[i];
        dominantIndex = i;
      }
    }

    if (dominantIndex == 0) return null;

    return dominantIndex * sampleRate / samples.length;
  }
}
