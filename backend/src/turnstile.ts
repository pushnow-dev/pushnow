import { AuthHttpError } from "./crypto";

const SITEVERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";
const EXPECTED_ACTION = "turnstile-spin-v1";
const MAX_TOKEN_LENGTH = 2048;

type TurnstileEnv = Env & {
  TURNSTILE_SECRET_KEY?: string;
  TURNSTILE_EXPECTED_HOSTNAME?: string;
  TURNSTILE_EXPECTED_HOSTNAMES?: string;
};

type TurnstileProtectedInput = {
  turnstileToken?: string;
  client?: { platform?: string };
};

type TurnstileOutcome = {
  success?: boolean;
  hostname?: string;
  action?: string;
  "error-codes"?: string[];
};

export async function verifyTurnstileForWebAuth(request: Request, env: TurnstileEnv, input: TurnstileProtectedInput): Promise<void> {
  if (!requiresTurnstile(request, input)) return;

  const secret = env.TURNSTILE_SECRET_KEY?.trim();
  if (!secret) {
    throw new AuthHttpError(500, "missing_turnstile_secret", "安全验证服务缺少密钥配置");
  }

  const token = input.turnstileToken?.trim() ?? "";
  if (!token || token.length > MAX_TOKEN_LENGTH) {
    throw new AuthHttpError(400, "missing_turnstile_token", "请先完成人机验证");
  }

  let outcome: TurnstileOutcome;
  try {
    const response = await fetch(SITEVERIFY_URL, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        secret,
        response: token,
        remoteip: clientIP(request),
        idempotency_key: crypto.randomUUID()
      })
    });
    outcome = (await response.json()) as TurnstileOutcome;
  } catch {
    throw new AuthHttpError(502, "turnstile_unavailable", "安全验证暂时不可用");
  }

  if (!outcome.success) {
    throw new AuthHttpError(400, "turnstile_failed", "安全验证失败，请重试");
  }

  if (outcome.action && outcome.action !== EXPECTED_ACTION) {
    throw new AuthHttpError(400, "turnstile_action_mismatch", "安全验证来源不匹配");
  }

  const expectedHostnames = expectedHosts(env);
  if (expectedHostnames.length > 0 && outcome.hostname && !expectedHostnames.includes(outcome.hostname)) {
    throw new AuthHttpError(400, "turnstile_hostname_mismatch", "安全验证域名不匹配");
  }
}

function requiresTurnstile(request: Request, input: TurnstileProtectedInput): boolean {
  return input.client?.platform === "web" || Boolean(request.headers.get("origin"));
}

function clientIP(request: Request): string | undefined {
  return request.headers.get("CF-Connecting-IP") ?? (request.headers.get("X-Forwarded-For")?.split(",")[0]?.trim() || undefined);
}

function expectedHosts(env: TurnstileEnv): string[] {
  const raw = env.TURNSTILE_EXPECTED_HOSTNAMES ?? env.TURNSTILE_EXPECTED_HOSTNAME ?? "";
  return raw.split(",").map((hostname) => hostname.trim()).filter(Boolean);
}
