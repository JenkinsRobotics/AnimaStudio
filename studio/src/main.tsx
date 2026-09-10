import { useEffect, useState, type FormEvent, type ReactNode } from "react";
import { createRoot } from "react-dom/client";
import {
  AppIcon,
  AetherIcon,
  Button,
  DocumentBar,
  ListBox,
  SelectField,
  StatusDot,
  TextField,
} from "@aether/ui";
import "@aether/ui/tokens.css";
import "@aether/ui/widgets.css";
import "../../core/ui/tokens/home.css";
import "./studio.css";
import { AdministrationPanels } from "./Administration";
import { LibraryHome } from "./LibraryHome";
import { PublicHome } from "./PublicHome";
import { Recovery } from "./Recovery";
import { EmailSettings, type MailSettings } from "./EmailSettings";
import { api } from "./api";
import {
  SetupWizard,
  SetupComplete,
  SignInFrame,
  type Installation,
} from "./SetupWizard";

export type User = {
  id: string;
  username: string;
  full_name: string;
  email: string;
  email_verified: boolean;
  avatar: string;
  theme: "dark" | "light" | "system";
  role: string;
  active: boolean;
  must_change: boolean;
};
export type App = {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  installed: boolean;
  url: string;
  admin_only: boolean;
};
type Status = {
  ready: boolean;
  name: string;
  user: User | null;
  apps: App[];
  installation: Installation | null;
  email_recovery_available: boolean;
};
type Settings = {
  name: string;
  bind_address: string;
  port: number;
  public_url: string;
  tls_cert: string;
  tls_key: string;
};
export type Admin = {
  mail: MailSettings;
  teams: { id: string; name: string; members: string[]; apps: string[] }[];
  access: Record<string, number>;
  services: {
    id: string;
    name: string;
    apps: string[];
    expires: number;
    active: number;
  }[];
  backups: { name: string; size: number; created: number }[];
  users: User[];
  settings: Settings;
  running_settings: Settings;
  restart_required: boolean;
  uptime_s: number;
  sessions: { username: string; count: number }[];
  audit: {
    id: number;
    time: number;
    actor: string;
    action: string;
    target: string;
  }[];
};
const roles = [
  { value: "member", label: "Member" },
  { value: "admin", label: "Administrator" },
];

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  );
}
function Section({
  title,
  description,
  children,
}: {
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <section className="section">
      <div className="section-heading">
        <h2>{title}</h2>
        {description && <p>{description}</p>}
      </div>
      {children}
    </section>
  );
}
function Authentication({
  status,
  refresh,
  report,
  onRecover,
}: {
  onRecover: () => void;
  status: Status;
  refresh: () => Promise<void>;
  report: (message: string) => void;
}) {
  const [busy, setBusy] = useState(false);
  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setBusy(true);
    try {
      await api(
        "/api/login",
        Object.fromEntries(new FormData(event.currentTarget)),
      );
      await refresh();
      const next = new URLSearchParams(location.search).get("next");
      const current = await api<Status>("/api/status");
      if (
        next &&
        /^\/(cad|animation|ui)\/(?:index\.html)?(?:\?[^#]*)?$/.test(next) &&
        !current.user?.must_change
      )
        location.assign(next);
    } catch (e) {
      report((e as Error).message);
    } finally {
      setBusy(false);
    }
  };
  return (
    <SignInFrame>
      <form className="auth-card" onSubmit={submit}>
        <span className="setup-eyebrow">{status.name}</span>
        <h2>Welcome back</h2>
        <p>Sign in to your workspace.</p>
        <Field label="Username or email">
          <TextField
            name="username"
            required
            autoComplete="username"
            maxLength={254}
          />
        </Field>
        <Field label="Password">
          <TextField
            name="password"
            type="password"
            required
            maxLength={256}
            autoComplete="current-password"
          />
        </Field>
        <Button primary type="submit" disabled={busy}>
          {busy ? "Signing in…" : "Sign in"}
        </Button>
        <Button onClick={onRecover}>Forgot username or password?</Button>
      </form>
    </SignInFrame>
  );
}
function Studio() {
  const [recovery, setRecovery] = useState<string | null>(() => new URLSearchParams(location.hash.slice(1)).get("reset"));
  const [setupComplete, setSetupComplete] = useState(false);
  const [signInMode, setSignInMode] = useState(
    () =>
      new URLSearchParams(location.search).has("next") ||
      new URLSearchParams(location.search).has("signin"),
  );
  const [status, setStatus] = useState<Status | null>(null);
  const [admin, setAdmin] = useState<Admin | null>(null);
  const [page, setPage] = useState(new URLSearchParams(location.search).has("account") ? "account" : "home");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [query, setQuery] = useState("");
  const [editUser, setEditUser] = useState<User | null>(null);
  const [network, setNetwork] = useState<Settings | null>(null);
  const refresh = async () => {
    const current = await api<Status>("/api/status");
    setStatus(current);
    if (location.pathname !== "/cad/" && current.user?.role === "admin" && !current.user.must_change) {
      const details = await api<Admin>("/api/admin/state");
      setAdmin(details);
      setNetwork(details.settings);
    } else {
      setAdmin(null);
      setNetwork(null);
    }
    if (current.user?.must_change) setPage("account");
  };
  useEffect(() => {
    refresh().catch((e: Error) => setError(e.message));
    const sync = (event: Event) => {
      const user = (event as CustomEvent<User | null>).detail;
      setStatus(current => current ? {...current, user} : current);
    };
    document.addEventListener("aether-account", sync);
    return () => document.removeEventListener("aether-account", sync);
  }, []);
  const run = async (path: string, body: object, message: string) => {
    setBusy(true);
    setError("");
    setNotice("");
    try {
      await api(path, body);
      await refresh();
      setNotice(message);
      return true;
    } catch (e) {
      setError((e as Error).message);
      return false;
    } finally {
      setBusy(false);
    }
  };
  const navigate = (id: string) => {
    setPage(id);
    setError("");
    setNotice("");
    setEditUser(null);
  };
  const report = (message: string) => {
    setError(message);
    setNotice("");
  };
  const banners = (
    <div className="messages" aria-live="polite">
      {error && (
        <div role="alert" className="message error">
          {error}
          <button onClick={() => setError("")} aria-label="Dismiss error">
            ×
          </button>
        </div>
      )}
      {notice && (
        <div role="status" className="message">
          {notice}
          <button
            onClick={() => setNotice("")}
            aria-label="Dismiss notification"
          >
            ×
          </button>
        </div>
      )}
    </div>
  );
  if (!status)
    return (
      <div className="studio aether-home-theme">
        <div className="auth">
          <h1>Aether Studio</h1>
          {error ? (
            <>
              <p role="alert">{error}</p>
              <Button
                onClick={() => refresh().catch((e: Error) => report(e.message))}
              >
                Retry connection
              </Button>
            </>
          ) : (
            <p>Connecting to your workspace…</p>
          )}
        </div>
      </div>
    );
  if (recovery !== null && status.ready) return <div className="studio aether-home-theme"><Recovery token={recovery} available={status.email_recovery_available} onBack={() => { setRecovery(null); setSignInMode(true); refresh().catch((e: Error) => setError(e.message)); }} /></div>;
  if (!status.ready)
    return (
      <div className="studio aether-home-theme">
        <SetupWizard
          installation={
            status.installation ?? {
              host_ready: true,
              storage_ready: true,
              packages: [],
            }
          }
          refresh={refresh}
          onComplete={() => setSetupComplete(true)}
        />
      </div>
    );
  if (setupComplete && status.user)
    return (
      <div className="studio aether-home-theme">
        <SetupComplete
          name={status.name}
          onContinue={() => setSetupComplete(false)}
        />
      </div>
    );
  if (!status.user && !signInMode)
    return (
      <div className="studio aether-home-theme">
        <PublicHome
          name={status.name}
          apps={status.apps}
          onSignIn={() => setSignInMode(true)}
        />
      </div>
    );
  if (!status.user)
    return (
      <div className="studio aether-home-theme">
        {banners}
        <Authentication status={status} refresh={refresh} report={report} onRecover={() => setRecovery("")} />
      </div>
    );
  if (location.pathname === "/cad/" && !status.user.must_change) return <LibraryHome workspace={status.name} />;
  const user = status.user;
  const isAdmin = user.role === "admin" && !user.must_change;
  const navigation = [
    ...(!user.must_change
      ? [
          { id: "home", label: "Home", icon: <AetherIcon name="home" /> },
          {
            id: "apps",
            label: "Applications",
            icon: <AetherIcon name="items" />,
          },
        ]
      : []),
    ...(isAdmin
      ? [
          { id: "users", label: "Users", icon: <AetherIcon name="assembly" /> },
          { id: "email", label: "Email delivery", icon: <AetherIcon name="document" /> },
          { id: "teams", label: "Teams", icon: <AetherIcon name="assembly" /> },
          {
            id: "access",
            label: "Roles & permissions",
            icon: <AetherIcon name="mate" />,
          },
          {
            id: "services",
            label: "Service accounts",
            icon: <AetherIcon name="hardware" />,
          },
          { id: "backups", label: "Backups", icon: <AetherIcon name="save" /> },
          {
            id: "plugins",
            label: "Community plugins",
            icon: <AetherIcon name="items" />,
            badge: "Planned",
          },
          {
            id: "network",
            label: "Server & network",
            icon: <AetherIcon name="settings" />,
          },
          {
            id: "activity",
            label: "Activity",
            icon: <AetherIcon name="history" />,
          },
        ]
      : []),
    {
      id: "account",
      label: "My account",
      icon: <AetherIcon name="document" />,
    },
  ];
  const visiblePage = user.must_change ? "account" : page;
  const title =
    navigation.find((item) => item.id === visiblePage)?.label ?? "Home";
  const submitUser = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    if (
      await run(
        "/api/admin/users",
        Object.fromEntries(new FormData(form)),
        "Account created. Share the temporary password with the user; they must change it at first sign-in.",
      )
    )
      form.reset();
  };
  const passwordForm = (
    <form
      className="form"
      onSubmit={async (event) => {
        event.preventDefault();
        const data = Object.fromEntries(new FormData(event.currentTarget));
        if (data.password !== data.confirm) {
          report("Passwords do not match.");
          return;
        }
        await run(
          "/api/password",
          data,
          "Password changed. Sign in again with your new password.",
        );
      }}
    >
      <Field label="Current password">
        <TextField
          name="current_password"
          type="password"
          required
          autoComplete="current-password"
        />
      </Field>
      <Field label="New password">
        <TextField
          name="password"
          type="password"
          minLength={12}
          maxLength={256}
          required
          autoComplete="new-password"
        />
      </Field>
      <Field label="Confirm new password">
        <TextField
          name="confirm"
          type="password"
          minLength={12}
          required
          autoComplete="new-password"
        />
      </Field>
      <Button type="submit" primary disabled={busy}>
        Change password
      </Button>
    </form>
  );
  return (
    <div className="studio aether-home-theme">
      <aside className="studio-sidebar">
        <div data-aether-account="" style={{ marginBottom: 12 }} />
        <div className="workspace-identity">
          <span className="workspace-avatar">
            <AppIcon app="studio" size={34} />
          </span>
          <div>
            <strong>{status.name}</strong>
            <small>
              {isAdmin ? "Administrator workspace" : "Personal workspace"}
            </small>
          </div>
        </div>
        <div className="sidebar-search">
          <TextField
            aria-label="Search navigation"
            placeholder="Search…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
        <div className="nav-heading">
          {isAdmin ? "Administration" : "Workspace"}
        </div>
        <nav aria-label="Studio navigation">
          <ListBox
            ariaLabel="Workspace sections"
            items={navigation.filter((item) =>
              item.label.toLowerCase().includes(query.toLowerCase()),
            )}
            selectedIDs={new Set([visiblePage])}
            onSelect={(ids) => ids[0] && navigate(ids[0])}
          />
        </nav>
        <div className="sidebar-bottom">
          <div className="host-label">
            <StatusDot kind="ok" /> Local host connected
          </div>
          <button className="profile" onClick={() => navigate("account")}>
            {user.avatar ? <img className="avatar" src={user.avatar} alt="" style={{objectFit:"cover"}} /> : <span className="avatar">{(user.full_name || user.username)[0].toUpperCase()}</span>}
            <span>
              <strong>{user.full_name || user.username}</strong>
              <small>
                {user.role === "admin" ? "Administrator" : "Member"}
              </small>
            </span>
          </button>
          <Button
            onClick={() => run("/api/logout", {}, "Signed out.")}
            disabled={busy}
          >
            Sign out
          </Button>
        </div>
      </aside>
      <div className="studio-body">
        <DocumentBar
          windowChrome={false}
          leading={<strong>{title}</strong>}
          trailing={
            <>
              <span className="header-caption">Aether Studio</span>
              <Button
                disabled={busy}
                onClick={() => {
                  setBusy(true);
                  refresh()
                    .catch((e: Error) => report(e.message))
                    .finally(() => setBusy(false));
                }}
                aria-label="Refresh server status"
              >
                <AetherIcon name="history" />
              </Button>
            </>
          }
        />
        <main className="studio-content">
          {banners}
          {visiblePage === "home" && (
            <>
              <div className="page-heading">
                <div>
                  <h1>Your workspace, together.</h1>
                  <p>Open your tools and manage your Aether installation.</p>
                </div>
                <span className="badge">
                  <StatusDot kind="ok" /> Online
                </span>
              </div>
              <Section title="Your applications">
                <div className="application-grid">
                  {status.apps
                    .filter((app) => app.enabled)
                    .map((app) => (
                      <a
                        key={app.id}
                        className={`application-card ${app.id}`}
                        href={app.installed ? app.url : undefined}
                        target="_blank" rel="noopener"
                        aria-disabled={!app.installed}
                      >
                        <div className="application-art">
                          <AppIcon app={app.id} size={108} />
                          <span>
                            {app.id === "cad"
                              ? "DESIGN"
                              : app.id === "animation"
                                ? "CREATE"
                                : "EXPLORE"}
                          </span>
                        </div>
                        <div className="application-copy">
                          <h3>{app.name}</h3>
                          <p>{app.description}</p>
                          <span className="application-open">
                            {app.installed
                              ? "Open application ↗"
                              : "Build required"}
                          </span>
                        </div>
                      </a>
                    ))}
                </div>
                {!status.apps.some((app) => app.enabled) && (
                  <div className="empty">
                    No applications are enabled.{" "}
                    {isAdmin
                      ? "Enable one in Applications to get started."
                      : "Ask your administrator to enable an application."}
                  </div>
                )}
              </Section>
              <Section title="Workspace overview">
                <div className="overview-grid">
                  <div className="summary-card">
                    <AetherIcon name="items" />
                    <strong>
                      {
                        status.apps.filter(
                          (app) => app.enabled && app.installed,
                        ).length
                      }
                    </strong>
                    <span>Available applications</span>
                  </div>
                  <div className="summary-card">
                    <AetherIcon name="assembly" />
                    <strong>
                      {admin
                        ? admin.users.filter((u) => u.active).length
                        : "Private"}
                    </strong>
                    <span>
                      {admin ? "Active users" : "Your workspace storage"}
                    </span>
                  </div>
                  <div className="summary-card">
                    <AetherIcon name="hardware" />
                    <strong>
                      {admin
                        ? `${Math.floor(admin.uptime_s / 60)} min`
                        : "Connected"}
                    </strong>
                    <span>{admin ? "Host uptime" : "Host connection"}</span>
                  </div>
                </div>
              </Section>
              <Section title="Make it yours">
                <div className="welcome-panel">
                  <AetherIcon name="window" width={32} height={32} />
                  <div>
                    <h3>Your apps, one click away</h3>
                    <p>
                      Open an application in Safari, then choose File → Add to
                      Dock. The Aether host stays running when you close the
                      window.
                    </p>
                  </div>
                </div>
              </Section>
            </>
          )}
          {visiblePage === "apps" && (
            <>
              <div className="page-heading">
                <div>
                  <h1>Applications</h1>
                  <p>
                    {isAdmin
                      ? "Choose the tools available on this installation."
                      : "Tools enabled by your administrator."}
                  </p>
                </div>
              </div>
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Application</th>
                      <th>Package</th>
                      <th>Access</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {status.apps.map((app) => (
                      <tr key={app.id}>
                        <td>
                          <div className="table-name">
                            <AppIcon app={app.id} size={30} />
                            <div>
                              <strong>{app.name}</strong>
                              <small>{app.description}</small>
                            </div>
                          </div>
                        </td>
                        <td>
                          {app.installed ? "Installed" : "Build required"}
                        </td>
                        <td>
                          {app.admin_only
                            ? "Administrators"
                            : "All signed-in users"}
                        </td>
                        <td>
                          <div className="actions">
                            {app.enabled && app.installed && (
                              <a className="text-link" href={app.url}>
                                Open ↗
                              </a>
                            )}
                            {isAdmin && (
                              <Button
                                active={app.enabled}
                                disabled={
                                  busy || (!app.installed && !app.enabled)
                                }
                                onClick={() =>
                                  run(
                                    "/api/admin/apps",
                                    { id: app.id, enabled: !app.enabled },
                                    `${app.name} ${app.enabled ? "disabled" : "enabled"}.`,
                                  )
                                }
                              >
                                {app.enabled ? "Disable" : "Enable"}
                              </Button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p className="hint">
                Enablement controls both application pages and backend access.
                Existing work is kept when an app is disabled.
              </p>
            </>
          )}
          {visiblePage === "users" && admin && (
            <>
              <div className="page-heading">
                <div>
                  <h1>Users & access</h1>
                  <p>Manage local accounts, permissions and sign-ins.</p>
                </div>
              </div>
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>User</th>
                      <th>Role</th>
                      <th>Status</th>
                      <th>Sessions</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {admin.users.map((u) => (
                      <tr key={u.id}>
                        <td>
                          <strong>{u.full_name || u.username}</strong><small style={{display:"block"}}>{u.username}{u.email ? ` · ${u.email}` : " · Email not added"}</small>
                          {u.id === user.id && <small> You</small>}
                        </td>
                        <td>
                          {u.role === "admin" ? "Administrator" : "Member"}
                        </td>
                        <td>
                          {!u.active
                            ? "Disabled"
                            : u.must_change
                              ? "Password change required"
                              : "Active"}
                        </td>
                        <td>
                          {admin.sessions.find((s) => s.username === u.username)
                            ?.count ?? 0}
                        </td>
                        <td>
                          <Button onClick={() => setEditUser(u)}>Manage</Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {editUser && (
                <Section title={`Manage ${editUser.username}`}>
                  <form
                    key={editUser.id}
                    className="form inline-form"
                    onSubmit={async (event) => {
                      event.preventDefault();
                      const values = Object.fromEntries(
                        new FormData(event.currentTarget),
                      );
                      if (
                        await run(
                          "/api/admin/user",
                          {
                            id: editUser.id,
                            action: "update",
                            role: values.role,
                            active: values.active === "true",
                          },
                          "Account updated; existing sessions revoked.",
                        )
                      )
                        setEditUser(null);
                    }}
                  >
                    <Field label="Role">
                      <SelectField
                        name="role"
                        defaultValue={editUser.role}
                        options={roles}
                      />
                    </Field>
                    <Field label="Account status">
                      <SelectField
                        name="active"
                        defaultValue={editUser.active ? "true" : "false"}
                        options={[
                          { value: "true", label: "Active" },
                          { value: "false", label: "Disabled" },
                        ]}
                      />
                    </Field>
                    <Button primary type="submit" disabled={busy}>
                      Save access
                    </Button>
                    <Button
                      disabled={busy}
                      onClick={() =>
                        run(
                          "/api/admin/user",
                          { id: editUser.id, action: "revoke_sessions" },
                          "All sessions revoked.",
                        )
                      }
                    >
                      Revoke sign-ins
                    </Button>
                    <Button onClick={() => setEditUser(null)}>Close</Button>
                  </form>
                  <form className="form inline-form" key={editUser.id + "identity"} onSubmit={async e => { e.preventDefault(); if(await run("/api/admin/user", { id: editUser.id, action: "identity", ...Object.fromEntries(new FormData(e.currentTarget)) }, "User details updated."))setEditUser(null); }}><Field label="Full name"><TextField name="full_name" defaultValue={editUser.full_name} required maxLength={120} /></Field><Field label="Email address"><TextField name="email" type="email" defaultValue={editUser.email} required maxLength={254} /></Field><Button type="submit" disabled={busy}>Save user details</Button></form>
                  {editUser.id !== user.id && (
                    <form
                      className="form inline-form"
                      onSubmit={async (event) => {
                        event.preventDefault();
                        const form = event.currentTarget;
                        const values = Object.fromEntries(new FormData(form));
                        if (
                          await run(
                            "/api/admin/user",
                            {
                              id: editUser.id,
                              action: "reset_password",
                              password: values.password,
                            },
                            "Password reset. The user must change this temporary password at sign-in.",
                          )
                        )
                          form.reset();
                      }}
                    >
                      <Field label="New temporary password">
                        <TextField
                          name="password"
                          type="password"
                          required
                          minLength={12}
                          maxLength={256}
                          autoComplete="new-password"
                        />
                      </Field>
                      <Button type="submit" disabled={busy}>
                        Reset password
                      </Button>
                    </form>
                  )}
                </Section>
              )}
              <Section
                title="Add a user"
                description="New users must change their temporary password at first sign-in."
              >
                <form className="form inline-form" onSubmit={submitUser}>
                  <Field label="Full name"><TextField name="full_name" required maxLength={120} autoComplete="off" /></Field>
                  <Field label="Email address"><TextField name="email" type="email" required maxLength={254} autoComplete="off" /></Field>
                  <Field label="Username">
                    <TextField
                      name="username"
                      required
                      minLength={2}
                      maxLength={64}
                      autoComplete="off"
                    />
                  </Field>
                  <Field label="Temporary password">
                    <TextField
                      name="password"
                      type="password"
                      minLength={12}
                      maxLength={256}
                      required
                      autoComplete="new-password"
                    />
                  </Field>
                  <Field label="Role">
                    <SelectField name="role" options={roles} />
                  </Field>
                  <Button primary type="submit" disabled={busy}>
                    Create user
                  </Button>
                </form>
              </Section>
            </>
          )}
          {visiblePage === "network" && admin && network && (
            <>
              <div className="page-heading">
                <div>
                  <h1>Server & network</h1>
                  <p>Configure where your Aether installation is available.</p>
                </div>
              </div>
              <div className="connection-strip">
                <StatusDot kind="ok" />
                <span>
                  Currently serving at{" "}
                  <strong>{admin.running_settings.public_url}</strong>
                </span>
              </div>
              <Section
                title="Connection settings"
                description="Use 127.0.0.1 for this device only, or 0.0.0.0 to listen on your network. Network access requires HTTPS."
              >
                <form
                  className="form network-form"
                  onSubmit={async (event) => {
                    event.preventDefault();
                    await run(
                      "/api/admin/settings",
                      network,
                      "Settings saved. Restart the host to apply connection changes.",
                    );
                  }}
                >
                  <Field label="Workspace name">
                    <TextField
                      value={network.name}
                      required
                      maxLength={80}
                      onChange={(e) =>
                        setNetwork({ ...network, name: e.target.value })
                      }
                    />
                  </Field>
                  <div className="form-row">
                    <Field label="Bind address">
                      <TextField
                        value={network.bind_address}
                        required
                        onChange={(e) =>
                          setNetwork({
                            ...network,
                            bind_address: e.target.value,
                          })
                        }
                      />
                    </Field>
                    <Field label="Port">
                      <TextField
                        type="number"
                        min={1024}
                        max={65535}
                        value={network.port}
                        required
                        onChange={(e) =>
                          setNetwork({
                            ...network,
                            port: Number(e.target.value),
                          })
                        }
                      />
                    </Field>
                  </div>
                  <Field label="Public URL">
                    <TextField
                      type="url"
                      value={network.public_url}
                      required
                      onChange={(e) =>
                        setNetwork({ ...network, public_url: e.target.value })
                      }
                    />
                    <small>
                      The address your devices will open, including the port.
                    </small>
                  </Field>
                  <Field label="TLS certificate file">
                    <TextField
                      value={network.tls_cert}
                      placeholder="/path/on/host/certificate.pem"
                      onChange={(e) =>
                        setNetwork({ ...network, tls_cert: e.target.value })
                      }
                    />
                  </Field>
                  <Field label="TLS private key file">
                    <TextField
                      value={network.tls_key}
                      placeholder="/path/on/host/private-key.pem"
                      onChange={(e) =>
                        setNetwork({ ...network, tls_key: e.target.value })
                      }
                    />
                    <small>
                      Paths refer to files on the host. Leave both blank for
                      local HTTP.
                    </small>
                  </Field>
                  <Button primary type="submit" disabled={busy}>
                    Save settings
                  </Button>
                </form>
              </Section>
              {admin.restart_required && (
                <div className="restart-panel">
                  <h3>Restart required</h3>
                  <p>
                    Save open work before restarting. Engine sessions will be
                    cleared; saved files and accounts are kept.
                  </p>
                  <Button
                    disabled={busy}
                    onClick={async () => {
                      setBusy(true);
                      try {
                        const result = await api<{ url: string }>(
                          "/api/admin/restart",
                          {},
                        );
                        setNotice(
                          `Host restarting. Reconnect at ${result.url}`,
                        );
                        setTimeout(() => location.assign(result.url), 2500);
                      } catch (e) {
                        report((e as Error).message);
                        setBusy(false);
                      }
                    }}
                  >
                    Restart host and reconnect
                  </Button>
                </div>
              )}
            </>
          )}
          {visiblePage === "activity" && admin && (
            <>
              <div className="page-heading">
                <div>
                  <h1>Activity</h1>
                  <p>
                    Recent sign-ins and administrative changes on this server.
                  </p>
                </div>
              </div>
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>When</th>
                      <th>User</th>
                      <th>Action</th>
                      <th>Target</th>
                    </tr>
                  </thead>
                  <tbody>
                    {admin.audit.map((entry) => (
                      <tr key={entry.id}>
                        <td>{new Date(entry.time * 1000).toLocaleString()}</td>
                        <td>{entry.actor}</td>
                        <td>{entry.action.replaceAll("_", " ")}</td>
                        <td>{entry.target || "—"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
          {admin && (
            <AdministrationPanels
              page={visiblePage}
              admin={admin}
              run={run}
              refresh={refresh}
              report={report}
              busy={busy}
            />
          )}
          {visiblePage === "email" && admin && <EmailSettings key={JSON.stringify(admin.mail)} settings={admin.mail} publicURL={admin.running_settings.public_url} run={run} busy={busy} />}
          {visiblePage === "account" && (
            <>
              <div className="page-heading">
                <div>
                  <h1>My account</h1>
                  <p>
                    Signed in as {user.username} ·{" "}
                    {user.role === "admin" ? "Administrator" : "Member"}
                  </p>
                </div>
              </div>
              {Boolean(user.must_change) && (
                <div className="restart-panel">
                  Change your temporary password to finish setting up your
                  account.
                </div>
              )}
              {!user.must_change && <Section title="Personal details" description="Your full name appears in the workspace. Use your email address or username to sign in."><form className="form" key={user.email + user.full_name} onSubmit={async e => {e.preventDefault();await run("/api/profile",Object.fromEntries(new FormData(e.currentTarget)),"Account details updated.");}}><Field label="Full name"><TextField name="full_name" defaultValue={user.full_name} autoComplete="name" required maxLength={120} /></Field><Field label="Email address"><TextField name="email" type="email" defaultValue={user.email} autoComplete="email" required maxLength={254} /></Field><Field label="Current password to save details"><TextField name="current_password" type="password" autoComplete="current-password" required /></Field><Button type="submit" primary disabled={busy}>Save personal details</Button></form><p className="hint" style={{marginTop:12}}>{status.email_recovery_available ? "Email recovery is available. A recovery link verifies access to your mailbox when used." : "Email recovery becomes available after an administrator configures Email delivery."}</p></Section>}
              <Section
                title="Change password"
                description="Changing your password signs you out on every device."
              >
                {passwordForm}
              </Section>
            </>
          )}
        </main>
      </div>
    </div>
  );
}
createRoot(document.getElementById("root")!).render(<Studio />);
