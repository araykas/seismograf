import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'database_helper.dart';
import 'history_page.dart';
import 'vibration_service.dart';

void main() {
  runApp(const SeismografApp());
}

class SeismografApp extends StatelessWidget {
  const SeismografApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seismograf',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const SensorDashboardPage(),
    );
  }
}

class SensorDashboardPage extends StatefulWidget {
  const SensorDashboardPage({super.key});

  @override
  State<SensorDashboardPage> createState() => _SensorDashboardPageState();
}

class _SensorDashboardPageState extends State<SensorDashboardPage>
    with WidgetsBindingObserver {
  static const int _maxSpots = 50;
  static const Duration _minUpdateInterval = Duration(milliseconds: 200);
  static const Duration _recordingInterval = Duration(seconds: 1);

  final List<FlSpot> _spots = [];
  late final StreamSubscription<AccelerometerEvent> _sub;
  late final DatabaseHelper _db;
  final VibrationService _service = VibrationService();

  double _currentMagnitude = 0.0;
  double _currentRawMagnitude = 0.0;
  int _nextX = 0;
  DateTime _lastSetState = DateTime.fromMillisecondsSinceEpoch(0);

  // Recording variables
  bool _isRecording = false;
  int? _currentSessionId;
  Timer? _recordingTimer;
  final List<double> _samplesBuffer = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _db = DatabaseHelper();
    _sub = accelerometerEventStream().listen(_onSensorEvent);
  }

  @override
  void dispose() {
    _sub.cancel();
    if (_recordingTimer?.isActive ?? false) {
      _recordingTimer?.cancel();
    }
    _db.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _db.close();
    }
  }

  void _onSensorEvent(AccelerometerEvent event) {
    final rawMagnitude = _service.computeRawMagnitude(event);
    final mag = _service.computeZeroedMagnitude(rawMagnitude);

    _currentRawMagnitude = rawMagnitude;
    _currentMagnitude = mag;
    _service.addSample(rawMagnitude);

    if (_isRecording) {
      _samplesBuffer.add(mag);
    }

    final now = DateTime.now();
    if (now.difference(_lastSetState) < _minUpdateInterval) {
      return;
    }

    _lastSetState = now;

    if (!mounted) return;

    setState(() {
      _spots.add(FlSpot(_nextX.toDouble(), mag));
      _nextX++;
      if (_spots.length > _maxSpots) {
        _spots.removeAt(0);
      }
    });
  }

  Future<void> _startRecording() async {
    final startTime = DateTime.now().toIso8601String();
    _currentSessionId = await _db.createSession(startTime);

    _samplesBuffer.clear();

    _recordingTimer = Timer.periodic(_recordingInterval, (_) async {
      await _recordingTick();
    });

    if (!mounted) return;
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _recordingTick() async {
    if (_samplesBuffer.isEmpty) return;

    final peakMagnitude = _samplesBuffer.reduce((a, b) => a > b ? a : b);
    final timestamp = DateTime.now().toIso8601String();

    await _db.insertVibrationLog(
      _currentSessionId!,
      timestamp,
      peakMagnitude,
      0,
    );

    _samplesBuffer.clear();
  }

  Future<void> _snapData() async {
    if (!_isRecording || _currentMagnitude == 0.0) return;

    final timestamp = DateTime.now().toIso8601String();
    await _db.insertVibrationLog(
      _currentSessionId!,
      timestamp,
      _currentMagnitude,
      1,
    );

    if (!mounted) return;

    const snack = SnackBar(content: Text('Snap saved successfully'));
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    if (_currentSessionId == null) return;

    final stats = await _db.calculateSessionStats(_currentSessionId!);
    final maxVibration = (stats['max_mag'] as num?)?.toDouble() ?? 0.0;
    final avgVibration = (stats['avg_mag'] as num?)?.toDouble() ?? 0.0;
    final endTime = DateTime.now().toIso8601String();

    await _db.endSession(
      _currentSessionId!,
      endTime,
      maxVibration,
      avgVibration,
    );

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _currentSessionId = null;
      _samplesBuffer.clear();
    });

    if (!mounted) return;

    const snack = SnackBar(content: Text('Recording saved!'));
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  void _calibrateZero() {
    if (!_service.hasCalibrationSamples) {
      const snack = SnackBar(
        content: Text('Wait for a few sensor samples before zeroing.'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snack);
      return;
    }

    _service.calibrateFromRecentSamples();

    if (!mounted) return;

    final snack = SnackBar(
      content: Text(
        'Zeroing set to ${_fmt(_service.gravityOffset)} m/s². Device at rest will now read near 0.',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);

    setState(() {});
  }

  void _resetZero() {
    _service.resetCalibration();

    if (!mounted) return;

    const snack = SnackBar(
      content: Text('Zero reset to default gravity offset.'),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);

    setState(() {});
  }

  static String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final bool hasData = _spots.isNotEmpty;
    final double minX = hasData ? _spots.first.x : 0.0;
    final double maxX = hasData
        ? (_spots.length == 1 ? _spots.first.x + 1.0 : _spots.last.x)
        : _maxSpots.toDouble();
    final double maxY = max(
      12.0,
      hasData ? _spots.map((spot) => spot.y).reduce(max) + 6.0 : 12.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seismograf'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryPage()),
                  );
                },
                child: const Text('History'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Real-Time Vibration',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Live Vibration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_fmt(_currentMagnitude)} m/s²',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Chip(
                            label: Text(
                              _isRecording ? 'Recording' : 'Idle',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: _isRecording
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          FilledButton(
                            onPressed: _isRecording ? null : _startRecording,
                            child: const Text('Start Recording'),
                          ),
                          FilledButton.tonal(
                            onPressed: _isRecording ? _stopRecording : null,
                            child: const Text('Stop'),
                          ),
                          OutlinedButton(
                            onPressed: _isRecording ? _snapData : null,
                            child: const Text('Snap Data'),
                          ),
                          OutlinedButton(
                            onPressed: _calibrateZero,
                            child: const Text('Zeroing'),
                          ),
                          TextButton(
                            onPressed: _resetZero,
                            child: const Text('Reset Zero'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Baseline: ${_fmt(_service.gravityOffset)} m/s²',
                          ),
                          Text('Raw: ${_fmt(_currentRawMagnitude)} m/s²'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kalibrasi Zeroing saat perangkat diam untuk mengurangi efek gravitasi.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    height: 300,
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 0.8,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 5,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 10,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        minX: minX,
                        maxX: maxX,
                        minY: 0,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _spots,
                            isCurved: true,
                            color: Colors.blue.shade700,
                            barWidth: 2.5,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.shade300.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 12),
                          const SizedBox(width: 8),
                          const Text(
                            'Recording in progress...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: _isRecording
              ? Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _snapData,
                        child: const Text('Snap Data'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _stopRecording,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Stop Recording'),
                      ),
                    ),
                  ],
                )
              : FilledButton(
                  onPressed: _startRecording,
                  child: const Text('Start Recording'),
                ),
        ),
      ),
    );
  }
}
