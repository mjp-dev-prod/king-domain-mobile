# Session updates to Slack

At the end of a coding session, the team (shareholders and future collaborators) gets a plain-language
update in Slack: what got done, where it stands (on one machine, on staging, live), what needs a
decision, what is next, plus the commits made. Built 2026-10-22; **not yet connected to a real Slack**
until the webhook below is created.

## How it works

| Piece | Where | Job |
|---|---|---|
| `tools/session-notify/notify.js` | this repo | `start`, `post` and `end` commands (below) |
| Hooks | `.claude/settings.json` | SessionStart runs `start`; SessionEnd runs `end` |
| Skill `session-update` | `.claude/skills/session-update/` | tells Claude how to write the update and what must never be in it |
| Webhook URL | `~/.claude/kd-slack-webhook` or env `KD_SLACK_WEBHOOK_URL` | **a secret, never in git or chat** |

- **start** (hook): records the commit each sibling repo (mobile, backend, web, admin, admin-mcp) is at, and
  tells Claude the session id. Posts nothing.
- **post** (Claude, when Victor says to wrap up): sends the written update, with the commits since `start`
  listed underneath (per repo: how many, and pushed or not). Marks the session as reported.
- **end** (hook, safety net): if no written update went out and something changed, posts the commit facts
  alone, labelled as automatic. Stays quiet on `/clear`, on resume, and when nothing changed.

Hooks always exit 0 and never slow a session beyond a few seconds. With no webhook configured they do nothing.

## One wrap-up, three readers

| Reader | Gets | From |
|---|---|---|
| Shareholders, collaborators | the plain-language update | Slack `#updates` (live since 2026-10-22) |
| Victor's Personal Manager (Telegram) | done items, so `/review` and the daily wrap-up show what shipped | `agent.ts complete/add` at wrap-up. The bot does not read Slack; its review lists commitments marked done, titles only, max 6 a week |
| Victor, presenting | a week rebuilt from the saved updates and the commits | `node tools/session-notify/notify.js digest --days 7` |

Every posted update is also saved to `~/.claude/kd-updates.jsonl` (Slack's free plan hides history after 90 days).
The Personal Manager step is in the `session-update` skill; its API and rules are in
`C:\projects\personal-manager\spec\AGENT_API.md`.

## Channels (workspace "MJP Productions Limited")

The webhook is tied to one channel, `#updates`. The others are for people, until there is a reason to automate them
(each automation needs its own webhook).

| Channel | For |
|---|---|
| `#updates` | only the automatic end-of-session updates |
| `#decisions` | one post per open product decision, linking the ledger item; the decision itself lives in the ledger |
| `#meetings` | agenda before, notes and action items after |
| `#builds` | a new staging app version is ready |
| `#feedback` | bugs and reactions from testers, a thread per issue |

## One-time setup (Victor)

1. Create the Slack workspace (free plan is enough).
2. https://api.slack.com/apps → Create New App → From scratch → pick the workspace.
3. Incoming Webhooks → switch on → **Add New Webhook to Workspace** → pick the updates channel
   (for a private channel, be in it first). Copy the URL.
4. Save the URL as the only line of `C:\Users\USER\.claude\kd-slack-webhook` (outside every repo).
5. Reload hooks once (`/hooks` in Claude Code, or restart it) so the project hooks are picked up.
6. Check without posting: ask Claude for a session update with `--dry-run`, then post a real one.

Slack revokes webhook URLs it finds in public repos. If the URL ever leaks, delete it in the app settings
and create a new one.

## For a new collaborator

They get the same repo (hooks and skill included), create their own channel membership, and save the
webhook URL Victor gives them in the same file. Posts then say "From <their git user.name>'s coding session".

## Safeguards

- Only `https://hooks.slack.com/...` is ever posted to.
- Anything that looks like a key, token, connection string or Slack webhook is replaced with `[redacted]`
  before sending, and `@channel`/`@here` are defused. This is a net, not a policy: the skill forbids
  secrets, bank/CAC details and user data in the text itself.
- Commit subjects are escaped so they cannot be read as Slack markup.

## Free Slack limits that matter (checked 2026-10-22)

90 days of searchable history, anything older than a year deleted, 10 app integrations, huddles 1-to-1 only.
So: decisions belong in the decision ledger and the docs, not only in Slack; use Google Meet for group
meetings (Google Calendar is one of the 10 apps and can post meeting reminders).

## Limits of this

- SessionEnd may not fire when an IDE panel is simply closed. The written update (`post`) is the reliable
  path; `end` is only a backup.
- `/clear` starts a new session id, so work before a `/clear` is not in the next update's commit list.
- A webhook cannot delete or edit a message once posted.

## Tests

`node --test tools/session-notify/notify.test.js` (22 tests: real script and git repos, fake Slack on
localhost). Covers: start state, post content and escaping, redaction, block limits, dry-run, Slack
refusing, unset or non-Slack webhook, the update log and digest, and the safety net's quiet cases.
The Personal Manager step is a written procedure for Claude, not code, so it has no test.
