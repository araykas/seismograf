import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'session_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final DatabaseHelper _db;
  late Future<List<Map<String, dynamic>>> _sessions;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _db = DatabaseHelper();
    _sessions = _db.getAllSessions();
  }

  void _refreshSessions() {
    setState(() {
      _sessions = _db.getSessionsBetweenDates(start: _startDate, end: _endDate);
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _startDate ?? now.subtract(const Duration(days: 7));
    final initialEnd = _endDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _sessions = _db.getSessionsBetweenDates(
          start: _startDate,
          end: _endDate,
        );
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _sessions = _db.getAllSessions();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteSession(int sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.deleteSession(sessionId);
        _refreshSessions();

        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting session: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring History'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _pickDateRange,
            tooltip: 'Filter by date range',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sessions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return Center(
              child: Text(
                _startDate != null && _endDate != null
                    ? 'No sessions found for the selected date range.'
                    : 'No sessions recorded yet.',
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_startDate != null && _endDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Filter: ${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearDateFilter,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: sessions.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final sessionId = session['id'] as int;
                    final startTime = DateTime.parse(
                      session['start_time'] as String,
                    );
                    final endTime = session['end_time'] != null
                        ? DateTime.parse(session['end_time'] as String)
                        : null;
                    final maxVib =
                        (session['max_vibration'] as num?)?.toDouble() ?? 0.0;
                    final avgVib =
                        (session['avg_vibration'] as num?)?.toDouble() ?? 0.0;

                    final duration = endTime != null
                        ? endTime.difference(startTime)
                        : Duration.zero;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SessionDetailPage(sessionId: sessionId),
                            ),
                          );
                        },
                        title: Text(
                          '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')} '
                          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:${startTime.second.toString().padLeft(2, '0')}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s',
                            ),
                            Text('Max: ${maxVib.toStringAsFixed(2)} m/s²'),
                            Text('Avg: ${avgVib.toStringAsFixed(2)} m/s²'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteSession(sessionId),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
