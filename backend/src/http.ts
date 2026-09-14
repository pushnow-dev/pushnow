import { AuthHttpError } from "./crypto";

export type JsonBody = Record<string, unknown> | undefined;

export async function readJsonBody(request: Request, maxBytes = 65536): Promise<JsonBody> {
  const length = Number(request.headers.get("content-length") ?? "0");
  if (length > maxBytes) {
    throw new AuthHttpError(413, "payload_too_large", "请求内容过大");
  }
  if (request.body === null) {
    return undefined;
  }
  const reader=request.body.getReader();
  const chunks:Uint8Array[]=[];
  let total=0;
  while(true) {
    const {done,value}=await reader.read();
    if(done) break;
    total+=value.byteLength;
    if(total>maxBytes){await reader.cancel();throw new AuthHttpError(413,"payload_too_large","Request too large");}
    chunks.push(value);
  }
  const data=new Uint8Array(total);let offset=0;
  for(const chunk of chunks){data.set(chunk,offset);offset+=chunk.byteLength;}
  try {
    const parsed=JSON.parse(new TextDecoder().decode(data));
    if(!parsed || typeof parsed!=='object' || Array.isArray(parsed)) throw new Error('invalid body');
    return toCamelCase(parsed) as JsonBody;
  } catch {
    throw new AuthHttpError(400, "invalid_json", "请求 JSON 无效");
  }
}

export function jsonResponse(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  const responseHeaders = new Headers(headers);
  responseHeaders.set("content-type", "application/json; charset=utf-8");
  return new Response(JSON.stringify(toSnakeCase(body)), { status, headers: responseHeaders });
}

export function emptyResponse(status = 204, headers: HeadersInit = {}): Response {
  return new Response(null, { status, headers });
}

export function corsHeaders(request: Request, env: Env): HeadersInit {
  const requestOrigin = request.headers.get("origin");
  const allowedOrigins = env.CORS_ORIGINS.split(",").map((origin) => origin.trim());
  const origin = requestOrigin && allowedOrigins.includes(requestOrigin) ? requestOrigin : allowedOrigins[0];
  const baseHeaders = ["authorization", "content-type", "idempotency-key", "x-jizhi-source-key"];
  const requested = (request.headers.get("access-control-request-headers") ?? "").toLowerCase();
  const extra = requested.length <= 1024
    ? [...new Set(requested.split(",").map(value => value.trim()).filter(value => /^x-[a-z0-9-]{1,60}$/.test(value) && !baseHeaders.includes(value)))]
    : [];
  // Reflect names, never values, only for the same trusted website origins.
  const allowedHeaders = requestOrigin === origin && extra.length <= 10 ? [...baseHeaders, ...extra] : baseHeaders;
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET,POST,PATCH,PUT,DELETE,OPTIONS",
    "access-control-allow-headers": allowedHeaders.join(","),
    "access-control-max-age": "86400",
    vary: "Origin, Access-Control-Request-Headers"
  };
}

export function bearerToken(request: Request): string {
  const authorization = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(authorization);
  if (!match) {
    throw new AuthHttpError(401, "missing_bearer_token", "请先登录");
  }
  return match[1];
}

export function errorResponse(error: unknown, requestID: string, headers: HeadersInit): Response {
  if (error instanceof AuthHttpError) {
    const responseHeaders = new Headers(headers);
    if ("retryAfterSeconds" in error) responseHeaders.set("Retry-After", String(error.retryAfterSeconds));
    return jsonResponse({ code: error.code, message: error.message, requestId: requestID, ...("retryAfterSeconds" in error ? { retry_after: error.retryAfterSeconds } : {}) }, error.status, responseHeaders);
  }
  console.error(
    JSON.stringify({
      event: "unhandled_error",
      requestID,
      message: error instanceof Error ? error.message : String(error)
    })
  );
  return jsonResponse({ code: "internal_error", message: "服务暂时不可用", requestId: requestID }, 500, headers);
}

function toSnakeCase(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(toSnakeCase);
  }
  if (!value || typeof value !== "object") {
    return value;
  }
  return Object.fromEntries(
    Object.entries(value).map(([key, entry]) => [
      key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`),
      toSnakeCase(entry)
    ])
  );
}

function toCamelCase(value: unknown, parentKey = ""): unknown {
  if (parentKey === "body") {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((entry) => toCamelCase(entry, parentKey));
  }
  if (!value || typeof value !== "object") {
    return value;
  }
  return Object.fromEntries(
    Object.entries(value).map(([key, entry]) => [
      key.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase()),
      toCamelCase(entry, key)
    ])
  );
}
