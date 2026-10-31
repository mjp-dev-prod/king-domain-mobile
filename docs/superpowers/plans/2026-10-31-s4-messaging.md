# S4: Messaging and calls (plan, 2026-10-31)

PRD §8 S4; decisions D18, D24, D26, D27, D28; research `messaging-2026-10-30.md`. Built unattended: local commits
only, schema on the Neon TEST branch only.

## What a person can do when this is done

**Both sides:** a Messages list with unread counts; one conversation per relationship, where the job's own events
appear as cards between the messages; text, photos, files and audio files (large ones straight to private storage);
report any message; a "write down what we agreed" card that only counts once both confirm; edit a text for 15
minutes with an "edited" mark (the original is kept); no deleting.

**Client:** starts a conversation with an applicant, an invited talent, or a talent on their shortlist.

**Talent:** replies. (Asking a client a question before applying is premium, D28, so it waits for S8.)

**Safety (D18):** before a job is awarded between two people, a message with a phone number, email, link, "talk on
WhatsApp", outside payment, a request for a fee, an invitation to meet, or a program is held, not delivered: the
sender sees why and can change it. After award the contract room allows it. Blocking is not available while a
contract is active; reporting always is, and a report on a person with a live contract alerts the team at once.

**Team:** queue "Safety reports": the reported message with the messages around it, dismiss or take action, with a
note, audited, in the inbox with a target.

## Decisions I am carrying, and ones I had to make

Carried: D18 warnings and report/block rules; D24 response time = median first reply over 30 days, shown in
buckets after 3 conversations (the S3 rule is wired to real conversations here); D27 contract-room messages cannot
be deleted (edit window, "edited" mark, original kept).

Made by me (listed again in the handoff):
1. **Delivery is by polling plus push, not sockets.** The conversation screen asks for new messages every few
   seconds while it is open, and a push is sent for each message. Socket.IO (as in Pendu) is a later upgrade; it
   would add a dependency and a stateful server on a free Render instance. Everything else is the same either way.
2. **No deleting at all**, not only inside a contract room. Simpler, and consistent with "the conversation is the
   record". Say if you want deleting before award.
3. **Edit window 15 minutes**, text only. (D27 says "short".)
4. **Voice notes are sent as audio files** in this build. The backend and the screens handle audio fully (5-minute
   limit, playback link). A recorder inside the app needs a native plugin I cannot verify on a phone from here, so
   it is not added.
5. **Calls are not built.** They need a real-time media provider (cost and account are an open item in the PRD) and
   the AI note-taker needs speech recognition. Per the PRD's honest-data rule nothing pretends to work: the
   conversation has no call button until a provider exists. What *is* built is the part that works without one: the
   "write down what we agreed" card, which is what counts in a dispute.
6. **Data saver** is an app setting (local to the phone): when on, nothing downloads by itself, and sizes show first.
7. **Offline queue** is in the app: a message typed offline waits and sends when the connection returns, with the
   same client id so it is never sent twice.
8. **Quiet hours and per-conversation mute** are not built (a settings item in the PRD).

## Backend

Schema: `Conversation` (one per client and talent), `Message` (text, voice, image, file, agreement, with held state,
flags, edit history, attachment fields and a client id for safe retries), `ConversationRead`, `MessageReport`,
`UserBlock`.

Routes: `GET/POST /conversations`, `GET /conversations/:id` (messages after a point, job events, read marker),
`POST /conversations/:id/messages`, attachment presign and complete, edit, agreements and confirm, report, block.
Admin: `/admin/safety-reports`. Response time stat added to every talent card.

## App

Messages tab for both roles; conversation screen (bubbles, event cards, held-message warning, composer with attach
and send, agreement card, report and block sheets); start-a-conversation buttons on applicants and talent profiles;
data-saver setting.

## Not in S4 (named so nothing is silently missing)

Calls and the AI note-taker; an in-app voice recorder; Socket.IO real-time delivery; quiet hours; mute.
