import { prepareMessageV2, recipientsV2, submitMessageV2, uploadAttachment } from "@pushnow/sdk";
import type { AuthorizedConfig, MessageContent, PreparedMessage } from "@pushnow/sdk";
import { HttpActivity, additionalHeaders } from "./http-activity";
import { SenderConnection } from "./playground-sender";

export function initPlayground(root: HTMLElement) {
  const zh = root.dataset.language === "zh-Hans";
  const t = (en: string, cn: string) => zh ? cn : en;
  const el = <T extends HTMLElement = HTMLElement>(selector: string) => root.querySelector<T>(selector)!;
  const form = el<HTMLFormElement>("[data-send-form]");
  const field = (name: string) => form.elements.namedItem(name) as HTMLInputElement;
  const status = el("[data-playground-status]");
  const http = new HttpActivity(el<HTMLOListElement>("[data-http-log]"), root.closest<HTMLElement>("[data-api]")!.dataset.api!);
  let last: { config: AuthorizedConfig; message: PreparedMessage } | null = null;
  let busy = false;
  const selectedDevices = new Set<string>();
  let selectionAccount: string | null = null;
  function clearRetry() { last = null; el<HTMLButtonElement>("[data-retry]").disabled = true; status.textContent = ""; status.dataset.tone = ""; }
  const connection = new SenderConnection(root, root.closest<HTMLElement>("[data-api]")!.dataset.api!, http,
    text => { status.textContent = text; status.dataset.tone = ""; if (text) { const tools = root.querySelector<HTMLDetailsElement>(".connection-tools"); if (tools) tools.open = true; } }, () => { last = null; el<HTMLButtonElement>("[data-retry]").disabled = true; renderDevices(); updateFields(); });

  function renderDevices() {
    const list = el("[data-target-devices]"); list.replaceChildren();
    connection.directory?.devices.forEach(device => {
      const label = document.createElement("label"), input = document.createElement("input");
      input.type = "checkbox"; input.value = device.id; input.name = "device";
      input.checked = selectedDevices.has(device.id);
      input.addEventListener("change", () => {
        clearRetry();
        if (input.checked) selectedDevices.add(device.id); else selectedDevices.delete(device.id);
        updateFields();
      });
      const text = document.createElement("span"); text.textContent = device.name;
      const platform = document.createElement("small"); platform.textContent = device.platform;
      text.append(document.createTextNode(" "), platform); label.append(input, text); list.append(label);
    });
    if (!connection.directory?.devices.length) {
      const empty = document.createElement("p");
      empty.textContent = t("Your devices will appear once the encrypted connection is ready.", "加密连接就绪后，会在这里显示可发送的设备。");
      list.append(empty);
    }
    // SenderConnection resets the form while connecting. Preserve an explicit device choice.
    if (selectedDevices.size) field("target").value = "selected";
    updateFields();
  }
  function updateFields() {
    const inbox = field("delivery").value === "inbox";
    const selected = field("target").value === "selected";
    el("[data-target-devices]").hidden = !selected || inbox;
    field("scheduledAt").disabled = field("schedule").value !== "later";
    field("scheduledAt").required = field("schedule").value === "later";
    field("sound").disabled = inbox;
    const devices = connection.directory?.devices ?? [];
    const names = devices.filter(device => selectedDevices.has(device.id)).map(device => device.name);
    const unavailable = selected && [...selectedDevices].some(id => !devices.some(device => device.id === id));
    const summary = root.querySelector<HTMLElement>("[data-recipient-summary]");
    if (summary) summary.textContent = inbox ? t("Saved to your account inbox. No push alert.", "保存到账号收件箱，不触发推送提醒。")
      : !connection.config ? t("Preparing your encrypted connection…", "正在准备加密连接…")
      : unavailable ? t("This device needs encryption setup. Open PushNow on it, then refresh devices.", "此设备尚未完成加密设置。请在该设备打开 PushNow，然后刷新设备。")
      : selected ? (names.length ? `${t("Send to", "发送至")} ${names.join(", ")}` : t("Choose at least one device below.", "请在下方选择至少一台设备。"))
      : `${t("Send to all authorized devices", "发送至全部授权设备")} · ${devices.length}`;
    document.querySelectorAll<HTMLElement>("[data-device-id]").forEach(card => {
      const active = selected && !inbox && selectedDevices.has(card.dataset.deviceId!);
      card.classList.toggle("is-selected", active);
      const button = card.querySelector<HTMLButtonElement>("[data-send-device]");
      button?.setAttribute("aria-pressed", String(active));
      if (button && connection.directory) {
        const eligible = devices.some(device => device.id === card.dataset.deviceId);
        button.textContent = eligible ? t("Send a notification", "发送提醒") : t("Connect device", "连接设备");
      }
    });
  }
  document.addEventListener("pushnow:devices-rendered", updateFields);
  document.addEventListener("pushnow:select-device", event => {
    const device = (event as CustomEvent<{id: string; name: string}>).detail;
    if (!device?.id || busy) return;
    clearRetry(); selectedDevices.clear(); selectedDevices.add(device.id);
    field("target").value = "selected"; field("delivery").value = "push";
    renderDevices();
    root.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth", block: "start" });
    if (connection.config) field("title").focus({ preventScroll: true });
    else {
      const heading = root.querySelector<HTMLElement>("h2"); heading?.setAttribute("tabindex", "-1"); heading?.focus({ preventScroll: true });
    }
  });
  document.addEventListener("pushnow:account-state", event => {
    const account = (event as CustomEvent).detail.user?.id ?? null;
    if (selectionAccount && selectionAccount !== account) {
      selectedDevices.clear(); clearRetry(); field("target").value = "all"; renderDevices();
    }
    selectionAccount = account;
  });
  document.addEventListener("pushnow:session-cleared", () => { selectionAccount = null; selectedDevices.clear(); clearRetry(); field("target").value = "all"; renderDevices(); });
  ["target", "delivery", "schedule", "sound"].forEach(name => field(name).addEventListener("change", () => { clearRetry(); updateFields(); }));
  field("target").addEventListener("change", () => { if (field("target").value === "all") { selectedDevices.clear(); renderDevices(); } else updateFields(); });
  el<HTMLButtonElement>("[data-clear-http]").onclick = () => http.clear();
  const message = (value: string, tone = "") => { status.textContent = value; status.dataset.tone = tone; };
  const toast = (title: string, body: string, tone = "success") => {
    document.dispatchEvent(new CustomEvent("pushnow:toast", { detail: { title, body, tone } }));
  };
  async function work(action: () => Promise<void>) {
    if (busy) return;
    busy = true; el<HTMLFieldSetElement>("[data-send-fields]").disabled = true;
    message(t("Working...", "正在处理..."));
    try { await action(); }
    catch (error) { message(error instanceof Error ? error.message : t("Request failed", "请求失败"), "error"); }
    finally {
      busy = false; el<HTMLFieldSetElement>("[data-send-fields]").disabled = !connection.config;
      el<HTMLButtonElement>("[data-retry]").disabled = !last;
    }
  }
  el<HTMLButtonElement>("[data-refresh-recipients]").onclick = () => void work(async () => {
    const options = connection.options();
    const directory = await recipientsV2(await connection.ready(), options);
    options.signal.throwIfAborted();
    connection.directory = directory; renderDevices();
    message(t("Devices refreshed. Ready to send.", "设备已刷新，可以发送。"), "success");
  });
  form.onsubmit = event => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    void work(async () => {
      const sound = field("sound").value;
      if (sound !== "default" && sound !== "silent" && sound !== "chime") throw new Error(t("Choose a supported sound", "请选择支持的铃声"));
      const title = field("title").value.trim();
      if (!title) throw new Error(t("Enter a title", "请输入标题"));
      const links = field("links").value.split(/\r?\n/).map(value => value.trim()).filter(Boolean);
      for (const value of links) {
        const url = new URL(value);
        if (!["https:", "http:"].includes(url.protocol) || url.username || url.password) throw new Error("Detail links must be HTTP(S) URLs without credentials");
      }
      let scheduledAt: string | undefined;
      if (field("schedule").value === "later") {
        const date = new Date(field("scheduledAt").value);
        if (!Number.isFinite(+date) || +date <= Date.now() || +date > Date.now() + 30 * 86400000) throw new Error("Schedule must be in the future, within 30 days");
        scheduledAt = date.toISOString();
      }
      const inboxOnly = field("delivery").value === "inbox";
      const deviceIds = inboxOnly ? [] : field("target").value === "selected"
        ? [...root.querySelectorAll<HTMLInputElement>("[name=device]:checked")].map(input => input.value) : undefined;
      if (!inboxOnly && deviceIds?.length === 0) throw new Error(t("Select at least one device", "请至少选择一个设备"));
      const files = [...(field("files").files || [])].map(file => ({ file, role: "file" }));
      for (const role of ["icon", "image"]) {
        const file = field(role).files?.[0];
        if (file) {
          if (!["image/png", "image/jpeg", "image/gif", "image/webp"].includes(file.type)) throw new Error("Icon and preview must be PNG, JPEG, GIF or WebP");
          files.push({ file, role });
        }
      }
      if (files.length > 20 || files.some(({ file }) => file.size > 20 * 1024 * 1024 - 16)) throw new Error("Maximum 20 attachments; each must be under 20 MiB");
      http.headers = additionalHeaders(field("headers").value);
      const options = connection.options();
      const config = await connection.ready();
      options.signal.throwIfAborted();
      message(t("Encrypting and sending...", "正在加密并发送..."));
      const directory = await recipientsV2(config, options);
      const content: MessageContent = { title, body: field("body").value, links, attachments: [] };
      for (const { file, role } of files) {
        const descriptor = await uploadAttachment(config, file, { name: file.name, mime: file.type || "application/octet-stream" }, options);
        content.attachments!.push(descriptor);
        if (role === "icon") content.icon_id = descriptor.id;
        if (role === "image") content.image_id = descriptor.id;
      }
      const prepared = await prepareMessageV2(config, directory, content, { sourceKind: "web", deviceIds, scheduledAt,
        ...(inboxOnly || sound === "default" ? {} : { sound }) });
      options.signal.throwIfAborted();
      last = { config, message: prepared };
      await submitMessageV2(config, prepared, options);
      options.signal.throwIfAborted();
      const submitted = t("Notification submitted.", "通知已提交。");
      const delivery = t("Track device delivery in the logs below.", "设备投递结果可在下方日志查看。");
      message(`${submitted} ${delivery}`, "success");
      toast(submitted, delivery);
      document.dispatchEvent(new CustomEvent("pushnow:notification-sent"));
    });
  };
  el<HTMLButtonElement>("[data-retry]").onclick = () => void work(async () => {
    if (!last) return;
    const pending = last;
    const options = connection.options();
    const config = await connection.ready();
    if (config.user_id !== pending.config.user_id || config.source_id !== pending.config.source_id) throw new Error("Sender changed; retry canceled");
    const result = await submitMessageV2(config, pending.message, options);
    options.signal.throwIfAborted();
    const retryTitle = t("API accepted", "接口已接收");
    const retryBody = `${result.message_id} · ${result.deduplicated ? t("Deduplicated", "已去重") : t("New request", "新请求")}`;
    message(`${retryTitle}: ${retryBody}`);
    toast(retryTitle, retryBody);
    document.dispatchEvent(new CustomEvent("pushnow:notification-sent"));
  });
  root.dataset.ready = "true";
}

document.querySelectorAll<HTMLElement>("[data-playground]").forEach(initPlayground);
