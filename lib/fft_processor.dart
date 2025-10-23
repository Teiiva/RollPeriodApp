import 'dart:math';
import 'package:fftea/fftea.dart';
import 'package:flutter/cupertino.dart';

class FFTProcessor {
  static FFT _getFFT(int n) => FFT(n);
  static List<double> _polyDetrend(List<double> x, List<double> y) {
    final mean = y.reduce((a, b) => a + b) / y.length;
    return y.map((v) => v - mean).toList();
  }
  static List<double> computePowerSpectrum(List<double> samples, {bool applyWindow = false}) {
    final fft = _getFFT(samples.length);
    final spectrum = fft.realFft(samples);
    final powerSpectrum = List<double>.generate(spectrum.length ~/ 2, (i) {
      final c = spectrum[i];
      return c.x * c.x + c.y * c.y;
    });
    return powerSpectrum;
  }
  static double _splineInterpolation(List<double> spectrum, int peakIdx) {
    if (peakIdx <= 0 || peakIdx >= spectrum.length - 1) return 0.0;

    final left = spectrum[peakIdx - 1];
    final center = spectrum[peakIdx];
    final right = spectrum[peakIdx + 1];

    final numerator = right - left;
    final denominator = 2 * (2 * center - left - right);

    if (denominator == 0) return 0.0;
    return numerator / denominator;
  }
  static double? findDominantFrequency(
      List<double> powerSpectrum,
      double sampleRate,
      double signalLength, {
        double minFreq = 0.02,
        double maxFreq = 0.5,
      }) {
    final freqResolution = sampleRate / signalLength;
    final minIdx = (minFreq / freqResolution).floor().clamp(0, powerSpectrum.length - 1);
    final maxIdx = (maxFreq / freqResolution).ceil().clamp(0, powerSpectrum.length - 1);

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

    final delta = _splineInterpolation(powerSpectrum, peakIdx);
    final refinedFreq = (peakIdx + delta) * freqResolution;

    return refinedFreq;
  }

  static double? findRollingPeriod(List<double> rollAngles, double sampleRate) {
    debugPrint("len : ${rollAngles.length}, sample rate : ${sampleRate}");
    if (rollAngles.length < 512 || sampleRate <= 0) return null;

    final time = List.generate(rollAngles.length, (i) => i / sampleRate);
    final detrended = _polyDetrend(time, rollAngles);

    final spectrum = computePowerSpectrum(detrended);
    final dominantFreq = findDominantFrequency(
      spectrum,
      sampleRate,
      detrended.length.toDouble(),
    );

    if (dominantFreq != null && dominantFreq > 0) {
      return 1.0 / dominantFreq;
    }
    return null;
  }
}
