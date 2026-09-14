import { SenderAbuseGuard } from "./sender-abuse";
import { checkSenderRequest } from "./sender-abuse-request";
import { EmailAuthService, configFromEnv, toApiUser } from "./auth-service";
import type { LogoutRequest, PasswordLoginRequest, RefreshSessionRequest, SetPasswordRequest, StartEmailAuthRequest, VerifyEmailAuthRequest } from "./contracts";
import { CloudflareAuthMailer } from "./email";
import { bearerToken, corsHeaders, emptyResponse, errorResponse, jsonResponse, readJsonBody } from "./http";
import type {
  CreateSourceKeyRequest,
  CreateSourceRequest,
  IngestItemRequest,
  ReminderInput,
  UpdateItemStateRequest,
  UpsertDevicePushTokenRequest
} from "./product-contracts";
import { ProductService } from "./product-service";
import { D1ProductStore } from "./product-store";
import { D1AuthStore } from "./store";
import { secureRoute } from "./secure-routes";
import { SecureDevices } from "./secure-devices";
import { cleanupExpiredSecureMessages, deliverSecureMessages } from "./secure-delivery";
import { archiveRoute } from "./v2-routes";
import { deliverArchiveMessages } from "./v2-delivery";
import { AttachmentService } from "./v2-attachments";
import { reconcileMembership, revenuecatWebhook } from "./revenuecat-routes";
import { verifyTurnstileForWebAuth } from "./turnstile";

export default {
  async scheduled(_event: ScheduledController, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(deliverSecureMessages(env).then(() => cleanupExpiredSecureMessages(env.DB)));
    ctx.waitUntil(deliverArchiveMessages(env));
    ctx.waitUntil(new SenderAbuseGuard(env.DB,env).deliverSecurityEmails(env));
    ctx.waitUntil(new AttachmentService(env.DB,env.SECURE_BLOBS).cleanOrphans());
    ctx.waitUntil(env.DB.batch([
      env.DB.prepare('DELETE FROM v2_rate_limits WHERE expires_at<?').bind(new Date().toISOString()),
      env.DB.prepare('DELETE FROM v2_authorizations WHERE expires_at<?').bind(new Date().toISOString())
    ]));
  },
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const headers = corsHeaders(request, env);
    if (request.method === "OPTIONS") {
      return emptyResponse(204, headers);
    }

    const requestID = crypto.randomUUID();
    try {
      return await route(request, env, ctx, headers);
    } catch (error) {
      return errorResponse(error, requestID, headers);
    }
  }
} satisfies ExportedHandler<Env>;

async function route(request: Request, env: Env, ctx: ExecutionContext, headers: HeadersInit): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === "GET" && (url.pathname === "/health" || url.pathname === "/healthz")) {
    return jsonResponse({ status: "ok" }, 200, headers);
  }

  if (request.method === "GET" && url.pathname === "/readyz") {
    const readiness = await env.DB.prepare("SELECT 1 AS ok").first<{ ok: number }>();
    return jsonResponse({ status: readiness?.ok === 1 ? "ready" : "degraded" }, readiness?.ok === 1 ? 200 : 503, headers);
  }

  const auth = new EmailAuthService(new D1AuthStore(env.DB), new CloudflareAuthMailer(env.EMAIL), configFromEnv(env));
  const product = new ProductService(new D1ProductStore(env.DB), { authTokenPepper: env.AUTH_TOKEN_PEPPER });
  if(request.method==='POST'&&url.pathname==='/v1/webhooks/revenuecat')return revenuecatWebhook(request,env,headers);
  if(request.method==='POST'&&url.pathname==='/v1/me/plan/reconcile')return reconcileMembership(request,env,auth,product,headers);
  if (url.pathname.startsWith('/v2/')) return archiveRoute(request,env,auth,product,headers,ctx);
  if (url.pathname.startsWith('/v1/secure/')) return secureRoute(request, env, auth, product, headers, ctx);

  if (request.method === "POST" && url.pathname === "/v1/auth/email/start") {
    const body = (await readJsonBody(request)) as StartEmailAuthRequest;
    await verifyTurnstileForWebAuth(request, env, body);
    const result = await auth.startLogin(body);
    return jsonResponse({ status: "verification_sent", expiresInSeconds: result.expiresInSeconds }, 202, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/auth/email/verify") {
    const body = (await readJsonBody(request)) as VerifyEmailAuthRequest;
    return jsonResponse(await auth.verifyLogin(body), 200, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/auth/password/login") {
    const body = (await readJsonBody(request)) as PasswordLoginRequest;
    await verifyTurnstileForWebAuth(request, env, body);
    return jsonResponse(await auth.loginWithPassword(body), 200, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/auth/refresh") {
    const body = (await readJsonBody(request)) as RefreshSessionRequest;
    return jsonResponse(await auth.refresh(body.refreshToken), 200, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/auth/logout") {
    const body = ((await readJsonBody(request)) ?? {}) as LogoutRequest;
    const accessToken = /^Bearer\s+(.+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    const session = await auth.authenticateLogout(accessToken, body.refreshToken);
    await new SecureDevices(env.DB).logout(session);
    await auth.logout(session.session.id, body.refreshToken);
    return emptyResponse(204, headers);
  }

  if (request.method === "GET" && url.pathname === "/v1/me") {
    const session = await auth.authenticate(bearerToken(request));
    return jsonResponse({ user: toApiUser(session.user) }, 200, headers);
  }

  if (request.method === "GET" && url.pathname === "/v1/me/plan") {
    const session = await auth.authenticate(bearerToken(request));
    return jsonResponse({ membership: await product.getMembershipStatus(session.user.id) }, 200, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/me/password") {
    const session = await auth.authenticate(bearerToken(request));
    const body = (await readJsonBody(request)) as SetPasswordRequest;
    return jsonResponse({ user: await auth.setPassword(session.user, body) }, 200, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/me/email/start-change") {
    const session = await auth.authenticate(bearerToken(request));
    const body = (await readJsonBody(request)) as StartEmailAuthRequest;
    const result = await auth.startEmailChange(session.user, body);
    return jsonResponse({ status: "verification_sent", expiresInSeconds: result.expiresInSeconds }, 202, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/me/email/verify-change") {
    const session = await auth.authenticate(bearerToken(request));
    const body = (await readJsonBody(request)) as VerifyEmailAuthRequest;
    return jsonResponse({ user: await auth.verifyEmailChange(session.user, body) }, 200, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/me/delete-request") {
    const session = await auth.authenticate(bearerToken(request));
    await auth.requestDeletion(session.user.id);
    return jsonResponse({ status: "deletion_requested" }, 202, headers);
  }

  if (request.method === "GET" && url.pathname === "/v1/sources") {
    const session = await auth.authenticate(bearerToken(request));
    return jsonResponse({ sources: await product.listSources(session.user.id) }, 200, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/sources") {
    const session = await auth.authenticate(bearerToken(request));
    const body = ((await readJsonBody(request)) ?? {}) as CreateSourceRequest;
    return jsonResponse({ source: await product.createSource(session.user.id, body) }, 201, headers);
  }

  const sourceKeysMatch = /^\/v1\/sources\/([^/]+)\/keys$/.exec(url.pathname);
  if (request.method === "POST" && sourceKeysMatch) {
    const session = await auth.authenticate(bearerToken(request));
    const body = ((await readJsonBody(request)) ?? {}) as CreateSourceKeyRequest;
    const result = await product.createSourceKey(session.user.id, decodeURIComponent(sourceKeysMatch[1]), body);
    return jsonResponse({ sourceKey: result.sourceKey, source_key: result.sourceKey, key: result.record }, 201, headers);
  }

  if (request.method === "POST" && url.pathname === "/v1/ingest/items") {
    const body = ((await readJsonBody(request)) ?? {}) as IngestItemRequest;
    await checkSenderRequest(env,product,sourceCredential(request),ctx);
    const result = await product.ingestItem(sourceCredential(request), request.headers.get("idempotency-key") ?? "", body);
    return jsonResponse({ item: result.item, deduplicated: result.deduplicated }, result.deduplicated ? 200 : 201, headers);
  }

  if (request.method === "GET" && url.pathname === "/v1/items") {
    const session = await auth.authenticate(bearerToken(request));
    return jsonResponse({ items: await product.listItems(session.user.id, url.searchParams.get("limit")) }, 200, headers);
  }

  const itemMatch = /^\/v1\/items\/([^/]+)$/.exec(url.pathname);
  if (request.method === "GET" && itemMatch) {
    const session = await auth.authenticate(bearerToken(request));
    return jsonResponse({ item: await product.getItem(session.user.id, decodeURIComponent(itemMatch[1])) }, 200, headers);
  }

  const itemStateMatch = /^\/v1\/items\/([^/]+)\/state$/.exec(url.pathname);
  if (request.method === "PATCH" && itemStateMatch) {
    const session = await auth.authenticate(bearerToken(request));
    const body = ((await readJsonBody(request)) ?? {}) as UpdateItemStateRequest;
    return jsonResponse({ item: await product.updateItemState(session.user.id, decodeURIComponent(itemStateMatch[1]), body) }, 200, headers);
  }

  const itemReminderMatch = /^\/v1\/items\/([^/]+)\/reminders$/.exec(url.pathname);
  if (request.method === "POST" && itemReminderMatch) {
    const session = await auth.authenticate(bearerToken(request));
    const body = ((await readJsonBody(request)) ?? {}) as ReminderInput;
    return jsonResponse({ reminder: await product.createReminder(session.user.id, decodeURIComponent(itemReminderMatch[1]), body) }, 201, headers);
  }

  if (request.method === "GET" && url.pathname === "/v1/reminders") {
    const session = await auth.authenticate(bearerToken(request));
    return jsonResponse({ reminders: await product.listReminders(session.user.id, url.searchParams.get("limit")) }, 200, headers);
  }

  if (request.method === "PUT" && url.pathname === "/v1/devices/apns-token") {
    const session = await auth.authenticate(bearerToken(request));
    const body = ((await readJsonBody(request)) ?? {}) as UpsertDevicePushTokenRequest;
    const device = await product.upsertDevicePushToken(session.user.id, body);
    return jsonResponse({ device: { id: device.id, platform: device.platform, enabled: device.enabled, updatedAt: device.updatedAt } }, 200, headers);
  }

  void ctx;
  return jsonResponse({ code: "not_found", message: "Not found" }, 404, headers);
}

function sourceCredential(request: Request): string {
  const explicitKey = request.headers.get("x-jizhi-source-key");
  if (explicitKey) return explicitKey;
  const authorization = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(authorization);
  if (match) return match[1];
  return "";
}
