async function j(res) {
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "Request failed");
  return data;
}

export const api = {
  health: () => fetch("/api/health").then(j),
  parseResume: (file) => {
    const fd = new FormData();
    fd.append("file", file);
    return fetch("/api/resume/parse", { method: "POST", body: fd }).then(j);
  },
  startInterview: (body) =>
    fetch("/api/interviews", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }).then(j),
  sendMessage: (id, message) =>
    fetch(`/api/interviews/${id}/message`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    }).then(j),
  getReport: (id) => fetch(`/api/interviews/${id}/report`, { method: "POST" }).then(j),
  getInterview: (id) => fetch(`/api/interviews/${id}`).then(j),
  history: () => fetch("/api/history").then(j),
  progress: () => fetch("/api/progress").then(j),
};
