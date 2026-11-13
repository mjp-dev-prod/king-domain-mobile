# Admin redesign: bring `king-domain-admin` up to brand v1, in light and dark

Written 2026-11-09 with Victor. Work starts Wednesday 2026-11-11. This is a plan; nothing here is built yet.
Brand tokens and rules stay in [CLAUDE.md](../../CLAUDE.md) (authoritative). This file does not copy them.

## Goal

The admin should feel like the same product as the app, and a reviewer should be able to clear a queue quickly and see
at a glance what is late. Today it is on brand v0 (ink and gold, outlined cards, serif everywhere) and reads as crude.
Moving the admin to v1 is the decision CLAUDE.md called "separate"; Victor made it on 2026-11-09 by asking for this work.
CLAUDE.md is updated as part of step 1 below.

## Decisions made (Victor, 2026-11-09)

| # | Decision |
|---|---|
| 1 | The four review queues (Authenticity, Skill reviews, Proof review, Identity) become **list on the left, detail on the right** on wide screens. On phones they fall back to separate pages. Every other page is restyled only. |
| 2 | **Work previews in queue rows**, which needs a small backend change (spec below). |
| 3 | The admin supports **light and dark**, with an Appearance setting. Mobile follows later as its own task. |
| 4 | Preview shows the **first file of any kind**: a picture when it is an image, otherwise a type icon with the file name or link host. No row is ever blank. |
| 5 | Light palette is derived from the mobile app and `prototypes/`. |

## What is wrong today (found 2026-11-09, from the code)

1. **Old palette.** `src/index.css` is v0: ink `#151a2e`, gold as the primary colour. Gold is used for buttons, focus rings and the
   signup chart. In v1 gold means money only.
2. **Outlined cards.** 142 `<Card>` uses, all shadcn's `rounded-xl border shadow-sm`. v1 has no card borders; depth comes from
   stacked surfaces, with corners of 16 and 20.
3. **Fraunces everywhere.** About 40 uses on every page title and stat number. v1 keeps Fraunces for the KD mark only. Titles are
   Public Sans 800. Mono is for eyebrow labels and step numbers only, but the dashboard is almost all of them.
4. **Narrow columns.** 36 pages hard-code `max-w-3xl`, so lists float in a wide window.
5. **Queue rows say little.** Name, skill, "7 days waiting" in one grey. No colour for lateness, no preview of the work, and
   `repeatOfRejected` is not shown.
6. **Status colours differ from the app.** Coral for pending and soft green for settled; v1 is amber for waiting, green for done, red for errors.
7. **Sidebar.** Same colour as the page, a faint active fill, a default white scrollbar, and a count on only one of twelve queues.
8. **No shared states and no motion.** Each page builds its own loading, empty and error block. Nothing responds to a press.

## Step 1: palette and brand record (about an hour, before any code)

- Read the dark tokens in CLAUDE.md and `app_colors.dart`, then check `prototypes/palette-explorer.html` and
  `king-domain-full-vision.html` for any real light palette. **Not yet confirmed that one exists.**
- If none exists, derive light values from the same roles (ground, three surfaces, text 1/2/3, violet, violet-text, gold, green, amber,
  red) and show swatches to Victor to approve.
- Check contrast for every text/background pair in both themes, WCAG AA. Violet used as text and gold on light surfaces will need darker values than on dark.
- Record the light palette in CLAUDE.md and update its scope paragraph (the admin is now v1). Victor approves the values first.

## Step 2: tokens (`src/index.css`)

- Dark and light sets as CSS variables; `:root` is light, `.dark` overrides, and an `Appearance` choice of System / Light / Dark
  stored per browser and applied before first paint (no flash).
- Public Sans for headings, 12/16/20/28 radii, violet focus ring, styled scrollbar, tabular numbers on money and counts.
- All 142 cards and every shadcn component read these variables, so this one change moves most of the site.
- Appearance control goes in `Settings`. It also needs a toggle in the shell for phones.

## Step 3: shared pieces

Built once in `src/components/`, matching `king-domain-mobile/lib/presentation/widgets/kit/`:

| Piece | Mobile counterpart | Notes |
|---|---|---|
| `Card` (tonal, no border, hover and press lift) | `kd_card.dart` | replaces the shadcn default |
| `StatusPill` | `status_pill.dart` | tones: brand, ok, warn, bad, plain; the same meaning as the app |
| `Eyebrow`, `StatTile` | text styles | mono only here |
| `QueueRow` | n/a | person, skill pill, wait time (amber, red once past the queue's target), `repeatOfRejected` flag, preview |
| `LoadingList`, `EmptyState`, `ErrorState` with Retry | `kd_layout.dart` | loading held at least 300 ms; empty says why and what next |
| `PageHeader` | `ContractHeader` | title, one sub line, pill, actions |
| `Money` | gold text | gold only for amounts |
| Buttons | `kd_button.dart` | violet primary; glow only on the single main action on a screen |
| Master-detail layout | n/a | list left, detail right at wide widths, plain pages on phones |

## Step 4: shell

Sidebar on its own surface, a count on every queue (amber when anything is past target), violet active item, styled scrollbar,
theme control, and the user block at the bottom. Counts reuse the Inbox's per-queue data where it exists.

## Step 5: backend preview change (own tests, own push, Victor approves first)

- **Where:** `king-domain-backend/src/admin/skillReviewRoutes.js`. The Authenticity list (`GET /`) returns only person, skill label,
  `submittedAt` and `repeatOfRejected`. The Skill reviews list has the same shape.
- **Add:** a `preview` on each row: `{ kind: 'image' | 'video' | 'document' | 'link', name, pieceTitle, url }`, taken from the
  first file of the first piece; `url` is a short-lived link from the same presign helper the detail screen uses (`filesWithLinks`).
  If the piece has only a link, `kind: 'link'` and `name` is the host. If there is no file or link, `preview: null` and the row shows the
  type icon for the skill.
- **Limits:** the lists already stop at 100 rows, so at most 100 links per load. Links expire (900 s today). The page must regenerate
  them on refresh and fall back to the icon if an image fails to load.
- **Not for Identity:** identity documents are private IDs. Their rows get **no preview**, only the person and the wait.
- **Proof review and Start proofs** use different data (`ProofItem`, start-proof fields). Check their list endpoints on Wednesday and apply
  the same `preview` shape only where the data is the person's own work.
- **Tests:** image, video, document, link-only and no-file cases; a private bucket that isn't configured returns `url: null`; a row's
  preview never contains another person's file. Run the backend suite files for these routes, not the whole suite.
- **Deploy:** the backend is on staging (`8200fab` at last report). Push after tests pass and Victor agrees.

## Step 6: pages, in daily-use order

1. **Inbox**, **Authenticity** (the first master-detail screen). **Stop here for Victor's review on a Vercel preview link.**
2. Skill reviews, Proof review, Identity (master-detail).
3. Disputes and Chargebacks, with money in gold.
4. Job posts, Shortlists, Safety reports, Reported reviews, Start proofs.
5. Overview: violet chart, Public Sans numbers, tonal tiles.
6. Decisions, Decision detail, New decision, Ledger, Entries, App releases, Team, Audit, Settings, and the sign-in, invite and password pages.

Every page keeps what it does today. This is a visual and layout change, plus the previews. No page loses a state: loading, empty, error with
Retry, and failed actions with a toast. The behaviour hooks (`Sentry`, capability checks, `PROOF_COUNTS_CHANGED`) stay untouched.

## How Victor sees it

Vercel deploys both admin projects from `master`, so do this on a branch. Vercel builds a preview URL for the branch without
touching `master`. **Do not merge to `master` until Victor signs off**, because that deploys the production admin
(`king-domain-admin`) too. Production admin talks to the production backend, which does not have S3 to S8 yet, so some queues show error states there.
That is expected and not a bug.

## Done means

- `npm run build` clean, lint no worse than the 13 old errors in untouched files.
- Contrast checked for every colour pair in light and dark.
- Before and after Playwright screenshots of every page at desktop and phone width, in both themes, attached for Victor.
- Every page checked for its loading, empty, error and long-text states.
- Backend preview tests pass; the previews show real work on staging data.
- CLAUDE.md updated (brand scope and light palette); `docs/README.md` indexed; this file updated to what was built.

## Out of scope

- Mobile light mode. It is its own task after this: every colour in the app is a fixed constant today (`AppColors`), so each one has to
  become theme-aware, and the app needs an Appearance row in `settings_screen.dart`. It uses the palette decided in step 1.
- The waitlist site (`king-domain-web`) stays on v0.
- No new admin features, queues or permissions.

## What was built and decided (2026-11-13)

Branch `king-domain-admin` `admin-redesign`, not merged to `master` (Victor signs off first). Backend preview change is on
`king-domain-backend` branch `admin-preview-fields`, not pushed to staging.

- **Theme:** light and dark both, defaulting to the system setting; Light and Dark are manual overrides (Settings, sidebar,
  phone header). No flash on load. The light palette was derived and measured (no v1 light palette existed); values in CLAUDE.md.
- **Proof review no longer exists** (removed 2026-11-09), so three master-detail queues: Authenticity, Skill reviews, Identity.
  List on the left, open item on the right, advance to the next after a decision; phones show one pane at a time.
- **Previews:** Authenticity and Skill review rows show a look at the work. Identity shows none (private IDs). Start proofs
  has none (multi-part data). Skill-review rows stay blind.
- **Shared pieces** in `src/components/kd/` (QueueRow, MasterDetail, WorkPreview, StatusPill, StatTile, Money, states) and
  `src/lib/` (queues, wait, useQueueList, hold, appearance).
- **Restyled:** every page. Gold only for money; charts use violet. Failed loads show an error with Retry instead of looking empty.
- **Split:** a second session restyled the 18 other pages and merged cleanly.
- Known: two primary-glow buttons appear on App releases when empty (header and empty state); lint is unchanged at 13 old errors.
