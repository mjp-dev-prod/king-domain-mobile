# Profile photos

**Status: built and tested on local branches `profile-photos` (both repos), NOT deployed (design decided by Victor 2026-10-22: photos are public, everyone can see them).**
Brand rules still hold: no stock photography, no decorative imagery. A photo is the person's own.
This is imagery surface 2 in [imagery-surfaces.md](./imagery-surfaces.md) ("profile photo").

## Decisions

| Question | Decision |
|---|---|
| Who sees a photo? | **Everyone**, where the app shows a person today: their own profile, the applicant list and the client card on a job. Contract headers show no avatar yet, so none was added there. |
| How is it stored? | In a **public** storage bucket (`avatars`). The link never expires and needs no sign-in, so it loads fast, can be cached, and cannot hit the expired-link problem proof thumbnails have. |
| What do people without a photo see? | Their initials, as today (`InitialsAvatar`). **No stock photos and no placeholder faces**, including on the demo accounts. |
| Who can set one? | Talents and clients, for their own account only. |

**What "public" means in practice:** anyone who has the exact link can open the picture, inside or
outside the app, with no login. The link contains a long random part, so it can't be guessed, but it
is not secret. That is why this is only for profile photos, never for proofs or delivered work, which
stay in private buckets whose links expire after minutes.

## Data

`User.photoPath String?`: the object's path in the `avatars` bucket (`<userId>/<timestamp>.<ext>`).
The public link is derived from it (`<SUPABASE_URL>/storage/v1/object/public/avatars/<path>`), so
the database never stores a link that could go stale.

## API (backend)

- `PUT /users/me/photo`: one image file (multipart field `file`). **JPG, PNG or WebP only** (no GIF:
  not animated avatars; no HEIC: many phones can't draw it), at most 5 MB, type decided by the file's
  bytes (`src/uploads.js`). Stores the new file, saves the path, then deletes the previous object.
  Returns the user with `photoUrl`.
- `DELETE /users/me/photo`: removes the object and clears the path. Idempotent.
- `photoUrl` (or null) appears on: the signed-in user, `client` on a job, `talent` on an application.
- Refusals use the same codes as other uploads (`unsupported_file`, `file_too_large`, `empty_file`).
- If the storage write fails, nothing changes in the database. If deleting the old object fails, the
  new photo is still saved and the leftover is logged (an orphan costs storage, not correctness).

## App

- `UserAvatar(name, photoUrl, size)`: the photo when there is one, the initials when there is not,
  and the initials again if the picture fails to load. Replaces `InitialsAvatar` where a person is shown.
- On the profile: tapping the avatar opens a sheet (Choose from gallery, Take a photo, Remove photo when
  one exists). The picked image is resized on the phone (about 800 px, quality 85) before upload, so
  files stay small. A toast confirms; failures show the server's reason.
- Reduced motion respected; every avatar has a text alternative (the person's name).

## Tests

Backend, over real HTTP with a **fake storage server** (like the fake Paystack): accepted types stored
with the sniffed content type; GIF, HEIC, HTML, empty, oversize refused; replacing deletes the old object;
remove clears it; storage failure leaves the database unchanged; `photoUrl` appears on the user, job
client and applicant; one person can't set another's photo. App: `UserAvatar` (photo, initials, failure
fallback, semantics), the sheet and its three actions, upload error shown, applicant and contract headers.

## Not in this work

Cropping UI, stripping EXIF location data from the file (the phone-side resize re-encodes the image,
which usually drops it, but this is not guaranteed and not tested), reporting or moderating photos,
and photos on the public waitlist site. Account deletion (a separate item) must delete the photo.
