import { useEffect, useState } from "react";
import Setup from "./views/Setup.jsx";
import InterviewRoom from "./views/InterviewRoom.jsx";
import Report from "./views/Report.jsx";
import Dashboard from "./views/Dashboard.jsx";
import { api } from "./api.js";

export default function App() {
  const [view, setView] = useState({ name: "setup" }); // setup | interview | report | dashboard
  const [apiKeyOk, setApiKeyOk] = useState(true);

  useEffect(() => {
    api.health().then((h) => setApiKeyOk(h.apiKeyConfigured)).catch(() => setApiKeyOk(false));
  }, []);

  return (
    <div className="shell">
      <header className="topbar">
        <div className="wordmark">
          INTERVIEW<span>PREP</span>
        </div>
        <nav className="topnav">
          <button className={view.name === "setup" ? "active" : ""} onClick={() => setView({ name: "setup" })}>
            New interview
          </button>
          <button
            className={view.name === "dashboard" ? "active" : ""}
            onClick={() => setView({ name: "dashboard" })}
          >
            History & progress
          </button>
        </nav>
      </header>

      {!apiKeyOk && (
        <div className="alert">
          The server has no Anthropic API key. Copy <code>server/.env.example</code> to <code>server/.env</code>,
          add your key, and restart the server.
        </div>
      )}

      {view.name === "setup" && (
        <Setup onStarted={(sessionId, rounds) => setView({ name: "interview", sessionId, rounds })} />
      )}
      {view.name === "interview" && (
        <InterviewRoom
          sessionId={view.sessionId}
          rounds={view.rounds}
          onFinished={() => setView({ name: "report", sessionId: view.sessionId })}
        />
      )}
      {view.name === "report" && (
        <Report sessionId={view.sessionId} onDone={() => setView({ name: "dashboard" })} />
      )}
      {view.name === "dashboard" && (
        <Dashboard onOpenReport={(sessionId) => setView({ name: "report", sessionId })} />
      )}
    </div>
  );
}
