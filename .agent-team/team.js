#!/usr/bin/env node
/*
 * team.js — cross-platform agent-team bus (Windows / macOS / Linux, Node >= 18, zero deps).
 *
 * Port of the cmux-team plugin without cmux: every agent is a persistent HEADLESS session
 * (`claude -p --session-id/--resume` or `codex exec [resume] -`) driven by a background runner.
 *
 *   send <role> <msg>   -> writes an inbox file, makes sure a runner is alive
 *   runner (_run)       -> lock -> drain inbox -> one engine turn in the same session -> repeat
 *   screen / status     -> read the agent's log / state files
 *   signal / wait-for   -> files in runs/<team>/signals/
 *
 * State lives in <repo>/.agent-team/ (override with AGENT_TEAM_DIR). Nothing here needs a
 * daemon, a PTY or a terminal emulator; everything is crash-resumable from the files.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');
const crypto = require('crypto');
const readline = require('readline');

const VERSION = '1.0.0';

// `status | head` closes our stdout early — exit quietly instead of crashing with EPIPE.
process.stdout.on('error', e => { if (e && e.code === 'EPIPE') process.exit(0); throw e; });
process.stderr.on('error', e => { if (!(e && e.code === 'EPIPE')) throw e; });
const IS_WIN = process.platform === 'win32';
const ROLE_FILES = { lead: 'lead.md', ui: 'worker-ui.md', qa: 'worker-qa.md' };
const RESERVED_TEAM_NAMES = new Set(['memory', 'roles', 'archive', 'runs', 'team', 'team.js']);
const MAX_CORES = 6;
const DEFAULT_WAIT_TIMEOUT = 300; // seconds; agents' shell tools have their own limits
const TURN_TIMEOUT_MIN = Number(process.env.AGENT_TEAM_TURN_TIMEOUT_MIN || 90);

// ----------------------------------------------------------------------------
// paths
// ----------------------------------------------------------------------------
function repoRoot() { return path.resolve(process.env.AGENT_TEAM_REPO || process.cwd()); }
function teamDirName() { return process.env.AGENT_TEAM_DIR || '.agent-team'; }
function teamDir() { return path.join(repoRoot(), teamDirName()); }
function rosterPath(team) { return path.join(teamDir(), `${team}.roster.json`); }
function runDir(team) { return path.join(teamDir(), 'runs', team); }
function logPath(team, role) { return path.join(runDir(team), 'logs', `${role}.log`); }
function runnerLogPath(team, role) { return path.join(runDir(team), 'logs', `${role}.runner.log`); }
function statePath(team, role) { return path.join(runDir(team), 'state', `${role}.json`); }
function inboxDir(team, role) { return path.join(runDir(team), 'inbox', role); }
function lockDir(team, role) { return path.join(runDir(team), 'locks', role); }
function signalsDir(team) { return path.join(runDir(team), 'signals'); }
function eventsPath(team) { return path.join(runDir(team), 'events.log'); }
function rolesRef() { return `${teamDirName()}/roles`; } // relative, forward slashes (agents' cwd = repo)

// ----------------------------------------------------------------------------
// small utils
// ----------------------------------------------------------------------------
function die(msg, code = 1) { process.stderr.write(`ERROR: ${msg}\n`); process.exit(code); }
function warn(msg) { process.stderr.write(`WARNING: ${msg}\n`); }
function say(msg) { process.stdout.write(`${msg}\n`); }
function nowIso() { return new Date().toISOString(); }
function hhmmss(iso) { const d = iso ? new Date(iso) : new Date(); return d.toTimeString().slice(0, 8); }
function ensureDir(p) { fs.mkdirSync(p, { recursive: true }); }
function readJson(p, fallback) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; } }
function writeJsonAtomic(p, obj) {
  ensureDir(path.dirname(p));
  const tmp = `${p}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2) + '\n');
  fs.renameSync(tmp, p);
}
function appendText(p, text) { ensureDir(path.dirname(p)); fs.appendFileSync(p, text); }
function oneLine(s, max = 300) {
  const t = String(s == null ? '' : s).replace(/\s+/g, ' ').trim();
  return t.length > max ? t.slice(0, max - 1) + '…' : t;
}
function tailLines(p, n) {
  if (!fs.existsSync(p)) return [];
  const lines = fs.readFileSync(p, 'utf8').split('\n');
  if (lines[lines.length - 1] === '') lines.pop();
  return n > 0 ? lines.slice(-n) : lines;
}
function pidAlive(pid) {
  if (!pid) return false;
  try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; }
}
function killTree(pid) {
  if (!pid) return;
  try {
    if (IS_WIN) cp.spawnSync('taskkill', ['/PID', String(pid), '/T', '/F'], { stdio: 'ignore' });
    else { try { process.kill(-pid, 'SIGTERM'); } catch { process.kill(pid, 'SIGTERM'); } }
  } catch { /* already gone */ }
}
// Windows keeps file handles open for a moment after taskkill — retry directory moves.
function renameRetry(src, dst, tries = 6) {
  for (let i = 0; ; i++) {
    try { fs.renameSync(src, dst); return; }
    catch (e) {
      if (i >= tries - 1 || !['EPERM', 'EBUSY', 'ENOTEMPTY', 'EACCES'].includes(e.code)) throw e;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
    }
  }
}
function sanitizeName(n, what) {
  if (!/^[A-Za-z0-9_-]+$/.test(n || '')) die(`${what} must match [A-Za-z0-9_-]+ (got: '${n}')`);
  return n;
}

// Locate an executable the way the shell would. On Windows npm shims are .cmd files, which
// Node can only spawn through cmd.exe (shell: true) — we track that per executable.
function resolveExe(name) {
  const dirs = (process.env.PATH || '').split(path.delimiter).filter(Boolean);
  const exts = IS_WIN ? ['.exe', '.cmd', '.bat', ''] : [''];
  for (const d of dirs) {
    for (const ext of exts) {
      const f = path.join(d, name + ext);
      try {
        const st = fs.statSync(f);
        if (st.isFile()) return { file: f, shell: IS_WIN && /\.(cmd|bat)$/i.test(f) };
      } catch { /* keep looking */ }
    }
  }
  return null;
}
function winQuote(a) {
  if (/^[A-Za-z0-9_\-.:=\/\\@,+%]+$/.test(a)) return a;
  return `"${a.replace(/"/g, '\\"')}"`;
}
// spawn an engine (claude/codex) with prompt on stdin, output streamed back.
function spawnExe(exe, args, opts) {
  if (exe.shell) {
    const cmdline = [winQuote(exe.file), ...args.map(winQuote)].join(' ');
    return cp.spawn(cmdline, Object.assign({ shell: true, windowsHide: true }, opts));
  }
  return cp.spawn(exe.file, args, Object.assign({ windowsHide: true }, opts));
}
function exeVersion(exe) {
  try {
    const r = exe.shell
      ? cp.spawnSync(`${winQuote(exe.file)} --version`, { shell: true, encoding: 'utf8', windowsHide: true, timeout: 20000 })
      : cp.spawnSync(exe.file, ['--version'], { encoding: 'utf8', windowsHide: true, timeout: 20000 });
    return oneLine((r.stdout || '') + (r.stderr || ''), 80) || `exit ${r.status}`;
  } catch (e) { return `error: ${e.message}`; }
}

// ----------------------------------------------------------------------------
// arg parsing: node team.js <cmd> [--key value]... [positional...]
// ----------------------------------------------------------------------------
const FLAG_KEYS = new Set(['team', 'lines', 'timeout', 'cores', 'agent', 'file', 'level', 'label', 'from', 'model', 'engine', 'engines']);
const BOOL_KEYS = new Set(['all', 'no-mission', 'clear', 'help', 'version', 'json', 'claude-only', 'codex-only', 'quiet', 'no-gitnexus', 'no-wt', 'no-doctor']);
function parseArgs(argv) {
  const out = { _: [], agent: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--') { out._.push(...argv.slice(i + 1)); break; }
    if (a.startsWith('--')) {
      const eq = a.indexOf('=');
      const key = eq > 0 ? a.slice(2, eq) : a.slice(2);
      if (BOOL_KEYS.has(key)) { out[key] = true; continue; }
      if (FLAG_KEYS.has(key)) {
        const val = eq > 0 ? a.slice(eq + 1) : argv[++i];
        if (val == null) die(`--${key} needs a value`);
        if (key === 'agent') out.agent.push(val); else out[key] = val;
        continue;
      }
      die(`unknown flag --${key} (see: node team.js --help)`);
    }
    out._.push(a);
  }
  return out;
}

// ----------------------------------------------------------------------------
// roster / state / events
// ----------------------------------------------------------------------------
function listRosters() {
  if (!fs.existsSync(teamDir())) return [];
  return fs.readdirSync(teamDir()).filter(f => f.endsWith('.roster.json')).map(f => f.replace(/\.roster\.json$/, ''));
}
function resolveTeam(opts) {
  const t = opts.team || process.env.TEAM;
  if (t) return sanitizeName(t, 'team name');
  const all = listRosters();
  if (all.length === 1) return all[0];
  if (all.length === 0) die(`no team roster in ${teamDir()} — spawn a team first`);
  die(`several teams exist (${all.join(', ')}) — pass --team <name> or set TEAM`);
}
function readRoster(team) {
  const r = readJson(rosterPath(team), null);
  if (!r) die(`no roster for team '${team}' at ${rosterPath(team)} (spawn it first)`);
  return r;
}
function requireRole(roster, role) {
  if (!roster.roles[role]) die(`role '${role}' not in team '${roster.team}' (roles: ${roster.role_order.join(', ')})`);
  return roster.roles[role];
}
function readState(team, role) { return readJson(statePath(team, role), { role, turns: 0 }); }
function writeState(team, role, st) { writeJsonAtomic(statePath(team, role), st); }
function appendEvent(team, role, text) {
  appendText(eventsPath(team), `${nowIso()}\t${role}\t${oneLine(text, 400)}\n`);
}
function roleFile(role) { return role.startsWith('core') ? 'worker-core.md' : ROLE_FILES[role]; }

// ----------------------------------------------------------------------------
// inbox + runner lifecycle
// ----------------------------------------------------------------------------
let seq = 0;
function enqueue(team, role, from, text) {
  const dir = inboxDir(team, role);
  ensureDir(dir);
  const at = nowIso();
  const name = `${Date.now().toString().padStart(14, '0')}-${String(process.pid).padStart(7, '0')}-${String(seq++).padStart(4, '0')}.json`;
  writeJsonAtomic(path.join(dir, name), { from, at, text });
  appendEvent(team, from, `send → ${role}: ${text}`);
}
function pendingCount(team, role) {
  try { return fs.readdirSync(inboxDir(team, role)).filter(f => f.endsWith('.json')).length; } catch { return 0; }
}
function drainInbox(team, role) {
  const dir = inboxDir(team, role);
  let files = [];
  try { files = fs.readdirSync(dir).filter(f => f.endsWith('.json')).sort(); } catch { return []; }
  const msgs = [];
  for (const f of files) {
    const p = path.join(dir, f);
    const m = readJson(p, null);
    try { fs.unlinkSync(p); } catch { /* ignore */ }
    if (m && m.text) msgs.push(m);
  }
  return msgs;
}
function lockInfo(team, role) {
  const d = lockDir(team, role);
  if (!fs.existsSync(d)) return null;
  const pid = Number((readJson(path.join(d, 'pid.json'), {}) || {}).pid || 0);
  return { pid, alive: pidAlive(pid), since: (readJson(path.join(d, 'pid.json'), {}) || {}).since };
}
function acquireLock(team, role) {
  const d = lockDir(team, role);
  ensureDir(path.dirname(d));
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      fs.mkdirSync(d);
      writeJsonAtomic(path.join(d, 'pid.json'), { pid: process.pid, since: nowIso() });
      return true;
    } catch (e) {
      if (e.code !== 'EEXIST') throw e;
      const info = lockInfo(team, role);
      if (info && info.alive) return false;
      try { fs.rmSync(d, { recursive: true, force: true }); } catch { /* retry */ }
    }
  }
  return false;
}
function releaseLock(team, role) { try { fs.rmSync(lockDir(team, role), { recursive: true, force: true }); } catch { /* ignore */ } }

function ensureRunner(team, role) {
  const info = lockInfo(team, role);
  if (info && info.alive) return 'running';
  ensureDir(path.join(runDir(team), 'logs'));
  const fd = fs.openSync(runnerLogPath(team, role), 'a');
  const env = Object.assign({}, process.env, { AGENT_TEAM_REPO: repoRoot(), AGENT_TEAM_DIR: teamDirName() });
  const child = cp.spawn(process.execPath, [__filename, '_run', team, role], {
    cwd: repoRoot(), env, detached: true, stdio: ['ignore', fd, fd], windowsHide: true,
  });
  child.unref();
  fs.closeSync(fd);
  return `started runner pid ${child.pid}`;
}

// ----------------------------------------------------------------------------
// engine command construction
// ----------------------------------------------------------------------------
const STRIP_ENV = [
  'CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT', 'CLAUDE_CODE_SESSION_ID', 'CLAUDE_CODE_CHILD_SESSION',
  'CLAUDE_CODE_MESSAGING_SOCKET', 'CLAUDE_CODE_MESSAGING_TOKEN', 'CLAUDE_CODE_BRIDGE_SESSION_ID',
  'CLAUDE_PID', 'CLAUDE_EFFORT', 'CODEX_SANDBOX', 'CODEX_SANDBOX_NETWORK_DISABLED', 'CODEX_THREAD_ID',
];
function childEnv(team, role, spec) {
  const env = Object.assign({}, process.env);
  for (const k of STRIP_ENV) delete env[k];
  env.TEAM = team;
  env.AGENT_TEAM_ROLE = role;
  env.AGENT_TEAM_ENGINE = spec.engine;
  env.AGENT_TEAM_DIR = teamDirName();
  env.AGENT_TEAM_REPO = repoRoot();
  // let claude workers block on wait-for longer than the default 2-minute Bash limit
  if (!env.BASH_DEFAULT_TIMEOUT_MS) env.BASH_DEFAULT_TIMEOUT_MS = '600000';
  if (!env.BASH_MAX_TIMEOUT_MS) env.BASH_MAX_TIMEOUT_MS = '1800000';
  return env;
}
function buildCommand(team, role, spec, st) {
  const engine = spec.engine;
  const exe = resolveExe(engine);
  if (!exe) throw new Error(`${engine} CLI not found on PATH`);
  const args = [];
  if (engine === 'claude') {
    args.push('-p', '--model', spec.model);
    if (spec.effort) args.push('--effort', spec.effort);
    args.push('--dangerously-skip-permissions', '--output-format', 'stream-json', '--verbose');
    args.push('--append-system-prompt-file', `${rolesRef()}/${roleFile(role)}`);
    if (st.session_started) args.push('--resume', st.session_id);
    else args.push('--session-id', st.session_id);
  } else if (engine === 'codex') {
    const base = ['--json', '--skip-git-repo-check', '--dangerously-bypass-approvals-and-sandbox'];
    if (spec.model) base.push('-m', spec.model);
    if (spec.effort) base.push('-c', `model_reasoning_effort=${spec.effort}`);
    base.push('-o', `${teamDirName()}/runs/${team}/state/${role}.last.txt`);
    if (st.session_id) args.push('exec', 'resume', ...base, st.session_id, '-');
    else args.push('exec', ...base, '-');
  } else {
    throw new Error(`unknown engine '${engine}'`);
  }
  return { exe, args };
}

// ----------------------------------------------------------------------------
// transcript rendering (stream-json / codex JSONL → readable log)
// ----------------------------------------------------------------------------
function toolSummary(name, input) {
  if (!input || typeof input !== 'object') return '';
  if (input.command) return oneLine(input.command, 300);
  if (input.file_path) return oneLine(input.file_path, 200);
  if (input.pattern) return oneLine(`${input.pattern} ${input.path || ''}`, 200);
  if (input.query) return oneLine(input.query, 200);
  if (input.description) return oneLine(input.description, 200);
  return oneLine(JSON.stringify(input), 200);
}
function contentText(c) {
  if (typeof c === 'string') return c;
  if (Array.isArray(c)) return c.map(x => (x && x.type === 'text' ? x.text : '')).join(' ');
  return '';
}
function renderClaude(ev, ctx) {
  switch (ev.type) {
    case 'system':
      if (ev.subtype === 'init') { ctx.session_id = ev.session_id; return `⚙ session ${ev.session_id} · model ${ev.model || ''}`; }
      return null;
    case 'assistant': {
      const out = [];
      for (const c of (ev.message && ev.message.content) || []) {
        if (c.type === 'text' && c.text) { ctx.texts.push(c.text); out.push(c.text); }
        else if (c.type === 'tool_use') out.push(`▶ ${c.name} ${toolSummary(c.name, c.input)}`);
      }
      return out.length ? out.join('\n') : null;
    }
    case 'user': {
      const out = [];
      for (const c of (ev.message && ev.message.content) || []) {
        if (c.type === 'tool_result') out.push(`  ↳ ${c.is_error ? '✗ ' : ''}${oneLine(contentText(c.content), 300)}`);
      }
      return out.length ? out.join('\n') : null;
    }
    case 'result': {
      ctx.result = ev;
      if (ev.is_error) ctx.error = oneLine(ev.result || (ev.errors || []).join('; ') || 'unknown error', 400);
      if (typeof ev.result === 'string' && ev.result && !ctx.texts.includes(ev.result)) ctx.texts.push(ev.result);
      const cost = ev.total_cost_usd != null ? ` · $${Number(ev.total_cost_usd).toFixed(3)}` : '';
      return `■ turn finished · ${ev.num_turns || '?'} steps · ${Math.round((ev.duration_ms || 0) / 1000)}s${cost}${ev.is_error ? ' · ✗ ERROR' : ''}`;
    }
    default: return null;
  }
}
function renderCodex(ev, ctx) {
  const item = ev.item || {};
  switch (ev.type) {
    case 'thread.started': ctx.session_id = ev.thread_id; return `⚙ thread ${ev.thread_id}`;
    case 'item.started':
      if (item.type === 'command_execution') return `▶ $ ${oneLine(item.command, 300)}`;
      return null;
    case 'item.completed':
      switch (item.type) {
        case 'agent_message': if (item.text) { ctx.texts.push(item.text); return item.text; } return null;
        case 'command_execution': return `  ↳ exit ${item.exit_code}: ${oneLine(item.aggregated_output, 300)}`;
        case 'file_change': return `✎ ${(item.changes || []).map(c => `${c.kind || ''} ${c.path || ''}`.trim()).join(', ')}`;
        case 'mcp_tool_call': return `▶ mcp ${item.server || ''}.${item.tool || ''}`;
        case 'web_search': return `▶ web_search ${oneLine(item.query, 200)}`;
        case 'error': ctx.error = oneLine(item.message, 400); return `✗ ${oneLine(item.message, 400)}`;
        default: return null;
      }
    case 'turn.completed': {
      const u = ev.usage || {};
      return `■ turn finished · in ${u.input_tokens || 0} · out ${u.output_tokens || 0}`;
    }
    case 'turn.failed': ctx.error = oneLine((ev.error && ev.error.message) || 'turn failed', 400); return `✗ turn failed: ${ctx.error}`;
    case 'error': ctx.error = oneLine(ev.message, 400); return `✗ error: ${ctx.error}`;
    default: return null;
  }
}
function lastTeamStatus(texts) {
  let last = null;
  for (const t of texts) for (const line of String(t).split('\n')) if (/^\s*TEAM-STATUS:/.test(line)) last = line.trim();
  return last;
}

// ----------------------------------------------------------------------------
// the runner: one process per (team, role) while there is work
// ----------------------------------------------------------------------------
function renderPrompt(msgs) {
  const body = msgs.map(m => `[from ${m.from} @ ${hhmmss(m.at)}]\n${m.text}`).join('\n\n');
  return msgs.length > 1 ? `You have ${msgs.length} new messages.\n\n${body}` : body;
}
function runTurn(team, role, msgs) {
  return new Promise(resolve => {
    const roster = readRoster(team);
    const spec = roster.roles[role];
    const st = readState(team, role);
    const turn = (st.turns || 0) + 1;
    const startedAt = Date.now();
    const log = logPath(team, role);
    const prompt = renderPrompt(msgs);
    appendText(log, `\n━━━━━━━━━━ TURN ${turn} · ${role} · ${nowIso()} ━━━━━━━━━━\n📨 ${prompt}\n──────────\n`);
    appendEvent(team, role, `turn ${turn} start (${msgs.length} msg)`);

    let cmd;
    try { cmd = buildCommand(team, role, spec, st); }
    catch (e) {
      appendText(log, `✗ cannot start engine: ${e.message}\n`);
      Object.assign(st, { last_error: e.message, last_turn_ended: nowIso() });
      writeState(team, role, st);
      return resolve();
    }
    const ctx = { texts: [], error: null, session_id: null, result: null };
    const child = spawnExe(cmd.exe, cmd.args, { cwd: repoRoot(), env: childEnv(team, role, spec), stdio: ['pipe', 'pipe', 'pipe'] });
    Object.assign(st, { engine: spec.engine, model: spec.model, effort: spec.effort, running_since: nowIso(), runner_pid: process.pid, child_pid: child.pid, last_error: null, turns: turn });
    writeState(team, role, st);

    const render = spec.engine === 'claude' ? renderClaude : renderCodex;
    const rawTail = [];
    const rlOut = readline.createInterface({ input: child.stdout });
    rlOut.on('line', line => {
      if (!line.trim()) return;
      let ev = null;
      try { ev = JSON.parse(line); } catch { /* not JSON */ }
      if (!ev) { rawTail.push(line); appendText(log, `${oneLine(line, 400)}\n`); return; }
      if (ev.session_id && !ctx.session_id) ctx.session_id = ev.session_id;
      const text = render(ev, ctx);
      if (text) appendText(log, `${text}\n`);
    });
    const rlErr = readline.createInterface({ input: child.stderr });
    rlErr.on('line', line => { if (line.trim()) { rawTail.push(line); appendText(log, `! ${oneLine(line, 400)}\n`); } });
    child.stdin.on('error', () => { /* engine exited early; the close handler reports it */ });
    child.stdin.end(prompt);

    const timer = setTimeout(() => {
      appendText(log, `✗ turn exceeded ${TURN_TIMEOUT_MIN} min — killing engine process\n`);
      ctx.error = ctx.error || `turn timeout after ${TURN_TIMEOUT_MIN} min`;
      killTree(child.pid);
    }, TURN_TIMEOUT_MIN * 60 * 1000);

    child.on('error', e => { ctx.error = `spawn failed: ${e.message}`; });
    child.on('close', code => {
      clearTimeout(timer);
      const secs = Math.round((Date.now() - startedAt) / 1000);
      const fresh = readState(team, role); // reboot may have replaced it mid-turn
      if (fresh.session_id !== st.session_id && spec.engine === 'claude') Object.assign(st, { session_id: fresh.session_id, session_started: fresh.session_started });
      if (ctx.session_id) { st.session_id = ctx.session_id; st.session_started = true; }
      const status = lastTeamStatus(ctx.texts);
      if (status) { st.last_status = status; st.last_status_at = nowIso(); }
      const errText = ctx.error || (code !== 0 ? `engine exited with code ${code}: ${oneLine(rawTail.slice(-3).join(' | '), 300)}` : null);
      const lost = /No conversation found|conversation.*not found|session.*not found|thread.*not found|no rollout|Unknown session/i
        .test([errText || '', ...rawTail].join(' '));
      Object.assign(st, { running_since: null, child_pid: null, last_turn_ended: nowIso(), last_turn_secs: secs, last_exit: code, last_error: errText });
      writeState(team, role, st);
      appendText(log, `━━ end turn ${turn} · exit ${code} · ${secs}s${errText ? ` · ✗ ${errText}` : ''} ━━\n`);
      appendEvent(team, role, `turn ${turn} end exit=${code} ${status || ''}${errText ? ` ERROR: ${errText}` : ''}`);
      if (lost && st.session_started && !(st.reboots > 2)) {
        appendText(log, `↻ session appears lost — starting a fresh session and redelivering the messages\n`);
        resetSession(team, role, spec, st);
        st.reboots = (st.reboots || 0) + 1;
        writeState(team, role, st);
        const notice = `[REBOOT NOTICE] Your previous session was lost. Re-read ${rolesRef()}/PROTOCOL.md${spec.engine === 'codex' ? ` and ${rolesRef()}/${roleFile(role)}` : ''}, ${teamDirName()}/memory/INDEX.md + PROJECT.md, ${teamDirName()}/SPEC.md and ${teamDirName()}/DECISIONS.md, then continue with the messages below.`;
        enqueue(team, role, 'system', notice);
        for (const m of msgs) enqueue(team, role, m.from, m.text);
      }
      resolve();
    });
  });
}
function resetSession(team, role, spec, st) {
  st.session_id = spec.engine === 'claude' ? crypto.randomUUID() : null;
  st.session_started = false;
}
async function cmdRun(argv) {
  const [team, role] = argv._;
  if (!team || !role) die('usage: _run <team> <role>');
  if (!acquireLock(team, role)) return; // another runner owns this role
  process.on('SIGTERM', () => { releaseLock(team, role); process.exit(0); });
  try {
    for (;;) {
      const msgs = drainInbox(team, role);
      if (!msgs.length) break;
      await runTurn(team, role, msgs);
    }
  } catch (e) {
    appendText(logPath(team, role), `✗ runner crashed: ${e.stack || e.message}\n`);
  } finally {
    releaseLock(team, role);
  }
  // a message may have landed between the last drain and the lock release
  if (pendingCount(team, role) > 0) return cmdRun(argv);
}

// ----------------------------------------------------------------------------
// spawn
// ----------------------------------------------------------------------------
const INDEX_TEMPLATE = `# Team Memory — Index

Rules (token discipline):
- ONE line here per memory file: \`- [title](path) — one-line hook of what's inside (date)\`.
- Read this INDEX + PROJECT.md first; then open ONLY files whose hook matches your current task. Never bulk-read this folder.
- Newest sessions on top. Keep hooks specific ("fixed stale-closure bug in useNotes") — vague hooks force wasteful reads.

## Project
- [PROJECT.md](PROJECT.md) — current big picture: what this is, stack, architecture, conventions, state

## Sessions (newest first)
`;
const PROJECT_TEMPLATE = `# Project Memory

> The current-state map of this project — what a new agent must know to act correctly.
> The LEAD updates it at mission end. Keep it SHORT: a map, not an encyclopedia.
> History lives in sessions/; live decision one-liners in ../DECISIONS.md; this file is NOW.

## What this project is
(one paragraph — fill during the first mission)

## Stack & commands
(languages, frameworks, and the exact build/test/lint commands)

## Architecture & key modules
(main folders/modules, what owns what, load-bearing interfaces)

## Conventions
(naming, patterns, and rules the team must respect)

## Current state & evolution
(what works today, what changed recently, known debt, where it's heading)
`;

function bootPrompt(team, role, engine) {
  const td = teamDirName();
  const memory = `${td}/memory/INDEX.md + PROJECT.md (project memory — then open ONLY the memory files relevant to the mission, token discipline)`;
  if (role === 'lead') {
    const leadReads = engine === 'codex' ? `${rolesRef()}/lead.md (your role instructions), then ${rolesRef()}/PROTOCOL.md` : `${rolesRef()}/PROTOCOL.md`;
    return `You are the LEAD of team ${team}. Env TEAM=${team}. First: read ${leadReads}, then ${memory}, then ${td}/SPEC.md, then ${td}/${team}.roster.json. Then print your TEAM-STATUS line as ready. If a MISSION message is included in this same delivery, begin your operating loop right away; otherwise END YOUR TURN — the mission arrives as your next message. Never start work before the mission arrives.`;
  }
  let reads = `${rolesRef()}/PROTOCOL.md, then ${memory}, then ${td}/SPEC.md`;
  if (engine === 'codex') reads = `${rolesRef()}/${roleFile(role)} (your role instructions), then ${reads}`;
  return `You are worker ${role} on team ${team}. Env TEAM=${team}. First: read ${reads}, then print your TEAM-STATUS line as ready and END YOUR TURN. TASK messages from your lead arrive as new messages — do not start work before tasking.`;
}

function sandboxGuard() {
  if (process.env.CODEX_SANDBOX_NETWORK_DISABLED === '1' || process.env.CODEX_SANDBOX === 'seatbelt') {
    die('running inside a Codex sandbox with network disabled — agents cannot reach the API from here. Re-run this command with escalated permissions (outside the sandbox), or start codex with --sandbox danger-full-access / --dangerously-bypass-approvals-and-sandbox.');
  }
}
function scaffoldMemory() {
  const mem = path.join(teamDir(), 'memory');
  ensureDir(path.join(mem, 'sessions'));
  // Carry over memory written by the cmux-team plugin on another machine, if present.
  const legacy = path.join(repoRoot(), '.cmux-team', 'memory');
  if (!fs.existsSync(path.join(mem, 'INDEX.md')) && fs.existsSync(path.join(legacy, 'INDEX.md')) && teamDirName() !== '.cmux-team') {
    fs.cpSync(legacy, mem, { recursive: true, force: false, errorOnExist: false });
    say(`Imported existing project memory from .cmux-team/memory/ → ${teamDirName()}/memory/`);
  }
  if (!fs.existsSync(path.join(mem, 'INDEX.md'))) fs.writeFileSync(path.join(mem, 'INDEX.md'), INDEX_TEMPLATE);
  if (!fs.existsSync(path.join(mem, 'PROJECT.md'))) fs.writeFileSync(path.join(mem, 'PROJECT.md'), PROJECT_TEMPLATE);
}
function copyRolesAndSelf() {
  const skillRoles = path.join(__dirname, '..', 'roles');
  const dest = path.join(teamDir(), 'roles');
  ensureDir(dest);
  let src = fs.existsSync(skillRoles) ? skillRoles : null;
  if (!src && fs.existsSync(path.join(__dirname, 'roles'))) src = path.join(__dirname, 'roles');
  if (src && path.resolve(src) !== path.resolve(dest)) {
    for (const f of fs.readdirSync(src)) if (f.endsWith('.md')) fs.copyFileSync(path.join(src, f), path.join(dest, f));
  }
  for (const f of ['PROTOCOL.md', 'lead.md', 'worker-core.md', 'worker-ui.md', 'worker-qa.md']) {
    if (!fs.existsSync(path.join(dest, f))) die(`role file missing: ${path.join(dest, f)} (skill install incomplete?)`);
  }
  const selfDest = path.join(teamDir(), 'team.js');
  if (path.resolve(__filename) !== path.resolve(selfDest)) fs.copyFileSync(__filename, selfDest);
}
function ensureGitNexus() {
  const gx = resolveExe('gitnexus');
  if (!gx) { warn('gitnexus CLI not found (npm i -g gitnexus) — agents boot without code-graph intelligence.'); return; }
  const run = (args, opts) => (gx.shell
    ? cp.spawnSync([winQuote(gx.file), ...args].join(' '), Object.assign({ shell: true, windowsHide: true, cwd: repoRoot() }, opts))
    : cp.spawnSync(gx.file, args, Object.assign({ windowsHide: true, cwd: repoRoot() }, opts)));
  const status = run(['status'], { encoding: 'utf8' });
  if (/up-to-date/.test((status.stdout || '') + (status.stderr || ''))) return;
  const meta = readJson(path.join(repoRoot(), '.gitnexus', 'meta.json'), {});
  const args = ['analyze'];
  if (meta.stats && Number(meta.stats.embeddings) > 0) args.push('--embeddings'); // plain analyze deletes embeddings
  say(`GitNexus index missing/stale — running 'gitnexus ${args.join(' ')}' (first run on a big repo can take a while)...`);
  const r = run(args, { stdio: 'inherit' });
  if (r.status !== 0) warn('gitnexus analyze failed — team boots without the code graph.');
}

function cmdSpawn(opts) {
  const team = sanitizeName(opts._[0], 'team name');
  if (RESERVED_TEAM_NAMES.has(team)) die(`'${team}' is a reserved name — pick another team name`);
  const cores = Number(opts.cores || 1);
  if (!Number.isInteger(cores) || cores < 1 || cores > MAX_CORES) die(`--cores must be 1-${MAX_CORES}`);
  const mission = opts['no-mission'] ? '' : opts._.slice(1).join(' ').trim();

  const roles = ['lead', 'core'];
  for (let i = 2; i <= cores; i++) roles.push(`core${i}`);
  roles.push('ui', 'qa');
  const DEFAULT_MODEL = { claude: 'sonnet', codex: '' }; // codex '' = the model in ~/.codex/config.toml
  let defEngine = opts.engine || '';
  if (defEngine && !['claude', 'codex'].includes(defEngine)) die(`--engine must be claude or codex (got '${defEngine}')`);
  if (!defEngine) {
    if (resolveExe('claude')) defEngine = 'claude';
    else if (resolveExe('codex')) { defEngine = 'codex'; say('claude CLI not found — defaulting every role to codex (--engine codex).'); }
    else die(`no agent engine on PATH — run: node ${path.relative(process.cwd(), __filename) || 'team.js'} setup --engines codex (or claude)`);
  }
  const specs = {};
  for (const r of roles) specs[r] = { engine: defEngine, model: DEFAULT_MODEL[defEngine], effort: '' };
  for (const ov of opts.agent) {
    const m = /^([A-Za-z0-9_-]+)=([a-z]+):([A-Za-z0-9._:-]+?)(?::([a-z]+))?$/.exec(ov);
    if (!m) die(`bad --agent spec '${ov}' (want role=engine:model[:effort])`);
    const [, role, engine, model, effort] = m;
    if (!roles.includes(role)) die(`--agent role '${role}' not in this team (roles: ${roles.join(', ')})`);
    if (!['claude', 'codex'].includes(engine)) die(`unknown engine '${engine}' in '${ov}' (supported: claude, codex)`);
    specs[role] = { engine, model, effort: effort || '' };
  }

  // --- preflight ---
  const td = teamDir();
  if (!fs.existsSync(path.join(td, 'SPEC.md'))) die(`${path.join(td, 'SPEC.md')} not found. Write the mission spec (with an objective Definition of Done) before spawning — agents boot by reading it.`);
  sandboxGuard();
  for (const eng of new Set(Object.values(specs).map(s => s.engine))) {
    if (!resolveExe(eng)) die(`engine '${eng}' requested but the '${eng}' CLI is not on PATH`);
  }
  for (const r of roles) { const li = lockInfo(team, r); if (li && li.alive) die(`team '${team}' still has a running agent (${r}, pid ${li.pid}). Tear it down first: node ${teamDirName()}/team.js teardown ${team}`); }
  if (fs.existsSync(runDir(team))) {
    const dest = path.join(td, 'archive', `${team}-${Date.now()}-stale`);
    ensureDir(path.dirname(dest));
    renameRetry(runDir(team), dest);
    if (fs.existsSync(rosterPath(team))) renameRetry(rosterPath(team), path.join(dest, `${team}.roster.json`));
    say(`Previous run of '${team}' archived to ${path.relative(repoRoot(), dest)}`);
  }

  ensureDir(td);
  for (const sub of ['logs', 'state', 'inbox', 'locks', 'signals']) ensureDir(path.join(runDir(team), sub));
  if (!fs.existsSync(path.join(td, 'DECISIONS.md'))) fs.writeFileSync(path.join(td, 'DECISIONS.md'), '');
  scaffoldMemory();
  copyRolesAndSelf();
  ensureGitNexus();

  const roster = {
    team, repo: repoRoot(), team_dir: teamDirName(), created_by: `agent-team skill v${VERSION}`, created_at: nowIso(),
    host: os.hostname(), platform: process.platform, role_order: roles, roles: {},
  };
  for (const r of roles) {
    const st = { role: r, engine: specs[r].engine, model: specs[r].model, effort: specs[r].effort, turns: 0, session_started: false };
    resetSession(team, r, specs[r], st);
    writeState(team, r, st);
    roster.roles[r] = Object.assign({}, specs[r], {
      session_id: st.session_id, log: path.relative(repoRoot(), logPath(team, r)).split(path.sep).join('/'),
    });
  }
  writeJsonAtomic(rosterPath(team), roster);
  appendEvent(team, 'orchestrator', `spawn team ${team}: ${roles.join(', ')}`);

  for (const r of roles) enqueue(team, r, 'system', bootPrompt(team, r, specs[r].engine));
  if (mission) enqueue(team, 'lead', 'orchestrator', `MISSION: ${mission} | Full spec: ${teamDirName()}/SPEC.md | Roster: ${teamDirName()}/${team}.roster.json | Begin your operating loop now.`);
  for (const r of roles) ensureRunner(team, r);

  say('');
  say(`Team '${team}' spawned (project: ${repoRoot()}).`);
  say(`${'ROLE'.padEnd(7)} ${'ENGINE/MODEL'.padEnd(28)} SESSION`);
  for (const r of roles) {
    const s = specs[r];
    say(`${r.padEnd(7)} ${`${s.engine}:${s.model || 'default'}${s.effort ? ':' + s.effort : ''}`.padEnd(28)} ${roster.roles[r].session_id || '(codex assigns on first turn)'}`);
  }
  if (specs.lead.engine === 'codex') say('NOTE: the lead runs codex — it reads roles/lead.md at boot (codex has no system-prompt flag); confirm with `screen lead` that it did.');
  say(`Roster:  ${path.relative(repoRoot(), rosterPath(team))}`);
  say(`Status:  node ${teamDirName()}/team.js status --team ${team}`);
  say(`Watch:   node ${teamDirName()}/team.js watch --team ${team}      (or: open — one terminal tab per agent)`);
  say(mission ? `Mission queued for the lead (delivered right after its boot reads).` : `No mission given — send it with: node ${teamDirName()}/team.js send lead "MISSION: ..."`);
  say(`NOTE: agents run FULL-AUTONOMY (claude --dangerously-skip-permissions / codex --dangerously-bypass-approvals-and-sandbox) inside ${repoRoot()}.`);
}

// ----------------------------------------------------------------------------
// messaging & observation verbs
// ----------------------------------------------------------------------------
function cmdSend(opts) {
  const team = resolveTeam(opts);
  const roster = readRoster(team);
  const role = opts._[0];
  if (!role) die('usage: send <role> <message...> | send <role> --file <path>');
  requireRole(roster, role);
  let text = opts._.slice(1).join(' ');
  if (opts.file) text = fs.readFileSync(opts.file, 'utf8');
  text = String(text || '').trim();
  if (!text) die('refusing to send an empty message');
  sandboxGuard();
  const from = opts.from || process.env.AGENT_TEAM_ROLE || 'orchestrator';
  enqueue(team, role, from, text);
  const r = ensureRunner(team, role);
  say(`Sent to ${role} (${r}): ${oneLine(text, 160)}`);
}
function runnerState(team, role) {
  const st = readState(team, role);
  const li = lockInfo(team, role);
  const pending = pendingCount(team, role);
  if (li && li.alive && st.running_since) return `RUNNING ${Math.round((Date.now() - Date.parse(st.running_since)) / 1000)}s`;
  if (li && li.alive) return 'starting';
  if (pending) return `QUEUED ${pending} (no runner!)`;
  if (st.last_error) return 'ERROR';
  return st.turns ? 'idle' : 'not booted';
}
function cmdStatus(opts) {
  const team = resolveTeam(opts);
  const roster = readRoster(team);
  if (opts.json) {
    const out = {};
    for (const r of roster.role_order) out[r] = Object.assign({ runner: runnerState(team, r), pending: pendingCount(team, r) }, readState(team, r));
    say(JSON.stringify(out, null, 2));
    return;
  }
  say(`team ${team} · ${roster.repo}`);
  for (const r of roster.role_order) {
    const st = readState(team, r);
    const s = roster.roles[r];
    const eng = `${s.engine}:${s.model || 'default'}${s.effort ? ':' + s.effort : ''}`;
    say(`${r.padEnd(7)} ${eng.padEnd(26)} ${runnerState(team, r).padEnd(22)} turns=${String(st.turns || 0).padEnd(3)} ${st.last_status || '—'}`);
    if (st.last_error) say(`${''.padEnd(7)} ✗ ${oneLine(st.last_error, 200)}`);
  }
  let sigs = [];
  try { sigs = fs.readdirSync(signalsDir(team)); } catch { /* none */ }
  if (sigs.length) say(`signals pending: ${sigs.join(', ')}`);
  const ev = tailLines(eventsPath(team), 3);
  if (ev.length) say(`last events:\n  ${ev.map(l => oneLine(l, 160)).join('\n  ')}`);
}
function cmdScreen(opts) {
  const team = resolveTeam(opts);
  const roster = readRoster(team);
  const role = opts._[0];
  if (!role) die('usage: screen <role> [--lines N] [--all]');
  requireRole(roster, role);
  const n = opts.all ? 0 : Number(opts.lines || 60);
  const lines = tailLines(logPath(team, role), n);
  say(lines.length ? lines.join('\n') : `(no output yet from ${role})`);
}
function cmdSignal(opts) {
  const team = resolveTeam(opts);
  const name = sanitizeName(opts._[0], 'signal name');
  const p = path.join(signalsDir(team), name);
  if (opts.clear) { try { fs.unlinkSync(p); } catch { /* none */ } say(`cleared signal ${name}`); return; }
  ensureDir(signalsDir(team));
  fs.writeFileSync(p, `${nowIso()} ${process.env.AGENT_TEAM_ROLE || 'orchestrator'}\n`);
  appendEvent(team, process.env.AGENT_TEAM_ROLE || 'orchestrator', `signal ${name}`);
  say(`signal ${name} set`);
}
async function cmdWaitFor(opts) {
  const team = resolveTeam(opts);
  const name = sanitizeName(opts._[0], 'signal name');
  const timeout = Number(opts.timeout || DEFAULT_WAIT_TIMEOUT);
  const p = path.join(signalsDir(team), name);
  const until = Date.now() + timeout * 1000;
  for (;;) {
    if (fs.existsSync(p)) {
      const who = oneLine(fs.readFileSync(p, 'utf8'), 80);
      try { fs.unlinkSync(p); } catch { /* ignore */ }
      say(`signal ${name} received (${who})`);
      return;
    }
    if (Date.now() >= until) { say(`timeout: no signal ${name} within ${timeout}s`); process.exit(1); }
    await new Promise(r => setTimeout(r, 1000));
  }
}
function cmdNotify(opts) {
  const team = resolveTeam(opts);
  const text = opts._.join(' ');
  if (!text) die('usage: notify <text>');
  appendEvent(team, process.env.AGENT_TEAM_ROLE || 'orchestrator', `NOTIFY ${text}`);
  appendText(path.join(runDir(team), 'NOTIFICATIONS.log'), `${nowIso()}\t${process.env.AGENT_TEAM_ROLE || 'orchestrator'}\t${oneLine(text, 400)}\n`);
  if (process.platform === 'darwin') {
    try { cp.spawnSync('osascript', ['-e', `display notification ${JSON.stringify(text)} with title ${JSON.stringify(`team ${team}`)}`], { stdio: 'ignore', timeout: 5000 }); } catch { /* best effort */ }
  }
  say(`notify: ${text}`);
}
function cmdLog(opts) {
  const team = resolveTeam(opts);
  const text = opts._.join(' ');
  if (!text) die('usage: log <text> [--level info|warn|error]');
  appendEvent(team, process.env.AGENT_TEAM_ROLE || 'orchestrator', `[${opts.level || 'info'}] ${text}`);
}
function cmdProgress(opts) {
  const team = resolveTeam(opts);
  const v = Number(opts._[0]);
  if (!(v >= 0 && v <= 1)) die('usage: progress <0..1> [--label text]');
  const role = process.env.AGENT_TEAM_ROLE || 'orchestrator';
  appendEvent(team, role, `progress ${Math.round(v * 100)}%${opts.label ? ` ${opts.label}` : ''}`);
  if (role !== 'orchestrator') { const st = readState(team, role); st.progress = v; st.progress_label = opts.label || ''; writeState(team, role, st); }
}
function cmdWhoami() {
  const role = process.env.AGENT_TEAM_ROLE;
  if (!role) { say(JSON.stringify({ role: 'orchestrator', team: process.env.TEAM || null, note: 'no AGENT_TEAM_ROLE in env — you are outside the team' })); return; }
  say(JSON.stringify({ role, team: process.env.TEAM, engine: process.env.AGENT_TEAM_ENGINE || null, team_dir: teamDirName() }));
}
function cmdRoster(opts) {
  const team = resolveTeam(opts);
  say(fs.readFileSync(rosterPath(team), 'utf8'));
}

// follow logs live (human view; replaces watching the cmux panes)
async function cmdWatch(opts) {
  const team = resolveTeam(opts);
  const roster = readRoster(team);
  const roles = opts._[0] ? [requireRole(roster, opts._[0]) && opts._[0]] : roster.role_order;
  const multi = roles.length > 1;
  const pos = {};
  for (const r of roles) {
    const p = logPath(team, r);
    const tail = tailLines(p, multi ? 15 : 40);
    for (const l of tail) say(multi ? `[${r}] ${l}` : l);
    pos[r] = fs.existsSync(p) ? fs.statSync(p).size : 0;
  }
  say(`── following ${roles.join(', ')} (Ctrl+C to stop) ──`);
  for (;;) {
    for (const r of roles) {
      const p = logPath(team, r);
      if (!fs.existsSync(p)) continue;
      const size = fs.statSync(p).size;
      if (size < pos[r]) pos[r] = 0;
      if (size > pos[r]) {
        const fd = fs.openSync(p, 'r');
        const buf = Buffer.alloc(size - pos[r]);
        fs.readSync(fd, buf, 0, buf.length, pos[r]);
        fs.closeSync(fd);
        pos[r] = size;
        for (const l of buf.toString('utf8').split('\n')) if (l !== '') say(multi ? `[${r}] ${l}` : l);
      }
    }
    await new Promise(res => setTimeout(res, 700));
  }
}
function cmdOpen(opts) {
  const team = resolveTeam(opts);
  const roster = readRoster(team);
  const teamJs = path.join(teamDirName(), 'team.js');
  const repo = repoRoot();
  if (IS_WIN) {
    const wt = resolveExe('wt');
    if (wt) {
      const parts = [];
      roster.role_order.forEach((r, i) => {
        parts.push(`${i ? ';' : ''} new-tab --title "${r}" -d "${repo}" cmd /k "chcp 65001>nul && node ${teamJs} watch ${r} --team ${team}"`);
      });
      cp.spawn(`wt -w agent-team-${team} ${parts.join(' ')}`, { shell: true, detached: true, stdio: 'ignore', windowsHide: true }).unref();
      say(`Opened Windows Terminal window 'agent-team-${team}' with one tab per agent.`);
    } else {
      for (const r of roster.role_order) {
        cp.spawn(`start "${r}" cmd /k "chcp 65001>nul && node ${teamJs} watch ${r} --team ${team}"`, { shell: true, cwd: repo, detached: true, stdio: 'ignore' }).unref();
      }
      say('Opened one console window per agent (install Windows Terminal for tabs).');
    }
    return;
  }
  if (process.platform === 'darwin') {
    for (const r of roster.role_order) {
      const script = `tell application "Terminal" to do script "cd ${repo.replace(/"/g, '\\"')} && node ${teamJs} watch ${r} --team ${team}"`;
      cp.spawnSync('osascript', ['-e', script], { stdio: 'ignore' });
    }
    say('Opened one Terminal.app window per agent.');
    return;
  }
  if (resolveExe('tmux')) {
    const s = `agent-team-${team}`;
    cp.spawnSync('tmux', ['new-session', '-d', '-s', s, '-c', repo, `node ${teamJs} watch lead --team ${team}`], { stdio: 'ignore' });
    for (const r of roster.role_order.slice(1)) cp.spawnSync('tmux', ['split-window', '-t', s, '-c', repo, `node ${teamJs} watch ${r} --team ${team}`], { stdio: 'ignore' });
    cp.spawnSync('tmux', ['select-layout', '-t', s, 'tiled'], { stdio: 'ignore' });
    say(`tmux session '${s}' created — attach with: tmux attach -t ${s}`);
    return;
  }
  say('Open one terminal per agent and run:');
  for (const r of roster.role_order) say(`  node ${teamJs} watch ${r} --team ${team}`);
}

// ----------------------------------------------------------------------------
// lifecycle: stop / reboot / teardown
// ----------------------------------------------------------------------------
function stopRole(team, role) {
  const st = readState(team, role);
  const li = lockInfo(team, role);
  let n = 0;
  if (st.child_pid && pidAlive(st.child_pid)) { killTree(st.child_pid); n++; }
  if (li && li.alive) { killTree(li.pid); n++; }
  releaseLock(team, role);
  if (n) { st.running_since = null; st.child_pid = null; writeState(team, role, st); }
  return n;
}
function cmdStop(opts) {
  const team = sanitizeName(opts._[0] || resolveTeam(opts), 'team name');
  const roster = readRoster(team);
  const roles = opts._[1] ? [opts._[1]] : roster.role_order;
  for (const r of roles) { requireRole(roster, r); say(`${r}: stopped ${stopRole(team, r)} process(es)`); }
  appendEvent(team, 'orchestrator', `stop ${roles.join(', ')}`);
}
function cmdReboot(opts) {
  const team = resolveTeam(opts);
  const roster = readRoster(team);
  const role = opts._[0];
  if (!role) die('usage: reboot <role> [--team T]');
  const spec = requireRole(roster, role);
  stopRole(team, role);
  const st = readState(team, role);
  resetSession(team, role, spec, st);
  st.reboots = (st.reboots || 0) + 1;
  st.last_error = null;
  writeState(team, role, st);
  roster.roles[role].session_id = st.session_id;
  writeJsonAtomic(rosterPath(team), roster);
  appendText(logPath(team, role), `\n↻ REBOOT requested by ${process.env.AGENT_TEAM_ROLE || 'orchestrator'} at ${nowIso()} — new session\n`);
  enqueue(team, role, 'system', `[REBOOT NOTICE] You were restarted in a fresh session. ${bootPrompt(team, role, spec.engine)} Also read ${teamDirName()}/DECISIONS.md and, if you are a worker, continue your last TASK (the lead will re-send it if needed).`);
  say(`${role}: ${ensureRunner(team, role)} (fresh session ${st.session_id || 'assigned by codex'})`);
}
function cmdTeardown(opts) {
  const team = sanitizeName(opts._[0], 'team name');
  const roster = readRoster(team);
  for (const r of roster.role_order) { const n = stopRole(team, r); if (n) say(`${r}: stopped ${n} process(es)`); }
  const sessions = path.join(teamDir(), 'memory', 'sessions');
  let has = false;
  try { has = fs.readdirSync(sessions).some(f => f.endsWith(`-${team}.md`)); } catch { /* none */ }
  if (!has) {
    warn(`no session summary in memory/sessions/ for team '${team}'.`);
    warn(`Project memory loses this mission — write ${teamDirName()}/memory/sessions/${new Date().toISOString().slice(0, 10)}-${team}.md (+ INDEX line) before moving on.`);
  }
  const archive = path.join(teamDir(), 'archive', `${team}-${Math.floor(Date.now() / 1000)}`);
  ensureDir(archive);
  if (fs.existsSync(runDir(team))) renameRetry(runDir(team), path.join(archive, 'runs'));
  for (const f of fs.readdirSync(teamDir())) {
    if (f.startsWith(`${team}.`) && f !== 'SPEC.md' && f !== 'DECISIONS.md') renameRetry(path.join(teamDir(), f), path.join(archive, f));
  }
  say(`Archived team '${team}' artifacts to ${path.relative(repoRoot(), archive)} (SPEC.md, DECISIONS.md, memory/ preserved).`);
}

// ----------------------------------------------------------------------------
// doctor (replaces setup.sh — nothing to install, everything to verify)
// ----------------------------------------------------------------------------
function installHint(what) {
  const H = {
    node: { win32: 'winget install -e --id OpenJS.NodeJS.LTS  (no admin? run install.ps1 — portable install)', darwin: 'brew install node  (or https://nodejs.org)', linux: 'run install.sh (portable) or https://nodejs.org' },
    git: { win32: 'winget install -e --id Git.Git', darwin: 'xcode-select --install  (or brew install git)', linux: 'sudo apt-get install -y git' },
    claude: { all: 'npm install -g @anthropic-ai/claude-code  then run `claude` once in your own terminal to log in' },
    codex: { all: 'npm install -g @openai/codex  then `codex login`' },
    gitnexus: { all: 'npm install -g gitnexus' },
    wt: { win32: 'winget install -e --id Microsoft.WindowsTerminal' },
  };
  const h = H[what] || {};
  return h[process.platform] || h.all || '';
}
function runExeSync(exe, args, opts) {
  if (exe.shell) return cp.spawnSync([winQuote(exe.file), ...args.map(winQuote)].join(' '), Object.assign({ shell: true, windowsHide: true }, opts));
  return cp.spawnSync(exe.file, args, Object.assign({ windowsHide: true }, opts));
}
function refreshWindowsPath() {
  if (!IS_WIN) return;
  const r = cp.spawnSync('powershell', ['-NoProfile', '-Command', "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"], { encoding: 'utf8', windowsHide: true });
  if (r.status === 0 && (r.stdout || '').trim()) process.env.PATH = `${r.stdout.trim()};${process.env.PATH}`;
}
function addToUserPathWindows(dir) {
  const ps = `$u=[Environment]::GetEnvironmentVariable('Path','User'); if (($u -split ';') -notcontains '${dir.replace(/'/g, "''")}') { [Environment]::SetEnvironmentVariable('Path', ($u.TrimEnd(';') + ';${dir.replace(/'/g, "''")}'), 'User') }`;
  const r = cp.spawnSync('powershell', ['-NoProfile', '-Command', ps], { encoding: 'utf8', windowsHide: true });
  return r.status === 0;
}
function cmdDoctor() {
  let fails = 0;
  const ok = m => say(`  OK    ${m}`);
  const wr = m => say(`  WARN  ${m}`);
  const ko = m => { fails++; say(`  FAIL  ${m}`); };
  say(`agent-team doctor v${VERSION} · ${process.platform} ${os.release()} · node ${process.version}`);
  const major = Number(process.version.slice(1).split('.')[0]);
  major >= 18 ? ok(`node ${process.version}`) : ko(`node ${process.version} is too old — ${installHint('node')}`);
  const claude = resolveExe('claude');
  claude ? ok(`claude CLI: ${claude.file} (${exeVersion(claude)})`) : wr(`claude CLI not on PATH — needed for claude roles → ${installHint('claude')}`);
  const codex = resolveExe('codex');
  codex ? ok(`codex CLI: ${codex.file} (${exeVersion(codex)})`) : wr(`codex CLI not on PATH — needed for codex roles → ${installHint('codex')}`);
  if (!claude && !codex) ko('no agent engine installed — run: node team.js setup --engines codex   (or --engines claude, or both)');
  else if (!claude) say('  NOTE  only codex is available → spawn with --engine codex (all-codex team, lead included)');
  const gx = resolveExe('gitnexus');
  gx ? ok(`gitnexus CLI: ${gx.file}`) : wr(`gitnexus CLI not found — optional, agents lose code-graph impact analysis → ${installHint('gitnexus')}`);
  const git = resolveExe('git');
  if (!git) ko(`git not on PATH → ${installHint('git')}  (or: node team.js setup)`);
  else {
    const r = cp.spawnSync(git.file, ['status', '--porcelain'], { cwd: repoRoot(), encoding: 'utf8', windowsHide: true });
    if (r.status !== 0) wr(`${repoRoot()} is not a git repository — team state and memory should live in git (git init)`);
    else if ((r.stdout || '').trim()) wr('git working tree is not clean — the protocol expects a clean tree (and a fresh branch) before spawn');
    else ok('git repository, clean working tree');
  }
  if (process.env.CODEX_SANDBOX_NETWORK_DISABLED === '1') ko('running inside a Codex sandbox with network disabled — run team commands with escalated permissions');
  else ok('no restrictive sandbox detected in this shell');
  if (IS_WIN) resolveExe('wt') ? ok('Windows Terminal found (open → one tab per agent)') : wr(`Windows Terminal (wt.exe) not found — \`open\` falls back to plain console windows → ${installHint('wt')}`);
  const spec = path.join(teamDir(), 'SPEC.md');
  fs.existsSync(spec) ? ok(`${teamDirName()}/SPEC.md present`) : wr(`${teamDirName()}/SPEC.md not written yet (Phase 1 — required before spawn)`);
  say(fails ? `\n${fails} problem(s) — fix them (node team.js setup installs what it can) before spawning a team.` : '\nAll good. Next: write SPEC.md, then spawn.');
  if (fails) process.exit(1);
}

// ----------------------------------------------------------------------------
// setup — install everything after Node (git, engine CLIs, gitnexus, Windows Terminal)
// ----------------------------------------------------------------------------
function cmdSetup(opts) {
  if (process.env.CODEX_SANDBOX_NETWORK_DISABLED === '1') die('setup needs network — run it with escalated permissions (outside the Codex sandbox)');
  const engines = String(opts.engines || 'codex,claude').split(',').map(x => x.trim()).filter(Boolean);
  for (const e of engines) if (!['claude', 'codex'].includes(e)) die(`--engines accepts claude and/or codex (got '${e}')`);
  const manual = [];
  const logins = [];
  const did = [];
  say(`agent-team setup v${VERSION} · ${process.platform} · node ${process.version}`);
  refreshWindowsPath();

  const winget = IS_WIN ? resolveExe('winget') : null;
  const brew = process.platform === 'darwin' ? resolveExe('brew') : null;
  const pkg = (label, exeName, wingetId, brewName, linuxCmd) => {
    if (resolveExe(exeName)) { say(`  OK    ${label} already installed`); return; }
    say(`  ..    installing ${label}`);
    let r = null;
    if (IS_WIN && winget) r = runExeSync(winget, ['install', '-e', '--id', wingetId, '--silent', '--accept-source-agreements', '--accept-package-agreements'], { stdio: 'inherit' });
    else if (brew && brewName) r = runExeSync(brew, ['install', brewName], { stdio: 'inherit' });
    refreshWindowsPath();
    if (resolveExe(exeName)) { did.push(label); say(`  OK    ${label} installed`); }
    else manual.push(`${label}: ${IS_WIN ? installHint(exeName) : process.platform === 'darwin' ? installHint(exeName) : (linuxCmd || installHint(exeName))}${r && r.status ? ` (installer exit ${r.status})` : ''}`);
  };
  pkg('Git', 'git', 'Git.Git', 'git', 'sudo apt-get install -y git');

  const npm = resolveExe('npm');
  if (!npm) manual.push('npm not found next to node — reinstall Node.js (https://nodejs.org)');
  const npmi = (label, exeName, pkgName) => {
    if (resolveExe(exeName)) { say(`  OK    ${label} already installed`); return 'present'; }
    if (!npm) { manual.push(`${label}: npm install -g ${pkgName}`); return false; }
    say(`  ..    npm install -g ${pkgName}`);
    const r = runExeSync(npm, ['install', '-g', pkgName], { stdio: 'inherit' });
    refreshWindowsPath();
    if (r.status === 0 && resolveExe(exeName)) { did.push(label); say(`  OK    ${label} installed`); return true; }
    if (r.status === 0) { did.push(label); say(`  OK    ${label} installed (not on PATH yet — see below)`); return true; }
    manual.push(`${label}: npm install -g ${pkgName} (exit ${r.status})`);
    return false;
  };
  if (engines.includes('codex')) { if (npmi('Codex CLI', 'codex', '@openai/codex') === true) logins.push('codex: run `codex login` (skip if this Codex session is already logged in)'); }
  if (engines.includes('claude')) { if (npmi('Claude Code', 'claude', '@anthropic-ai/claude-code') === true) logins.push('claude: open a NEW terminal, run `claude` once and complete the login (browser); then `claude --version` must print a version'); }
  if (!opts['no-gitnexus']) npmi('GitNexus (code graph)', 'gitnexus', 'gitnexus');
  if (IS_WIN && !opts['no-wt']) pkg('Windows Terminal', 'wt', 'Microsoft.WindowsTerminal', null, null);

  // make sure npm's global bin dir is on PATH (portable Node installs miss it)
  if (npm) {
    const r = runExeSync(npm, ['config', 'get', 'prefix'], { encoding: 'utf8' });
    const prefix = (r.stdout || '').trim();
    if (prefix) {
      const bin = IS_WIN ? prefix : path.join(prefix, 'bin');
      const onPath = (process.env.PATH || '').split(path.delimiter).some(d => path.resolve(d || '.') === path.resolve(bin));
      if (!onPath) {
        if (IS_WIN && addToUserPathWindows(bin)) { process.env.PATH = `${bin};${process.env.PATH}`; did.push('PATH'); say(`  OK    added npm global bin to your user PATH: ${bin} (new terminals pick it up)`); }
        else manual.push(`add npm's global bin dir to PATH: ${IS_WIN ? `setx PATH "%PATH%;${bin}"` : `echo 'export PATH="${bin}:$PATH"' >> ~/.profile`}`);
      }
    }
  }

  say('');
  if (did.length) say(`Installed/changed: ${did.join(', ')}`);
  if (manual.length) { say('Needs a manual step (no package manager / no admin rights):'); for (const m of manual) say(`  - ${m}`); }
  if (logins.length) { say('Logins (interactive — the human must do these):'); for (const l of logins) say(`  - ${l}`); }
  say('');
  if (!opts['no-doctor']) cmdDoctor();
}

// ----------------------------------------------------------------------------
// help / main
// ----------------------------------------------------------------------------
const HELP = `team.js v${VERSION} — headless agent-team bus (Windows/macOS/Linux)

usage: node team.js <command> [options]

  doctor                                   verify node / claude / codex / gitnexus / git (prints install hints)
  setup [--engines codex,claude] [--no-gitnexus] [--no-wt]
                                           install git, engine CLIs, gitnexus, Windows Terminal (winget/brew/npm); fix PATH
  spawn <team> [--engine claude|codex] [--cores N] [--agent role=engine:model[:effort]]... [mission words...]
                                           boot lead + core[,core2..] + ui + qa; queue the mission for the lead
                                           --engine sets every role's default (codex lead allowed → all-codex team)
  send <role> <message...> | --file <path> deliver a message (next turn of that agent's session)
  status [--json]                          runner state + last TEAM-STATUS per role
  screen <role> [--lines N] [--all]        tail of an agent's transcript
  wait-for <name> [--timeout S]            block until a signal is set (default ${DEFAULT_WAIT_TIMEOUT}s); consumes it
  signal <name> [--clear]                  set (or clear) a signal
  notify <text> · log <text> [--level L] · progress <0..1> [--label L]
  whoami · roster                          identity / team composition
  watch [role]                             follow transcript(s) live
  open                                     one terminal tab/window per agent (wt / Terminal.app / tmux)
  stop <team> [role]                       kill runner(s), keep state (resume later with send)
  reboot <role>                            fresh session for one role (after a lost session)
  teardown <team>                          stop everything, archive runs/ + roster (keeps SPEC, DECISIONS, memory)

  common options: --team <name> (or env TEAM; auto-detected when only one team exists)
  env: AGENT_TEAM_DIR (default .agent-team) · AGENT_TEAM_REPO (default cwd) · AGENT_TEAM_TURN_TIMEOUT_MIN (default ${TURN_TIMEOUT_MIN})
`;

async function main() {
  const argv = process.argv.slice(2);
  const cmd = argv[0];
  const opts = parseArgs(argv.slice(1));
  if (!cmd || cmd === '--help' || cmd === 'help' || opts.help) { say(HELP); return; }
  if (cmd === '--version' || cmd === 'version') { say(VERSION); return; }
  const table = {
    doctor: cmdDoctor, setup: cmdSetup, spawn: cmdSpawn, send: cmdSend, status: cmdStatus, screen: cmdScreen,
    'wait-for': cmdWaitFor, signal: cmdSignal, notify: cmdNotify, log: cmdLog, progress: cmdProgress,
    whoami: cmdWhoami, roster: cmdRoster, watch: cmdWatch, open: cmdOpen, stop: cmdStop, reboot: cmdReboot,
    teardown: cmdTeardown, _run: cmdRun,
  };
  if (!table[cmd]) die(`unknown command '${cmd}'\n${HELP}`);
  await table[cmd](opts);
}
main().catch(e => die(e.stack || e.message));
