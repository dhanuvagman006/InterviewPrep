import Database from "better-sqlite3";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(__dirname, "..", "data");
fs.mkdirSync(dataDir, { recursive: true });

const db = new Database(path.join(dataDir, "interviewprep.db"));
db.pragma("journal_mode = WAL");

db.exec(`
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  finished_at TEXT,
  status TEXT NOT NULL DEFAULT 'active', -- active | completed | abandoned
  difficulty TEXT NOT NULL,
  role TEXT NOT NULL,
  company_style TEXT,
  resume_text TEXT,
  round_index INTEGER NOT NULL DEFAULT 0,
  interviewer_notes TEXT NOT NULL DEFAULT '',
  asked_questions TEXT NOT NULL DEFAULT '[]', -- JSON array
  round_summaries TEXT NOT NULL DEFAULT '[]'  -- JSON array of {round, summary, score}
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  round_index INTEGER NOT NULL,
  role TEXT NOT NULL, -- user | assistant
  content TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS reports (
  session_id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  overall_score REAL,
  decision TEXT, -- strong_hire | hire | borderline | reject
  report_json TEXT NOT NULL,
  FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS candidate_profile (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  updated_at TEXT,
  profile_json TEXT NOT NULL DEFAULT '{}'
);
INSERT OR IGNORE INTO candidate_profile (id, profile_json) VALUES (1, '{}');
`);

export default db;
