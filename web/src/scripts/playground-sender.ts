import { beginAccountLogin, finishAccountLogin, validateConfig, recipientsV2 } from "@pushnow/sdk";
import type { AuthorizedConfig, RecipientDirectory } from "@pushnow/sdk";
import { session } from "./account-session";
import { accountSession } from "./account-session";
import type { HttpActivity } from "./http-activity";

export class SenderConnection {
  config: AuthorizedConfig | null = null;
  directory: RecipientDirectory | null = null;
  private connecting = false;
  private connectionQueued = false;
  private attemptedUser: string | null = null;
  private readonly storageKey = "pushnow.web.sender";
  private generation = 0;
  controller = new AbortController();
  constructor(readonly root: HTMLElement, readonly api: string, readonly http: HttpActivity,
    readonly message: (value: string) => void, readonly changed: () => void) {
    this.el<HTMLInputElement>("[data-import-config]").onchange = async event => {
      const input = event.target as HTMLInputElement;
      const file = input.files?.[0]; input.value = "";
      if (!file) return;
      await this.run(async () => {
        this.reset();
        if (file.size > 128 * 1024) throw new Error("Sender configuration must be under 128 KiB");
        await this.connect(validateConfig(JSON.parse(await file.text())));
      });
    };
    this.el<HTMLButtonElement>("[data-authorize]").onclick = () => { this.clearSaved(); this.reset(); this.attemptedUser = null; void this.automatic(); };
    this.el<HTMLButtonElement>("[data-cancel-authorization]").onclick = () => this.reset();
    this.el<HTMLButtonElement>("[data-disconnect]").onclick = () => { this.clearSaved(); this.reset(); };
    this.el<HTMLButtonElement>("[data-export-config]").onclick = () => {
      if (!this.config || !confirm("This file contains your sender token and private key. Export to a private location?")) return;
      const url = URL.createObjectURL(new Blob([JSON.stringify(this.config)], { type: "application/json" }));
      const link = document.createElement("a"); link.href = url; link.download = "pushnow-sender.json"; link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    };
    document.addEventListener("pushnow:session-cleared", () => { this.attemptedUser = null; this.clearSaved(); this.reset(); this.http.clear(); });
    document.addEventListener("pushnow:account-state", event => {
      const user = (event as CustomEvent).detail.user;
      if ((this.config && user?.id !== this.config.user_id) || (user && this.attemptedUser && user.id !== this.attemptedUser)) { this.clearSaved(); this.reset(); this.http.clear(); }
      if (user && this.attemptedUser !== user.id) {
        if (this.connecting) this.connectionQueued = true;
        else void this.automatic();
      }
    });
    window.addEventListener("pagehide", () => this.reset());
    window.addEventListener("pageshow", event => { if (event.persisted) { this.attemptedUser = null; void this.automatic(); } });
    void this.automatic();
  }
  private clearSaved() { try { sessionStorage.removeItem(this.storageKey); } catch {} }
  async automatic() {
    if (this.connecting) return;
    this.connecting = true;
    await this.run(async () => {
      const user = await this.account();
      if (this.config?.user_id === user.id || this.attemptedUser === user.id) return;
      this.attemptedUser = user.id;
      this.reset();
      const version = this.generation;
      let saved: AuthorizedConfig | null = null;
      try { saved = JSON.parse(sessionStorage.getItem(this.storageKey) || "null"); } catch { this.clearSaved(); }
      if (saved?.user_id === user.id) {
        // A revoked or paused saved key must not be silently replaced.
        try {
          await this.connect(validateConfig(saved));
        } catch {
          this.clearSaved();
          this.reset();
          throw new Error(this.root.dataset.language === "zh-Hans"
            ? "此浏览器保存的发送 Key 已失效。请重新连接浏览器。"
            : "This browser's saved sender key is no longer active. Connect the browser again.");
        }
        return;
      }
      this.clearSaved();
      const token = session()?.accessToken;
      if (!token) throw new Error("Sign in first");
      this.el("[data-authorization]").hidden = false;
      this.message(this.root.dataset.language === "zh-Hans" ? "正在自动连接。首次连接请在已登录的 iPhone 打开最新版 PushNow，无需输入授权码。" : "Connecting automatically. For first connection, open the latest PushNow on your signed-in iPhone. No approval code needed.");
      const pending = await beginAccountLogin(this.api, token, "Web dashboard", this.options());
      this.check(version);
      const config = await finishAccountLogin(pending, this.options());
      this.check(version);
      await this.connect(config);
      this.check(version);
      try { sessionStorage.setItem(this.storageKey, JSON.stringify(config)); } catch {}
      this.el("[data-authorization]").hidden = true;
      document.dispatchEvent(new CustomEvent("pushnow:keys-updated"));
    });
    this.connecting = false;
    if (this.connectionQueued) { this.connectionQueued = false; void this.automatic(); }
  }
  el<T extends HTMLElement = HTMLElement>(selector: string) { return this.root.querySelector<T>(selector)!; }
  options() { return { fetcher: this.http.fetcher, signal: this.controller.signal }; }
  private check(version: number) { if (version !== this.generation) throw new Error("Sender changed"); }
  private async account() {
    const user = await accountSession.validateSession(this.api);
    if (!user) throw new Error("Sign in before connecting a sender");
    return user;
  }
  async connect(config: AuthorizedConfig) {
    const version = this.generation, user = await this.account();
    if (config.user_id !== user.id || new URL(config.api_url).origin !== new URL(this.api).origin) throw new Error("Sender does not belong to this account or API");
    const directory = await recipientsV2(config, this.options());
    this.check(version);
    this.config = config; this.directory = directory;
    this.el("[data-sender-status]").textContent = this.root.dataset.language === "zh-Hans" ? "加密连接已就绪" : "Encrypted connection ready";
    this.el<HTMLButtonElement>("[data-export-config]").disabled = false;
    this.el<HTMLButtonElement>("[data-disconnect]").disabled = false;
    this.el<HTMLFieldSetElement>("[data-send-fields]").disabled = false;
    this.message(""); this.changed();
  }
  async ready() {
    if (!this.config) throw new Error("Connect a sender first");
    const config = { ...this.config };
    const user = await this.account();
    if (config.user_id !== user.id) throw new Error("Account changed");
    return validateConfig(config);
  }
  reset() {
    this.generation++; this.controller.abort(); this.controller = new AbortController();
    this.config = null; this.directory = null; 
    this.el<HTMLFormElement>("[data-send-form]").reset();

    this.el("[data-authorization]").hidden = true;
    this.el<HTMLFieldSetElement>("[data-send-fields]").disabled = true;
    this.el<HTMLButtonElement>("[data-export-config]").disabled = true;
    this.el<HTMLButtonElement>("[data-disconnect]").disabled = true;
    this.el("[data-sender-status]").textContent = this.root.dataset.language === "zh-Hans" ? "未连接发送身份" : "No sender connected";
    this.message(""); this.changed();
  }
  async run(action: () => Promise<void>) {
    const button = this.el<HTMLButtonElement>("[data-authorize]");
    button.disabled = true;
    try { await action(); } catch (error) {
      const text = error instanceof Error ? error.message : "Request failed";
      if (/HTTP 401|invalid_source_key|authorization_expired|session_expired/i.test(text)) {
        this.clearSaved(); this.reset();
        this.message(this.root.dataset.language === "zh-Hans"
          ? "发送身份已失效。请重新连接浏览器。"
          : "The sender connection is no longer active. Connect the browser again.");
      } else this.message(text);
    }
    finally { button.disabled = false; }
  }
}
