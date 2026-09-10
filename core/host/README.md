# Aether Studio host

One background host serves the administration workspace and bundled web apps.
The browser owns the window. No Swift wrapper or window-owned Python process is
required. The canonical animation/assembly engine remains `animacore.bridge`.

## Start on this Mac

Double-click **Install Aether Studio.command** at the repository root, or run:

```sh
zsh core/host/install-macos.sh
```

The installer checks prerequisites, prepares dependencies, builds Studio, CAD, Animation and UI; installs the per-user
`studio.aether.host` LaunchAgent; builds four browser shortcuts at the repository
root; and opens first-run setup. It requires Python 3.11 or 3.12, Node.js 22.12+ and macOS command-line utilities.
It creates `.venv` when missing, installs the engine dependencies and runs `npm ci`
for each web package. `zsh core/host/install-macos.sh --check` checks prerequisites
without installing or changing the running service. Re-running the installer
does not interrupt an already-running host. To load changed Python host code,
save open work then restart the service with `launchctl kickstart -k
"gui/$(id -u)/studio.aether.host"`.

Default address: **http://localhost:8780**. The host starts at login and keeps
running when browser windows close. This is a per-user login service, not a
system daemon that runs while all users are logged out.

First run uses a host-authorized setup link opened by the installer or Studio app.
The browser exchanges its fragment for an HttpOnly setup cookie lasting one hour;
authorization survives refresh, and no code needs to be typed. The guided browser flow is **Welcome → Workspace → Administrator → Applications → Review**.
Name the workspace, choose your administrator credentials, select bundled apps,
and confirm on the final review. Draft choices stay in memory; account, name and
app enablement are committed together only at Finish setup. A completion screen
then opens Studio. There is no shipped default password. To reopen that setup link:

```sh
.venv/bin/python -m core.host open
```

For a foreground host on another supported Python platform:

```sh
.venv/bin/python -m core.host serve --data /path/to/private/aether-data
```

Only one process should serve a given data directory. The current distribution
runs from this checkout; standalone installers, containers and auto-updates are
not shipped by this work.

## Browser applications

| URL | Purpose |
| --- | --- |
| `/` | Normal Studio home, also visible while signed out; first-run wizard until configured |
| `/cad/` | Aether CAD |
| `/animation/` | Aether Animation |
| `/ui/` | Aether UI design gallery, administrators only |

After setup, the normal home shows enabled product cards and Sign in. Administration
items appear only for an authenticated administrator. A direct package link prompts
for sign-in when needed and then returns to that package. No private workspace data
or user lists are exposed on the signed-out home.

Open a package in Safari and choose **File → Add to Dock**. Each application
provides its name, start URL, and Core-derived icons. Browser installation adds a
shortcut/window; it does not enable offline engine operation. The four root
`.app` bundles are convenience URL openers, not embedded browsers. Their build
scripts no longer compile the legacy Swift launchers.

Product API calls stay on the same origin under `/cad/rpc` or
`/animation/rpc`, with per-login, per-application engine handles. Applications
include a Studio link. Returning after a host restart requires reopening the
saved document because in-memory engine sessions do not survive a restart.

## Administration

The reference is a quiet charcoal home with a fixed left navigation and blue
selection, using Core controls, vector assets and the shared home theme.

- **Home:** installed app cards and live-on-refresh host/account statistics.
- **Applications:** enable/disable bundled packages. Enforcement covers pages,
  static package assets, workspace files and API calls, including already-open
  application windows. Disabling keeps saved data.
- **Users:** create local accounts, change roles, disable accounts, revoke
  sign-ins, and reset passwords. New/reset users must change their temporary
  password. Self-demotion/self-disable and removing the last admin are blocked.
- **Teams:** membership and application grants. No shared team storage is implied.
- **Roles & permissions:** Administrator, Member and scoped Service account;
  optionally require team membership for CAD or Animation. Admins retain access
  to enabled applications. There are no read-only geometry/editor roles yet.
- **Service accounts:** app-scoped tokens, shown once, expiring in 1–365 days,
  revocable immediately. These cannot administer the server or use interactive
  sign-in. Each has its own workspace storage.
- **Backups:** create/download a database and saved-workspace snapshot. Restore
  is an offline console operation into an empty directory. Browser-local or
  unsaved state, installed builds and TLS key/certificate files are not backed up.
- **Server & network:** workspace name, IPv4 bind address, port, public URL and
  TLS file paths. Validate and save; restart explicitly to apply. Save work first.
  A failed listener change during restart restores the previous listener.
- **Activity:** recent sign-ins and administrative operations, without passwords
  or tokens. Not a complete document-edit audit log.
- **My account:** full name and email editing (current password required), plus password change; revokes all existing sign-ins.
- **Email delivery:** administrator-configured SMTP with STARTTLS or implicit TLS, protected credentials and an explicit test-email action. Recovery emails include the username and a one-use reset link expiring after 30 minutes. Recovery revokes existing sign-ins.
- **Community plugins:** explicitly planned, no installation or execution yet.

Grafana's [user management](https://grafana.com/docs/grafana/latest/administration/user-management/),
[teams](https://grafana.com/docs/grafana/latest/administration/team-management/),
[service accounts](https://grafana.com/docs/grafana/latest/administration/service-accounts/),
and [backup administration](https://grafana.com/docs/grafana/latest/administration/back-up-grafana/)
are interaction references, not dependencies or promises of Grafana feature parity.

## Network and authentication

Default binding is `127.0.0.1`; the initial installation is local-only. For
network access, configure a hostname/address reachable by your other devices,
set bind address to `0.0.0.0` or the host's IPv4 address, and configure an HTTPS
public URL with the same port plus a certificate/private key readable by the
host. The certificate must be trusted by those devices. Certificate issuance,
router/firewall changes, automatic DNS, reverse-proxy termination and IPv6 are
not automated. No actual second-device connection is claimed by the local QA.

Passwords use salted scrypt hashes. Random sign-in tokens are hashed in SQLite,
expire after 12 hours, and use HttpOnly/SameSite=Strict cookies (Secure on HTTPS).
Account disable, password reset and session revocation take effect at the next
request. JSON writes require a matching Origin and an allowed Host. Service
account APIs instead accept explicit `Authorization: Bearer aether_sa_…` tokens.
Sign-in failures are rate limited by account and source address. API bodies have
an 8 MB limit. This initial stdlib host is designed for a small local installation;
SSO, MFA, organization tenancy,
provisioning imports, scheduled backups, external data sources and community
plugin execution remain future work.

## Persistent data and recovery

macOS default: `~/Library/Application Support/Aether Studio/`.
Other platforms: `~/.local/share/aether-studio/`.

- `studio.sqlite3`: accounts, password hashes, sessions, teams, app policies,
  service token hashes, network settings and activity.
- `workspaces/<user-id>/`: private host-saved files and seeded sample character.
- `backups/`: downloadable private backup archives.
- `setup-token`: removed when the first administrator is created.
- `mail.json`: private SMTP settings/credentials, excluded from backup archives. Reconfigure email after restoring.
- `logs/`: macOS service output.

Existing repository and browser-local projects are not silently moved into the
new account directories. Use product import/export/open workflows to bring them
across. Hosted CAD now saves Parts and Assembly archives into the server library; standalone/browser-local files still need importing;
team membership does not make files collaborative. Animation text saves use
content revision checks to reject stale writes. CAD's workspace bridge retains
its existing engine revision behavior; full cross-device project history and
collaboration are not delivered by this host.

Recover a forgotten password from the trusted host console:

```sh
.venv/bin/python -m core.host reset-password --username your-name
```

The command prompts for the password rather than putting it in shell arguments.
It revokes sessions; it does not reactivate an administratively disabled account.

Restore a downloaded backup to an empty directory:

```sh
.venv/bin/python -m core.host restore --archive /path/backup.zip --data /path/empty-data
.venv/bin/python -m core.host serve --data /path/empty-data
```

Stop the existing service first if using its port. Keep its original data as a
rollback copy. Restore validates archive paths/database integrity, clears browser
sessions, disables old service tokens, and resets networking to local-only.
Accounts, team grants and saved workspace files survive. TLS files must be
provisioned separately. Backup archives contain password hashes and private work.

## Verification

```sh
.venv/bin/python -m pytest core/host/tests -q
.venv/bin/ruff check core/host
npm run build --prefix studio
```

Host tests cover setup takeover prevention, credential storage, account and engine
isolation, stale file saves, resets/revocation, app/team restrictions, service
scopes, network validation, backup/restore, traversal, rate limiting and HTTP
origin/cookie boundaries. Manual browser walkthroughs additionally cover the
admin UI, all three package routes and restart/reconnect. Icon derivatives are
regenerated from Core SVGs on macOS with
`.venv/bin/python core/host/build-web-icons.py`.

### Email recovery

Setup collects full name, username and email. Existing accounts migrate without losing passwords or sessions; add missing details in My account or Users. Sign in with username or email. Email recovery stays unavailable until an administrator configures **Email delivery**. Use the configured public URL reachable by recipients; a localhost reset link only opens correctly on the host. Recovery requests return the same response for known and unknown accounts and are rate limited. Tokens are stored hashed, expire after 30 minutes and work once. Changing the email address invalidates pending reset links. Successful recovery verifies mailbox access; merely entering an address does not verify it. No original password is sent. Local console password recovery remains available if SMTP is unavailable.

## Product file home and account preferences

`/cad/` serves the CAD library home, and `/cad/index.html?document=<id>` opens a saved document in the editor. Authentication retains that destination. The root Studio app launcher opens CAD in a separate tab/window; Safari Add to Dock can make `/cad/` its own installed web app. The host cannot automatically install a Safari web app from a webpage.

Library metadata and file bytes live in the `library` and `library_recents` SQLite tables. `POST /api/library/{list,create,read,save,rename,share,copy}` always requires a signed-in user and enabled/permitted application. Service accounts do not have library access. Personal entries are private to the owner. Workspace entries are readable to other users with app access; only owners write them. Copies are new private files. Save/rename/share require `expected_revision` and return 409 on a stale version. `create` can create folders; visibility is inherited from the chosen folder. Per-file share/unshare moves the file to the destination root.

CAD imports `.cadpart`, `.aether`, `.step` and `.stp` up to 6 MB. Library JSON requests allow 9 MB to carry base64 overhead; other APIs keep their 8 MB cap. The library does not reinterpret document content; product parsers and the canonical Core engine do. Files are returned through authenticated JSON as base64, never served as executable HTML. Backups include library documents automatically. Existing local downloads are not silently migrated. Saving is explicit; no auto-save, file version history, granular user invitations, trash or real-time coediting is claimed.

`POST /api/preferences` stores dark/light/system appearance and an optional PNG/JPEG avatar (256 KB maximum) on the account. `core/session/account.js` renders a shared account control into front-end-owned slots and uses the same `/api/status` identity everywhere. Names and pictures come from that account; themes use Core tokens. Same-browser tabs synchronize via BroadcastChannel; other browser sessions refresh on focus. The server must be reachable through its configured HTTPS network URL to use the same files from other physical devices. Localhost remains host-only.
