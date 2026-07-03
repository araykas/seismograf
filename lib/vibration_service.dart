import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class VibrationService {
  static const double defaultGravity = 9.81;
  static const int sampleWindow = 20;

  final List<double> _recentMagnitudes = [];
  double _gravityOffset = defaultGravity;

  double get gravityOffset => _gravityOffset;

  double computeRawMagnitude(AccelerometerEvent event) {
    return sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
  }

  double computeZeroedMagnitude(double rawMagnitude) {
    final value = rawMagnitude - _gravityOffset;
    return value < 0.0 ? 0.0 : value;
  }

  void addSample(double rawMagnitude) {
    _recentMagnitudes.add(rawMagnitude);
    if (_recentMagnitudes.length > sampleWindow) {
      _recentMagnitudes.removeAt(0);
    }
  }

  bool get hasCalibrationSamples => _recentMagnitudes.isNotEmpty;

  void calibrateFromRecentSamples() {
    if (_recentMagnitudes.isEmpty) {
      _gravityOffset = defaultGravity;
      return;
    }

    final sum = _recentMagnitudes.fold<double>(
      0.0,
      (prev, next) => prev + next,
    );
    _gravityOffset = sum / _recentMagnitudes.length;
  }

  void resetCalibration() {
    _gravityOffset = defaultGravity;
  }
}
