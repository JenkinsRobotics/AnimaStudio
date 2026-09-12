// One host-backed account control for every Aether front end.
let account = null;
const subscribers = new Set();
async function request(path, body) {
  const response = await fetch(
    path,
    body
      ? {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        }
      : undefined,
  );
  const data = await response.json();
  if (!response.ok)
    throw new Error(data.error || "Unable to update your account.");
  return data;
}
let workspaceTheme = null;
function applyTheme() {
  // Precedence: the member's personal theme, then the application override,
  // then the workspace base. Modes (System/Light/Dark) work inside any theme.
  const first = location.pathname.split("/")[1];
  const scope = ["cad", "animation", "ui"].includes(first) ? first : "studio";
  const personal = account && account.theme_id && account.theme_id.trim();
  const effective =
    personal ||
    (workspaceTheme && (workspaceTheme.apps?.[scope] || workspaceTheme.base)) ||
    "aether-default";
  const root = document.documentElement;
  for (const name of Array.from(root.classList))
    if (name.startsWith("aether-theme-")) root.classList.remove(name);
  if (effective !== "aether-default")
    root.classList.add("aether-theme-" + effective);
}
function apply() {
  applyTheme();
  for (const update of subscribers) update();
}
async function refresh() {
  try {
    const status = await request("/api/status");
    account = status.user;
    workspaceTheme = status.theme || null;
    apply();
    document.dispatchEvent(
      new CustomEvent("aether-account", { detail: account }),
    );
  } catch {
    /* Existing app connection status handles host outages. */
  }
}
const channel =
  typeof BroadcastChannel === "function"
    ? new BroadcastChannel("aether-account")
    : null;
channel?.addEventListener("message", refresh);
window.addEventListener("focus", refresh);
document.addEventListener("aether-account-refresh", () => {
  refresh();
  channel?.postMessage("changed");
});
function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text) node.textContent = text;
  if (className) node.className = className;
  return node;
}
class AetherAccount extends HTMLElement {
  connectedCallback() {
    this.update = () => this.render();
    subscribers.add(this.update);
    this.render();
  }
  disconnectedCallback() {
    subscribers.delete(this.update);
  }
  render() {
    this.replaceChildren();
    if (!account) return;
    const details = element("details", "", "suite-account");
    const summary = element("summary");
    summary.setAttribute(
      "aria-label",
      "Account: " + (account.full_name || account.username),
    );
    const avatar = account.avatar
      ? element("img")
      : element(
          "span",
          (account.full_name || account.username).slice(0, 1).toUpperCase(),
        );
    avatar.className = "suite-avatar";
    if (account.avatar) {
      avatar.src = account.avatar;
      avatar.alt = "";
    }
    summary.append(avatar);
    const label = element(
      "span",
      account.full_name || account.username,
      "suite-account-name",
    );
    summary.append(label);
    const menu = element("div", "", "suite-account-menu");
    const identity = element("div", "", "suite-account-identity");
    identity.append(
      element("strong", account.full_name || account.username),
      element("small", account.email || account.username),
    );
    menu.append(identity);
    const error = element("p");
    error.setAttribute("role", "alert");
    const item = (text, go) => {
      const row = element("button", text, "suite-account-item");
      row.type = "button";
      row.onclick = go;
      menu.append(row);
      return row;
    };
    item("My account", () => location.assign("/?account=1"));
    item("Aether Studio", () => location.assign("/"));
    menu.append(element("div", "", "suite-account-separator"));
    const logout = element("button", "Sign out", "suite-account-item");
    logout.type = "button";
    logout.onclick = async () => {
      try {
        await request("/api/logout", {});
        channel?.postMessage("changed");
        location.assign(
          "/?next=" + encodeURIComponent(location.pathname + location.search),
        );
      } catch (e) {
        error.textContent = e.message;
      }
    };
    menu.append(logout, error);
    details.append(summary, menu);
    this.append(details);
  }
}
customElements.define("aether-account", AetherAccount);
// Place this shared control in front-end-owned slots after React mounts.
const mount = () =>
  document.querySelectorAll("[data-aether-account]").forEach((slot) => {
    if (!slot.querySelector("aether-account"))
      slot.append(document.createElement("aether-account"));
  });
new MutationObserver(mount).observe(document.body, {
  childList: true,
  subtree: true,
});
mount();
refresh();
