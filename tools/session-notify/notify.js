#!/usr/bin/env node
// Session updates for the King Domain team (shareholders, collaborators), posted to Slack.
//
//   start   SessionStart hook. Remembers where each repo was when the session began and tells Claude
//           its session id, so a written update can be tied to this session.
//   post    Posts a written update (plain language, from Claude) plus the commits made since start.
//   end     SessionEnd hook. A safety net: if no written update went out, posts the commit facts alone.
//
// Behaviour is documented in docs/core/session-updates.md. Hooks never fail a session: every hook path
// exits 0, and with no webhook configured they do nothing at all.
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const { execFileSync } = require("node:child_process");

const WORKSPACE = path.resolve(__dirname, "..", "..", "..");
const REPO_NAMES = ["king-domain-mobile", "king-domain-backend", "king-domain-web", "king-domain-admin", "king-domain-admin-mcp"];
const WEBHOOK_PREFIX = "https://hooks.slack.com/";
const MAX_COMMITS_PER_REPO = 12;
const SECTION_LIMIT = 2800; // Slack allows 3000 characters in one section block
const MAX_BLOCKS = 45; // Slack allows 50

const claudeDir = () => path.join(os.homedir(), ".claude");
const stateDir = () => process.env.KD_NOTIFY_STATE_DIR || path.join(claudeDir(), "kd-session");
const repoPaths = () =>
  (process.env.KD_NOTIFY_REPOS ? process.env.KD_NOTIFY_REPOS.split(path.delimiter) : REPO_NAMES.map((n) => path.join(WORKSPACE, n))).filter(
    (p) => fs.existsSync(path.join(p, ".git")),
  );

// ---------- git ----------

function git(repo, ...args) {
  try {
    return execFileSync("git", ["-C", repo, ...args], { encoding: "utf8", timeout: 4000, stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return null;
  }
}

function snapshot() {
  return repoPaths().map((p) => ({ path: p, name: path.basename(p), head: git(p, "rev-parse", "HEAD") }));
}

/** What changed in each repo since the session began. Repos with nothing to say are left out. */
function changesSince(started) {
  const out = [];
  for (const r of started) {
    const branch = git(r.path, "rev-parse", "--abbrev-ref", "HEAD") || "?";
    const range = r.head ? `${r.head}..HEAD` : null;
    const log = range ? git(r.path, "log", range, `--max-count=${MAX_COMMITS_PER_REPO + 1}`, "--format=%h%x09%s") : null;
    const commits = log ? log.split("\n").filter(Boolean).map((l) => l.split("\t")) : [];
    const notPushed = git(r.path, "rev-list", "--count", "@{u}..HEAD"); // null when the branch has no upstream
    const dirty = (git(r.path, "status", "--porcelain") || "").split("\n").filter(Boolean).length;
    if (!commits.length && !dirty) continue;
    out.push({ name: r.name, branch, commits: commits.slice(0, MAX_COMMITS_PER_REPO), more: commits.length > MAX_COMMITS_PER_REPO, notPushed, dirty });
  }
  return out;
}

// ---------- text safety ----------

const SECRET_PATTERNS = [
  /https:\/\/hooks\.slack\.com\/\S+/g,
  /postgres(?:ql)?:\/\/\S+/gi,
  /\b[sp]k_(?:live|test)_[A-Za-z0-9]+/g,
  /\beyJ[\w-]+\.[\w-]+\.[\w-]+/g,
  /\bBearer\s+\S+/gi,
  /\b[A-Za-z0-9]{32,}\b/g,
];

/** Nothing that looks like a key, token or connection string leaves the machine, and no one gets @-pinged. */
function clean(text) {
  let t = String(text ?? "");
  for (const re of SECRET_PATTERNS) t = t.replace(re, "[redacted]");
  return t.replace(/<!(channel|here|everyone)>/gi, "$1").replace(/<!subteam[^>]*>/gi, "a group");
}

/** Slack reads & < > as markup; commit subjects are data, not formatting. */
const escapeMrkdwn = (t) => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// ---------- message ----------

function factsLines(changes) {
  const lines = [];
  for (const c of changes) {
    const where = c.notPushed === null ? "no remote branch yet" : c.notPushed === "0" ? "pushed" : `${c.notPushed} not pushed`;
    const n = c.commits.length + (c.more ? "+" : "");
    const parts = [];
    if (c.commits.length) parts.push(`${n} commit${c.commits.length === 1 && !c.more ? "" : "s"}, ${where}`);
    if (c.dirty) parts.push(`${c.dirty} file${c.dirty === 1 ? "" : "s"} changed, not committed`);
    lines.push(`*${c.name}* (${escapeMrkdwn(clean(c.branch))}): ${parts.join("; ")}`);
    for (const [sha, subject] of c.commits) lines.push(`    \`${sha}\` ${escapeMrkdwn(clean(subject))}`);
    if (c.more) lines.push("    …and more");
  }
  return lines;
}

function chunk(text, limit) {
  const out = [];
  let cur = "";
  for (const para of text.split(/\n{2,}/)) {
    if (para.length > limit) {
      if (cur) out.push(cur), (cur = "");
      for (let i = 0; i < para.length; i += limit) out.push(para.slice(i, i + limit));
    } else if ((cur + "\n\n" + para).length > limit) {
      out.push(cur);
      cur = para;
    } else cur = cur ? cur + "\n\n" + para : para;
  }
  if (cur) out.push(cur);
  return out;
}

function author() {
  const repo = repoPaths()[0];
  return (repo && git(repo, "config", "user.name")) || null;
}

function buildPayload({ title, summary, changes, auto }) {
  const date = new Date().toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
  const heading = `${title} · ${date}`;
  const blocks = [{ type: "header", text: { type: "plain_text", text: heading.slice(0, 150) } }];
  if (summary) for (const part of chunk(clean(summary).trim(), SECTION_LIMIT)) blocks.push({ type: "section", text: { type: "mrkdwn", text: part } });
  const lines = factsLines(changes);
  if (lines.length) {
    blocks.push({ type: "divider" });
    const label = auto ? "*What changed* (from git; no written update was sent for this session)" : "*In the code*";
    for (const part of chunk([label, ...lines].join("\n"), SECTION_LIMIT)) blocks.push({ type: "section", text: { type: "mrkdwn", text: part } });
  }
  const who = author();
  blocks.push({ type: "context", elements: [{ type: "mrkdwn", text: who ? `From ${escapeMrkdwn(clean(who))}'s coding session` : "From a coding session" }] });
  if (blocks.length > MAX_BLOCKS) blocks.length = MAX_BLOCKS;
  return { text: heading, blocks };
}

// ---------- Slack ----------

function webhookUrl() {
  let url = process.env.KD_SLACK_WEBHOOK_URL;
  if (!url) {
    try {
      url = fs.readFileSync(path.join(claudeDir(), "kd-slack-webhook"), "utf8").split(/\r?\n/).find((l) => l.trim());
    } catch {}
  }
  url = url?.trim();
  if (!url) return null;
  // The URL is a secret and a target: only ever post to Slack (the override exists for the tests).
  if (!url.startsWith(WEBHOOK_PREFIX) && process.env.KD_NOTIFY_ALLOW_ANY_URL !== "1") return null;
  return url;
}

async function send(payload) {
  const url = webhookUrl();
  if (!url) return { ok: false, error: "no Slack webhook configured (see docs/core/session-updates.md)" };
  try {
    const res = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload), signal: AbortSignal.timeout(8000) });
    if (!res.ok) return { ok: false, error: `Slack answered ${res.status}: ${(await res.text()).slice(0, 200)}` };
    return { ok: true };
  } catch (e) {
    return { ok: false, error: `could not reach Slack: ${e.message}` };
  }
}

// ---------- session state ----------

const safeId = (id) => (/^[\w-]{1,80}$/.test(String(id)) ? String(id) : crypto.createHash("sha1").update(String(id)).digest("hex"));
const stateFile = (id) => path.join(stateDir(), `${safeId(id)}.json`);

function loadState(id) {
  try {
    return JSON.parse(fs.readFileSync(stateFile(id), "utf8"));
  } catch {
    return null;
  }
}
function saveState(id, state) {
  fs.mkdirSync(stateDir(), { recursive: true });
  fs.writeFileSync(stateFile(id), JSON.stringify(state, null, 2));
}
function pruneOldState() {
  try {
    for (const f of fs.readdirSync(stateDir())) {
      const p = path.join(stateDir(), f);
      if (Date.now() - fs.statSync(p).mtimeMs > 30 * 86400000) fs.rmSync(p);
    }
  } catch {}
}

// ---------- commands ----------

const readStdin = () => {
  try {
    return fs.readFileSync(0, "utf8");
  } catch {
    return "";
  }
};
const hookInput = () => {
  try {
    return JSON.parse(readStdin() || "{}");
  } catch {
    return {};
  }
};
const arg = (name) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : undefined;
};

function cmdStart() {
  const input = hookInput();
  const id = input.session_id;
  if (!id) return;
  pruneOldState();
  if (!loadState(id)) saveState(id, { sessionId: id, startedAt: new Date().toISOString(), repos: snapshot(), summaryPostedAt: null });
  const configured = webhookUrl() !== null;
  const context =
    `Team updates: this session's id is ${id}. When Victor wraps up (or asks for the team update), follow the session-update skill and post with ` +
    `\`node tools/session-notify/notify.js post --session ${id} --file <summary.md>\`. ` +
    (configured ? "Slack is configured." : "Slack is NOT configured yet: no webhook in KD_SLACK_WEBHOOK_URL or ~/.claude/kd-slack-webhook, so nothing will post.");
  process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: context } }));
}

async function cmdPost() {
  const id = arg("session");
  const file = arg("file");
  const summary = file ? fs.readFileSync(file, "utf8") : readStdin();
  if (!summary.trim()) return fail("the update is empty; nothing to post");
  const state = id ? loadState(id) : null;
  const changes = state ? changesSince(state.repos) : [];
  const payload = buildPayload({ title: arg("title") || "King Domain update", summary, changes, auto: false });
  if (process.argv.includes("--dry-run")) return void process.stdout.write(JSON.stringify(payload, null, 2) + "\n");
  const res = await send(payload);
  if (!res.ok) return fail(res.error);
  if (state) saveState(id, { ...state, summaryPostedAt: new Date().toISOString() });
  process.stdout.write("Posted to Slack.\n");
}

async function cmdEnd() {
  const input = hookInput();
  const id = input.session_id;
  if (!id || ["clear", "resume"].includes(input.reason)) return; // not the end of the work
  const state = loadState(id);
  if (!state || state.summaryPostedAt || state.endPostedAt) return;
  const changes = changesSince(state.repos);
  if (!changes.length) return;
  const res = await send(buildPayload({ title: "King Domain session ended", summary: "", changes, auto: true }));
  if (res.ok) saveState(id, { ...state, endPostedAt: new Date().toISOString() });
}

function fail(message) {
  process.stderr.write(`session-notify: ${message}\n`);
  process.exitCode = 1;
}

async function main() {
  const cmd = process.argv[2];
  if (cmd === "post") return cmdPost();
  // Hooks must never break or slow a session: swallow everything and exit 0.
  try {
    if (cmd === "start") cmdStart();
    else if (cmd === "end") await cmdEnd();
    else fail("usage: notify.js start|post|end");
  } catch {}
  if (cmd === "start" || cmd === "end") process.exitCode = 0;
}

if (require.main === module) main();
module.exports = { clean, escapeMrkdwn, buildPayload, chunk, changesSince, webhookUrl };
