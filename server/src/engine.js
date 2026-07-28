import crypto from "crypto";
import { geminiGenerate } from "./gemini.js";
import db from "./db.js";
import { ROUNDS, baseSystemPrompt, reportPrompt } from "./rounds.js";

const getSession = db.prepare("SELECT * FROM sessions WHERE id = ?");
const getMessages = db.prepare(
  "SELECT role, content, round_index FROM messages WHERE session_id = ? ORDER BY id"
);
const insertMessage = db.prepare(
  "INSERT INTO messages (session_id, round_index, role, content, created_at) VALUES (?, ?, ?, ?, ?)"
);
const getProfileRow = db.prepare("SELECT profile_json FROM candidate_profile WHERE id = 1");

export function loadProfile() {
  try {
    return JSON.parse(getProfileRow.get().profile_json);
  } catch {
    return {};
  }
}

export function createSession({ difficulty, role, companyStyle, resumeText }) {
  const id = crypto.randomUUID();
  db.prepare(
    `INSERT INTO sessions (id, created_at, difficulty, role, company_style, resume_text)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).run(id, new Date().toISOString(), difficulty, role, companyStyle || null, resumeText || null);
  return id;
}

function parseControl(text) {
  const match = text.match(/<control>([\s\S]*?)<\/control>/);
  let control = null;
  if (match) {
    try {
      control = JSON.parse(match[1]);
    } catch {
      control = null;
    }
  }
  const visible = text.replace(/<control>[\s\S]*?<\/control>/g, "").trim();
  return { visible, control };
}

async function callInterviewer(session, history) {
  const askedQuestions = JSON.parse(session.asked_questions);
  const roundSummaries = JSON.parse(session.round_summaries);
  const system = baseSystemPrompt({
    session,
    profile: loadProfile(),
    notes: session.interviewer_notes,
    askedQuestions,
    roundSummaries,
  });

  // Keep the recent window verbatim; older turns are summarized implicitly via notes.
  const window = history.slice(-30).map((m) => ({ role: m.role, content: m.content }));
  if (window.length === 0) {
    window.push({ role: "user", content: "(The candidate has joined the interview. Greet them and begin.)" });
  } else if (window[0].role === "assistant") {
    // Gemini requires the conversation to start with a user turn.
    window.unshift({ role: "user", content: "(Earlier conversation continues below.)" });
  }

  return geminiGenerate({ system, messages: window, maxTokens: 1500 });
}

export async function handleTurn(sessionId, userMessage) {
  const session = getSession.get(sessionId);
  if (!session) throw new Error("Session not found");
  if (session.status !== "active") throw new Error("Session is not active");

  const now = new Date().toISOString();
  if (userMessage != null) {
    insertMessage.run(sessionId, session.round_index, "user", userMessage, now);
  }
  const history = getMessages.all(sessionId);

  const raw = await callInterviewer(session, history);
  const { visible, control } = parseControl(raw);

  insertMessage.run(sessionId, session.round_index, "assistant", visible, new Date().toISOString());

  let notes = session.interviewer_notes;
  const asked = JSON.parse(session.asked_questions);
  const summaries = JSON.parse(session.round_summaries);
  let roundIndex = session.round_index;
  let interviewComplete = false;

  if (control) {
    if (control.notes_append) notes += (notes ? "\n" : "") + `[R${roundIndex + 1}] ` + control.notes_append;
    if (control.question_asked) asked.push(control.question_asked);
    if (control.round_complete) {
      summaries.push({
        round: ROUNDS[roundIndex].title,
        score: control.round_score ?? null,
        summary: control.round_summary || "",
      });
      if (roundIndex < ROUNDS.length - 1) {
        roundIndex += 1;
      } else {
        interviewComplete = true;
      }
    }
  }

  db.prepare(
    `UPDATE sessions SET interviewer_notes = ?, asked_questions = ?, round_summaries = ?, round_index = ?, status = ?, finished_at = ? WHERE id = ?`
  ).run(
    notes,
    JSON.stringify(asked),
    JSON.stringify(summaries),
    roundIndex,
    interviewComplete ? "completed" : "active",
    interviewComplete ? new Date().toISOString() : null,
    sessionId
  );

  return {
    message: visible,
    roundIndex,
    roundTitle: ROUNDS[Math.min(roundIndex, ROUNDS.length - 1)].shortTitle,
    interviewComplete,
    roundJustCompleted: !!control?.round_complete,
    notesCount: notes.split("\n").filter(Boolean).length,
  };
}

export async function generateReport(sessionId) {
  const session = getSession.get(sessionId);
  if (!session) throw new Error("Session not found");
  const existing = db.prepare("SELECT report_json FROM reports WHERE session_id = ?").get(sessionId);
  if (existing) return JSON.parse(existing.report_json);

  const history = getMessages.all(sessionId);
  const transcriptDigest = history
    .map((m) => `${m.role === "user" ? "CANDIDATE" : "INTERVIEWER"}: ${m.content.slice(0, 400)}`)
    .join("\n")
    .slice(-24000);

  const prompt = reportPrompt({
    session,
    notes: session.interviewer_notes,
    roundSummaries: JSON.parse(session.round_summaries),
    transcriptDigest,
    profile: loadProfile(),
  });

  const text = await geminiGenerate({
    messages: [{ role: "user", content: prompt }],
    maxTokens: 4000,
    json: true,
  });
  const clean = text.replace(/```json|```/g, "").trim();
  const report = JSON.parse(clean);

  db.prepare(
    "INSERT INTO reports (session_id, created_at, overall_score, decision, report_json) VALUES (?, ?, ?, ?, ?)"
  ).run(sessionId, new Date().toISOString(), report.overall_score, report.decision, JSON.stringify(report));

  if (report.updated_profile) {
    db.prepare("UPDATE candidate_profile SET updated_at = ?, profile_json = ? WHERE id = 1").run(
      new Date().toISOString(),
      JSON.stringify(report.updated_profile)
    );
  }
  if (session.status !== "completed") {
    db.prepare("UPDATE sessions SET status = 'completed', finished_at = ? WHERE id = ?").run(
      new Date().toISOString(),
      sessionId
    );
  }
  return report;
}
