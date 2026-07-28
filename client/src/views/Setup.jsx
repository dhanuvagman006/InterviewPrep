import { useState } from "react";
import { api } from "../api.js";

const STAGES = [
  ["Round 1", "Resume validation & HR screening"],
  ["Round 2", "Coding assessment — adaptive DSA problems"],
  ["Round 3", "Technical I — CS fundamentals, deep follow-ups"],
  ["Round 4", "Technical II — your projects & system design"],
  ["Round 5", "Behavioral — real stories, not a questionnaire"],
  ["Round 6", "Hiring manager — fit, goals, final verdict"],
];

export default function Setup({ onStarted }) {
  const [role, setRole] = useState("Software Engineer");
  const [difficulty, setDifficulty] = useState("intermediate");
  const [companyStyle, setCompanyStyle] = useState("");
  const [resumeText, setResumeText] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function handleFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setBusy(true);
    setError(null);
    try {
      const { text } = await api.parseResume(file);
      setResumeText(text);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function start() {
    setBusy(true);
    setError(null);
    try {
      const { sessionId, rounds } = await api.startInterview({ role, difficulty, companyStyle, resumeText });
      onStarted(sessionId, rounds);
    } catch (err) {
      setError(err.message);
      setBusy(false);
    }
  }

  return (
    <div className="setup-grid">
      <div className="setup-hero">
        <span className="eyebrow">Full hiring pipeline · ~2–3 hours · adaptive</span>
        <h1>Sit the whole interview. Get the real verdict.</h1>
        <p>
          An AI interviewer runs you through all six rounds of a software engineering hiring process — probing
          your resume, adapting difficulty to your answers, keeping private notes, and ending with a hire/no-hire
          decision plus a concrete improvement plan.
        </p>
        <ul className="pipeline">
          {STAGES.map(([stage, desc]) => (
            <li key={stage}>
              <span className="stage">{stage}</span>
              <span>{desc}</span>
            </li>
          ))}
        </ul>
      </div>

      <div className="panel setup-form">
        <div className="field">
          <label htmlFor="role">Role you're interviewing for</label>
          <input id="role" type="text" value={role} onChange={(e) => setRole(e.target.value)} />
        </div>

        <div className="field">
          <label>Difficulty</label>
          <div className="seg" role="group" aria-label="Difficulty">
            {["beginner", "intermediate", "advanced"].map((d) => (
              <button key={d} type="button" className={difficulty === d ? "on" : ""} onClick={() => setDifficulty(d)}>
                {d[0].toUpperCase() + d.slice(1)}
              </button>
            ))}
          </div>
        </div>

        <div className="field">
          <label htmlFor="company">Company style to simulate (optional)</label>
          <input
            id="company"
            type="text"
            placeholder="e.g. big-tech product company, early-stage startup"
            value={companyStyle}
            onChange={(e) => setCompanyStyle(e.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="resume">Resume</label>
          <textarea
            id="resume"
            placeholder="Paste your resume text here, or upload a PDF below. The interviewer will verify everything on it."
            value={resumeText}
            onChange={(e) => setResumeText(e.target.value)}
          />
          <input type="file" accept=".pdf,.txt,.md" onChange={handleFile} aria-label="Upload resume file" />
          <p className="hint">You can start without a resume — Round 1 will build one from your answers.</p>
        </div>

        {error && <p style={{ color: "var(--red)", fontSize: 13 }}>{error}</p>}

        <button className="btn-primary" onClick={start} disabled={busy}>
          {busy ? "Preparing your interviewer…" : "Begin interview"}
        </button>
      </div>
    </div>
  );
}
