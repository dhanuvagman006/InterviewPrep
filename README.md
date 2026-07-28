# InterviewPrep — AI Hiring Simulator

An end-to-end software engineering interview simulator. An AI interviewer runs you through the full six-round hiring pipeline of a real company — validating your resume, adapting difficulty to your answers, keeping private evaluation notes, and ending with a hire/no-hire verdict, a detailed report, and a personalized improvement plan. Every interview is recorded so the coach tracks your progress and personalizes future interviews.

## The pipeline

1. **Resume validation & HR screening** — walks through every project and skill on your resume and verifies it's genuine.
2. **Coding assessment** — randomized DSA problems (arrays → backtracking) matched to your level; evaluated on correctness, complexity, code quality, and edge cases.
3. **Technical I** — CS fundamentals (DS/Algo, OS, DBMS, networks, OOP, SQL, REST, HTTP, auth, concurrency, memory) with progressively deeper follow-ups.
4. **Technical II** — your projects, design decisions, trade-offs, and a system design exercise.
5. **Behavioral** — real stories, with follow-ups whenever answers get vague.
6. **Hiring manager final** — goals, fit, your questions, and the verdict: Strong Hire / Hire / Borderline / Reject.

Afterward you get a full committee report: overall score, per-round scores, ten skill dimensions, strengths and weaknesses, and an improvement plan that names exactly which questions exposed which weak concepts and what to practice in what order.

## How it works

- **Adaptive interviewer** — every model turn carries the interviewer's running private notes, the log of questions already asked (never repeated), completed-round summaries, and your long-term candidate profile. Difficulty rises and falls with your answers.
- **Control channel** — the interviewer appends a hidden JSON control block to each reply (notes, question log, round transitions, round scores) which the server parses and strips before you see the message.
- **Long-term memory** — each report updates a persistent candidate profile (recurring strengths/weaknesses, mastered topics, focus topics, recommended difficulty) that shapes every future interview.
- **Progress tracking** — the dashboard charts your overall score across interviews and the movement of each skill dimension since your first attempt.

## Stack

- **Server:** Node + Express, SQLite (better-sqlite3), Google Gemini API (`gemini-2.5-flash` via REST), PDF resume parsing.
- **Client:** React + Vite, no UI framework — a custom "evaluation dossier" design system. Voice-to-voice interviews via the browser's Web Speech API (speech recognition + speech synthesis), no extra API needed.

## Setup

```bash
git clone https://github.com/dhanuvagman006/InterviewPrep.git
cd InterviewPrep
npm install
npm run install:all

cp server/.env.example server/.env
# edit server/.env and set GEMINI_API_KEY=...

npm run dev
```

- Client: http://localhost:5173
- Server: http://localhost:3001

Get a free Gemini API key from Google AI Studio (https://aistudio.google.com). The database is created automatically at `server/data/interviewprep.db`.

## API

| Method | Route | Purpose |
| --- | --- | --- |
| POST | `/api/resume/parse` | Extract text from an uploaded PDF/TXT resume |
| POST | `/api/interviews` | Start a session (role, difficulty, company style, resume) |
| POST | `/api/interviews/:id/message` | Send an answer, get the interviewer's reply |
| POST | `/api/interviews/:id/report` | Generate (or fetch) the final evaluation |
| GET | `/api/interviews/:id` | Full transcript + report |
| GET | `/api/history` | All past interview attempts |
| GET | `/api/progress` | Score series + candidate profile |

## Voice-to-voice interviews

Voice mode is on by default in browsers that support it (Chrome and Edge; speech recognition is not available in Firefox, and Safari support is partial):

- The interviewer's replies are spoken aloud.
- When the interviewer finishes speaking, your microphone opens automatically. Speak your answer; a ~2-second pause sends it — a hands-free loop for the whole interview.
- Tap the mic to finish early, or the stop button to cancel. "Skip" cuts off a long spoken question (the text stays on screen).
- Code is always typed: switching to code mode pauses the voice loop, and coding problems are shown on screen rather than read out.
- Toggle "Voice: off" any time to do a classic typed interview.

## Notes

- A full run takes roughly 2–3 hours, like a real onsite; the interviewer shortens rounds if you struggle and digs deeper if you excel.
- Currently single-user by design; the schema (sessions/messages/reports/profile) is ready to grow a `user_id` column for multi-user support.
- Never commit `server/.env` — it holds your API key.
- Voice recognition quality depends on your browser and microphone; everything you say is transcribed on-device/by your browser vendor's speech service, not sent to Gemini as audio.
