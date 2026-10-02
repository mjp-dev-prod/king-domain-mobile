# Imagery surfaces — where images appear, and what each one traces back to

**Status (2026-10-02):** inventory and links only. Nothing here is decided beyond what the linked
docs already decided; each surface's build order is still open. Brand rule for all of them:
[CLAUDE.md → Brand v1 → Imagery](../../CLAUDE.md) (real content only, illustrations for empty
states, no stock, no decorative 3D).

Why this doc exists: Victor asked that any image surface we render be linked to the earlier
plans and decisions, so a screen can't quietly add imagery that contradicts them.

## The surfaces

| # | Surface | Where it shows | Traces back to | Built today? |
|---|---|---|---|---|
| 1 | **Proof of work** | Talent profile; each application a client reviews; talent discovery cards | [Correction 01 — proof of skill](../core/correction-proof-of-skill-screen.md) (proof is a real file, portfolio link or description, verified by a person); [Correction 02 — talent discovery](../core/correction-talent-discovery-screen.md) ("add a real avatar and a small thumbnail of the actual attached work sample"; thumbnails must not imply a ranking through size or placement) | Partly: `ProofItem.filePath`, one private file per item, shown as a link. No thumbnail, no portfolio-link field, **no server-side file-type check** |
| 2 | **Profile photo** | Talent and client headers, applications, contract screens, discovery cards | Correction 02 (real avatar per card) | No field, no upload. The app shows initials |
| 3 | **Delivered work** | Contract review, version history | Ledger decision `736051b0` ("How a job gets paid", rule 6: "each version of the work" is recorded); [stage 2 spec](./stage-2-delivery-and-changes.md) (immutable `ContractDelivery` versions); brand imagery rule ("delivered media") | Partly: each version stores a file path; the app shows a link, no preview |
| 4 | **Job reference images** | Job post and job detail (a moodboard, "like this") | Brand imagery rule names moodboards as allowed content. **No product decision** says jobs carry attachments | No |
| 5 | **Empty-state illustrations** | No jobs, nothing delivered, no proof yet | Victor 2026-10-01: "we don't need assets, at most illustrations"; brand rule allows them | No; illustration style not chosen |

## Tension to keep visible (not resolved here)

[Vision vs research reconciliation §3](../core/vision-vs-research-reconciliation.md) says buyers'
real fear is **deception**, and proposes **process-based proof, not static portfolio images**,
because "a static image proves nothing anymore" (AI-generated portfolios, impersonated headshots).

So surfaces 1 and 2 must not present an image *as* proof:

- A work thumbnail is there to make an application **legible** at a glance. What makes it
  trustworthy is the human reviewer's verification (already built) and, later, process evidence.
- A profile photo is identity, not credibility. It doesn't replace university verification.
- Whether process-based proof (recorded work-in-progress, timestamped steps) gets built is still
  an open product decision. Rendering thumbnails must not quietly settle it.

## Gaps found while compiling this

- Proof and delivery uploads accept any file type (only a 10 MB size limit). Needs server-side
  type checking before real users (security, and needed for previews anyway).
- Correction 01 allows a portfolio **link** as proof; `ProofItem` has no URL field.
- Signed file URLs expire after 5 minutes, so thumbnails need their own caching approach.

## Prototype images (not the real app)

Prototypes use hand-picked example photos from the **Unsplash API** (decided 2026-10-02; Picsum
rejected as generic stock, randomuser.me rejected because its faces mostly aren't West African).

- `prototypes/tools/fetch-unsplash.js` fetches a pool once; the key lives in the git-ignored
  `.env.prototype`. Output holds no key.
- Picked by eye from a contact sheet, locked by photo id in `prototypes/data/example-images.js`.
  Excluded: children, real brand names (a student must never appear to have delivered a real
  company's logo), and images that aren't design work.
- Unsplash rules followed: images hotlinked from the API URLs, every photographer credited
  with a link. Every prototype page says the people and work are examples.
- Used in `prototypes/palette-explorer.html`: profile photos (surface 2), proof thumbnails on
  the profile and on applicant cards (surface 1), the delivered brand kit with version switching
  (surface 3). Surfaces 4 and 5 are not shown because they aren't decided.
