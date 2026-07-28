import { useEffect, useState } from "react";
import { api } from "../api.js";

const DECISION_LABEL = {
  strong_hire: "Strong hire",
  hire: "Hire",
  borderline: "Borderline",
  reject: "Reject",
};

const DIM_LABEL = {
  technical_knowledge: "Technical knowledge",
  coding_ability: "Coding ability",
  communication: "Communication",
  confidence: "Confidence",
  problem_solving: "Problem solving",
  resume_authenticity: "Resume authenticity",
  project_understanding: "Project understanding",
  leadership: "Leadership",
  system_design: "System design",
  behavioral: "Behavioral",
};

export default function Report({ sessionId, onDone }) {
  const [report, setReport] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    api
      .getReport(sessionId)
      .then((r) => !cancelled && setReport(r))
      .catch((e) => !cancelled && setError(e.message));
    return () => { cancelled = true; };
  }, [sessionId]);

  if (error) return <div className="panel empty">Couldn't build the report: {error}</div>;
  if (!report)
    return (
      <div className="panel empty">
        The hiring committee is writing your evaluation… this takes about half a minute.
      </div>
    );

  return (
    <div className="panel">
      <div className="report-head">
        <div>
          <span className="eyebrow">Hiring committee evaluation</span>
          <div className="score-big">
            {Math.round(report.overall_score)}<small> / 100 overall</small>
          </div>
        </div>
        <div className={"verdict " + report.decision}>{DECISION_LABEL[report.decision] || report.decision}</div>
      </div>

      <div className="report-section">
        <h2>Decision reasoning</h2>
        <p>{report.decision_reasoning}</p>
      </div>

      <div className="report-section">
        <h2>Round scores</h2>
        {(report.round_scores || []).map((r) => (
          <p key={r.round} style={{ fontSize: 13.5 }}>
            <strong style={{ fontFamily: "var(--mono)" }}>{r.score}/10</strong> — {r.round}. {r.commentary}
          </p>
        ))}
      </div>

      <div className="report-section">
        <h2>Skill dimensions</h2>
        <div className="dims">
          {Object.entries(report.dimensions || {}).map(([k, v]) => (
            <div className="dim" key={k}>
              {DIM_LABEL[k] || k} <span className="val">{v}/10</span>
              <div className="bar"><i style={{ width: `${(v / 10) * 100}%` }} /></div>
            </div>
          ))}
        </div>
      </div>

      <div className="report-section two-col">
        <div>
          <h2>Strengths</h2>
          <ul className="list-plain">{(report.strengths || []).map((s, i) => <li key={i}>{s}</li>)}</ul>
        </div>
        <div>
          <h2>Weaknesses</h2>
          <ul className="list-plain">{(report.weaknesses || []).map((s, i) => <li key={i}>{s}</li>)}</ul>
        </div>
      </div>

      <div className="report-section">
        <h2>Improvement plan</h2>
        {(report.improvement_plan || []).map((p, i) => (
          <div className="plan-item" key={i}>
            <h4>{p.area}</h4>
            <dl>
              <dt>What went wrong</dt><dd>{p.what_went_wrong}</dd>
              <dt>Why</dt><dd>{p.why}</dd>
              <dt>Weak concepts</dt><dd>{(p.weak_concepts || []).join(", ")}</dd>
              <dt>Questions that exposed it</dt><dd>{(p.exposing_questions || []).join(" · ")}</dd>
              <dt>How to improve</dt><dd>{p.how_to_improve}</dd>
              <dt>Practice order</dt><dd>{(p.practice_order || []).join(" → ")}</dd>
              <dt>Resources</dt><dd>{(p.resources || []).join(" · ")}</dd>
            </dl>
          </div>
        ))}
      </div>

      <div className="report-section two-col">
        <div>
          <h2>Short-term goals (2 weeks)</h2>
          <ul className="list-plain">{(report.short_term_goals || []).map((s, i) => <li key={i}>{s}</li>)}</ul>
        </div>
        <div>
          <h2>Long-term goals (2–3 months)</h2>
          <ul className="list-plain">{(report.long_term_goals || []).map((s, i) => <li key={i}>{s}</li>)}</ul>
        </div>
      </div>

      <div className="report-section">
        <h2>Progress vs your history</h2>
        <p>{report.progress_vs_history}</p>
        <button className="btn-primary" onClick={onDone} style={{ marginTop: 10 }}>
          Go to history & progress
        </button>
      </div>
    </div>
  );
}
