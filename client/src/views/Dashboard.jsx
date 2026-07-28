import { useEffect, useState } from "react";
import { api } from "../api.js";

function TrendChart({ series }) {
  if (!series.length) return <p className="hint">Complete an interview to start your trend line.</p>;
  const w = 640, h = 180, pad = 28;
  const xs = series.map((_, i) =>
    series.length === 1 ? w / 2 : pad + (i * (w - pad * 2)) / (series.length - 1)
  );
  const y = (score) => h - pad - (score / 100) * (h - pad * 2);
  const path = series.map((p, i) => `${i === 0 ? "M" : "L"}${xs[i]},${y(p.overall)}`).join(" ");
  return (
    <svg viewBox={`0 0 ${w} ${h}`} width="100%" role="img" aria-label="Overall score across interviews">
      {[0, 50, 100].map((g) => (
        <g key={g}>
          <line x1={pad} x2={w - pad} y1={y(g)} y2={y(g)} stroke="#e2e7e9" />
          <text x={4} y={y(g) + 4} fontSize="10" fontFamily="var(--mono)" fill="#8a97a0">{g}</text>
        </g>
      ))}
      <path d={path} fill="none" stroke="#171d22" strokeWidth="2" />
      {series.map((p, i) => (
        <circle key={i} cx={xs[i]} cy={y(p.overall)} r="4"
          fill={p.decision === "reject" ? "#b3402e" : p.decision === "borderline" ? "#c77e1f" : "#1f7a4d"}>
          <title>{new Date(p.date).toLocaleDateString()} — {Math.round(p.overall)}/100 ({p.decision})</title>
        </circle>
      ))}
    </svg>
  );
}

function dimensionTrends(series) {
  if (series.length < 2) return [];
  const first = series[0].dimensions || {};
  const last = series[series.length - 1].dimensions || {};
  return Object.keys(last)
    .filter((k) => first[k] != null)
    .map((k) => ({ key: k, delta: +(last[k] - first[k]).toFixed(1) }))
    .filter((d) => d.delta !== 0)
    .sort((a, b) => b.delta - a.delta);
}

export default function Dashboard({ onOpenReport }) {
  const [history, setHistory] = useState(null);
  const [progress, setProgress] = useState(null);

  useEffect(() => {
    api.history().then(setHistory);
    api.progress().then(setProgress);
  }, []);

  if (!history || !progress) return <div className="panel empty">Loading your record…</div>;

  const trends = dimensionTrends(progress.series);
  const profile = progress.profile || {};

  return (
    <div className="dash-grid">
      <div>
        <div className="panel chartbox">
          <span className="eyebrow">Overall score across interviews</span>
          <TrendChart series={progress.series} />
          {trends.length > 0 && (
            <p style={{ fontSize: 13, marginTop: 8 }}>
              Since your first interview:{" "}
              {trends.map((t) => (
                <span key={t.key} style={{ marginRight: 12, fontFamily: "var(--mono)", fontSize: 12, color: t.delta > 0 ? "var(--green)" : "var(--red)" }}>
                  {t.key.replaceAll("_", " ")} {t.delta > 0 ? "+" : ""}{t.delta}
                </span>
              ))}
            </p>
          )}
        </div>

        <div className="panel" style={{ marginTop: 20 }}>
          <div style={{ padding: "16px 18px 4px" }}>
            <span className="eyebrow">Interview history</span>
          </div>
          {history.length === 0 && <div className="empty">No interviews yet. Your record starts with the first one.</div>}
          {history.map((row) => (
            <div className="history-row" key={row.id}>
              <span className="mono">{new Date(row.created_at).toLocaleDateString()}</span>
              <span>{row.role} · {row.difficulty}{row.durationMinutes ? ` · ${row.durationMinutes} min` : ""}</span>
              <span className="mono">{row.overall_score != null ? Math.round(row.overall_score) + "/100" : "—"}</span>
              <span><span className={"tag " + (row.decision || "active")}>{(row.decision || row.status).replaceAll("_", " ")}</span></span>
              {row.overall_score != null ? (
                <button className="btn-ghost" onClick={() => onOpenReport(row.id)}>Report</button>
              ) : <span />}
            </div>
          ))}
        </div>
      </div>

      <aside className="panel" style={{ padding: 20 }}>
        <span className="eyebrow">What the coach knows about you</span>
        <h3 style={{ margin: "2px 0 12px", fontSize: 16 }}>Candidate profile</h3>
        {Object.keys(profile).length === 0 ? (
          <p className="hint">After your first completed interview, the coach builds a profile here and uses it to personalize every future interview.</p>
        ) : (
          <div style={{ fontSize: 13.5 }}>
            <p><strong>Recurring strengths:</strong> {(profile.recurring_strengths || []).join(", ") || "—"}</p>
            <p><strong>Recurring weaknesses:</strong> {(profile.recurring_weaknesses || []).join(", ") || "—"}</p>
            <p><strong>Mastered topics:</strong> {(profile.mastered_topics || []).join(", ") || "—"}</p>
            <p><strong>Focus next:</strong> {(profile.focus_topics || []).join(", ") || "—"}</p>
            <p><strong>Recommended difficulty:</strong> {profile.recommended_next_difficulty || "—"}</p>
            {profile.notes && <p className="hint">{profile.notes}</p>}
          </div>
        )}
      </aside>
    </div>
  );
}
