import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/interview_engine.dart';
import '../services/gemini_tts_service.dart';
import '../services/resume_service.dart';
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
  String _difficulty = 'intermediate';
  bool _busy = false;
  bool _hasKey = true;
  StoredResume? _resume;
  String? _resumeError;

  @override
  void initState() {
    super.initState();
    _checkKey();
    _loadResume();
  }

  Future<void> _loadResume() async {
    final r = await ResumeService.load();
    if (mounted) setState(() => _resume = r);
  }

  Future<void> _uploadResume() async {
    setState(() => _resumeError = null);
    try {
      final r = await ResumeService.pickAndStore();
      if (r != null && mounted) setState(() => _resume = r);
    } catch (e) {
      if (mounted) {
        setState(() => _resumeError = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _removeResume() async {
    await ResumeService.remove();
    if (mounted) setState(() => _resume = null);
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
        // Resume comes from the stored upload (ResumeService) automatically.
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
    var voice = prefs.getString('tts_voice') ?? 'Charon';
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
                style: TextStyle(color: AppColors.steel, fontSize: 13)),
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
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (ctx2, setSheet) => DropdownButtonFormField<String>(
                value: voice,
                decoration: const InputDecoration(labelText: 'Interviewer voice'),
                items: [
                  for (final e in GeminiTtsService.voices.entries)
                    DropdownMenuItem(
                        value: e.key, child: Text('${e.key} — ${e.value}')),
                  const DropdownMenuItem(
                      value: 'device',
                      child: Text('Device voice — robotic but instant & offline')),
                ],
                onChanged: (v) => setSheet(() => voice = v ?? 'Charon'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await prefs.setString('gemini_api_key', keyCtrl.text.trim());
                  await prefs.setString('gemini_model', modelCtrl.text.trim());
                  await GeminiTtsService.setVoice(voice);
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
                fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1, color: AppColors.ink),
            children: const [
              TextSpan(text: 'INTERVIEW'),
              TextSpan(text: 'PREP', style: TextStyle(color: AppColors.green)),
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
                leading: const Icon(Icons.key_off_outlined, color: AppColors.amber),
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
            style: TextStyle(color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                for (final (i, r) in rounds.indexed)
                  ListTile(
                    dense: true,
                    leading: Text('R${i + 1}',
                        style: GoogleFonts.jetBrainsMono(color: AppColors.steel, fontSize: 12)),
                    title: Text(r.title, style: const TextStyle(fontSize: 13.5)),
                    trailing: Text('~${r.minutes}m',
                        style: GoogleFonts.jetBrainsMono(color: AppColors.steel, fontSize: 11)),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _resume == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Resume', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text(
                          'Upload it once — every interview uses it until you replace it. '
                          'The interviewer verifies everything on it. You can also skip this '
                          'and describe your background by voice in Round 1.',
                          style: TextStyle(color: AppColors.steel, fontSize: 12.5, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _uploadResume,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Upload resume (PDF)'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.description_outlined,
                                size: 20, color: AppColors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_resume!.fileName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'On file since ${_resume!.updatedAt.day}/${_resume!.updatedAt.month}/${_resume!.updatedAt.year} · '
                          '${_resume!.text.length} characters extracted. '
                          'The interviewer will use this resume for every interview.',
                          style: const TextStyle(color: AppColors.steel, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            OutlinedButton(
                                onPressed: _uploadResume, child: const Text('Replace')),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _removeResume,
                              child: const Text('Remove',
                                  style: TextStyle(color: AppColors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          if (_resumeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_resumeError!,
                  style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
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
