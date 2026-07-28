import { useEffect, useRef, useState } from "react";
import { api } from "../api.js";

function renderContent(text) {
  // Split into code blocks and prose for display.
  const parts = text.split(/```(?:\w*\n)?/);
  return parts.map((part, i) =>
    i % 2 === 1 ? <pre key={i}>{part}</pre> : <span key={i}>{part}</span>
  );
}

export default function InterviewRoom({ sessionId, rounds, onFinished }) {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [codeMode, setCodeMode] = useState(false);
  const [roundIndex, setRoundIndex] = useState(0);
  const [notesCount, setNotesCount] = useState(0);
  const [startedAt] = useState(Date.now());
  const [elapsed, setElapsed] = useState(0);
  const [busy, setBusy] = useState(false);
  const [complete, setComplete] = useState(false);
  const logRef = useRef(null);

  useEffect(() => {
    const t = setInterval(() => setElapsed(Math.floor((Date.now() - startedAt) / 60000)), 15000);
    return () => clearInterval(t);
  }, [startedAt]);

  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, busy]);

  // Kick off: interviewer speaks first.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      setBusy(true);
      try {
        const res = await api.sendMessage(sessionId, null);
        if (cancelled) return;
        setMessages([{ role: "assistant", content: res.message }]);
        setRoundIndex(res.roundIndex);
        setNotesCount(res.notesCount);
      } finally {
        if (!cancelled) setBusy(false);
      }
    })();
    return () => { cancelled = true; };
  }, [sessionId]);

  async function send() {
    const text = codeMode ? "```\n" + input.trim() + "\n```" : input.trim();
    if (!text || busy) return;
    setMessages((m) => [...m, { role: "user", content: text }]);
    setInput("");
    setBusy(true);
    try {
      const res = await api.sendMessage(sessionId, text);
      setMessages((m) => [...m, { role: "assistant", content: res.message }]);
      setRoundIndex(res.roundIndex);
      setNotesCount(res.notesCount);
      if (res.interviewComplete) setComplete(true);
    } catch (err) {
      setMessages((m) => [...m, { role: "assistant", content: "(Connection issue — please resend your last answer.) " + err.message }]);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <div className="roundtrack" aria-label="Interview rounds">
        {rounds.map((r, i) => (
          <div key={r} className={"step " + (i < roundIndex ? "done" : i === roundIndex ? "now" : "")}>
            {i < roundIndex ? "✓ " : ""}{r}
          </div>
        ))}
      </div>

      <div className="room">
        <div className="panel chat">
          <div className="chat-log" ref={logRef}>
            {messages.map((m, i) => (
              <div key={i} className={"msg " + (m.role === "user" ? "candidate" : "interviewer")}>
                <span className="who">{m.role === "user" ? "You" : "Interviewer"}</span>
                {renderContent(m.content)}
              </div>
            ))}
          </div>
          {busy && <div className="typing">Interviewer is writing…</div>}

          {complete ? (
            <div className="composer">
              <button className="btn-primary" onClick={onFinished}>
                Interview finished — view your evaluation
              </button>
            </div>
          ) : (
            <div className="composer">
              <textarea
                className={codeMode ? "code-mode" : ""}
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey && !codeMode) {
                    e.preventDefault();
                    send();
                  }
                }}
                placeholder={codeMode ? "Write your solution here…" : "Answer the interviewer… (Enter to send, Shift+Enter for a new line)"}
                aria-label="Your answer"
              />
              <div className="composer-row">
                <button className="btn-ghost" onClick={() => setCodeMode(!codeMode)}>
                  {codeMode ? "Switch to answer mode" : "Switch to code mode"}
                </button>
                <button className="btn-primary" onClick={send} disabled={busy || !input.trim()}>
                  Send
                </button>
              </div>
            </div>
          )}
        </div>

        <aside className="notepad" aria-label="Interview status">
          <span className="eyebrow">Interviewer's notepad</span>
          <h3>Evaluation in progress</h3>
          <div className="meta">
            <span>ROUND — {rounds[Math.min(roundIndex, rounds.length - 1)]}</span>
            <span>ELAPSED — {elapsed} min</span>
            <span>NOTES TAKEN — {notesCount}</span>
          </div>
          <div className="scratch">
            The interviewer is keeping private notes on every answer. You'll see all of them, scored and
            explained, in your final evaluation.
          </div>
        </aside>
      </div>
    </div>
  );
}
