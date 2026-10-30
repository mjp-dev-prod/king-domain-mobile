---
exported_at: 2026-10-30T21:00:00+01:00
work_dir: c:\mobile-projects\flutter\kings domain\king-domain-mobile
related_repos:
  - c:\mobile-projects\flutter\kings domain\king-domain-mobile (Flutter, branch: profile-photos) - 1 commit ahead of origin/staging (d720c74, Slack tooling only); origin/master untouched
  - c:\mobile-projects\flutter\kings domain\king-domain-backend (Node/Express/Prisma 7, branch: profile-photos) - even with origin/staging (a0d8b02); origin/master untouched
  - c:\mobile-projects\flutter\kings domain\king-domain-web (React/Vite, branch: master) - even with origin/master (f52f0f5), privacy pages live
  - c:\mobile-projects\flutter\hive (cross-project index, branch: master) - pushed
topic: Built and deployed to STAGING everything from Victor's gap list (applications view, lifecycle stepper, edit/close job, upload checks, job search, app icon, profile photos, account deletion + privacy pages, push notifications), set up the team workflow (Slack, Fathom notetaker, weekly Saturday meeting), and recorded two new feature tasks from the 24 Oct team meeting that are NOT started.
status: STAGING is current and published (KD Staging 1.2.5). PRODUCTION is untouched and still runs old code. The first real push notification has NOT been tested on a phone. Currency selection and the audio/video portfolio are planned for this week and not started.
---

# Claude Export - Session Handoff

Read top to bottom once. This is a handoff record, not a task list to run unprompted.

---

## How Victor wants to work (read this first)

Victor corrected these in this session. Follow them from the first message.

- **Never shrink, postpone or list obstacles as a reason not to build.** "Do not take shortcuts just because of complexity." When he said a video portfolio needs a player and storage, I answered with a list of problems and he called it laziness. The right move: state the decision he already made (storage moves to Cloudflare R2 or an upgrade, a video player is easy, reviewers know what they sign off) and plan to build it fully.
- **Stay on King Domain.** He asked to ignore tasks that are not his or not King Domain (AlliSports, Pendu, Rentipede, NIN, bank forms). Do not bring them up.
- **Do not build until he says go.** For the two meeting tasks he said "don't build yet, we don't understand it, it's a task during the week".
- **His PC is RAM-starved.** Run only targeted tests; the full suites at the end of a sprint, one at a time. Codemagic runs the full analyze + test on every staging build, which counts as the full check.
- **Deploy needs his go-ahead each time.** Never push mobile `master` (triggers the production APK) or backend `master` (production). Staging = branch `staging` of each repo. Tests never touch production.
- Secrets stay out of chat and git. The mobile repo is **public** on GitHub.
- Research with Exa before building on anything external. Believe his bug reports over my logs.

---

## Part 1 - What is built and where it lives

All on the local branch `profile-photos` of both repos (a chain: work-gaps, upload hardening, job search, app icon, photos, account deletion, push, Slack tooling).

| Feature | Spec / doc (mobile repo) |
|---|---|
| My applications view, five-step lifecycle stepper, edit/close a job | `docs/features/work-gaps-applications-stepper-job-edit.md`, `work-gaps-implementation-plan.md` |
| Server-side upload checks (type from the file's bytes) | `docs/core/testing.md`, backend `src/uploads.js` |
| Job search / sort / can-apply switch, app icon + launch screen | `lib/presentation/screens/jobs/feed_filter.dart`, `tools/launcher_icons/` |
| Public profile photos | `docs/features/profile-photos.md` |
| Account deletion (blocked by any unfinished contract, anonymise-and-remove, race-safe) + privacy policy and delete-account web pages | `docs/features/account-deletion-and-privacy.md` |
| Push notifications (outbox over ContractEvent, FCM v1) | `docs/features/push-notifications.md` |
| Slack end-of-session updates, saved log, weekly `digest`, Personal Manager step | `docs/core/session-updates.md`, skill `.claude/skills/session-update/` |

Verification so far was targeted tests only (backend: accountDeletion 16, push 30, photos, jobs; app: delete_account, push_service, push_ui, shell tests; tools/session-notify 23) plus a clean analyze. The last FULL runs were 2026-10-22; Codemagic's staging build of `e4dded9` ran full analyze + tests and passed.

---

## Part 2 - Deployed state

**Staging (live, current):**
- Neon staging DB schema pushed (read-back empty): `User.photoPath`, `User.deletedAt`, `DeviceToken`, `ContractEvent.pushedAt`.
- Backend `staging` branch live on Render (`king-domain-backend-staging`, workspace "king domain staging", service `srv-db0chamgekts7393l6t0`). Log line `[push] dispatcher running every 5s` confirmed.
- Render env set on staging AND production services: `FCM_SERVICE_ACCOUNT_JSON` (base64 of each Firebase project's service-account key) and `SUPPORT_EMAIL=kingdomainapp@gmail.com`. On production they are inert: production runs old code.
- App: Codemagic built `e4dded9` as **KD Staging 1.2.5**; Victor published it. Codemagic variables `GOOGLE_SERVICES_STAGING_B64` and `GOOGLE_SERVICES_PRODUCTION_B64` are set.
- Web: privacy and delete-account pages live at `king-domain.vercel.app/privacy/` and `/delete-account/`.

**Production: NOT touched.** It needs, in order: Victor runs the production schema push (additive: photoPath, deletedAt, DeviceToken, pushedAt, plus the earlier Job columns), backend to `master` (auto-deploys production Render), a draft release, app to `master` (Codemagic production build). Victor decides when; his Personal Manager item #2 tracks it.

Firebase: staging project `king-domain-staging` (app `com.kingdomain.king_domain.staging`), production `king-domain-8878e` (`com.kingdomain.king_domain`). The two `google-services.json` files sit in `android/app/src/{staging,production}/`, git-ignored.

**Open and unconfirmed: the first real push.** The staging log has no `[push]` send line since 24 Oct. One phone registered a token. Test: two staging accounts, award a job, the talent should get "You were picked" within about 5 seconds with the app open (toast) and closed. Then read the Render staging log for `[push] user=... sent=1`.

---

## Part 3 - Team workflow (set up this session)

- **Slack** workspace "MJP Productions Limited": channels `#updates`, `#decisions`, `#meetings`, `#builds`, `#feedback`, `#social`. The `kd updates` app posts to `#updates` through a webhook stored in `~/.claude/kd-slack-webhook` (never in git). Apps installed: kd updates, Fathom, Google Calendar.
- **Wrap-up routine** (skill `session-update`): when Victor says "wrap up", write a plain-language update, post it with `node tools/session-notify/notify.js post --session <id> --file <md>`, then record shipped milestones in his Personal Manager. Hooks in `.claude/settings.json` record each session start and post a commit-only backup at session end (only when there are new commits).
- **Weekly meeting:** Google Calendar event "King Domain weekly", Saturdays 22:00 to 23:30 Lagos time, on the `kingdomainapp@gmail.com` calendar, four guests, Meet link `https://meet.google.com/fdq-drpf-zbb`. Fathom (free plan) records it. **Start the call from the calendar event's "Join with Google Meet"**, not as an impromptu Meet, or Fathom will not join by itself (it did not on 24 Oct; Victor added it by hand). Fathom emails the summary and recording link to attendees; **it posts nothing to Slack by itself** (confirmed 24 Oct), so paste the recording link into `#meetings`. A Slack channel reminder posts in `#meetings` every Saturday at 9:30pm (profile time zone is UTC+01:00).
- Decisions from the 24 Oct meeting (Fathom recap): Slack is the hub, WhatsApp only for announcements; restart the CAC application (Victor said not to discuss CAC further, it is a hassle); use a partner company's temporary Paystack key for real-money testing until the business account exists (raise the risks if it comes up: account terms, real money, payouts); real-money testing by end of December; all team members test the staging app and post feedback in Slack; major decisions go through the admin dashboard decision ledger.

---

## Part 4 - Next work: two features, planned for this week, NOT started

Both are in Victor's Personal Manager (#37, #38). **Do not start until he says go.** When he does, plan, then build completely.

1. **Currency selection in the app.** Not yet defined: display only (Naira symbol and formatting) versus letting a client pay in another currency. Facts from Paystack's docs (read 2026-10-24): `transaction/initialize` accepts `currency` NGN, GHS, ZAR or USD with amounts in the subunit; transfer recipients are per country (`nuban` = NGN), so a payout in naira for a dollar job needs a conversion rule. That is a money and fee decision; per the team's rule it goes through the decision ledger. Ask Victor which of the two he means in one question, then build.
2. **Audio and video portfolio for videographers** (proof of work today is image/document only; Supabase caps each file at 50 MB project-wide). Decided by Victor: move video storage to Cloudflare R2. R2 facts (docs, 2026-10-24): presigned PUT URLs valid up to 7 days; multipart upload for large files (5 MiB to 5 GiB parts, up to 5 TiB objects); a CORS policy is needed for browser uploads; no egress fees; free tier 10 GB-month. The backend already has R2 code for the APK (`src/storage.js`: `uploadApk`, `presignApkUpload`, env `R2_*`) to reuse. Needs: direct-to-R2 upload from the app, a video/audio player on proof items, reviewer playback in the admin proof-review page, type checks by bytes (`src/uploads.js`), and deletion on account delete.

---

## Part 5 - Open items and decisions for Victor (King Domain only)

- Emails are shown to the other side of a job: every talent who views a job gets the client's name, photo and **email**, and the reverse. Decide whether to show email only after an award.
- No age rule exists anywhere (can under-18s sign up?). The privacy policy is silent on it.
- The app downloads its fonts from Google at runtime (`google_fonts`); bundling them would remove that and make first launch work offline.
- The delete-account page promises deletion by email request "within 30 days"; that number is mine, confirm it.
- Terms of service are deliberately not drafted: they depend on the payment and dispute model.
- Firebase is on the deprecated registration-token APIs; moving to Installation IDs is a planned, low-risk follow-up (`docs/features/push-notifications.md`).
- Backend `master` is at `9fa22e4` and mobile `master` at `5b91f73`: both are the production code, which is behind staging by everything above.
- The unpublished 1.2.3 staging draft is still there (ask before deleting).

---

## What to do next, if picking this up cold

1. Ask Victor how the push test went; if not done, walk him through it and read the staging log.
2. When he says go on the two features: ask the one currency question, then write the plan and build with tests first. R2 for video is decided.
3. When he asks to ship to production: follow the order in Part 2, one step at a time, with his go-ahead for each.
4. At wrap-up: run the `session-update` routine.

Do not start any of this without Victor explicitly asking.
