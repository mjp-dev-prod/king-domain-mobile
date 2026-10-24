// Run: node --test tools/session-notify/
// Real script, real git repos in a temp folder, a fake Slack on localhost. Nothing reaches real Slack.
"use strict";
const { describe, it, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const http = require("node:http");
const { spawn, execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "notify.js");
const SECRET_URL = "https://hooks.slack.com/services/T000/B000/abcdefghijklmnopqrstuvwx";

let tmp, repoA, repoB, stateDir, slack, received, slackStatus;

const git = (repo, ...a) => execFileSync("git", ["-C", repo, "-c", "user.name=Victor", "-c", "user.email=v@example.com", ...a], { encoding: "utf8" }).trim();
function makeRepo(name) {
  const p = path.join(tmp, name);
  fs.mkdirSync(p);
  git(p, "init", "-q", "-b", "master");
  git(p, "config", "user.name", "Victor");
  fs.writeFileSync(path.join(p, "a.txt"), "1");
  git(p, "add", ".");
  git(p, "commit", "-q", "-m", "first");
  return p;
}
function commit(repo, subject) {
  fs.appendFileSync(path.join(repo, "a.txt"), "x");
  git(repo, "add", ".");
  git(repo, "commit", "-q", "-m", subject);
}

const baseEnv = () => ({
  ...process.env,
  KD_NOTIFY_REPOS: [repoA, repoB].join(path.delimiter),
  KD_NOTIFY_STATE_DIR: stateDir,
  KD_NOTIFY_LOG: path.join(stateDir, "updates.jsonl"),
  KD_NOTIFY_ALLOW_ANY_URL: "1",
  KD_SLACK_WEBHOOK_URL: `http://127.0.0.1:${slack.address().port}/hook`,
  HOME: tmp,
  USERPROFILE: tmp, // no real ~/.claude/kd-slack-webhook can leak into a test
});
// Async on purpose: the fake Slack lives in this process, so a blocking spawn would deadlock it.
const run = (args, { input = "", env = {} } = {}) =>
  new Promise((resolve) => {
    const child = spawn(process.execPath, [SCRIPT, ...args], { env: { ...baseEnv(), ...env }, stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "", stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    const timer = setTimeout(() => child.kill(), 20000);
    child.on("close", (status) => (clearTimeout(timer), resolve({ status, stdout, stderr })));
    child.stdin.end(input);
  });
const hook = (cmd, body, env) => run([cmd], { input: JSON.stringify(body), env });
const texts = (payload) => payload.blocks.flatMap((b) => (b.text ? [b.text.text] : b.elements ? b.elements.map((e) => e.text) : [])).join("\n");

before(async () => {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), "kd-notify-"));
  slack = http.createServer((req, res) => {
    let body = "";
    req.on("data", (d) => (body += d));
    req.on("end", () => {
      received.push(JSON.parse(body));
      res.writeHead(slackStatus).end(slackStatus === 200 ? "ok" : "invalid_payload");
    });
  });
  await new Promise((r) => slack.listen(0, "127.0.0.1", r));
});
after(() => {
  slack.close();
  fs.rmSync(tmp, { recursive: true, force: true });
});
beforeEach(() => {
  received = [];
  slackStatus = 200;
  stateDir = fs.mkdtempSync(path.join(tmp, "state-"));
  for (const r of [repoA, repoB]) if (r) fs.rmSync(r, { recursive: true, force: true });
  repoA = makeRepo("repo-a");
  repoB = makeRepo("repo-b");
});

describe("start", () => {
  it("records where every repo is and hands Claude the session id", async () => {
    const r = await hook("start", { session_id: "s1" });
    assert.equal(r.status, 0);
    const out = JSON.parse(r.stdout).hookSpecificOutput;
    assert.equal(out.hookEventName, "SessionStart");
    assert.match(out.additionalContext, /session's id is s1/);
    assert.match(out.additionalContext, /Slack is configured/);
    const state = JSON.parse(fs.readFileSync(path.join(stateDir, "s1.json"), "utf8"));
    assert.equal(state.repos.length, 2);
    assert.equal(state.repos[0].head, git(repoA, "rev-parse", "HEAD"));
    assert.equal(received.length, 0, "starting a session posts nothing");
  });

  it("keeps the first start when the same session starts again (resume, compaction)", async () => {
    await hook("start", { session_id: "s1" });
    const before = fs.readFileSync(path.join(stateDir, "s1.json"), "utf8");
    commit(repoA, "work");
    await hook("start", { session_id: "s1" });
    assert.equal(fs.readFileSync(path.join(stateDir, "s1.json"), "utf8"), before);
  });

  it("says plainly when Slack is not set up, and still exits 0", async () => {
    const r = await hook("start", { session_id: "s2" }, { KD_SLACK_WEBHOOK_URL: "" });
    assert.equal(r.status, 0);
    assert.match(JSON.parse(r.stdout).hookSpecificOutput.additionalContext, /NOT configured/);
  });

  it("survives garbage on stdin", async () => {
    const r = await run(["start"], { input: "not json" });
    assert.equal(r.status, 0);
    assert.equal(r.stdout, "");
  });
});

describe("post", () => {
  it("sends the written update with the commits made since the session began", async () => {
    await hook("start", { session_id: "s1" });
    commit(repoA, "Add the thing");
    commit(repoA, "Fix <b>bold</b> & more");
    const r = await run(["post", "--session", "s1"], { input: "*Photos are built.* Not deployed yet." });
    assert.equal(r.status, 0, r.stderr);
    assert.equal(received.length, 1);
    const t = texts(received[0]);
    assert.match(t, /Photos are built/);
    assert.match(t, /\*repo-a\* \(master\): 2 commits, no remote branch yet/);
    assert.match(t, /Add the thing/);
    assert.match(t, /Fix &lt;b&gt;bold&lt;\/b&gt; &amp; more/, "commit subjects are escaped, not read as markup");
    assert.doesNotMatch(t, /repo-b/, "a repo with no changes is not mentioned");
    assert.match(t, /From Victor's coding session/);
    assert.equal(received[0].blocks[0].type, "header");
  });

  it("marks the session as reported so the safety net stays quiet", async () => {
    await hook("start", { session_id: "s1" });
    commit(repoA, "work");
    await run(["post", "--session", "s1"], { input: "Update." });
    await hook("end", { session_id: "s1", reason: "other" });
    assert.equal(received.length, 1, "only the written update");
  });

  it("reports uncommitted work and unpushed commits honestly", async () => {
    await hook("start", { session_id: "s1" });
    commit(repoA, "work");
    fs.writeFileSync(path.join(repoB, "new.txt"), "wip");
    await run(["post", "--session", "s1"], { input: "Update." });
    const t = texts(received[0]);
    assert.match(t, /\*repo-b\* \(master\): 1 file changed, not committed/);
    assert.match(t, /repo-a\* \(master\): 1 commit, no remote branch yet/);
  });

  it("never sends a key, token, connection string or @channel", async () => {
    const leaks = [
      `see ${SECRET_URL}`,
      "postgresql://user:pw@host/db?sslmode=require",
      "sk_live_abcdef123456",
      "Bearer abc.def.ghi",
      "a".repeat(40),
      "<!channel> look",
    ].join("\n\n");
    await run(["post"], { input: leaks });
    const t = texts(received[0]);
    for (const bad of ["hooks.slack.com", "postgresql://", "sk_live_", "Bearer abc", "a".repeat(40), "<!channel>"]) assert.doesNotMatch(t, new RegExp(bad.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    assert.match(t, /\[redacted\]/);
    assert.match(t, /channel look/);
  });

  it("splits a long update across blocks inside Slack's limits", async () => {
    const long = Array.from({ length: 40 }, (_, i) => `Paragraph ${i} ` + "word ".repeat(120)).join("\n\n");
    await run(["post"], { input: long });
    const blocks = received[0].blocks;
    assert.ok(blocks.length > 3 && blocks.length <= 50);
    for (const b of blocks) if (b.text?.type === "mrkdwn") assert.ok(b.text.text.length <= 3000);
  });

  it("--dry-run prints the message and sends nothing", async () => {
    const r = await run(["post", "--dry-run"], { input: "Hello." });
    assert.equal(received.length, 0);
    assert.match(JSON.parse(r.stdout).blocks[1].text.text, /Hello\./);
  });

  it("fails loudly (exit 1) when Slack refuses, and does not mark the session reported", async () => {
    slackStatus = 400;
    await hook("start", { session_id: "s1" });
    const r = await run(["post", "--session", "s1"], { input: "Update." });
    assert.equal(r.status, 1);
    assert.match(r.stderr, /Slack answered 400/);
    assert.equal(JSON.parse(fs.readFileSync(path.join(stateDir, "s1.json"), "utf8")).summaryPostedAt, null);
  });

  it("fails loudly when there is no webhook, or when it is not a Slack address", async () => {
    for (const env of [{ KD_SLACK_WEBHOOK_URL: "" }, { KD_SLACK_WEBHOOK_URL: "https://evil.example.com/x", KD_NOTIFY_ALLOW_ANY_URL: "0" }]) {
      const r = await run(["post"], { input: "Update.", env });
      assert.equal(r.status, 1);
      assert.match(r.stderr, /no Slack webhook configured/);
    }
    assert.equal(received.length, 0);
  });

  it("refuses an empty update", async () => {
    const r = await run(["post"], { input: "  \n" });
    assert.equal(r.status, 1);
    assert.equal(received.length, 0);
  });
});

describe("the update log and digest", () => {
  it("keeps every posted update, and digest rebuilds the period from it plus the commits", async () => {
    await hook("start", { session_id: "s1" });
    commit(repoA, "Add photos");
    await run(["post", "--session", "s1", "--title", "Photos"], { input: "*Photos are built.* Not deployed." });
    const logged = fs.readFileSync(path.join(stateDir, "updates.jsonl"), "utf8").trim().split("\n").map((l) => JSON.parse(l));
    assert.equal(logged.length, 1);
    assert.equal(logged[0].title, "Photos");
    assert.match(logged[0].summary, /Photos are built/);
    const d = await run(["digest", "--days", "7"]);
    assert.equal(d.status, 0, d.stderr);
    assert.match(d.stdout, /## Updates sent/);
    assert.match(d.stdout, /Photos are built/);
    assert.match(d.stdout, /### repo-a/);
    assert.match(d.stdout, /Add photos/);
  });

  it("does not log an update Slack refused", async () => {
    slackStatus = 400;
    await run(["post"], { input: "Update." });
    assert.equal(fs.existsSync(path.join(stateDir, "updates.jsonl")), false);
  });

  it("says so when nothing was sent, and rejects a bad --days", async () => {
    const d = await run(["digest"]);
    assert.match(d.stdout, /None were sent in this period/);
    assert.equal((await run(["digest", "--days", "abc"])).status, 1);
  });
});

describe("end (the safety net)", () => {
  it("posts the commit facts when no written update went out", async () => {
    await hook("start", { session_id: "s1" });
    commit(repoB, "Build the feature");
    const r = await hook("end", { session_id: "s1", reason: "other" });
    assert.equal(r.status, 0);
    assert.equal(received.length, 1);
    const t = texts(received[0]);
    assert.match(t, /no written update was sent/);
    assert.match(t, /Build the feature/);
    assert.equal(received[0].blocks[0].text.text.startsWith("King Domain session ended"), true);
  });

  it("posts once, even if the hook fires twice", async () => {
    await hook("start", { session_id: "s1" });
    commit(repoB, "work");
    await hook("end", { session_id: "s1", reason: "other" });
    await hook("end", { session_id: "s1", reason: "other" });
    assert.equal(received.length, 1);
  });

  it("stays quiet when the only change is an uncommitted file, and leaves such repos out when there is real work", async () => {
    await hook("start", { session_id: "s1" });
    fs.writeFileSync(path.join(repoA, "wip.txt"), "unfinished");
    await hook("end", { session_id: "s1", reason: "other" });
    assert.equal(received.length, 0, "an edited file alone is not news");

    commit(repoB, "Real work");
    await hook("end", { session_id: "s1", reason: "other" });
    assert.equal(received.length, 1);
    const t = texts(received[0]);
    assert.match(t, /Real work/);
    assert.doesNotMatch(t, /repo-a/, "the repo with only an unfinished file is not mentioned");
  });

  it("stays quiet when nothing changed", async () => {
    await hook("start", { session_id: "s1" });
    await hook("end", { session_id: "s1", reason: "other" });
    assert.equal(received.length, 0);
  });

  it("stays quiet on /clear and resume, which are not the end of the work", async () => {
    await hook("start", { session_id: "s1" });
    commit(repoA, "work");
    await hook("end", { session_id: "s1", reason: "clear" });
    await hook("end", { session_id: "s1", reason: "resume" });
    assert.equal(received.length, 0);
  });

  it("stays quiet for a session it never saw start", async () => {
    commit(repoA, "work");
    await hook("end", { session_id: "unknown", reason: "other" });
    assert.equal(received.length, 0);
  });

  it("exits 0 when Slack is down or unconfigured, so a session can always close", async () => {
    await hook("start", { session_id: "s1" });
    commit(repoA, "work");
    assert.equal((await hook("end", { session_id: "s1", reason: "other" }, { KD_SLACK_WEBHOOK_URL: "http://127.0.0.1:1/hook" })).status, 0);
    assert.equal((await hook("end", { session_id: "s1", reason: "other" }, { KD_SLACK_WEBHOOK_URL: "" })).status, 0);
  });
});
