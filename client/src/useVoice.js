import { useCallback, useEffect, useRef, useState } from "react";

// Voice layer built on the browser's Web Speech API.
// - unlock(): must be called from a click; unlocks speech synthesis (browsers block
//   audio that starts without a user gesture) and requests microphone permission.
// - speak(): reads interviewer replies aloud, sentence-chunked so long questions
//   don't hit Chrome's 15-second synthesis cutoff. Code blocks are announced, not read.
// - listen(): live speech-to-text; resolves the final transcript after ~2.2s of
//   silence, enabling a hands-free conversation loop.

const SR = typeof window !== "undefined" && (window.SpeechRecognition || window.webkitSpeechRecognition);

export function voiceSupported() {
  return !!SR && "speechSynthesis" in window;
}

function pickVoice() {
  const voices = window.speechSynthesis.getVoices();
  return (
    voices.find((v) => v.lang.startsWith("en") && /Google UK English Male|Google US English|Natural|Neural/i.test(v.name)) ||
    voices.find((v) => v.lang.startsWith("en")) ||
    voices[0] ||
    null
  );
}

function chunkSentences(text) {
  // Split on sentence boundaries, merging tiny fragments, so each utterance is short.
  const raw = text.match(/[^.!?]+[.!?]+["')\]]*|\S[^.!?]*$/g) || [text];
  const chunks = [];
  let buf = "";
  for (const s of raw) {
    if ((buf + s).length > 180 && buf) {
      chunks.push(buf.trim());
      buf = s;
    } else {
      buf += s;
    }
  }
  if (buf.trim()) chunks.push(buf.trim());
  return chunks;
}

export function useVoice({ onFinalTranscript }) {
  const [speaking, setSpeaking] = useState(false);
  const [listening, setListening] = useState(false);
  const [interim, setInterim] = useState("");
  const [micGranted, setMicGranted] = useState(false);
  const recRef = useRef(null);
  const finalRef = useRef("");
  const silenceTimer = useRef(null);
  const activeRef = useRef(false);
  const speakingRef = useRef(false);
  const queueRef = useRef([]);
  const callbackRef = useRef(onFinalTranscript);
  callbackRef.current = onFinalTranscript;

  const unlock = useCallback(async () => {
    // 1. Unlock speech synthesis inside the user gesture.
    try {
      const u = new SpeechSynthesisUtterance(" ");
      u.volume = 0;
      window.speechSynthesis.speak(u);
      window.speechSynthesis.getVoices();
    } catch { /* noop */ }
    // 2. Ask for the microphone up front so the loop never stalls on a prompt.
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      stream.getTracks().forEach((t) => t.stop());
      setMicGranted(true);
      return true;
    } catch {
      setMicGranted(false);
      return false;
    }
  }, []);

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
    queueRef.current = [];
    speakingRef.current = false;
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
      setInterim((finalRef.current + " " + interimText).trim());
      clearTimeout(silenceTimer.current);
      if (finalRef.current.trim()) {
        silenceTimer.current = setTimeout(finishUtterance, 2200);
      }
    };
    rec.onend = () => {
      if (activeRef.current) {
        try { rec.start(); } catch { /* restarting too fast */ }
      }
    };
    rec.onerror = (e) => {
      if (e.error === "not-allowed" || e.error === "service-not-allowed") {
        activeRef.current = false;
        setListening(false);
        setMicGranted(false);
      }
    };

    try {
      rec.start();
      setListening(true);
      setInterim("");
    } catch { /* already started */ }
  }, [finishUtterance]);

  const speak = useCallback((text, { onDone } = {}) => {
    if (!("speechSynthesis" in window)) { onDone?.(); return; }
    window.speechSynthesis.cancel();

    const spoken = text
      .replace(/```[\s\S]*?```/g, " I've put the details on your screen. ")
      .replace(/[*_#`>|]/g, "")
      .replace(/\s+/g, " ")
      .trim();
    if (!spoken) { onDone?.(); return; }

    const chunks = chunkSentences(spoken);
    queueRef.current = chunks;
    speakingRef.current = true;
    setSpeaking(true);

    const voice = pickVoice();
    const next = () => {
      if (!speakingRef.current) return;
      const chunk = queueRef.current.shift();
      if (chunk == null) {
        speakingRef.current = false;
        setSpeaking(false);
        onDone?.();
        return;
      }
      const u = new SpeechSynthesisUtterance(chunk);
      if (voice) u.voice = voice;
      u.rate = 1.0;
      u.pitch = 1.0;
      u.onend = next;
      u.onerror = next;
      window.speechSynthesis.speak(u);
    };
    next();
  }, []);

  const stopSpeaking = useCallback(() => {
    speakingRef.current = false;
    queueRef.current = [];
    window.speechSynthesis.cancel();
    setSpeaking(false);
  }, []);

  useEffect(() => {
    // Chrome silently pauses long synthesis sessions; nudge it while speaking.
    const t = setInterval(() => {
      if (speakingRef.current && window.speechSynthesis.paused) window.speechSynthesis.resume();
    }, 4000);
    window.speechSynthesis?.getVoices();
    return () => {
      clearInterval(t);
      window.speechSynthesis?.cancel();
      activeRef.current = false;
      speakingRef.current = false;
      try { recRef.current?.stop(); } catch { /* noop */ }
      clearTimeout(silenceTimer.current);
    };
  }, []);

  return { unlock, micGranted, speak, stopSpeaking, listen, stopListening, finishUtterance, speaking, listening, interim };
}
