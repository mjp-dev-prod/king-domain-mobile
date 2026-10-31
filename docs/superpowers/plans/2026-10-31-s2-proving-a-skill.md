# S2 Proving a skill: plan

Status: written and built the same night (2026-10-31), unattended. Compact on purpose: it records the design
decisions and the task list; the code is the detail. Source: PRD §3.1 step 5, §4.3 and decisions D5 to D9;
`docs/research/proof-verification-2026-10-30.md`.

## Goal

A talent proves a skill with real work: an evidence pack, an authenticity check by a person, then two reviewers
who practise the skill, with the reasons always shown. Passing keeps the existing apply gate working.

## Decisions I made without Victor (flagged in the handoff)

1. **The old single-file proof stays, as the bridge.** `ProofItem` is what the apply gate reads
   (`Verified in <category>`). When a skill submission is verified, the server upserts a verified `ProofItem` in that
   skill's category. Nothing else in jobs, applying or the talent profile changes.
2. **Statuses:** `draft` → `authenticity` (submitted, waiting for a checker) → `review` (authenticity passed,
   waiting for reviewers) → `verified` | `notYet` | `removed`. Nothing is ever deleted: a result and its history stay.
3. **Two reviewers, blind; a third on disagreement; majority decides.** A reviewer scores each rubric line 1 to 4 and
   gives a verdict. A pass is refused if any line is 1 (below the standard). The second reviewer cannot see the first's
   scores until they have submitted their own.
4. **Rubric lines are in code** (`src/rubrics.js`), the video lines taken from the research doc, the other four drafted
   by me and marked `draft: true`: each needs a session with a practitioner (PRD open item).
5. **The system flags, people decide:** a submission whose output files are all byte-identical to files from an
   earlier "Not yet" attempt is flagged `repeatOfRejected` for the checker, who may apply the penalty (2 months, then
   3, D9) or dismiss it. Stolen work is a permanent ban, applied by a checker with a note. Identical files are detected
   by the storage ETag (an MD5 for single uploads).
6. **Uploads go straight to a private Cloudflare R2 bucket** with presigned links (D: video storage on R2). A new env
   var `R2_PRIVATE_BUCKET` names the bucket; unset means uploads answer "not available" (501) and nothing is faked.
   Victor must create that bucket (it must not be the public APK bucket).
7. A submission needs **2 or 3 pieces**, each with title, brief, role, date and a finished file or a live link; at
   least one piece with a working file; at least one with a draft; the walkthrough video; the declaration of own work
   (and of AI use if any); and, after a "Not yet", acceptance of the terms about repeat submissions.

## Tasks

1. Backend: schema (`SkillSubmission`, `SubmissionPiece`, `SubmissionFile`, `SubmissionReview`, `SkillRestriction`).
2. Backend: `src/rubrics.js` and the pure decision rules (`src/submissionRules.js`), unit-tested without a database.
3. Backend: private R2 helpers (presign upload and download, head), with an optional `R2_ENDPOINT` so tests can fake it.
4. Backend: talent routes (hub, draft, pieces, files, declaration, submit, results, history) with tests.
5. Backend: admin routes: authenticity queue (checker) and skill-review queue (reviewer), both blind and audited,
   with inbox queues; emails on the result.
6. Admin dashboard: authenticity page and skill-review page.
7. App: the Skills hub, the submission builder (readiness checklist, pieces, files, walkthrough, declaration), and the
   result screen with reasons and history.
8. Full suites, handoff update.

## Not in this slice

Calibration sets for new reviewers, the practitioners' rubric sessions, reviewer pay, and the "Proven" level (S7).
