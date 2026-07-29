import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/session.dart';
import '../services/interview_engine.dart';
import '../services/storage_service.dart';
import 'report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<InterviewSession>? _sessions;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await StorageService.loadSessions();
    final profile = await StorageService.loadProfile();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _profile = profile;
      });
    }
  }

  Color _decisionColor(String? d) => switch (d) {
        'strong_hire' || 'hire' => Ink.green,
        'borderline' => Ink.amber,
        'reject' => Ink.red,
        _ => Ink.steel,
      };

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    final reported = (sessions ?? [])
        .where((s) => s.report != null)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('HISTORY & PROGRESS')),
      body: sessions == null
          ? const Center(child: CircularProgressIndicator(color: Ink.ink))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Eyebrow('Overall score across interviews'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: reported.isEmpty
                        ? const Text('Complete an interview to start your trend line.',
                            style: TextStyle(color: Ink.steel, fontSize: 13))
                        : SizedBox(
                            height: 150,
                            child: CustomPaint(
                              size: const Size(double.infinity, 150),
                              painter: _TrendPainter(reported),
                            ),
                          ),
                  ),
                ),
                if (reported.length >= 2) ...[
                  const SizedBox(height: 8),
                  _dimensionDeltas(reported),
                ],
                const SizedBox(height: 22),
                const Eyebrow('What the coach knows about you'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _profile.isEmpty
                        ? const Text(
                            'After your first completed interview, the coach builds a profile here '
                            'and uses it to personalize every future interview.',
                            style: TextStyle(color: Ink.steel, fontSize: 13))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _profileLine('Recurring strengths',
                                  _profile['recurring_strengths']),
                              _profileLine('Recurring weaknesses',
                                  _profile['recurring_weaknesses']),
                              _profileLine('Mastered topics', _profile['mastered_topics']),
                              _profileLine('Focus next', _profile['focus_topics']),
                              _profileLine('Recommended difficulty',
                                  _profile['recommended_next_difficulty']),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 22),
                const Eyebrow('Interview history'),
                const SizedBox(height: 10),
                if (sessions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No interviews yet. Your record starts with the first one.',
                          style: TextStyle(color: Ink.steel)),
                    ),
                  ),
                for (final s in sessions)
                  Card(
                    child: ListTile(
                      onTap: s.report != null
                          ? () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ReportScreen(engine: InterviewEngine(s))))
                          : null,
                      onLongPress: () async {
                        await StorageService.deleteSession(s.id);
                        _load();
                      },
                      title: Text('${s.role} · ${s.difficulty}',
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${DateFormat('d MMM y, h:mm a').format(s.createdAt)}'
                        '${s.durationMinutes != null ? ' · ${s.durationMinutes} min' : ''}',
                        style:
                            GoogleFonts.jetBrainsMono(fontSize: 10.5, color: Ink.steel),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            s.report != null
                                ? '${(s.report!['overall_score'] as num?)?.round() ?? '—'}/100'
                                : '—',
                            style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            ((s.report?['decision'] as String?) ?? s.status)
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                letterSpacing: 1,
                                color: _decisionColor(s.report?['decision'] as String?)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (sessions.isNotEmpty)
                  const Center(
                    child: Text('Long-press an entry to delete it.',
                        style: TextStyle(color: Ink.steel, fontSize: 11)),
                  ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _profileLine(String label, dynamic value) {
    final text = value is List ? value.join(', ') : (value?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Ink.ink, fontSize: 13.5, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: text.isEmpty ? '—' : text),
          ],
        ),
      ),
    );
  }

  Widget _dimensionDeltas(List<InterviewSession> reported) {
    final first = Map<String, dynamic>.from(reported.first.report!['dimensions'] ?? {});
    final last = Map<String, dynamic>.from(reported.last.report!['dimensions'] ?? {});
    final deltas = <String, double>{};
    for (final k in last.keys) {
      if (first[k] is num && last[k] is num) {
        final d = (last[k] as num).toDouble() - (first[k] as num).toDouble();
        if (d != 0) deltas[k] = d;
      }
    }
    if (deltas.isEmpty) return const SizedBox.shrink();
    final sorted = deltas.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final e in sorted)
          Text(
            '${e.key.replaceAll('_', ' ')} ${e.value > 0 ? '+' : ''}${e.value.toStringAsFixed(1)}',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11, color: e.value > 0 ? Ink.green : Ink.red),
          ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<InterviewSession> reported;
  _TrendPainter(this.reported);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 22.0;
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E7E9)
      ..strokeWidth = 1;
    for (final g in [0, 50, 100]) {
      final y = size.height - pad - (g / 100) * (size.height - pad * 2);
      canvas.drawLine(Offset(pad, y), Offset(size.width - 4, y), gridPaint);
    }

    final points = <Offset>[];
    for (var i = 0; i < reported.length; i++) {
      final score = ((reported[i].report!['overall_score'] as num?) ?? 0).toDouble();
      final x = reported.length == 1
          ? size.width / 2
          : pad + i * (size.width - pad - 8) / (reported.length - 1);
      final y = size.height - pad - (score / 100) * (size.height - pad * 2);
      points.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = Ink.ink
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final decision = reported[i].report!['decision'] as String?;
      final color = switch (decision) {
        'strong_hire' || 'hire' => Ink.green,
        'borderline' => Ink.amber,
        _ => Ink.red,
      };
      canvas.drawCircle(points[i], 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.reported != reported;
}
