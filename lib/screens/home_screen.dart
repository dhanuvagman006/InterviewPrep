import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/interview_engine.dart';
import '../services/rounds.dart';
import 'dashboard_screen.dart';
import 'interview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roleCtrl = TextEditingController(text: 'Software Engineer');
  final _companyCtrl = TextEditingController();
  final _resumeCtrl = TextEditingController();
  String _difficulty = 'intermediate';
  bool _busy = false;
  bool _hasKey = true;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _hasKey = (prefs.getString('gemini_api_key') ?? '').isNotEmpty);
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final engine = await InterviewEngine.create(
        difficulty: _difficulty,
        role: _roleCtrl.text.trim().isEmpty ? 'Software Engineer' : _roleCtrl.text.trim(),
        companyStyle: _companyCtrl.text.trim(),
        resumeText: _resumeCtrl.text.trim(),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InterviewScreen(engine: engine)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final keyCtrl = TextEditingController(text: prefs.getString('gemini_api_key') ?? '');
    final modelCtrl =
        TextEditingController(text: prefs.getString('gemini_model') ?? 'gemini-2.5-flash');
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Get a free key at aistudio.google.com — it stays on this device.',
                style: TextStyle(color: Ink.steel, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Gemini API key'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(labelText: 'Model'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await prefs.setString('gemini_api_key', keyCtrl.text.trim());
                  await prefs.setString('gemini_model', modelCtrl.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
    _checkKey();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1, color: Ink.ink),
            children: const [
              TextSpan(text: 'INTERVIEW'),
              TextSpan(text: 'PREP', style: TextStyle(color: Ink.green)),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'History & progress',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const DashboardScreen())),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_hasKey)
            Card(
              child: ListTile(
                leading: const Icon(Icons.key_off_outlined, color: Ink.amber),
                title: const Text('Add your Gemini API key to begin'),
                subtitle: const Text('Free at aistudio.google.com'),
                onTap: _openSettings,
              ),
            ),
          if (!_hasKey) const SizedBox(height: 16),
          const Eyebrow('Full hiring pipeline · Spoken · Adaptive'),
          const SizedBox(height: 6),
          Text('Sit the whole interview.\nGet the real verdict.',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'An AI interviewer talks you through all six rounds of a software engineering hiring '
            'process — asking questions aloud, listening to your answers, probing your resume, '
            'adapting to how you perform, and ending with a hire/no-hire decision plus a concrete '
            'improvement plan.',
            style: TextStyle(color: Ink.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                for (final (i, r) in rounds.indexed)
                  ListTile(
                    dense: true,
                    leading: Text('R${i + 1}',
                        style: GoogleFonts.jetBrainsMono(color: Ink.steel, fontSize: 12)),
                    title: Text(r.title, style: const TextStyle(fontSize: 13.5)),
                    trailing: Text('~${r.minutes}m',
                        style: GoogleFonts.jetBrainsMono(color: Ink.steel, fontSize: 11)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Set up your interview', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _roleCtrl,
            decoration: const InputDecoration(labelText: 'Role you\'re interviewing for'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'beginner', label: Text('Beginner')),
              ButtonSegment(value: 'intermediate', label: Text('Intermediate')),
              ButtonSegment(value: 'advanced', label: Text('Advanced')),
            ],
            selected: {_difficulty},
            onSelectionChanged: (s) => setState(() => _difficulty = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyCtrl,
            decoration: const InputDecoration(
              labelText: 'Company style to simulate (optional)',
              hintText: 'e.g. big-tech product company, early-stage startup',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _resumeCtrl,
            maxLines: 7,
            style: GoogleFonts.jetBrainsMono(fontSize: 12.5),
            decoration: const InputDecoration(
              labelText: 'Resume (paste text)',
              hintText:
                  'Paste your resume here. The interviewer verifies everything on it.\nLeave empty to describe your background by voice in Round 1.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.mic),
            label: Text(_busy ? 'Preparing your interviewer…' : 'Begin interview'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
