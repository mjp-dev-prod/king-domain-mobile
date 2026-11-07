# Polish pass: bugs and wording from Victor's phone walk-through

Status: **planned, due Tuesday 2026-11-10 at the latest.** Raised by Victor, 2026-11-07, from the KD Staging build.

## Bugs

| # | What Victor saw | What the code shows (checked 2026-11-07) | Fix |
|---|---|---|---|
| 1 | Signing out doesn't go home; he has to press Back to see onboarding. | Sign out now lives on the Settings page, which is a pushed screen. Clearing the sign-in swaps the screen underneath, but Settings stays on top. `logout()` in `auth_provider.dart` never pops it. | After sign-out, pop every pushed screen back to the root. Same for delete account. A test that signs out from Settings and expects onboarding with no Back. |
| 2 | Admins get no email when someone sends a skill for review. | Sending a submission (`user/submissionRoutes.js`, "authenticity") records it and raises **no alert at all**. Alerts exist (`alerts.js`: Slack plus email to whoever is on call, else the owners) but this queue never calls them. | Raise an alert when a submission is sent. Open question for Victor: urgent (at once) or digest (one message at 08:00 Lagos). Check on staging that mail actually leaves (Brevo key is set there). |

## Wording

The rule: say it the way a person would, and give the reason. No rule-book phrasing.

- "What you sent" and "Send only your own work" read robotic (`skills_hub_screen.dart:194`, `submission_screen.dart:388`).
- The "same files unchanged = 2 months, then 3" line is not understood (`submission_screen.dart:495`; source `submissions.js:26-27`, rule D9). Say it plainly: if a reviewer says "Not yet" and you send the same work again without fixing it, you are locked out of that skill for 2 months, then 3 months.
- Walk every screen for the same problem, not just these three.
- Add small info tips (icon, tap to explain) where a term needs a reason: start proof, change rounds, held payment, Proven, usage rights.

## Look

- Contrast: areas don't read as separate sections. Check surface steps against the brand table in `CLAUDE.md` (ground, surface 1, 2, 3); a card must be one step lighter than what it sits on. Also check text against its surface (AA).

## Not decided

- Whether the skill-review email is urgent or digest.
