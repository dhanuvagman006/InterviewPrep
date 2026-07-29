import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/session.dart';
import '../services/interview_engine.dart';
import 'dashboard_screen.dart';

class ReportScreen extends StatefulWidget {
  final InterviewEngine engine;
  const ReportScreen({super.key, required this.engine});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _report;
  String? _error;

  static const decisionLabel = {
    'strong_hire': 'STRONG HIRE',
    'hire': 'HIRE',
    'borderline': 'BORDERLINE',
    'reject': 'REJECT',
  };
  static const dimLabel = {
    'technical_knowledge': 'Technical knowledge',
    'coding_ability': 'Coding ability',
    'communication': 'Communication',
    'confidence': 'Confidence',
    'problem_solving': 'Problem solving',
    'resume_authenticity': 'Resume authenticity',
    'project_understanding': 'Project understanding',
    'leadership': 'Leadership',
    'system_design': 'System design',
    'behavioral': 'Behavioral',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.engine.generateReport();
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Color _decisionColor(String d) => switch (d) {
        'strong_hire' || 'hire' => AppColors.green,
        'borderline' => AppColors.amber,
        _ => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EVALUATION')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Couldn\'t build the report: $_error',
                        style: const TextStyle(color: AppColors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () { setState(() => _error = null); _load(); },
                        child: const Text('Try again')),
                  ],
                ),
              ),
            )
          : _report == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.ink),
                        SizedBox(height: 16),
                        Text('The hiring committee is writing your evaluation…',
                            style: TextStyle(color: AppColors.steel)),
                      ],
                    ),
                  ),
                )
              : _body(context, _report!),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _body(BuildContext context, Map<String, dynamic> r) {
    final decision = (r['decision'] as String?) ?? 'borderline';
    final dims = Map<String, dynamic>.from(r['dimensions'] ?? {});
    final plan = (r['improvement_plan'] as List? ?? []);
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Hiring committee evaluation'),
                  Text('${(r['overall_score'] as num?)?.round() ?? '—'}',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 44, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const Text('/ 100 overall', style: TextStyle(color: AppColors.steel, fontSize: 13)),
                ],
              ),
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: _decisionColor(decision), width: 3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    decisionLabel[decision] ?? decision.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        fontSize: 16,
                        color: _decisionColor(decision)),
                  ),
                ),
              ),
            ],
          ),
        ),
        _section('Decision reasoning',
            Text(r['decision_reasoning'] ?? '', style: const TextStyle(height: 1.5))),
        _section(
          'Round scores',
          Column(
            children: [
              for (final rs in (r['round_scores'] as List? ?? []))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${rs['score']}/10  ',
                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700)),
                      Expanded(
                          child: Text('${rs['round']}. ${rs['commentary'] ?? ''}',
                              style: const TextStyle(fontSize: 13.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _section(
          'Skill dimensions',
          Column(
            children: [
              for (final e in dims.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dimLabel[e.key] ?? e.key, style: const TextStyle(fontSize: 12.5)),
                          Text('${e.value}/10',
                              style:
                                  GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.steel)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      LinearProgressIndicator(
                        value: ((e.value as num?)?.toDouble() ?? 0) / 10,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E7E9),
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _section('Strengths', _bullets(r['strengths'])),
        _section('Weaknesses', _bullets(r['weaknesses'])),
        _section(
          'Improvement plan',
          Column(
            children: [
              for (final p in plan)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['area'] ?? '',
                            style: Theme.of(context).textTheme.titleMedium),
                        _kv('What went wrong', p['what_went_wrong']),
                        _kv('Why', p['why']),
                        _kv('Weak concepts', (p['weak_concepts'] as List? ?? []).join(', ')),
                        _kv('Questions that exposed it',
                            (p['exposing_questions'] as List? ?? []).join(' · ')),
                        _kv('How to improve', p['how_to_improve']),
                        _kv('Practice order', (p['practice_order'] as List? ?? []).join(' → ')),
                        _kv('Resources', (p['resources'] as List? ?? []).join(' · ')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _section('Short-term goals (2 weeks)', _bullets(r['short_term_goals'])),
        _section('Long-term goals (2–3 months)', _bullets(r['long_term_goals'])),
        _section('Progress vs your history',
            Text(r['progress_vs_history'] ?? '', style: const TextStyle(height: 1.5))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardScreen())),
            child: const Text('Go to history & progress'),
          ),
        ),
      ],
    );
  }

  Widget _bullets(dynamic list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in (list as List? ?? []))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: AppColors.steel)),
                  Expanded(child: Text('$s', style: const TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
        ],
      );

  Widget _kv(String k, dynamic v) {
    if (v == null || '$v'.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5, letterSpacing: 1.2, color: AppColors.steel)),
          const SizedBox(height: 2),
          Text('$v', style: const TextStyle(fontSize: 13.5)),
        ],
      ),
    );
  }
}
