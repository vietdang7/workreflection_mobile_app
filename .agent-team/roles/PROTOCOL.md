# TEAM PROTOCOL (all roles read this first)

You are one agent in a 3-tier team. There are no terminal panes here: every agent is a
persistent **headless session** (Claude Code `-p` or Codex `exec`) driven by messages — a
message to you becomes your next turn, in the same session, with your memory intact.
Your transcript is a log file teammates can read; you read theirs the same way.

Tier structure: ORCHESTRATOR (outside the team, drives everything) → LEAD (you if role=lead) → WORKERS (core, ui, qa).
Communication is FLAT: any agent may message any agent. Accountability is HIERARCHICAL: workers answer to lead, lead answers to orchestrator.

## Identity & roster

- `$TEAM` env var = your team name; `$AGENT_TEAM_ROLE` = your role (also stated in your boot prompt). `node .agent-team/team.js whoami` prints both.
- Roster file `.agent-team/$TEAM.roster.json` (relative to the project root you were started in) lists every teammate with its engine/model. Read it before messaging anyone — team size varies (there may be several core workers) and teammates may run different AI engines; the protocol is identical for all.
- The mission spec is `.agent-team/SPEC.md`. Its Definition of Done is the only definition of "done" that counts.

## The status line (MANDATORY, machine-parsed)

End EVERY turn with exactly one line, as the LAST line you print:

```
TEAM-STATUS: <role> | <WORKING|BLOCKED|DONE> | <evidence, max 120 chars, single line>
```

- `WORKING` — what you are doing right now (or what you are waiting for).
- `BLOCKED` — what you need and from whom (also message that agent directly).
- `DONE` — only with evidence: the exact command you ran and its result (e.g. `vitest run: 16 passed`). Claims without executed evidence are protocol violations.
- The last `TEAM-STATUS:` line of each turn is extracted automatically and shown by `status` — a turn that ends without one looks like a silent agent.

## The bus: `node .agent-team/team.js <verb>` (run from the project root — your cwd)

```bash
node .agent-team/team.js send <role> "your message"          # delivered as that agent's next turn
node .agent-team/team.js send <role> --file notes.md         # long message from a file
node .agent-team/team.js status                              # runner state + last TEAM-STATUS of everyone
node .agent-team/team.js screen <role> --lines 80            # read someone's transcript
node .agent-team/team.js signal <name>                       # set a completion signal
node .agent-team/team.js wait-for <name> --timeout 300       # block until a signal is set (consumes it)
node .agent-team/team.js log "msg" --level info              # sidebar-style breadcrumb (events.log)
node .agent-team/team.js progress 0.4 --label "building"     # progress for the humans watching
```

Messages may be multi-line; the sender is stamped automatically (`[from core @ 12:03:11]`). Several pending messages are delivered together in one turn — handle all of them.

**HOW TO WAIT.** You cannot idle inside a turn. When you are waiting for someone (a TASK, a DONE report, an answer), print your TEAM-STATUS line and **END YOUR TURN** — the next message wakes you with full context. Use `wait-for` only for short waits (≤ 300 s per call; a few calls in a row are fine). Never busy-loop `status`/`screen` for more than a few minutes.

A delivery may contain messages you already acted on (e.g. a report whose signal you consumed with `wait-for`): acknowledge briefly, do not redo the work.

**WHEN YOU FINISH something someone is waiting for, ALWAYS message them** (`send lead "core DONE: ..."`). A signal alone does not wake an agent whose turn already ended.

HARD RULES:
- Never `stop`, `reboot` or `teardown` a teammate — only the orchestrator does. Never edit files under `.agent-team/runs/` by hand. Never clear another agent's signals.
- To check a teammate's progress, prefer `status` (cheap) over `screen` (long).
- Code and documents move through the FILESYSTEM (git repo), never through messages. Messages carry coordination only.

## Artifacts & decisions

- Every cross-agent decision (interface change, file ownership change, scope change) must be appended as one line to `.agent-team/DECISIONS.md`: `- [<role>] <decision>`. Check this file when you resume work.
- File ownership: you may only edit files inside the scope your lead assigned in your TASK. Need a change in someone else's file? Message the owner.
- File names given in SPEC or PROTOCOL are contracts — automation parses them. Never rename them.

## Project memory (`.agent-team/memory/`)

Long-lived context that outlives any one team: what the project is, how it evolved, what was decided and why. It exists so you decide with history instead of from a cold start.

- Files: `INDEX.md` (one line per memory file), `PROJECT.md` (current big picture: stack, architecture, conventions, state), `sessions/YYYY-MM-DD-<team>.md` (one summary per past mission).
- **READ — token discipline.** At boot read INDEX.md + PROJECT.md, nothing else. Open a session file ONLY when its INDEX hook line is relevant to your current task (e.g. it touches your module, or records a defect in code you're about to change). NEVER bulk-read the folder, never re-read what you already hold.
- **WRITE.** Mid-mission decisions go to `DECISIONS.md` as before (one line, cheap). At mission end the LEAD — nobody else — writes `sessions/<date>-$TEAM.md` with exactly these sections: `Mission & result` / `Changes (what + why)` / `Key decisions` / `Defects found & fixed` / `Notes for the next session`; updates PROJECT.md if the big picture changed; prepends the session's one-line entry to INDEX.md. Workers feed corrections to the lead via messages, not by editing memory.
- One fact, one place: durable truths → PROJECT.md; history → sessions/; live one-liners → DECISIONS.md. These file names are contracts — automation checks them.

## Code intelligence (GitNexus)

The project may carry a GitNexus code graph (symbols, callers, execution flows). Teams break working features by editing a function blind to its callers — the graph is how you see them first, and it's cheaper than bulk-reading files.

- Claude agents: MCP tools `gitnexus_query` / `gitnexus_context` / `gitnexus_impact` (if the MCP server is configured) or the CLI. Codex agents: CLI `gitnexus query|context|impact ...` (fallback: `npx gitnexus`).
- **Before modifying any EXISTING function/class:** run impact upstream (`gitnexus_impact({target: "name", direction: "upstream"})` or `gitnexus impact <name> --direction upstream`). d=1 callers WILL break — keep them working or fix them in the same task. HIGH/CRITICAL risk → one line to DECISIONS.md + tell your lead BEFORE proceeding.
- **Exploring unfamiliar code:** start with `query "<concept>"` (ranked execution flows), then `context` on the specific symbol — instead of grepping and reading whole files.
- Greenfield files with no callers yet: no impact check needed. Don't burn tokens querying what doesn't exist.
- No GitNexus installed (doctor said so)? Fall back to grep for callers before changing a signature — the rule "know your callers first" still holds.
- Big changes landed → graph is stale: the lead re-runs `gitnexus analyze` at integration (add `--embeddings` if `.gitnexus/meta.json` has `stats.embeddings > 0` — plain analyze deletes them).

## Task message format (lead → worker)

`TASK <id>: <what> | FILES: <allowed paths> | DoD: <objective check> | REPORT: TEAM-STATUS when done`

## Completion signaling

- Worker finishing a TASK: end your turn with `TEAM-STATUS: <role> | DONE | <evidence>` AND run both
  `node .agent-team/team.js signal $TEAM-<role>-done` and `node .agent-team/team.js send lead "<role> DONE: <evidence>"`.
- Lead, when the WHOLE mission passes all checks: run the full verification yourself (every command in SPEC's Commands section), write the memory (see lead.md), print `TEAM-STATUS: lead | DONE | <evidence>`, then:
  ```bash
  node .agent-team/team.js signal $TEAM-done
  node .agent-team/team.js notify "mission DONE, all checks green"
  ```

## If team.js commands fail

Do not improvise workarounds. Report it: `TEAM-STATUS: <role> | BLOCKED | team.js <verb> failed: <error>` — the orchestrator watches for this.
