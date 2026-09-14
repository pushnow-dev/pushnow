const hashToPanel: Record<string, string> = {
  "#account": "account",
  "#account-panel": "account",
  "#keys-heading": "keys",
  "#keys-title": "keys",
  "#api-playground": "send",
  "#api-playground-panel": "send",
  "#logs-heading": "logs",
  "#logs-title": "logs"
};

const panelToHash: Record<string, string> = {
  account: "#account",
  keys: "#keys-heading",
  send: "#api-playground",
  logs: "#logs-heading"
};

function initDashboardTabs(root: HTMLElement) {
  const tabs = [...root.querySelectorAll<HTMLButtonElement>("[data-dashboard-tab]")];
  const panels = [...root.querySelectorAll<HTMLElement>("[data-dashboard-panel]")];
  if (!tabs.length || !panels.length) return;

  const activate = (target: string, updateHash: boolean) => {
    const panel = panels.find(item => item.dataset.dashboardPanel === target) ? target : "account";
    tabs.forEach(tab => {
      const active = tab.dataset.dashboardTab === panel;
      tab.classList.toggle("is-active", active);
      tab.setAttribute("aria-selected", String(active));
    });
    panels.forEach(item => {
      item.hidden = item.dataset.dashboardPanel !== panel;
    });
    if (updateHash) history.replaceState(null, "", panelToHash[panel] || "#account");
  };

  tabs.forEach(tab => {
    tab.addEventListener("click", () => activate(tab.dataset.dashboardTab || "account", true));
  });
  window.addEventListener("hashchange", () => activate(hashToPanel[location.hash] || "account", false));
  activate(hashToPanel[location.hash] || "account", false);
}

document.querySelectorAll<HTMLElement>("[data-dashboard-tabs]").forEach(initDashboardTabs);
