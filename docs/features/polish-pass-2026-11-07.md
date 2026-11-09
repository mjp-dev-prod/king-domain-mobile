# Polish pass: bugs and wording from Victor's phone walk-through

Status: **built 2026-11-09 (earlier than the Tuesday due date), awaiting Victor's phone check.** Raised by Victor, 2026-11-07, from the KD Staging build. What was done, and what is still open, is at the bottom.

## Bugs

| # | What Victor saw | What the code shows (checked 2026-11-07) | Fix |
|---|---|---|---|
| 1 | Signing out doesn't go home; he has to press Back to see onboarding. | Sign out now lives on the Settings page, which is a pushed screen. Clearing the sign-in swaps the screen underneath, but Settings stays on top. `logout()` in `auth_provider.dart` never pops it. | After sign-out, pop every pushed screen back to the root. Same for delete account. A test that signs out from Settings and expects onboarding with no Back. |
| 2 | Admins get no email when someone sends a skill for review. | Sending a submission (`user/submissionRoutes.js`, "authenticity") records it and raises **no alert at all**. Alerts exist (`alerts.js`: Slack plus email to whoever is on call, else the owners) but this queue never calls them. | Raise an alert when a submission is sent. Open question for Victor: urgent (at once) or digest (one message at 08:00 Lagos). Check on staging that mail actually leaves (Brevo key is set there). |

| 3 | The "verified" badge on his own profile opens a strange three-step screen that looks like the old flow. Verified skills shouldn't just pile up under the profile. | The Profile tab (`shell/profile_tabs.dart`) draws a pill for every **category** the talent picked at sign-up, and turns it green "verified" from the **old proof-of-work flow** (`isVerifiedIn`, backed by `ProofItem`). The "Finish your profile, 1 of 3" card and the Proof of work section open `ProfileOverviewScreen` and `ProofUploadScreen`: the old flow, from before skill verification existed. The backend still honours old proof as a fallback (`jobsRoutes.js:275`, `discovery.js:34`), so the two systems run side by side. | Show a green badge only for a **skill** the person was verified in through the new flow (a verified skill submission), with the skill's name, never a sign-up category. Tapping it opens that skill (what was sent, its history), not the old stepper. Not-yet-verified skills show as "Get verified", not as a plain pill. Replace the three-step "Finish your profile" card with the real next step (verify a skill, add payout). |

| 4 | Both reviewers verified the demo talent and he got no notification until he refreshed. | **The backend never sends a push for a skill result.** When the second reviewer decides (`admin/skillReviewRoutes.js:266`) it sends an email only (`sendSkillVerified` / `sendSkillNotYet`). The push outbox (`pushDispatcher.js`) reads only job events (`ContractEvent`), so nothing skill-related can ever reach it. Authenticity pass and "Not yet" at that step send nothing either. **The push format is right:** every push is an FCM *notification* message with a data payload and high priority on a named channel, so Android shows it by itself when the app is closed or in the background, with no Dart code waking (there is no background handler, and none is needed for this kind). **The app has two gaps:** while the app is open Android shows nothing, so the push is a toast (`app_shell.dart:70`), and `_openFromPush` only understands job pushes (it needs a `jobId`), so a skill push would open nothing and refresh nothing; and the app does not refetch skills when it returns to the foreground, which is why he needed to refresh. | Send a push at three moments: first check passed (it's now with reviewers), Verified, Not yet (`discovery.notify`, as other team actions do). Give it `type: skill_verified` etc. with the skill. In the app, a skill push refreshes the skills and the profile, and tapping it opens that skill. Also refresh skills when the app comes back to the foreground. Test on staging with the two accounts, watching the server log for the `[push]` line. |
| 5 | Retire the old proof-of-work flow for good (Victor, 2026-11-09). | See item 3. | Remove the old stepper, the Proof of work section, the proof upload screen and its admin page; stop the backend honouring old proof when someone applies (`jobsRoutes.js:275`) and in discovery (`discovery.js:34`). Anyone verified only the old way must re-verify; on staging that is test accounts. Needs its own backend test pass. |

## Decision for Victor

Answered 2026-11-09: **retire the old proof flow.** Still open: whether the skill-review admin email is urgent or a daily digest.

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

## Done 2026-11-09

| Item | What was done |
|---|---|
| 1 Sign-out | Signing out closes every pushed screen. Test: sign out from Settings lands on the first screen, and fails with the fix removed. |
| 2 Admin email | Admins are emailed (and Slacked) the moment a skill is sent; reviewers who hold the skill when it passes the first check; reminders at the target and at twice the target (`skillNotices.js`, run on the existing ops sweep). |
| 3 Verified badge | Only skills earned through a passed submission show, by name, and open that submission. |
| 4 Skill pushes | Talent is pushed at first check passed, verified, not yet, needs a change. App refreshes skills on a skill push and when it returns to the foreground. |
| 5 Old proof flow | Retired in the app, the backend (no upload route, no fallback when applying or in discovery) and the admin (no Proof review page, route, queue or badge). The `proof_items` table is kept only so old files are cleaned up when an account is deleted. |
| Wording | The skills flow rewritten in plain English: "Only send work you made", "Your submission" (was "What you sent"), "Complete" / "Something is missing" (were "All there" / "Gaps"), the "2 months, then 3" line says what happens and why, "judge" instead of "score", job-type descriptions say what each type is. |
| Tips | A small "i" that explains a term in plain words, from one glossary (`glossary.dart`): verified, first check, walkthrough, Not yet, start proof, rounds of changes, held payment, the 10%, Proven, usage rights, milestones. A test keeps the glossary free of rule-book words. |
| Contrast | Measured, not guessed. Surfaces lightened one step; Text-3 raised from 3.0-3.9:1 (failed AA) to 4.7:1 or better; tinted cards drawn over Surface-1 (they were darker than plain cards). `test/colors_contrast_test.dart` holds the line. CLAUDE.md and the prototypes carry the new values. |

## Still open

- **Auto-approval copy.** The protection screen says a delivery is approved automatically after 3 days if the client does not answer. Auto-release is switched off on staging, so the text promises something that is not on. Either switch it on or soften the copy (Victor's call).
- **The remaining screens** (identity, applicants, messages, reviews) were read and are mostly plain already; only the lines listed above were changed. A second pair of eyes on the phone is the real test.
- **Tips not yet placed:** the service fee (10%) has a glossary entry but its tip sits only in the protection summary's held-money line; usage-rights tip appears in the brief form but not on the read-only job brief.
- **Drop the `proof_items` table** (after old files are cleaned up): a later, deliberate migration.
