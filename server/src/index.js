import "dotenv/config";
import express from "express";
import cors from "cors";
import multer from "multer";
import db from "./db.js";
import { ROUNDS } from "./rounds.js";
import { createSession, handleTurn, generateReport } from "./engine.js";

const app = express();
app.use(cors());
app.use(express.json({ limit: "2mb" }));
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 8 * 1024 * 1024 } });

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, apiKeyConfigured: !!process.env.GEMINI_API_KEY });
});

// ---- Resume upload (PDF or plain text) ----
app.post("/api/resume/parse", upload.single("file"), async (req, res) => {
  try {
    const file = req.file;
    if (!file) return res.status(400).json({ error: "No file uploaded" });
    if (file.mimetype === "application/pdf") {
      const { default: pdfParse } = await import("pdf-parse/lib/pdf-parse.js");
      const parsed = await pdfParse(file.buffer);
      return res.json({ text: parsed.text.trim() });
    }
    return res.json({ text: file.buffer.toString("utf8").trim() });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Could not read that file. Paste your resume text instead." });
  }
});

// ---- Interview lifecycle ----
app.post("/api/interviews", (req, res) => {
  const { difficulty = "intermediate", role = "Software Engineer", companyStyle, resumeText } = req.body || {};
  const id = createSession({ difficulty, role, companyStyle, resumeText });
  res.json({ sessionId: id, rounds: ROUNDS.map((r) => r.shortTitle) });
});

app.post("/api/interviews/:id/message", async (req, res) => {
  try {
    const result = await handleTurn(req.params.id, req.body?.message ?? null);
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.post("/api/interviews/:id/report", async (req, res) => {
  try {
    const report = await generateReport(req.params.id);
    res.json(report);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/interviews/:id", (req, res) => {
  const session = db.prepare("SELECT * FROM sessions WHERE id = ?").get(req.params.id);
  if (!session) return res.status(404).json({ error: "Not found" });
  const messages = db
    .prepare("SELECT role, content, round_index, created_at FROM messages WHERE session_id = ? ORDER BY id")
    .all(req.params.id);
  const report = db.prepare("SELECT report_json FROM reports WHERE session_id = ?").get(req.params.id);
  res.json({
    session: { ...session, resume_text: undefined, interviewer_notes: undefined },
    messages,
    report: report ? JSON.parse(report.report_json) : null,
    rounds: ROUNDS.map((r) => r.shortTitle),
  });
});

// ---- History & progress ----
app.get("/api/history", (_req, res) => {
  const rows = db
    .prepare(
      `SELECT s.id, s.created_at, s.finished_at, s.status, s.difficulty, s.role, s.round_index,
              r.overall_score, r.decision, r.report_json
       FROM sessions s LEFT JOIN reports r ON r.session_id = s.id
       ORDER BY s.created_at DESC`
    )
    .all();
  res.json(
    rows.map((row) => {
      let roundScores = null, strengths = null, weaknesses = null;
      if (row.report_json) {
        const rep = JSON.parse(row.report_json);
        roundScores = rep.round_scores;
        strengths = rep.strengths;
        weaknesses = rep.weaknesses;
      }
      const duration =
        row.finished_at && row.created_at
          ? Math.round((new Date(row.finished_at) - new Date(row.created_at)) / 60000)
          : null;
      return { ...row, report_json: undefined, durationMinutes: duration, roundScores, strengths, weaknesses };
    })
  );
});

app.get("/api/progress", (_req, res) => {
  const reports = db
    .prepare(
      `SELECT r.created_at, r.overall_score, r.decision, r.report_json
       FROM reports r ORDER BY r.created_at ASC`
    )
    .all();
  const series = reports.map((r) => {
    const rep = JSON.parse(r.report_json);
    return {
      date: r.created_at,
      overall: r.overall_score,
      decision: r.decision,
      dimensions: rep.dimensions || {},
    };
  });
  const profile = db.prepare("SELECT profile_json, updated_at FROM candidate_profile WHERE id = 1").get();
  res.json({ series, profile: JSON.parse(profile.profile_json), profileUpdatedAt: profile.updated_at });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`InterviewPrep server on http://localhost:${PORT}`));
