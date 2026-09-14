type Key = { suspended_until?: number | null; id: string; source_id: string; source_name: string; key_prefix: string; created_at: string; expires_at: string | null; last_used_at: string | null; revoked_at: string | null };
type Log = { message_id: string; source_id: string; key_id: string; source_name: string; created_at: string; scheduled_at: string | null; expires_at: string | null; read_at: string | null; deliveries: { device_id: string; device_name: string; status: string; last_error: string | null; attempts: number; accepted_at: string | null }[] };
type SecretExport = { source_id: string; source_name: string; source_key: string; created_at: string; expires_at: string | null };

export function initKeysLogs(root: HTMLElement) {
  const zh = root.dataset.language === "zh-Hans";
  const t = (en: string, cn: string) => zh ? cn : en;
  const el = <T extends HTMLElement>(selector: string) => root.querySelector<T>(selector)!;
  const form = el<HTMLFormElement>("[data-add-key]");
  const source = form.elements.namedItem("source") as HTMLSelectElement;
  const filter = el<HTMLSelectElement>("[data-log-filter]");
  const keyMessage = el("[data-key-message]");
  const logMessage = el("[data-log-message]");
  let keys: Key[] = [], cursor: string | null = null, generation = 0, logGeneration = 0;
  let lastSecret: SecretExport | null = null;
  const token = () => { try { const s = JSON.parse(sessionStorage.getItem("pushnow.web.session") || "null"); return s?.access_token || s?.accessToken || ""; } catch { return ""; } };
  const date = (value: string | null) => value ? new Date(value).toLocaleString(zh ? "zh-CN" : "en-US") : t("None", "无");
  const errorText = (error: unknown) => error instanceof Error ? error.message : t("Request failed", "请求失败");
  async function request(path: string, method = "GET", body?: unknown) {
    const auth = token();
    if (!auth) throw new Error(t("Please sign in again", "请重新登录"));
    const api = root.closest<HTMLElement>("[data-api]")?.dataset.api || "https://api.pushnow.dev";
    if (window.pushnowSession) return window.pushnowSession.accountRequest(api, path, {
      method, ...(body === undefined ? {} : { body: JSON.stringify(body) })
    });
    const response = await fetch(api + path, { method, headers: { Authorization: `Bearer ${auth}`, "Content-Type": "application/json" }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    const data = response.status === 204 ? null : await response.json().catch(() => null);
    if (!response.ok) throw new Error(response.status === 401 ? t("Session expired. Please sign in again.", "登录已过期，请重新登录。") : data?.message || data?.code || `HTTP ${response.status}`);
    return data;
  }
  function node(tag: string, text: string, parent: HTMLElement) { const n = document.createElement(tag); n.textContent = text; parent.append(n); return n; }
  function button(text: string, parent: HTMLElement, action: (b: HTMLButtonElement) => Promise<void>) {
    const b = document.createElement("button"); b.type = "button"; b.textContent = text; parent.append(b);
    b.onclick = async () => { b.disabled = true; try { await action(b); } catch (e) { keyMessage.textContent = errorText(e); } finally { b.disabled = false; } };
  }
  function clearSecret() { lastSecret = null; el("[data-secret]").textContent = ""; el("[data-secret-panel]").hidden = true; }
  function isActiveKey(key: Key) {
    return !key.revoked_at && (!key.expires_at || new Date(key.expires_at).getTime() > Date.now());
  }
  function selectedSourceActiveCount(sourceID: string) {
    return keys.filter(k => k.source_id === sourceID && isActiveKey(k)).length;
  }
  function createLimitText() {
    return t("This sender already has 2 active keys. Delete one, or regenerate an existing key.", "此发送来源已经有 2 个有效 Key。请先删除一个，或直接重新生成已有 Key。");
  }
  function expiryFromForm() {
    const expiry = (form.elements.namedItem("expiry") as HTMLSelectElement).value;
    return expiry === "never" ? null : new Date(Date.now() + Number(expiry) * 86400000).toISOString();
  }
  async function createKey(sourceID: string, expiresAt: string | null) {
    return request(`/v1/sources/${encodeURIComponent(sourceID)}/keys`, "POST", { expires_at: expiresAt });
  }
  function showSecret(data: { sourceKey?: string; source_key?: string; key?: Partial<Key> & { expiresAt?: string | null } }, sourceID: string, sourceName: string, expiresAt: string | null) {
    const sourceKey = data.sourceKey || data.source_key || "";
    if (!sourceKey) throw new Error(t("The API did not return a source key", "接口没有返回 source_key"));
    lastSecret = { source_id: sourceID, source_name: sourceName, source_key: sourceKey, created_at: new Date().toISOString(), expires_at: data.key?.expires_at ?? data.key?.expiresAt ?? expiresAt };
    el("[data-secret]").textContent = sourceKey;
    el("[data-secret-panel]").hidden = false;
  }
  function updateCreateState() {
    const submit = form.querySelector<HTMLButtonElement>("button")!;
    const count = source.value ? selectedSourceActiveCount(source.value) : 0;
    submit.disabled = !source.options.length || count >= 2;
    if (source.value && count >= 2) keyMessage.textContent = createLimitText();
    else if (keyMessage.textContent === createLimitText()) keyMessage.textContent = "";
  }
  function renderKeys() {
    const list = el("[data-key-list]"); list.replaceChildren();
    const selected = source.value, selectedFilter = filter.value;
    source.replaceChildren(); filter.replaceChildren(new Option(t("All keys", "全部 Key"), ""));
    const sources = new Map<string, string>();
    keys.forEach(k => {
      sources.set(k.source_id, k.source_name || k.source_id);
      filter.add(new Option(`${k.source_name || k.source_id} · ${k.key_prefix}`, k.id));
      const row = node("article", "", list); row.className = "entry";
      node("strong", `${k.source_name || k.source_id} · ${k.key_prefix}`, row);
      const expired = k.expires_at && new Date(k.expires_at).getTime() <= Date.now();
      node("p", k.revoked_at ? t("Deleted", "已删除") : expired ? t("Expired", "已过期") : k.suspended_until && k.suspended_until > Date.now() ? t(`Paused until ${new Date(k.suspended_until).toLocaleString()}`, `暂停至 ${new Date(k.suspended_until).toLocaleString()}`) : t("Active", "有效"), row);
      node("p", `${t("Created", "创建时间")}: ${date(k.created_at)} · ${t("Last used", "最后使用")}: ${date(k.last_used_at)}`, row);
      node("p", `${t("Expires", "到期时间")}: ${k.expires_at ? date(k.expires_at) : t("Never", "永不过期")}`, row);
      node("p", t("Only the prefix is recoverable here. The full source_key is shown once when it is generated.", "这里仅能查看前缀。完整 source_key 只会在生成时显示一次。"), row);
      if (k.revoked_at) return;
      const actions = node("div", "", row); actions.className = "entry-actions";
      const input = document.createElement("input"); input.type = "datetime-local"; input.setAttribute("aria-label", t("Expiry date", "到期时间"));
      if (k.expires_at) { const d = new Date(k.expires_at); input.value = new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16); }
      actions.append(input);
      button(t("Save expiry", "保存有效期"), actions, async () => {
        const expiry = input.value ? new Date(input.value).toISOString() : null;
        if (expiry && new Date(expiry).getTime() <= Date.now()) throw new Error(t("Choose a future date", "请选择未来的时间"));
        await request(`/v2/keys/${encodeURIComponent(k.id)}`, "PATCH", { expires_at: expiry }); await loadKeys();
      });
      button(t("Never expires", "永不过期"), actions, async () => { await request(`/v2/keys/${encodeURIComponent(k.id)}`, "PATCH", { expires_at: null }); await loadKeys(); });
      button(t("Regenerate", "重新生成"), actions, async () => {
        if (!confirm(t(`Regenerate ${k.key_prefix}? The old key will stop working immediately.`, `重新生成 ${k.key_prefix}？旧 Key 会立即失效。`))) return;
        await request(`/v2/keys/${encodeURIComponent(k.id)}`, "DELETE");
        const data = await createKey(k.source_id, k.expires_at);
        showSecret(data, k.source_id, k.source_name || k.source_id, k.expires_at);
        await loadKeys();
      });
      button(t("Delete", "删除"), actions, async () => {
        if (!confirm(t(`Delete ${k.key_prefix}? This key will no longer be able to send notifications.`, `删除 ${k.key_prefix}？此 Key 将无法再发送通知。`))) return;
        await request(`/v2/keys/${encodeURIComponent(k.id)}`, "DELETE"); await loadKeys();
      });
    });
    sources.forEach((name, id) => source.add(new Option(name, id)));
    if (sources.has(selected)) source.value = selected;
    if (keys.some(k => k.id === selectedFilter)) filter.value = selectedFilter;
    updateCreateState();
    if (!keys.length) node("p", t("No keys yet. Connect a sender with CLI login and approve it in the iOS app.", "暂无 Key。请通过 CLI 登录连接发送来源，并在 iOS App 中批准。"), list);
  }
  document.addEventListener("pushnow:keys-updated", () => { void loadKeys(); });
  async function loadKeys() {
    const version = generation; keyMessage.textContent = t("Loading...", "加载中...");
    try { const data = await request("/v2/keys"); if (version !== generation) return; keys = data.keys || []; renderKeys(); if (!form.querySelector<HTMLButtonElement>("button")!.disabled) keyMessage.textContent = ""; }
    catch (e) { if (version === generation) keyMessage.textContent = errorText(e); }
  }
  async function loadLogs(append = false) {
    const version = ++logGeneration, accountVersion = generation;
    const more = el<HTMLButtonElement>("[data-more]"); more.disabled = true;
    if (!append) { cursor = null; el("[data-log-list]").replaceChildren(); more.hidden = true; }
    logMessage.textContent = t("Loading...", "加载中...");
    try {
      const query = new URLSearchParams({ limit: "20" }); if (filter.value) query.set("key_id", filter.value); if (append && cursor) query.set("cursor", cursor);
      const data = await request(`/v2/logs?${query}`);
      if (version !== logGeneration || accountVersion !== generation) return;
      const logs: Log[] = data.logs || []; const list = el("[data-log-list]");
      const statuses: Record<string, string> = { accepted: t("Provider accepted", "服务商已接受"), pending: t("Pending", "待发送"), queued: t("Queued", "排队中"), retry: t("Retry pending", "等待重试"), blocked: t("Blocked", "已阻止"), failed: t("Failed", "失败"), suppressed: t("Suppressed", "未发送"), scheduled: t("Scheduled", "已定时") };
      logs.forEach(log => {
        const row = node("article", "", list); row.className = "entry";
        node("strong", log.source_name || log.source_id, row);
        node("p", `${t("Message", "消息")}: ${log.message_id}`, row);
        node("p", `Key: ${keys.find(k => k.id === log.key_id)?.key_prefix || log.key_id}`, row);
        node("p", `${t("Created", "创建时间")}: ${date(log.created_at)} · ${t("Scheduled", "计划发送")}: ${date(log.scheduled_at)}`, row);
        node("p", `${t("Expires", "到期时间")}: ${date(log.expires_at)} · ${t("Read", "已读时间")}: ${date(log.read_at)}`, row);
        if (!log.deliveries.length) node("p", t("No device deliveries", "无设备推送记录"), row);
        log.deliveries.forEach(d => {
          const detail = node("div", "", row); detail.className = "delivery";
          node("strong", `${d.device_name || d.device_id} · ${statuses[d.status] || d.status}`, detail);
          node("p", `${d.device_id} · ${t("Attempts", "尝试次数")}: ${d.attempts}`, detail);
          if (d.accepted_at) node("p", `${t("Provider accepted at", "服务商接受时间")}: ${date(d.accepted_at)}`, detail);
          if (d.last_error) node("p", d.last_error, detail);
        });
      });
      cursor = data.next_cursor || null; more.hidden = !cursor;
      logMessage.textContent = !append && !logs.length ? t("No notifications yet", "暂无通知记录") : "";
    } catch (e) { if (version === logGeneration && accountVersion === generation) logMessage.textContent = errorText(e); }
    finally { if (version === logGeneration) more.disabled = false; }
  }
  form.onsubmit = async event => {
    event.preventDefault(); if (!source.value) return;
    const version = generation; const b = form.querySelector<HTMLButtonElement>("button")!; b.disabled = true; clearSecret();
    const expiresAt = expiryFromForm();
    try {
      if (selectedSourceActiveCount(source.value) >= 2) throw new Error(createLimitText());
      const sourceName = source.options[source.selectedIndex]?.textContent || source.value;
      const data = await createKey(source.value, expiresAt);
      if (version !== generation) return;
      showSecret(data, source.value, sourceName, expiresAt); await loadKeys();
    } catch (e) { if (version === generation) keyMessage.textContent = errorText(e); }
    finally { if (version === generation) updateCreateState(); }
  };
  source.onchange = updateCreateState;
  el("[data-copy]").onclick = async () => { try { await navigator.clipboard.writeText(el("[data-secret]").textContent || ""); keyMessage.textContent = t("Copied", "已复制"); } catch { keyMessage.textContent = t("Copy unavailable. Select the key to copy it.", "无法自动复制，请选中密钥复制。"); } };
  el("[data-download-secret]").onclick = () => {
    if (!lastSecret) return;
    const url = URL.createObjectURL(new Blob([JSON.stringify(lastSecret, null, 2)], { type: "application/json" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `pushnow-source-key-${lastSecret.source_name.replace(/[^a-z0-9_-]+/gi, "-").replace(/^-|-$/g, "") || "sender"}.json`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  };
  el("[data-dismiss]").onclick = clearSecret;
  const reload = () => { if (token()) { void loadKeys(); void loadLogs(); } };
  document.addEventListener("pushnow:notification-sent", reload);
  el("[data-reload]").onclick = reload; filter.onchange = () => void loadLogs(); el("[data-more]").onclick = () => void loadLogs(true);
  document.addEventListener("pushnow:dashboard", event => {
    generation++; logGeneration++; clearSecret(); keys = []; cursor = null;
    el("[data-key-list]").replaceChildren(); el("[data-log-list]").replaceChildren(); source.replaceChildren(); filter.replaceChildren();
    if ((event as CustomEvent).detail.enabled) reload();
  });
  window.addEventListener("pagehide", clearSecret);
  reload();
}
