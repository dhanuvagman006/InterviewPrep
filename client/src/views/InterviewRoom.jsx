import { useEffect, useRef, useState } from "react";
import { api } from "../api.js";
import { useVoice, voiceSupported } from "../useVoice.js";

function renderContent(text) {
  const parts = text.split(/```(?:\w*\n)?/);
  return parts.map((part, i) =>
    i % 2 === 1 ? <pre key={i}>{part}</pre> : <span key={i}>{part}</span>
  );
}

function extractCode(text) {
  const blocks = [...text.matchAll(/```(?:\w*\n)?([\s\S]*?)```/g)].map((m) => m[1]);
  return blocks.length ? blocks.join("\n\n") : null;
}

export default function InterviewRoom({ sessionId, rounds, onFinished }) {
  const canVoice = voiceSupported();
  const [phase, setPhase] = useState(canVoice ? "lobby" : "live"); // lobby | live
  const [voiceMode, setVoiceMode] = useState(canVoice);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [codeMode, setCodeMode] = useState(false);
  const [showTranscript, setShowTranscript] = useState(false);
  const [roundIndex, setRoundIndex] = useState(0);
  const [notesCount, setNotesCount] = useState(0);
  const [startedAt, setStartedAt] = useState(null);
  const [elapsed, setElapsed] = useState(0);
  const [busy, setBusy] = useState(false);
  const [complete, setComplete] = useState(false);
  const logRef = useRef(null);
  const voiceModeRef = useRef(voiceMode);
  voiceModeRef.current = voiceMode;
  const codeModeRef = useRef(codeMode);
  codeModeRef.current = codeMode;

  const voice = useVoice({ onFinalTranscript: (text) => sendText(text) });

  const lastInterviewer = [...messages].reverse().find((m) => m.role === "assistant");
  const screenCode = lastInterviewer ? extractCode(lastInterviewer.content) : null;

  useEffect(() => {
    if (!startedAt) return;
    const t = setInterval(() => setElapsed(Math.floor((Date.now() - startedAt) / 60000)), 15000);
    return () => clearInterval(t);
  }, [startedAt]);

  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, busy, voice.interim, showTranscript]);

  function handleReply(res) {
    setMessages((m) => [...m, { role: "assistant", content: res.message }]);
    setRoundIndex(res.roundIndex);
    setNotesCount(res.notesCount);
    if (res.interviewComplete) {
      setComplete(true);
      if (voiceModeRef.current) voice.speak(res.message);
      return;
    }
    if (voiceModeRef.current) {
      voice.speak(res.message, {
        onDone: () => {
          if (voiceModeRef.current && !codeModeRef.current) voice.listen();
        },
      });
    }
  }

  async function begin() {
    setPhase("live");
    setStartedAt(Date.now());
    setBusy(true);
    try {
      const res = await api.sendMessage(sessionId, null);
      handleReply(res);
    } finally {
      setBusy(false);
    }
  }

  async function joinWithVoice() {
    const ok = await voice.unlock();
    setVoiceMode(ok);
    await begin();
  }

  async function joinTyped() {
    setVoiceMode(false);
    await begin();
  }

  // Non-voice browsers skip the lobby.
  useEffect(() => {
    if (!canVoice && phase === "live" && messages.length === 0 && !busy) begin();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function sendText(text) {
    if (!text || busy) return;
    voice.stopListening();
    setMessages((m) => [...m, { role: "user", content: text }]);
    setInput("");
    setBusy(true);
    try {
      const res = await api.sendMessage(sessionId, text);
      handleReply(res);
    } catch (err) {
      const msg = "(Connection issue — please repeat your last answer.) " + err.message;
      setMessages((m) => [...m, { role: "assistant", content: msg }]);
      if (voiceModeRef.current) voice.speak("Sorry, I lost you for a second. Could you repeat that?", {
        onDone: () => voiceModeRef.current && !codeModeRef.current && voice.listen(),
      });
    } finally {
      setBusy(false);
    }
  }

  function sendTyped() {
    const text = codeMode ? "```\n" + input.trim() + "\n```" : input.trim();
    if (!text.replace(/`/g, "").trim()) return;
    sendText(text);
  }

  function toggleVoiceMode() {
    const next = !voiceMode;
    setVoiceMode(next);
    if (!next) {
      voice.stopSpeaking();
      voice.stopListening();
    } else {
      voice.unlock().then((ok) => {
        if (ok && !busy && !voice.speaking) voice.listen();
      });
    }
  }

  // ---------- lobby ----------
  if (phase === "lobby") {
    return (
      <div className="panel lobby">
        <span className="eyebrow">Interview room</span>
        <h1>Your interviewer is ready.</h1>
        <p>
          This is a spoken interview. The interviewer will ask you questions out loud and listen to your answers —
          just talk, the way you would in a real call. Pausing for a couple of seconds sends your answer.
          Coding problems appear on screen, and code is typed.
        </p>
        <div className="lobby-actions">
          <button className="btn-primary" onClick={joinWithVoice}>
            🎙 Join with voice
          </button>
          <button className="btn-ghost" onClick={joinTyped}>
            Join as a typed interview instead
          </button>
        </div>
        <p className="hint">Joining asks for microphone permission. Use headphones if you can — it keeps the interviewer from hearing itself.</p>
      </div>
    );
  }

  // ---------- live ----------
  const status = complete
    ? "Interview finished"
    : busy
    ? "Thinking…"
    : voice.speaking
    ? "Asking…"
    : voice.listening
    ? "Listening to you"
    : voiceMode && !codeMode
    ? "Waiting — tap the mic to answer"
    : "Your turn";

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
        <div className="panel stage-wrap">
          {voiceMode && !codeMode ? (
            <div className="stage" aria-live="polite">
              <div className={"orb " + (voice.speaking ? "speaking" : voice.listening ? "listening" : busy ? "thinking" : "")}>
                <span>{voice.speaking ? "🗣" : voice.listening ? "🎙" : busy ? "…" : "●"}</span>
              </div>
              <div className="stage-status">{status}</div>

              {/* Captions: the current question, so you can re-read while answering */}
              {lastInterviewer && (
                <div className="caption">{lastInterviewer.content.replace(/```[\s\S]*?```/g, "").trim()}</div>
              )}
              {screenCode && (
                <pre className="screen-code" aria-label="Problem details">{screenCode}</pre>
              )}
              {voice.listening && <div className="you-line">“{voice.interim || "…"}”</div>}

              <div className="stage-controls">
                {voice.speaking && (
                  <button className="btn-ghost" onClick={() => { voice.stopSpeaking(); if (!codeMode) voice.listen(); }}>
                    Skip question audio
                  </button>
                )}
                {voice.listening ? (
                  <button className="btn-primary" onClick={voice.finishUtterance}>Done — send answer</button>
                ) : (
                  !busy && !voice.speaking && !complete && (
                    <button className="btn-primary" onClick={voice.listen}>🎙 Answer</button>
                  )
                )}
                {complete && (
                  <button className="btn-primary" onClick={onFinished}>View your evaluation</button>
                )}
              </div>
            </div>
          ) : (
            <div className="chat">
              <div className="chat-log" ref={logRef} style={{ minHeight: "40vh" }}>
                {messages.map((m, i) => (
                  <div key={i} className={"msg " + (m.role === "user" ? "candidate" : "interviewer")}>
                    <span className="who">{m.role === "user" ? "You" : "Interviewer"}</span>
                    {renderContent(m.content)}
                  </div>
                ))}
              </div>
              {busy && <div className="typing">Interviewer is thinking…</div>}
              {complete ? (
                <div className="composer">
                  <button className="btn-primary" onClick={onFinished}>Interview finished — view your evaluation</button>
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
                        sendTyped();
                      }
                    }}
                    placeholder={codeMode ? "Write your solution here, then submit…" : "Type your answer…"}
                    aria-label="Your answer"
                  />
                  <div className="composer-row">
                    <span />
                    <button className="btn-primary" onClick={sendTyped} disabled={busy || !input.trim()}>
                      {codeMode ? "Submit code" : "Send"}
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}

          <div className="modebar">
            <button className="btn-ghost" onClick={() => setCodeMode(!codeMode)}>
              {codeMode ? "← Back to conversation" : "Open code editor"}
            </button>
            {canVoice && (
              <button className="btn-ghost" onClick={toggleVoiceMode}>
                {voiceMode ? "Voice: on" : "Voice: off"}
              </button>
            )}
            <button className="btn-ghost" onClick={() => setShowTranscript(!showTranscript)}>
              {showTranscript ? "Hide transcript" : "Show transcript"}
            </button>
          </div>

          {showTranscript && voiceMode && !codeMode && (
            <div className="transcript" ref={logRef}>
              {messages.map((m, i) => (
                <div key={i} className={"msg " + (m.role === "user" ? "candidate" : "interviewer")}>
                  <span className="who">{m.role === "user" ? "You" : "Interviewer"}</span>
                  {renderContent(m.content)}
                </div>
              ))}
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
            <span>MODE — {codeMode ? "CODE" : voiceMode ? "VOICE" : "TEXT"}</span>
          </div>
          <div className="scratch">
            Speak naturally — a two-second pause sends your answer. The interviewer keeps private notes on every
            answer; you'll see all of them, scored and explained, in your final evaluation.
          </div>
        </aside>
      </div>
    </div>
  );
}
