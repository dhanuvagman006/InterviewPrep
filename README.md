# InterviewPrep — AI Voice Interview Simulator (Flutter)

A Flutter app that runs you through the complete six-round hiring process of a software engineering interview — **as a spoken call**. An AI interviewer (Google Gemini) asks questions out loud, listens to your voice answers, probes your resume, adapts difficulty to your performance, keeps private evaluation notes, and ends with a hire/no-hire verdict, a detailed report, and a personalized improvement plan. Every attempt is saved on-device so the coach tracks your progress and personalizes future interviews.

No server needed — the app talks to the Gemini API directly and stores everything locally.

## The pipeline

1. **Resume validation & HR screening** — walks through every project and skill on your resume and verifies it's genuine.
2. **Coding assessment** — randomized DSA problems (arrays → backtracking) matched to your level; think aloud by voice, type your code in the built-in editor; evaluated on correctness, complexity, code quality, and edge cases.
3. **Technical I** — CS fundamentals (DS/Algo, OS, DBMS, networks, OOP, SQL, REST, HTTP, auth, concurrency, memory) with progressively deeper follow-ups.
4. **Technical II** — your projects, design decisions, trade-offs, and a system design exercise.
5. **Behavioral** — real stories, with follow-ups whenever answers get vague.
6. **Hiring manager final** — goals, fit, your questions, and the verdict: Strong Hire / Hire / Borderline / Reject.

## Voice-to-voice

- Join the interview room and tap **"Join with voice"** — the interviewer greets you and asks the first question aloud.
- When it finishes speaking, the mic opens automatically. Answer out loud; pausing for ~2 seconds sends your answer. The entire interview is hands-free.
- The call screen shows a status orb (asking / listening / thinking), captions of the current question, and a live transcript of what it's hearing from you. The full transcript is behind the captions button.
- Coding problems: the voice says the details are on screen; examples render in a code panel and you type your solution in the code editor.
- "Skip question audio" cuts off a long question; the voice toggle switches to a typed interview at any time.
- **Use headphones** — otherwise the mic can pick up the interviewer's own voice.

Voice uses the device's native speech recognition and text-to-speech (via `speech_to_text` and `flutter_tts`), so quality is far better than browser speech APIs and there's no extra API cost.

## After the interview

- **Evaluation report**: overall score /100, stamped verdict, per-round scores, ten skill dimensions, strengths/weaknesses, and an improvement plan naming exactly which questions exposed which weak concepts, with practice order, resources, and short/long-term goals.
- **History & progress**: every attempt recorded (date, duration, scores, decision); a trend chart of your overall score; per-dimension deltas since your first interview.
- **Personalized coaching**: each report updates a persistent candidate profile (recurring strengths/weaknesses, mastered topics, focus topics, recommended difficulty) that shapes every future interview — mastered ground is skipped, weak areas get more attention.

## Setup

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+).

```bash
git clone https://github.com/dhanuvagman006/InterviewPrep.git
cd InterviewPrep

# Generate the platform scaffolding (android/, ios/, etc.)
flutter create .

flutter pub get
```

### Add permissions

**Android** — in `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` (above `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<queries>
  <intent>
    <action android:name="android.speech.RecognitionService" />
  </intent>
</queries>
```

Also set `minSdk = 24` in `android/app/build.gradle(.kts)` if it's lower.

**iOS** — in `ios/Runner/Info.plist`, inside the top-level `<dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>The interviewer listens to your spoken answers.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Your spoken answers are transcribed for the interview.</string>
```

### Run

```bash
flutter run
```

Then in the app: **Settings (gear icon) → paste your Gemini API key** (free at https://aistudio.google.com) → Begin interview. The key is stored only on your device.

## Project structure

```
lib/
  main.dart                     # theme ("evaluation dossier" design) + app shell
  models/session.dart           # session, messages, round summaries, report
  services/
    rounds.dart                 # the 6 round definitions + interviewer prompts
    gemini_service.dart         # Gemini REST client (chat + JSON report mode)
    interview_engine.dart       # turn handling, hidden control-block parsing,
                                # round transitions, report generation, profile update
    voice_service.dart          # native STT (silence auto-send) + TTS
    storage_service.dart        # on-device persistence (sessions + profile)
  screens/
    home_screen.dart            # setup: role, difficulty, resume, settings
    interview_screen.dart       # the voice call: lobby, orb stage, code editor
    report_screen.dart          # verdict stamp, dimensions, improvement plan
    dashboard_screen.dart       # trend chart, history, candidate profile
```

## How the interviewer stays adaptive

Every model turn carries: the interviewer's running private notes, the log of questions already asked this interview (never repeated), completed-round summaries with scores, and your long-term candidate profile. The interviewer ends each reply with a hidden `<control>` JSON block (new notes, question log entry, round transitions with 0–10 scores) which the engine parses and strips — you only ever hear the conversation.

## Notes

- A full run takes roughly 2–3 hours like a real onsite; the interviewer shortens rounds if you struggle and digs deeper if you excel. You can also leave and the session stays in history.
- Resume input is pasted text for now (on-device PDF text extraction can be added with the `syncfusion_flutter_pdf` package).
- Speech recognition needs Google app / speech services on Android and Siri dictation enabled on iOS.
