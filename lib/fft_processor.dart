import 'dart:math';

class FFTProcessor {
  static final _hannWindowCache = <int, List<double>>{};

  static List<double> _getHannWindow(int n) {
    return _hannWindowCache.putIfAbsent(n, () {
      return List<double>.generate(n, (i) {
        return 0.5 - 0.5 * cos(2 * pi * i / (n - 1));
      });
    });
  }

  static List<double> _polyDetrend(List<double> x, List<double> y) {
    // Fit ax^2 + bx + c
    final n = x.length;
    if (n < 3) return y;

    final sumX = x.reduce((a, b) => a + b);
    final sumX2 = x.map((xi) => xi * xi).reduce((a, b) => a + b);
    final sumX3 = x.map((xi) => pow(xi, 3).toDouble()).reduce((a, b) => a + b);
    final sumX4 = x.map((xi) => pow(xi, 4).toDouble()).reduce((a, b) => a + b);
    final sumY = y.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => x[i] * y[i]).reduce((a, b) => a + b);
    final sumX2Y = List.generate(n, (i) => x[i] * x[i] * y[i]).reduce((a, b) => a + b);

    final A = [
      [sumX4, sumX3, sumX2],
      [sumX3, sumX2, sumX],
      [sumX2, sumX,  n.toDouble()]
    ];
    final B = [sumX2Y, sumXY, sumY];

    // Solve system (could use more stable method)
    final det = (A[0][0] * (A[1][1] * A[2][2] - A[1][2] * A[2][1])
        - A[0][1] * (A[1][0] * A[2][2] - A[1][2] * A[2][0])
        + A[0][2] * (A[1][0] * A[2][1] - A[1][1] * A[2][0]));

    if (det.abs() < 1e-12) return y;

    final inv = List.generate(3, (_) => List.filled(3, 0.0));
    // Inverse manually (Cramer's rule or similar)
    inv[0][0] =  (A[1][1] * A[2][2] - A[1][2] * A[2][1]) / det;
    inv[0][1] = -(A[0][1] * A[2][2] - A[0][2] * A[2][1]) / det;
    inv[0][2] =  (A[0][1] * A[1][2] - A[0][2] * A[1][1]) / det;
    inv[1][0] = -(A[1][0] * A[2][2] - A[1][2] * A[2][0]) / det;
    inv[1][1] =  (A[0][0] * A[2][2] - A[0][2] * A[2][0]) / det;
    inv[1][2] = -(A[0][0] * A[1][2] - A[0][2] * A[1][0]) / det;
    inv[2][0] =  (A[1][0] * A[2][1] - A[1][1] * A[2][0]) / det;
    inv[2][1] = -(A[0][0] * A[2][1] - A[0][1] * A[2][0]) / det;
    inv[2][2] =  (A[0][0] * A[1][1] - A[0][1] * A[1][0]) / det;

    final coeffs = List.filled(3, 0.0);
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        coeffs[i] += inv[i][j] * B[j];
      }
    }

    return List.generate(n, (i) {
      final xi = x[i];
      final trend = coeffs[0] * xi * xi + coeffs[1] * xi + coeffs[2];
      return y[i] - trend;
    });
  }

  static List<double> _removeOutliers(List<double> signal, double threshold) {
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final std = sqrt(signal.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / signal.length);
    return signal.map((v) => v.clamp(mean - threshold * std, mean + threshold * std)).toList();
  }

  static List<double> computePowerSpectrum(List<double> samples) {
    final n = samples.length;
    final window = _getHannWindow(n);
    final spectrum = List<double>.filled(n ~/ 2, 0.0);

    for (var k = 0; k < n ~/ 2; k++) {
      var real = 0.0;
      var imag = 0.0;
      for (var t = 0; t < n; t++) {
        final angle = -2 * pi * k * t / n;
        final x = samples[t] * window[t];
        real += x * cos(angle);
        imag += x * sin(angle);
      }
      spectrum[k] = real * real + imag * imag;
    }

    return spectrum;
  }

  static double? findRollingPeriod(List<double> rollAngles, int sampleRate) {
    if (rollAngles.length < 512 || sampleRate <= 0) return null;

    final n = rollAngles.length;
    final dt = 1.0 / sampleRate;
    final time = List.generate(n, (i) => i * dt);

    // Filtrage
    final filtered = _lowPassFilter(rollAngles, sampleRate, cutoffFreq: 0.8);

    // Detrend
    final detrended = _polyDetrend(time, filtered);

    // Nettoyage
    final cleaned = _removeOutliers(detrended, 3.0);

    // FFT
    final spectrum = computePowerSpectrum(cleaned);
    final freqResolution = sampleRate / n;

    final minIdx = (0.02 / freqResolution).floor();
    final maxIdx = (0.5 / freqResolution).ceil().clamp(0, spectrum.length - 1);


    int peakIndex = minIdx;
    double maxPower = 0.0;
    for (int i = minIdx; i <= maxIdx; i++) {
      if (spectrum[i] > maxPower) {
        maxPower = spectrum[i];
        peakIndex = i;
      }
    }

    // Parabole pour raffiner la fréquence
    if (peakIndex <= 0 || peakIndex >= spectrum.length - 1) return null;

    final alpha = spectrum[peakIndex - 1];
    final beta = spectrum[peakIndex];
    final gamma = spectrum[peakIndex + 1];
    final denom = alpha - 2 * beta + gamma;

    double delta = 0.0;
    if (denom != 0) {
      delta = 0.5 * (alpha - gamma) / denom;
    }

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
      filtered[i] = filtered[i - 1] + alpha * (samples[i] - filtered[i - 1]);
    }

    return filtered;
  }
}
