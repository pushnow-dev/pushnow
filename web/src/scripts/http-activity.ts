const sensitive = /authorization|cookie|token|secret|password|private|device_code|user_code|(^|_)key($|_)/i;
export function redact(value: unknown, depth = 0): unknown {
  if (depth > 6) return "[truncated]";
  if (Array.isArray(value)) return value.slice(0, 30).map(item => redact(item, depth + 1));
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).map(([key, item]) =>
    [key, sensitive.test(key) ? "[redacted]" : redact(item, depth + 1)]));
  return typeof value === "string" && value.length > 500 ? `${value.slice(0, 100)}...[${value.length} characters]` : value;
}

export function additionalHeaders(value: string): Headers {
  const data = JSON.parse(value || "{}");
  if (!data || typeof data !== "object" || Array.isArray(data) || Object.keys(data).length > 10) throw new Error("Enter a JSON object with at most 10 X- headers");
  const headers = new Headers();
  for (const [key, val] of Object.entries(data)) {
    if (!/^x-[a-z0-9-]{1,60}$/i.test(key) || typeof val !== "string" || /[^\x20-\x7e]/.test(val) || val.length > 200) {
      throw new Error("Additional headers must use X- names and short, single-line text values");
    }
    headers.set(key, val);
  }
  return headers;
}

export class HttpActivity {
  private generation = 0;
  headers = new Headers();
  constructor(private list: HTMLOListElement, private api: string) {}
  clear() { this.generation++; this.list.replaceChildren(); }
  fetcher: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    if (url.origin !== new URL(this.api).origin || url.username || url.password) throw new Error("Unexpected API origin");
    this.headers.forEach((value, key) => request.headers.set(key, value));
    const generation = this.generation, start = performance.now();
    let body: unknown = null;
    if (request.headers.get("content-type")?.includes("application/json")) {
      body = await request.clone().json().catch(() => "[unreadable JSON]");
    } else if (request.body) body = "[encrypted binary upload]";
    const entry = { method: request.method, path: url.pathname,
      request: { headers: Object.fromEntries([...request.headers].map(([key, value]) =>
        [key, ["content-type", "idempotency-key"].includes(key) ? value : "[redacted]"])), body: redact(body) } };
    try {
      const response = await fetch(request);
      const data = response.status === 204 ? null : await response.clone().json().catch(() => "[non-JSON response]");
      if (generation === this.generation) this.append({ ...entry, status: response.status,
        durationMs: Math.round(performance.now() - start), response: redact(data) });
      return response;
    } catch (error) {
      if (generation === this.generation) this.append({ ...entry, status: "Network error", durationMs: Math.round(performance.now() - start) });
      throw error;
    }
  };
  private append(entry: { method: string; path: string; status: string | number; durationMs: number; response?: unknown }) {
    const li = document.createElement("li"), details = document.createElement("details"), summary = document.createElement("summary"), pre = document.createElement("pre");
    summary.textContent = `${entry.method} ${entry.path} · ${entry.status} · ${entry.durationMs} ms`;
    pre.textContent = JSON.stringify(entry, null, 2);
    details.append(summary, pre); li.append(details); this.list.prepend(li);
    while (this.list.children.length > 50) this.list.lastElementChild?.remove();
  }
}
