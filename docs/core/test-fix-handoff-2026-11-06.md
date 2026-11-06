# Handoff: make the app test suite green, then push (2026-11-06)

Written for the agent picking this up. Read `CLAUDE.md` first; its hard rules apply. Victor (the owner) approved
the pushes at the end of this doc, on the condition that the app suite is green. Write what you find into
**Results** at the bottom of this file. Don't open a new doc for it.

## Where things stand

| Part | State |
|---|---|
| Backend (`king-domain-backend`, branch `s0-foundations`) | Full suite green (all 38 files), pushed to staging as `8200fab`. **Don't touch it.** |
| Admin (`king-domain-admin`, branch `master`) | `npm run build` clean. 7 commits ahead of `origin/master`, not pushed. Lint shows 13 old errors in files nobody touched in this work. Leave them alone. |
| App (`king-domain-mobile`, branch `s0-foundations`, last commit `3843046`) | `flutter analyze lib` clean. Full `flutter test` had 36 failures; 17 are fixed and committed; **19 remain** (below). |

Already fixed and committed in the app:
- **Settings page** (`lib/presentation/screens/profile/settings_screen.dart`). Notifications, money shown in, data saver,
  privacy, sign out and delete account moved off the profile tab and the Messages tab.
- **Filters**: removable chips instead of a bare number on the Filters button (`FeedFilters.active` in
  `lib/data/models/discovery.dart`).
- **Test stubs**: `test/discovery_test_support.dart` (`discoveryStubs()`) now stubs `displayCurrencyProvider` and
  `conversationsProvider`. Unstubbed providers make real HTTP calls in tests, and those leave a pending 5 s timer that fails the test.

## The job

1. Make every one of the 19 tests below pass.
2. For each failure, first decide whether **the app is wrong** or **the test is wrong**:
   - If the app is wrong, fix `lib/`. A missing state, text that isn't shown, or a layout that overflows on a phone are
     real bugs, and the rule is no dead ends or blank states.
   - Fix only the test when the test is wrong: it looks below the fold, its finder is too broad, or it waits forever on
     an animation that is meant to run.
   - Never weaken an assertion just to get a pass. If you change what a test checks, say why in Results.
3. Run `flutter analyze` (lib and test), then the **full** `flutter test` once. It must be all green.
4. Commit, then do the pushes in "Pushing" below.
5. Fill in Results.

## The 19 failures (run of 2026-11-06)

"Observed" means read from the failure output. "Likely" is a guess; confirm it before you act on it.

| # | Test (file:line) | What failed | Likely cause and where to look |
|---|---|---|---|
| 1 | `messages_test.dart:71` "conversations show … how many are waiting" | `find.bySemanticsLabel('3 unread')` finds 0 | Likely: the `Semantics(label: '${c.unread} unread', child: Text('${c.unread}'))` in `messages_screen.dart` (~line 108) merges its label with the child's text. Adding `excludeSemantics: true` should make a screen reader say "3 unread" once, which also improves the app. The test already calls `tester.ensureSemantics()`. |
| 2 | `packages_premium_test.dart` "browsing packages lists packages …" | **Observed: `RenderFlex` overflowed by 175 px**, `package_browse_screen.dart:107` (a `Row`) | **Real UI bug.** The row is too wide for a phone. Fix the layout with `Expanded`/`Flexible`/`Wrap` and `maxLines` + ellipsis, and check it at 360 dp width. |
| 3–5 | `packages_premium_test.dart` "package orders …" (talent sees the clock; a refusal when accepting; client can cancel) | **Observed: `RenderFlex` overflowed by 2 px**, `package_orders_screen.dart:107` | **Real UI bug**, same kind as #2. The "talent sees the clock" test also reports a second exception; re-check it after the overflow is fixed. |
| 6 | `packages_premium_test.dart:359` "with premium on and nothing bought, asking opens the purchase first …" | `pumpAndSettle` timed out | Something keeps animating: a `StatusPill(pulse: true)`, a spinner, or a `Skeleton` waiting on a provider that never resolves. Find which. If the animation is meant to run, use `pump(Duration)`, the way `dispute_screen_test.dart`'s `_drain` does; if it's an unstubbed provider, stub it. |
| 7 | `packages_premium_test.dart:380` "a client sees waiting questions and can answer them" | `pumpAndSettle` timed out | Same as #6. |
| 8 | `dispute_screen_test.dart:189` "three days late … cancel for a refund after confirming" | text containing "This can't be undone:" not found | Check whether the confirm sheet still says this, or whether the sheet never opened (the tap missed something below the fold). The viewport is 1080×2600 at 3× (360×866 logical). |
| 9 | `dispute_screen_test.dart:213` "an offer from the other person can be accepted or declined, with the clock shown" | text containing "left" not found | The answer-by clock is missing or worded differently. If the offer card shows no time left, it's an app bug: the PRD gives 48 h to answer. |
| 10 | `dispute_screen_test.dart:246` "asking the team to decide asks first …" | no "Ask King Domain to decide" to tap | Below the fold, or the button is worded differently. |
| 11 | `dispute_screen_test.dart:260` "asks for an address, once, with the purpose" | "Tell us where we can reach you" not found | Same check as #10. |
| 12 | `dispute_screen_test.dart:291` "an agreement says what was agreed" | text containing "more time" found **2** times | **Observed**: the intro paragraph also contains "more time". The finder is too broad; match the agreement line itself. |
| 13 | `discovery_screens_test.dart:520` "a talent profile shows the verified work and saves or unsaves" | "Salon promo" not found | The verified piece title is either below the fold (the reputation section added in S7 sits above it), or no longer shown. If it's no longer shown, that's a bug: verified work is the proof clients come for. |
| 14 | `review_screen_test.dart:109` "cannot be sent until every question … is answered" | `Bad state: No element` | A `.first`/`.last` on a finder that found nothing, probably an answer chip that isn't built yet or is off-screen. |
| 15 | `review_screen_test.dart:133` "a refused send shows the reason and keeps what was typed" | "The 14 days to review this job have passed." not found | Check that a refused send shows the server's message; if it doesn't, that's an app bug. |
| 16 | `review_screen_test.dart:156` "once both are in, both are shown …" | `pumpAndSettle` timed out | Same as #6. |
| 17 | `contract_extras_test.dart:259` "a typed part opens a sheet that checks the length before saving" | `pumpAndSettle` timed out | Same as #6. |
| 18 | `contract_extras_test.dart:326` "raising a point offers only the checklist, never taste" | `pumpAndSettle` timed out | Same as #6. |
| 19 | `stage2_screens_test.dart:229` "client contract screen delivered: approving pays only after confirming" | "Brand kit attached" not found | The delivery note is either below the fold or no longer shown after the S5 contract changes. If the note the talent wrote isn't shown, that's an app bug. |

Several of these may share one cause; fix #2–#5 first, since an overflow exception can make later expectations in the same test fail too.

## How to work here (this machine and this repo)

- **The PC is slow and short on RAM.** Run one heavy process at a time. While fixing, run single files, e.g.
  `flutter test test/dispute_screen_test.dart`, or one test with `--plain-name "…"`. Run the full suite **once**, at
  the end. `flutter analyze lib` takes about 3 minutes.
- Shell is Git Bash on Windows. Heredocs with quotes often break, so write scripts with a file tool, then run them.
- Source files use **CRLF** line endings. Keep them: the Edit tool is fine; plain `sed -i` can mix endings.
- Test patterns already in use:
  - Wrap the app in `MediaQuery(... disableAnimations: true)`.
  - Set the viewport with `tester.view.physicalSize` and `devicePixelRatio`, plus `addTearDown(tester.view.reset)`.
  - Stub providers with `overrideWith`.
  - A `ListView` builds lazily, so text below the fold "does not exist". Use `scrollUntilVisible`, then `ensureVisible`,
    before a `tap`, or make the viewport taller.
- Brand rules for any UI fix are in `CLAUDE.md`: tokens in `lib/core/constants/`, kit widgets in `lib/presentation/widgets/kit/`.
- Commit messages end with the attribution line your harness gives you.

## Pushing (approved by Victor on 2026-11-06, once the suite is green)

1. **App to staging:**
   - Run `git push origin s0-foundations:staging` in `king-domain-mobile`. It is a fast-forward of about 23 commits.
   - It starts the Codemagic `king-domain-staging` build (the "KD Staging" app).
   - **Never push app `master`**: that starts the production internal build.
2. **Admin:**
   - Run `git push origin master` in `king-domain-admin`, 7 commits.
   - Vercel deploys **both** projects from `master`: `king-domain-admin` (production) and `king-domain-admin-staging`.
   - Victor accepted this. Production admin talks to the production backend, which doesn't have S3–S8 yet, so the new
     queues there (Job posts, Shortlists, Safety reports, Start proofs, Disputes, Chargebacks, Reported reviews) will
     show their error states until the backend is promoted. That is expected; don't "fix" it.
   - Check that both Vercel deployments finish (Vercel MCP `list_deployments`, or the CLI).
3. The backend is already on staging. Nothing to do there.

## After that (not yours)

Step 4 belongs to Victor, on his phone: walk the whole journey on staging with a test client and two talents
(pay, start proof, deliver, review, dispute, a package order). Tell him the build is ready for it.

## Results

_To be filled in by the agent: for each of the 19, the cause, what you changed (in `lib/` or the test) and why;
any assertion you changed and why; final `flutter analyze` output; final full `flutter test` count; the commit
hashes pushed; the Codemagic and Vercel outcomes; anything left open. Also update the "Last full run" line in
`docs/core/testing.md`._
