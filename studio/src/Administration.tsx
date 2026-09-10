import { useState } from "react";
import { AetherIcon, Button, Checkbox, TextField } from "@aether/ui";
import type { Admin } from "./main";
import { api } from "./api";

type Props = {
  page: string;
  admin: Admin;
  busy: boolean;
  run: (path: string, data: object, message: string) => Promise<boolean>;
  refresh: () => Promise<void>;
  report: (message: string) => void;
};
export function AdministrationPanels({
  page,
  admin,
  busy,
  run,
  refresh,
  report,
}: Props) {
  const [team, setTeam] = useState<Admin["teams"][number] | null>(null);
  const [secret, setSecret] = useState("");
  const [working, setWorking] = useState(false);
  const [confirmation, setConfirmation] = useState("");
  if (page === "plugins")
    return (
      <>
        <div className="page-heading">
          <div>
            <h1>Community plugins</h1>
            <p>Future support</p>
          </div>
          <span className="badge">Planned</span>
        </div>
        <div className="welcome-panel">
          <AetherIcon name="items" width={36} height={36} />
          <div>
            <h3>A place for community-built tools</h3>
            <p>
              Community plugin discovery, installation and updates are planned.
              Bundled Aether applications are managed in Applications today.
            </p>
          </div>
        </div>
      </>
    );
  if (page === "teams")
    return (
      <>
        <div className="page-heading">
          <div>
            <h1>Teams</h1>
            <p>
              Group users and grant access to applications with restricted
              access.
            </p>
          </div>
          <Button
            primary
            onClick={() => setTeam({ id: "", name: "", members: [], apps: [] })}
          >
            Create team
          </Button>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Team</th>
                <th>Members</th>
                <th>Application grants</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {admin.teams.map((item) => (
                <tr key={item.id}>
                  <td>{item.name}</td>
                  <td>{item.members.length}</td>
                  <td>{item.apps.join(", ") || "None"}</td>
                  <td>
                    <Button onClick={() => setTeam(item)}>Edit team</Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!admin.teams.length && (
            <div className="empty">
              No teams yet. Create one to manage application access for a group.
            </div>
          )}
        </div>
        {team && (
          <form
            className="form team-form"
            onSubmit={async (event) => {
              event.preventDefault();
              if (await run("/api/admin/team", team, "Team saved."))
                setTeam(null);
            }}
          >
            <h2>{team.id ? "Edit team" : "New team"}</h2>
            <label className="field">
              <span>Team name</span>
              <TextField
                value={team.name}
                onChange={(e) => setTeam({ ...team, name: e.target.value })}
                required
                maxLength={80}
              />
            </label>
            <fieldset>
              <legend>Members</legend>
              {admin.users.map((u) => (
                <Checkbox
                  key={u.id}
                  label={u.username}
                  checked={team.members.includes(u.id)}
                  onChange={(e) =>
                    setTeam({
                      ...team,
                      members: e.target.checked
                        ? [...team.members, u.id]
                        : team.members.filter((id) => id !== u.id),
                    })
                  }
                />
              ))}
            </fieldset>
            <fieldset>
              <legend>Application grants</legend>
              {["cad", "animation"].map((id) => (
                <Checkbox
                  key={id}
                  label={id === "cad" ? "Aether CAD" : "Aether Animation"}
                  checked={team.apps.includes(id)}
                  onChange={(e) =>
                    setTeam({
                      ...team,
                      apps: e.target.checked
                        ? [...team.apps, id]
                        : team.apps.filter((app) => app !== id),
                    })
                  }
                />
              ))}
            </fieldset>
            <p className="hint">
              Grants are enforced when an application requires team membership
              in Roles & permissions.
            </p>
            <div className="actions">
              <Button primary type="submit" disabled={busy}>
                Save team
              </Button>
              <Button onClick={() => setTeam(null)}>Cancel</Button>
              {team.id && (
                <Button
                  disabled={busy}
                  onClick={async () => {
                    if (confirmation !== team.id) {
                      setConfirmation(team.id);
                      return;
                    }
                    if (
                      await run(
                        "/api/admin/team",
                        { id: team.id, action: "delete" },
                        "Team deleted; membership grants removed.",
                      )
                    ) {
                      setTeam(null);
                      setConfirmation("");
                    }
                  }}
                >
                  {confirmation === team.id
                    ? "Confirm delete team"
                    : "Delete team"}
                </Button>
              )}
            </div>
          </form>
        )}
      </>
    );
  if (page === "access")
    return (
      <>
        <div className="page-heading">
          <div>
            <h1>Roles & permissions</h1>
            <p>Server roles and application access rules.</p>
          </div>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Role</th>
                <th>Permissions</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Administrator</td>
                <td>
                  Manage the server, accounts, teams, backups and enabled
                  applications.
                </td>
              </tr>
              <tr>
                <td>Member</td>
                <td>
                  Open permitted applications, edit personal workspace files and
                  manage their own password.
                </td>
              </tr>
              <tr>
                <td>Service account</td>
                <td>
                  Call explicitly scoped application APIs using a revocable,
                  expiring token. No administration access.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <section className="section">
          <h2>Application access</h2>
          <p className="hint">
            Administrators retain access to enabled apps. Members need a
            matching team grant when restricted access is enabled.
          </p>
          <div className="policy-list">
            {["cad", "animation"].map((id) => (
              <Checkbox
                key={id}
                label={`${id === "cad" ? "Aether CAD" : "Aether Animation"}: require team membership`}
                description="Uncheck to allow all active members."
                checked={Boolean(admin.access[id])}
                disabled={busy}
                onChange={(e) =>
                  run(
                    "/api/admin/access",
                    { id, restricted: e.target.checked },
                    "Application access policy updated.",
                  )
                }
              />
            ))}
          </div>
        </section>
      </>
    );
  if (page === "services")
    return (
      <>
        <div className="page-heading">
          <div>
            <h1>Service accounts</h1>
            <p>Scoped API access for your scripts and integrations.</p>
          </div>
        </div>
        {secret && (
          <div className="restart-panel">
            <h3>Copy your token now</h3>
            <p>
              This is the only time the complete token is shown. Send it in the
              Authorization: Bearer header.
            </p>
            <TextField
              aria-label="New service account token"
              value={secret}
              readOnly
              onFocus={(e) => e.target.select()}
              style={{ width: "100%" }}
            />
            <Button onClick={() => setSecret("")} style={{ marginTop: 12 }}>
              I have saved this token
            </Button>
          </div>
        )}
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Applications</th>
                <th>Expires</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {admin.services.map((service) => (
                <tr key={service.id}>
                  <td>{service.name}</td>
                  <td>{service.apps.join(", ")}</td>
                  <td>
                    {new Date(service.expires * 1000).toLocaleDateString()}
                  </td>
                  <td>
                    {service.active && service.expires > Date.now() / 1000
                      ? "Active"
                      : "Revoked / expired"}
                  </td>
                  <td>
                    {Boolean(service.active) && (
                      <Button
                        disabled={busy}
                        onClick={() =>
                          run(
                            "/api/admin/service",
                            { id: service.id, action: "revoke" },
                            "Service token revoked.",
                          )
                        }
                      >
                        Revoke
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <form
          className="form team-form"
          onSubmit={async (event) => {
            event.preventDefault();
            const form = event.currentTarget;
            const data = new FormData(form);
            setWorking(true);
            setSecret("");
            try {
              const result = await api<{ token: string }>(
                "/api/admin/service",
                {
                  name: data.get("name"),
                  days: Number(data.get("days")),
                  apps: data.getAll("apps"),
                },
              );
              setSecret(result.token);
              form.reset();
              await refresh();
            } catch (e) {
              report((e as Error).message);
            } finally {
              setWorking(false);
            }
          }}
        >
          <h2>Create a service account</h2>
          <label className="field">
            <span>Name</span>
            <TextField name="name" required maxLength={80} />
          </label>
          <label className="field">
            <span>Expires after (days)</span>
            <TextField
              name="days"
              type="number"
              min={1}
              max={365}
              defaultValue={30}
              required
            />
          </label>
          <fieldset>
            <legend>Application scopes</legend>
            <Checkbox name="apps" value="cad" label="Aether CAD" />
            <Checkbox name="apps" value="animation" label="Aether Animation" />
          </fieldset>
          <Button primary type="submit" disabled={working}>
            Create token
          </Button>
        </form>
      </>
    );
  if (page === "backups")
    return (
      <>
        <div className="page-heading">
          <div>
            <h1>Backups</h1>
            <p>Snapshots of accounts, settings and saved workspace files.</p>
          </div>
          <Button
            primary
            disabled={busy}
            onClick={() =>
              run("/api/admin/backup", {}, "Backup created. Download it below.")
            }
          >
            Create backup
          </Button>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Backup</th>
                <th>Created</th>
                <th>Size</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {admin.backups.map((backup) => (
                <tr key={backup.name}>
                  <td>{backup.name}</td>
                  <td>{new Date(backup.created * 1000).toLocaleString()}</td>
                  <td>{(backup.size / 1024).toFixed(1)} KB</td>
                  <td>
                    <a
                      className="text-link"
                      href={`/api/admin/backups/${backup.name}`}
                      download
                    >
                      Download
                    </a>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!admin.backups.length && (
            <div className="empty">No backups yet.</div>
          )}
        </div>
        <div className="welcome-panel">
          <AetherIcon name="save" width={32} height={32} />
          <div>
            <h3>Restore from the host console</h3>
            <p>
              Restore into an empty data directory with the Studio CLI. Existing
              installations are never overwritten. Restore clears sign-ins,
              revokes service tokens and resets the network to local-only
              access.
            </p>
            <code>
              python -m core.host restore --archive backup.zip --data
              /path/to/empty-directory
            </code>
            <p className="hint">
              Backups include password hashes and project files; keep them
              private. They exclude browser-local unsaved work, TLS files and
              installed application builds.
            </p>
          </div>
        </div>
      </>
    );
  return null;
}
