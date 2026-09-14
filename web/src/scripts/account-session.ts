const storageKey = "pushnow.web.session";
type User = { id: string; email: string };
type Session = { accessToken: string; refreshToken?: string; user?: User };
let epoch = 0;
let refreshTask: Promise<void> | undefined;
let verifiedUser: User | undefined;

export class AccountError extends Error {
  constructor(public status: number, public code: string) { super(code || `HTTP ${status}`); }
}

export function session(): Session | null {
  try {
    const raw = JSON.parse(sessionStorage.getItem(storageKey) || "null");
    const accessToken = raw?.accessToken ?? raw?.access_token;
    if (typeof accessToken !== "string" || !accessToken) return null;
    return { accessToken, refreshToken: raw.refreshToken ?? raw.refresh_token, user: raw.user };
  } catch { return null; }
}

function announce() {
  document.dispatchEvent(new CustomEvent("pushnow:account-state", { detail: { user: verifiedUser ?? null } }));
}

export function saveSession(value: unknown) {
  if (!value || typeof value !== "object") throw new Error("Invalid login response");
  const raw = value as Record<string, unknown>;
  if (typeof (raw.accessToken ?? raw.access_token) !== "string") throw new Error("Invalid login response");
  epoch++;
  sessionStorage.setItem(storageKey, JSON.stringify(value));
  verifiedUser = undefined;
  announce();
  document.dispatchEvent(new CustomEvent("pushnow:session-updated"));
}

export function clearSession() {
  epoch++;
  sessionStorage.removeItem(storageKey);
  verifiedUser = undefined;
  announce();
  document.dispatchEvent(new CustomEvent("pushnow:session-cleared"));
}

async function responseData(response: Response) {
  const data = response.status === 204 ? null : await response.json().catch(() => null);
  if (!response.ok) throw new AccountError(response.status, typeof data?.code === "string" ? data.code : `HTTP ${response.status}`);
  return data;
}

export async function publicRequest(api: string, path: string, options: RequestInit = {}) {
  if (!path.startsWith("/v1/auth/") || path.includes("..")) throw new Error("Invalid authentication endpoint");
  return responseData(await fetch(new URL(path, api), { ...options, redirect: "error",
    signal: options.signal ?? AbortSignal.timeout(20_000),
    headers: { "Content-Type": "application/json", ...Object.fromEntries(new Headers(options.headers)) } }));
}

async function refresh(api: string) {
  if (refreshTask) return refreshTask;
  const current = session(), version = epoch;
  if (!current?.refreshToken) { clearSession(); throw new AccountError(401, "session_expired"); }
  refreshTask = (async () => {
    try {
      const data = await publicRequest(api, "/v1/auth/refresh", {
        method: "POST", body: JSON.stringify({ refreshToken: current.refreshToken })
      });
      if (epoch !== version) throw new Error("Account changed");
      sessionStorage.setItem(storageKey, JSON.stringify(data));
    } catch (error) {
      if (epoch === version && error instanceof AccountError && error.status === 401) clearSession();
      throw error;
    } finally { refreshTask = undefined; }
  })();
  return refreshTask;
}

export async function accountRequest(api: string, path: string, options: RequestInit = {}) {
  if (!/^\/v[12]\//.test(path) || path.includes("..")) throw new Error("Invalid account endpoint");
  const version = epoch;
  const send = async () => {
    const auth = session();
    if (!auth) throw new AccountError(401, "session_expired");
    const headers = new Headers(options.headers);
    headers.set("Content-Type", "application/json");
    headers.set("Authorization", `Bearer ${auth.accessToken}`);
    return { response: await fetch(new URL(path, api), { ...options, headers, redirect: "error",
      signal: options.signal ?? AbortSignal.timeout(20_000) }), accessToken: auth.accessToken };
  };
  let result = await send();
  if (result.response.status === 401) {
    if (session()?.accessToken === result.accessToken) await refresh(api);
    result = await send();
  }
  const data = await responseData(result.response);
  if (version !== epoch) throw new Error("Account changed");
  return data;
}

export async function validateSession(api: string) {
  if (!session()) { verifiedUser = undefined; announce(); return null; }
  const data = await accountRequest(api, "/v1/me");
  if (typeof data?.user?.id !== "string" || typeof data.user.email !== "string") throw new Error("Invalid account response");
  verifiedUser = data.user;
  announce();
  return verifiedUser;
}

export async function signOut(api: string) {
  const auth = session();
  if (!auth) { clearSession(); return; }
  // Keep the session on network failure so server-side logout can be retried.
  await publicRequest(api, "/v1/auth/logout", { method: "POST",
    headers: { Authorization: `Bearer ${auth.accessToken}` },
    body: JSON.stringify({ refreshToken: auth.refreshToken })
  }).catch(error => { if (!(error instanceof AccountError && error.status === 401)) throw error; });
  clearSession();
}

export const accountSession = { session, saveSession, clearSession, publicRequest, accountRequest, validateSession, signOut };
declare global { interface Window { pushnowSession: typeof accountSession } }
