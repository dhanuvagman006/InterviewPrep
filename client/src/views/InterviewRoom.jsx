import { useEffect, useRef, useState } from "react";
import { api } from "../api.js";
import { useVoice, voiceSupported } from "../useVoice.js";

function renderContent(text) {
  const parts = text.split(/```(?:\w*\n)?/);
  return parts.map((part, i) =>
    i % 2 === 1 ? <pre key={i}>{part}</pre> : <span key={i}>{part}</span>
  );
}

export default function InterviewRoom({ sessionId, rounds, onFinished }) {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [codeMode, setCodeMode] = useState(false);
  const [voiceMode, setVoiceMode] = useState(voiceSupported());
  const [roundIndex, setRoundIndex] = useState(0);
  const [notesCount, setNotesCount] = useState(0);
  const [startedAt] = useState(Date.now());
  const [elapsed, setElapsed] = useState(0);
  const [busy, setBusy] = useState(false);
  const [complete, setComplete] = useState(false);
  const logRef = useRef(null);
  const voiceModeRef = useRef(voiceMode);
  voiceModeRef.current = voiceMode;
  const codeModeRef = useRef(codeMode);
  codeModeRef.current = codeMode;

  const voice = useVoice({
    onFinalTranscript: (text) => sendText(text),
  });

  useEffect(() => {
    const t = setInterval(() => setElapsed(Math.floor((Date.now() - startedAt) / 60000)), 15000);
    return () => clearInterval(t);
  }, [startedAt]);

  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, busy, voice.interim]);

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
      // Speak the reply, then open the mic — the hands-free loop.
      voice.speak(res.message, {
        onDone: () => {
          if (voiceModeRef.current && !codeModeRef.current) voice.listen();
        },
      });
    }
  }

  // Interviewer speaks first.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      setBusy(true);
      try {
        const res = await api.sendMessage(sessionId, null);
        if (!cancelled) handleReply(res);
      } finally {
        if (!cancelled) setBusy(false);
      }
    })();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessionId]);

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
      setMessages((m) => [
        ...m,
        { role: "assistant", content: "(Connection issue — please resend your last answer.) " + err.message },
      ]);
    } finally {
      setBusy(false);
    }
  }

  function sendTyped() {
    const text = codeMode ? "```\n" + input.trim() + "\n```" : input.trim();
    sendText(text);
  }

  function toggleVoiceMode() {
    const next = !voiceMode;
    setVoiceMode(next);
    if (!next) {
      voice.stopSpeaking();
      voice.stopListening();
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
            {voice.listening && (
              <div className="msg candidate live">
                <span className="who">You — speaking</span>
                {voice.interim || "…"}
              </div>
            )}
          </div>
          {busy && <div className="typing">Interviewer is thinking…</div>}
          {voice.speaking && <div className="typing">🔊 Interviewer is speaking… <button className="btn-mini" onClick={() => { voice.stopSpeaking(); if (voiceMode && !codeMode) voice.listen(); }}>Skip</button></div>}

          {complete ? (
            <div className="composer">
              <button className="btn-primary" onClick={onFinished}>
                Interview finished — view your evaluation
              </button>
            </div>
          ) : (
            <div className="composer">
              {voiceMode && !codeMode ? (
                <div className="voice-deck">
                  <button
                    className={"mic " + (voice.listening ? "live" : "")}
                    onClick={() => (voice.listening ? voice.finishUtterance() : voice.listen())}
                    disabled={busy || voice.speaking}
                    aria-label={voice.listening ? "Finish answer and send" : "Start speaking"}
                  >
                    {voice.listening ? "■" : "🎙"}
                  </button>
                  <div className="voice-hints">
                    <strong>{voice.listening ? "Listening — pause to send, or tap to finish" : voice.speaking ? "Interviewer speaking…" : busy ? "Waiting for interviewer…" : "Tap the mic and answer out loud"}</strong>
                    <span className="hint">Answers send automatically after a short pause. Prefer typing? Switch modes below.</span>
                  </div>
                </div>
              ) : (
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
                  placeholder={codeMode ? "Write your solution here…" : "Answer the interviewer… (Enter to send, Shift+Enter for a new line)"}
                  aria-label="Your answer"
                />
              )}
              <div className="composer-row">
                <div style={{ display: "flex", gap: 8 }}>
                  <button className="btn-ghost" onClick={() => setCodeMode(!codeMode)}>
                    {codeMode ? "Leave code mode" : "Code mode"}
                  </button>
                  {voiceSupported() ? (
                    <button className="btn-ghost" onClick={toggleVoiceMode}>
                      {voiceMode ? "Voice: on" : "Voice: off"}
                    </button>
                  ) : (
                    <span className="hint" style={{ alignSelf: "center" }}>
                      Voice needs Chrome or Edge
                    </span>
                  )}
                </div>
                {(!voiceMode || codeMode) && (
                  <button className="btn-primary" onClick={sendTyped} disabled={busy || !input.trim()}>
                    Send
                  </button>
                )}
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
            <span>MODE — {codeMode ? "CODE" : voiceMode ? "VOICE" : "TEXT"}</span>
          </div>
          <div className="scratch">
            The interviewer is keeping private notes on every answer. You'll see all of them, scored and
            explained, in your final evaluation. Speak naturally — pauses end your answer, and code is always
            typed in code mode.
          </div>
        </aside>
      </div>
    </div>
  );
}
