---
name: session-update
description: Write and post the King Domain team update to Slack at the end of a working session. Use when Victor says to wrap up, end the session, send the update, or tell the team what we did, and before any session handoff.
---

# Session update

The readers are the **shareholders and future collaborators**: people who care about the product and
the company, not the code. Write for them, post it, and say what you posted.

How the plumbing works is in `docs/core/session-updates.md`. The SessionStart hook gave you this
session's id ("Team updates: this session's id is ..."). If you lost it, it is in
`~/.claude/kd-session/` (newest file).

## 1. Write the update

Save it as a file in the scratchpad (not in the repo), in **Slack formatting**: `*bold*` with one
asterisk, `•` bullets, no `#` headings, no tables, no code blocks. Around 120 to 200 words.

Cover, in this order:

- *Done:* what now works, in terms of what a person can do in the product. "Talents can add a profile
  photo", not "added PUT /users/me/photo".
- *Where it stands:* say exactly where each piece lives: on Victor's machine only, on staging (the
  test app), or live. "Built and tested, not deployed" is a complete and honest status. If tests
  were not run, or something failed, say that.
- *Needs a decision or help:* anything blocked on a person or on one of the open product decisions in
  the decision ledger. Name the decision and who it is waiting on. Do not settle one quietly.
- *Next:* one to three things.

The commit list is added under your text automatically (what changed, per repo, and whether it is
pushed), so do not repeat commit messages.

## 2. What must never go in

- Keys, tokens, passwords, connection strings, webhook URLs. (The script redacts what looks like
  one, but do not rely on that.)
- Bank, Paystack or CAC account details, filing numbers, access codes.
- Names, emails or anything else about real users or applicants.
- Anything presented as decided that is still open (pricing, payment provider, verification rules).
- Hype. If it is half-done, say half-done.

## 3. Post it

```
node tools/session-notify/notify.js post --session <session id> --file <path to your summary>
```

Add `--dry-run` to print the message without sending. If it prints an error, tell Victor the exact
error; do not retry in a loop. If Slack is not configured, say so and point at the setup steps in
`docs/core/session-updates.md`. Then paste the text you posted into your reply so Victor can see it.

A posted update cannot be recalled by a webhook, so read the text once more before sending.

If no update is sent, the SessionEnd hook posts the commit facts alone when the session closes.

A posted update is also saved to `~/.claude/kd-updates.jsonl`, so the history outlives Slack's free
90-day window.

## 4. Tell the Personal Manager

Victor's Telegram bot does not read Slack. Its weekly review ("Moved forward", Sunday 20:00 or `/review`)
and its daily wrap-up list **commitments marked done**, titles only, and at most 6 per week. So what
shipped has to be written there, or his week looks empty. Rules are in the hive:
`C:\mobile-projects\flutter\hive\projects\personal-manager.md` and `C:\projects\personal-manager\spec\AGENT_API.md`.
Never print or commit `.agent.json`.

```
node C:\projects\personal-manager\scripts\agent.ts <action> --agent "claude:king-domain-mobile" --notify false --why "<one line>" ...
```

1. `list --query "King Domain"` first. If the work finished an open commitment, `complete --id N --note "what shipped, and where it stands"`. If one is blocked or changed shape, `note --id N --text "..."`.
2. For a real milestone that was not a commitment, `add --title "..." --kind task --area "King Domain"` and then `complete --id <new id> --note "..."`. **One to three per session, milestone level, not per commit**: the review shows only 6 a week.
3. Titles are read cold on a phone, so they must stand alone and be honest about status: "Built profile photos (not deployed)", "Put job search on staging". Deploying later is its own item.
4. Do not add things that only you wanted done, and do not add future work: only Victor's own asks or dated items.
5. Finish with one `announce --text "<project>: marked N done, noted M. <what matters most>"` (3 to 400 characters).

## Weekly summary (for presenting)

When Victor asks for his week, run `node tools/session-notify/notify.js digest --days 7` (any number of
days). It prints the updates already sent plus the commits per repo, all branches. Write the summary from
that in plain terms, in the order he would present: what shipped, what is in progress, what is blocked or
needs a decision. State what is deployed and what is not. Do not post it to Slack unless he asks.
