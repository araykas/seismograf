import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';

class SessionDetailPage extends StatefulWidget {
  final int sessionId;

  const SessionDetailPage({required this.sessionId, super.key});

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late final DatabaseHelper _db;
  late Future<_SessionData> _sessionData;

  @override
  void initState() {
    super.initState();
    _db = DatabaseHelper();
    _sessionData = _loadSessionData();
  }

  Future<_SessionData> _loadSessionData() async {
    final session = await _db.getSession(widget.sessionId);
    final logs = await _db.getSessionLogs(widget.sessionId);

    if (session == null) {
      throw Exception('Session not found');
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < logs.length; i++) {
      final mag = (logs[i]['magnitude'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), mag));
    }

    return _SessionData(
      startTime: DateTime.parse(session['start_time'] as String),
      endTime: session['end_time'] != null
          ? DateTime.parse(session['end_time'] as String)
          : null,
      maxVibration: (session['max_vibration'] as num?)?.toDouble() ?? 0.0,
      avgVibration: (session['avg_vibration'] as num?)?.toDouble() ?? 0.0,
      spots: spots,
      logCount: logs.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Details'), centerTitle: true),
      body: FutureBuilder<_SessionData>(
        future: _sessionData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final duration = data.endTime != null
              ? data.endTime!.difference(data.startTime)
              : Duration.zero;
          final chartMaxY = max(data.maxVibration + 5, 10.0);
          final bottomInterval = data.spots.length > 100
              ? 20.0
              : data.spots.length > 50
              ? 10.0
              : 5.0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Session Info',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Start Time', data.startTime),
                          _buildInfoRow(
                            'End Time',
                            data.endTime ?? 'In Progress',
                          ),
                          _buildInfoRow(
                            'Duration',
                            '${duration.inMinutes}m ${duration.inSeconds % 60}s',
                          ),
                          _buildInfoRow(
                            'Max Vibration',
                            '${data.maxVibration.toStringAsFixed(2)} m/s²',
                          ),
                          _buildInfoRow(
                            'Avg Vibration',
                            '${data.avgVibration.toStringAsFixed(2)} m/s²',
                          ),
                          _buildInfoRow('Data Points', '${data.logCount}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Vibration Chart',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        height: 300,
                        child: data.spots.isEmpty
                            ? const Center(child: Text('No data available'))
                            : LineChart(
                                LineChartData(
                                  clipData: const FlClipData.all(),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (v) => FlLine(
                                      color: Colors.grey.shade300,
                                      strokeWidth: 0.8,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 5,
                                        reservedSize: 45,
                                        getTitlesWidget: (value, meta) => Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: bottomInterval,
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
                                  borderData: FlBorderData(show: true),
                                  minX: 0,
                                  maxX: data.spots.last.x,
                                  minY: 0,
                                  maxY: chartMaxY,
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: data.spots,
                                      isCurved: true,
                                      color: Colors.green,
                                      barWidth: 2.0,
                                      dotData: FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.green.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    final valueStr = value is DateTime
        ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}'
        : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(valueStr),
        ],
      ),
    );
  }
}

class _SessionData {
  final DateTime startTime;
  final DateTime? endTime;
  final double maxVibration;
  final double avgVibration;
  final List<FlSpot> spots;
  final int logCount;

  _SessionData({
    required this.startTime,
    required this.endTime,
    required this.maxVibration,
    required this.avgVibration,
    required this.spots,
    required this.logCount,
  });
}
