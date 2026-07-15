# dev/briefings/ — cross-agent coordination

Multiple AI agents (Claude Code, Codex/ChatGPT) and humans work this repo
in parallel. This folder is how they coordinate. It complements — never
replaces — the durable docs:

- `AGENTS.md` (symlinked as `CLAUDE.md`) — the standing contract every
  agent reads first, every session.
- `dev/docs/reality/STATUS.md` — shipped truth, updated with every
  behavior change.
- `dev/docs/roadmap/` — planned behavior.

## Protocol

1. **One file per active goal**, named `YYYY-MM-DD-<topic>.md` (date the
   goal started). It states the goal, the work split (who owns what),
   and a **Handoff log** at the bottom.
2. **Before starting work**, an agent reads the active briefing and
   claims/checks its lane. Lanes follow the ownership boundaries in
   `AGENTS.md` — don't edit the other lane's code without noting it in
   the handoff log first.
3. **After a work session**, the agent appends one dated entry to the
   Handoff log: what shipped, what's in flight, what the other agent
   needs to know (contract changes especially). Keep entries to a few
   lines — STATUS.md carries the detail.
4. **When a goal completes**, distill anything durable into
   `dev/docs/reality/STATUS.md` / `dev/docs/history/` and delete the
   briefing file. This folder holds active work only.
