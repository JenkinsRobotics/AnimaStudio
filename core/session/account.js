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
function apply() {
  const theme = account?.theme || "dark";
  document.documentElement.dataset.aetherTheme =
    theme === "system"
      ? matchMedia("(prefers-color-scheme: light)").matches
        ? "light"
        : "dark"
      : theme;
  for (const update of subscribers) update();
}
async function refresh() {
  try {
    const status = await request("/api/status");
    account = status.user;
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
matchMedia("(prefers-color-scheme: light)").addEventListener("change", apply);
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
    menu.append(
      element("strong", account.full_name || account.username),
      element("small", account.email || account.username),
    );
    const field = element("label", "Appearance");
    const select = element("select");
    select.setAttribute("aria-label", "Account appearance");
    for (const value of ["dark", "light", "system"]) {
      const option = element("option", value[0].toUpperCase() + value.slice(1));
      option.value = value;
      select.append(option);
    }
    select.value = account.theme || "dark";
    const error = element("p");
    error.setAttribute("role", "alert");
    const save = async (body) => {
      try {
        await request("/api/preferences", body);
        await refresh();
        channel?.postMessage("changed");
      } catch (e) {
        error.textContent = e.message;
      }
    };
    select.onchange = () => save({ theme: select.value });
    field.append(select);
    menu.append(field);
    const picture = element("label", "Profile picture");
    const input = element("input");
    input.type = "file";
    input.accept = "image/png,image/jpeg";
    input.setAttribute("aria-label", "Profile picture");
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) return;
      if (file.size > 262144) {
        error.textContent = "Choose a PNG or JPEG smaller than 256 KB.";
        return;
      }
      const reader = new FileReader();
      reader.onload = () => save({ avatar: reader.result });
      reader.readAsDataURL(file);
    };
    picture.append(input);
    menu.append(picture);
    if (account.avatar) {
      const remove = element("button", "Remove picture");
      remove.onclick = () => save({ avatar: "" });
      menu.append(remove);
    }
    const profile = element("a", "Manage account");
    profile.href = "/?account=1";
    menu.append(profile);
    const studio = element("a", "Aether Studio");
    studio.href = "/";
    menu.append(studio);
    const logout = element("button", "Sign out");
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
