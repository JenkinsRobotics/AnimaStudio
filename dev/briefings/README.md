# dev/briefings/ — cross-agent coordination

Multiple AI agents (Claude Code, Codex/ChatGPT) and humans work this repo
in parallel. This folder is how they coordinate. It complements — never
replaces — the durable docs:

- `AGENTS.md` (symlinked as `CLAUDE.md`) — the standing contract every
  agent reads first, every session.
- `dev/docs/reality/STATUS.md` — shipped truth, updated with every
  behavior change.
- `dev/docs/roadmap/` — planned behavior.

## Mailboxes — `claude.md` and `codex.md`

The two standing files are the agents' mailboxes (roles are defined in
`AGENTS.md` → Team roles). Each has an **IN** section (anyone —
Jonathan or the other agent — appends tasks/messages; the owner checks
them off) and an **OUT** section (the owner writes replies, review
findings, and plans, newest first). Every agent session starts by
reading its own IN and ends by updating its OUT. Prune checked-off
items once both sides have seen them.

## Protocol

1. **One file per active goal**, named `YYYY-MM-DD-<topic>.md` (date the
   goal started). It states the goal, the work split (who owns what),
   and a **Handoff log** at the bottom.
2. **Before starting work**, an agent reads the active briefing and
   adds a bounded row to **Live claims** with its agent name, task, exact file
   globs, and acceptance command. Lanes follow the ownership boundaries in
   `AGENTS.md`. Overlapping file claims are not allowed.
3. **After a work session**, the agent appends one dated entry to the
   Handoff log: what shipped, what's in flight, what the other agent
   needs to know (contract changes especially). Keep entries to a few
   lines — STATUS.md carries the detail.
4. **When a goal completes**, distill anything durable into
   `dev/docs/reality/STATUS.md` / `dev/docs/history/` and delete the
   briefing file. This folder holds active work only.

## Shared-checkout safety

- Modified and untracked files belong to their current claimant until released.
- Stage and commit explicit claimed paths only; never sweep the worktree.
- Do not stash, clean, reset, rebase, checkout, or globally format while another
  claim is active.
- Use the briefing's **Requests** section for cross-lane API or contract changes.
- If two tasks need the same file, sequence them or use separate Git worktrees.
