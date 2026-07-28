import { useCallback, useEffect, useRef, useState } from "react";

// Voice layer built on the browser's Web Speech API.
// - speak(): reads interviewer replies aloud (code blocks are skipped and announced).
// - listen(): live speech-to-text with interim results; resolves the final transcript
//   after ~2.2s of silence, enabling a hands-free conversation loop.

const SR = typeof window !== "undefined" && (window.SpeechRecognition || window.webkitSpeechRecognition);

export function voiceSupported() {
  return !!SR && "speechSynthesis" in window;
}

function pickVoice() {
  const voices = window.speechSynthesis.getVoices();
  return (
    voices.find((v) => v.lang.startsWith("en") && /Google|Natural|Neural/i.test(v.name)) ||
    voices.find((v) => v.lang.startsWith("en")) ||
    voices[0] ||
    null
  );
}

export function useVoice({ onFinalTranscript }) {
  const [speaking, setSpeaking] = useState(false);
  const [listening, setListening] = useState(false);
  const [interim, setInterim] = useState("");
  const recRef = useRef(null);
  const finalRef = useRef("");
  const silenceTimer = useRef(null);
  const activeRef = useRef(false); // whether we should keep the recognizer alive
  const callbackRef = useRef(onFinalTranscript);
  callbackRef.current = onFinalTranscript;

  const stopListening = useCallback(() => {
    activeRef.current = false;
    clearTimeout(silenceTimer.current);
    try { recRef.current?.stop(); } catch { /* already stopped */ }
    setListening(false);
    setInterim("");
  }, []);

  const finishUtterance = useCallback(() => {
    const text = finalRef.current.trim();
    finalRef.current = "";
    stopListening();
    if (text) callbackRef.current?.(text);
  }, [stopListening]);

  const listen = useCallback(() => {
    if (!SR || activeRef.current) return;
    window.speechSynthesis.cancel();
    setSpeaking(false);

    const rec = new SR();
    recRef.current = rec;
    rec.lang = "en-US";
    rec.continuous = true;
    rec.interimResults = true;
    activeRef.current = true;
    finalRef.current = "";

    rec.onresult = (e) => {
      let interimText = "";
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const t = e.results[i][0].transcript;
        if (e.results[i].isFinal) finalRef.current += t + " ";
        else interimText += t;
      }
      setInterim(interimText || finalRef.current);
      clearTimeout(silenceTimer.current);
      // Auto-send after a pause, once we actually have words.
      if (finalRef.current.trim()) {
        silenceTimer.current = setTimeout(finishUtterance, 2200);
      }
    };
    rec.onend = () => {
      // Chrome stops recognition periodically; restart while the mic is meant to be on.
      if (activeRef.current) {
        try { rec.start(); } catch { /* restarting too fast */ }
      }
    };
    rec.onerror = (e) => {
      if (e.error === "not-allowed" || e.error === "service-not-allowed") {
        activeRef.current = false;
        setListening(false);
        setInterim("Microphone permission denied — check your browser settings.");
      }
    };

    try {
      rec.start();
      setListening(true);
      setInterim("");
    } catch {
      /* already started */
    }
  }, [finishUtterance]);

  const speak = useCallback((text, { onDone } = {}) => {
    if (!("speechSynthesis" in window)) { onDone?.(); return; }
    window.speechSynthesis.cancel();

    // Replace code blocks with a spoken pointer; strip residual markdown.
    const spoken = text
      .replace(/```[\s\S]*?```/g, " I've put the details on your screen. ")
      .replace(/[*_#`>]/g, "")
      .trim();
    if (!spoken) { onDone?.(); return; }

    const u = new SpeechSynthesisUtterance(spoken);
    const v = pickVoice();
    if (v) u.voice = v;
    u.rate = 1.02;
    u.onstart = () => setSpeaking(true);
    u.onend = () => { setSpeaking(false); onDone?.(); };
    u.onerror = () => { setSpeaking(false); onDone?.(); };
    window.speechSynthesis.speak(u);
  }, []);

  const stopSpeaking = useCallback(() => {
    window.speechSynthesis.cancel();
    setSpeaking(false);
  }, []);

  useEffect(() => {
    // Some browsers load voices asynchronously.
    window.speechSynthesis?.getVoices();
    return () => {
      window.speechSynthesis?.cancel();
      activeRef.current = false;
      try { recRef.current?.stop(); } catch { /* noop */ }
      clearTimeout(silenceTimer.current);
    };
  }, []);

  return { speak, stopSpeaking, listen, stopListening, finishUtterance, speaking, listening, interim };
}
