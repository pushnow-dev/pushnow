import { accountSession } from "./account-session";

window.pushnowSession = accountSession;
const nav = document.querySelector<HTMLElement>("[data-account-nav]");
const api = nav?.dataset.api || "https://api.pushnow.dev";
function render(user: { email: string } | null) {
  document.querySelectorAll<HTMLElement>("[data-nav-login]").forEach(el => { el.hidden = !!user; });
  document.querySelectorAll<HTMLElement>("[data-nav-account]").forEach(el => { el.hidden = !user; });
  document.querySelectorAll<HTMLElement>("[data-nav-email]").forEach(el => { el.textContent = user?.email || ""; });
}
document.addEventListener("pushnow:account-state", event => render((event as CustomEvent).detail.user));
document.addEventListener("pushnow:session-updated", () => void accountSession.validateSession(api).catch(() => {}));
document.dispatchEvent(new CustomEvent("pushnow:session-ready"));
void accountSession.validateSession(api).catch(() => {});
