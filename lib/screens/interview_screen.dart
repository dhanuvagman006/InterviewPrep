import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/interview_engine.dart';
import '../services/rounds.dart';
import '../services/voice_service.dart';
import 'report_screen.dart';

class InterviewScreen extends StatefulWidget {
  final InterviewEngine engine;
  const InterviewScreen({super.key, required this.engine});
  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final VoiceService _voice = VoiceService();
  final _codeCtrl = TextEditingController();
  final _typedCtrl = TextEditingController();

  bool _joined = false;
  bool _voiceMode = true;
  bool _codeMode = false;
  bool _showTranscript = false;
  bool _busy = false;
  bool _complete = false;
  String? _error;

  InterviewEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _voice.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
  }

  // ---------- flow ----------

  Future<void> _joinWithVoice() async {
    final ok = await _voice.init();
    setState(() {
      _voiceMode = ok;
      _joined = true;
      if (!ok) {
        _error = 'Microphone unavailable — running as a typed interview. '
            'Grant mic permission in system settings to enable voice.';
      }
    });
    await _openingTurn();
  }

  Future<void> _joinTyped() async {
    setState(() {
      _voiceMode = false;
      _joined = true;
    });
    await _openingTurn();
  }

  Future<void> _openingTurn() async {
    // Interviewer speaks first: resume already in progress? continue silently.
    if (engine.session.messages.isNotEmpty) {
      final last = engine.session.messages.last;
      if (last.role == 'assistant' && _voiceMode) {
        await _speakThenListen(last.content);
      }
      return;
    }
    await _runTurn(null);
  }

  Future<void> _runTurn(String? userText) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await engine.handleTurn(userText);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _complete = res.interviewComplete;
      });
      if (_voiceMode) {
        if (res.interviewComplete) {
          await _voice.speak(res.message);
        } else {
          await _speakThenListen(res.message);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
      if (_voiceMode) {
        await _voice.speak('Sorry, I lost the connection for a moment. '
            'When you are ready, tap answer and repeat that for me.');
      }
    }
  }

  Future<void> _speakThenListen(String message) async {
    await _voice.speak(message);
    if (!mounted || !_voiceMode || _codeMode || _complete) return;
    await _voice.listen(onFinal: _onSpokenAnswer);
  }

  void _onSpokenAnswer(String text) {
    if (_busy || _complete) return;
    _runTurn(text);
  }

  void _submitCode() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    _codeCtrl.clear();
    setState(() => _codeMode = false);
    _runTurn('```\n$code\n```');
  }

  void _sendTyped() {
    final text = _typedCtrl.text.trim();
    if (text.isEmpty) return;
    _typedCtrl.clear();
    _runTurn(text);
  }

  Future<void> _toggleVoice() async {
    if (_voiceMode) {
      await _voice.stopSpeaking();
      await _voice.cancelListening();
      setState(() => _voiceMode = false);
    } else {
      final ok = await _voice.init();
      setState(() => _voiceMode = ok);
      if (ok && !_busy && !_complete && !_codeMode) {
        await _voice.listen(onFinal: _onSpokenAnswer);
      }
    }
  }

  // ---------- UI ----------

  String? get _lastQuestion {
    for (final m in engine.session.messages.reversed) {
      if (m.role == 'assistant') return m.content;
    }
    return null;
  }

  String? get _screenCode {
    final q = _lastQuestion;
    if (q == null) return null;
    final blocks = RegExp(r'```(?:\w*\n)?([\s\S]*?)```')
        .allMatches(q)
        .map((m) => m.group(1)!.trim())
        .toList();
    return blocks.isEmpty ? null : blocks.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final session = engine.session;
    return Scaffold(
      appBar: AppBar(
        title: Text(rounds[session.roundIndex].shortTitle.toUpperCase()),
        actions: [
          IconButton(
            tooltip: _showTranscript ? 'Hide transcript' : 'Show transcript',
            icon: Icon(_showTranscript ? Icons.subtitles_off_outlined : Icons.subtitles_outlined),
            onPressed: () => setState(() => _showTranscript = !_showTranscript),
          ),
          IconButton(
            tooltip: _voiceMode ? 'Voice on' : 'Voice off',
            icon: Icon(_voiceMode ? Icons.record_voice_over : Icons.voice_over_off),
            onPressed: _joined ? _toggleVoice : null,
          ),
        ],
      ),
      body: !_joined ? _lobby(context) : _live(context),
    );
  }

  Widget _lobby(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Interview room'),
          const SizedBox(height: 6),
          Text('Your interviewer is ready.', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text(
            'This is a spoken interview. The interviewer asks questions out loud and listens to '
            'your answers — just talk, like a real call. Pausing for a couple of seconds sends '
            'your answer. Coding problems appear on screen, and code is typed.\n\n'
            'Use headphones for the best experience.',
            style: TextStyle(color: Ink.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _joinWithVoice,
            icon: const Icon(Icons.mic),
            label: const Text('Join with voice'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _joinTyped,
            child: const Text('Join as a typed interview instead'),
          ),
        ],
      ),
    );
  }

  Widget _live(BuildContext context) {
    final session = engine.session;
    return Column(
      children: [
        // Round track
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              for (final (i, r) in rounds.indexed)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: i == session.roundIndex ? Ink.ink : Ink.panel,
                      border: Border.all(color: Ink.line),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      r.shortTitle,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        color: i < session.roundIndex
                            ? Ink.green
                            : i == session.roundIndex
                                ? Colors.white
                                : Ink.steel,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_error!, style: const TextStyle(color: Ink.red, fontSize: 12.5)),
          ),
        Expanded(
          child: _codeMode
              ? _codeEditor(context)
              : _showTranscript
                  ? _transcript(context)
                  : _stage(context),
        ),
        _bottomBar(context),
      ],
    );
  }

  Widget _stage(BuildContext context) {
    final status = _complete
        ? 'Interview finished'
        : _busy
            ? 'Thinking…'
            : _voice.speaking
                ? 'Asking…'
                : _voice.listening
                    ? 'Listening to you'
                    : _voiceMode
                        ? 'Tap Answer to speak'
                        : 'Your turn — type below';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _Orb(speaking: _voice.speaking, listening: _voice.listening, thinking: _busy),
          const SizedBox(height: 12),
          Text(status.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(color: Ink.steel, fontSize: 11, letterSpacing: 1.4)),
          const SizedBox(height: 18),
          if (_lastQuestion != null)
            Text(
              _lastQuestion!.replaceAll(RegExp(r'```[\s\S]*?```'), '').trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.55),
            ),
          if (_screenCode != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10151A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_screenCode!,
                  style: GoogleFonts.jetBrainsMono(color: const Color(0xFFD7E0E6), fontSize: 12)),
            ),
          ],
          if (_voice.listening) ...[
            const SizedBox(height: 16),
            Text('“${_voice.liveTranscript.isEmpty ? '…' : _voice.liveTranscript}”',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontStyle: FontStyle.italic, color: Ink.inkSoft, fontSize: 14.5)),
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _transcript(BuildContext context) {
    final messages = engine.session.messages;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final m = messages[i];
        final isUser = m.role == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            decoration: BoxDecoration(
              color: isUser ? Ink.ink : const Color(0xFFF4F6F7),
              border: Border.all(color: isUser ? Ink.ink : Ink.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(m.content,
                style: TextStyle(
                    color: isUser ? const Color(0xFFF2F4F5) : Ink.ink, fontSize: 13.5)),
          ),
        );
      },
    );
  }

  Widget _codeEditor(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_screenCode != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10151A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_screenCode!,
                  style: GoogleFonts.jetBrainsMono(color: const Color(0xFFD7E0E6), fontSize: 11.5)),
            ),
          Expanded(
            child: TextField(
              controller: _codeCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.jetBrainsMono(fontSize: 13, color: const Color(0xFFD7E0E6)),
              decoration: InputDecoration(
                hintText: 'Write your solution here…',
                hintStyle: const TextStyle(color: Ink.steel),
                fillColor: const Color(0xFF10151A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Ink.panel,
        border: Border(top: BorderSide(color: Ink.line)),
      ),
      child: _complete
          ? ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => ReportScreen(engine: engine)),
              ),
              child: const Text('Interview finished — view your evaluation'),
            )
          : _codeMode
              ? Row(children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _codeMode = false),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: _busy ? null : _submitCode,
                        child: const Text('Submit code')),
                  ),
                ])
              : _voiceMode
                  ? Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => setState(() => _codeMode = true),
                          icon: const Icon(Icons.code, size: 18),
                          label: const Text('Code'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _voice.speaking
                              ? OutlinedButton(
                                  onPressed: () async {
                                    await _voice.stopSpeaking();
                                    if (!_codeMode && !_complete) {
                                      await _voice.listen(onFinal: _onSpokenAnswer);
                                    }
                                  },
                                  child: const Text('Skip question audio'),
                                )
                              : _voice.listening
                                  ? ElevatedButton.icon(
                                      onPressed: _voice.finishNow,
                                      icon: const Icon(Icons.check),
                                      label: const Text('Done — send answer'),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _voice.listen(onFinal: _onSpokenAnswer),
                                      icon: const Icon(Icons.mic),
                                      label: const Text('Answer'),
                                    ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => setState(() => _codeMode = true),
                          icon: const Icon(Icons.code, size: 18),
                          label: const Text('Code'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _typedCtrl,
                            decoration: const InputDecoration(hintText: 'Type your answer…'),
                            onSubmitted: (_) => _sendTyped(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _busy ? null : _sendTyped,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
    );
  }
}

class _Orb extends StatelessWidget {
  final bool speaking, listening, thinking;
  const _Orb({required this.speaking, required this.listening, required this.thinking});

  @override
  Widget build(BuildContext context) {
    final color = speaking
        ? Ink.ink
        : listening
            ? Ink.red
            : Ink.panel;
    final icon = speaking
        ? Icons.graphic_eq
        : listening
            ? Icons.mic
            : thinking
                ? Icons.more_horiz
                : Icons.circle_outlined;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: listening ? Ink.red : Ink.line, width: 2),
        boxShadow: listening
            ? [BoxShadow(color: Ink.red.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 6)]
            : speaking
                ? [BoxShadow(color: Ink.ink.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 4)]
                : [],
      ),
      child: Icon(icon,
          size: 38, color: (speaking || listening) ? Colors.white : Ink.steel),
    );
  }
}
