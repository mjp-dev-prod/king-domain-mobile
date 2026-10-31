# Messaging: the conversation between client and talent (research, 2026-10-30)

**Why:** Today a client and talent cannot talk inside King Domain at all, so every question goes to email
or WhatsApp, which is where scams live (client trust D18) and where nothing counts in a dispute. PRD research
topic 6. It proposes; decisions are in §8.

Tags: 🟢 fact (named source) · 🔵 observed (this codebase) · 🟣 synthesis · 🟡 hypothesis · 🔴 unknown.

## 1. Short answer

🟣 One conversation per relationship, where the job's own events (funding, start proof, drafts,
deliveries, change requests, extensions) appear as cards between the messages, so the conversation **is**
the job's record. Text, voice notes, photos and files from the start; voice and video calls inside the app;
built light on data; protected by the warnings and report rules already decided.

## 2. What King Domain has today (🔵)

- No messages. A contract has an event history (`ContractEvent`, `GET /jobs/:id/contract/history`) and push
  notifications, but no way to talk.
- Decided already: no contact details before award, warnings in the thread, report and block (D18); a
  talent's response time shown from real data (D24).

## 3. How Nigerians actually communicate for work (🟢)

- **WhatsApp is the default business channel**: 88% of 100 Nigerian SMBs surveyed used it (Bassey 2021);
  over 39 million MSMEs, many run on it (BusinessDay 2025).
- **Voice notes are the most used feature for talking to customers** (39.3%, ahead of text at 36.8%) in a
  survey of 356 Kano traders; most were 18–35 (Zaria Journal of Communication, 2025).
- **Data is expensive**: after the January 2025 tariff increase the average 1 GB rose to about ₦475
  (BusinessDay, Mar 2025); MTN's 2 GB monthly plan is ₦1,500. A student pays for every video and call.

## 4. What the platforms do (🟢)

- **Upwork:** messages and video calls in the app; contact or payment details only after a contract and
  only in that contract's room; report any message; **blocking is hidden while a contract is active** (the
  conversation must stay available); keeping talk on the platform is what gives documentation in a dispute.
- **Fiverr:** video calls in the app; outside tools only after an order is placed, and then users are told
  to document what was agreed back on Fiverr.
- **Airbnb:** messages analysed for safety; contact details and outside links held before booking;
  in-thread reminders with one-tap report.
- 🔵 **Pendu**, Victor's other product, already runs real-time chat over Socket.IO and calls on a mediasoup
  media server, so the techniques exist in this workspace.

## 5. Proposal (🟣, for the PRD)

### 5.1 Conversations
- **Before award:** a conversation opens when a client messages an applicant or an invited talent, or when
  a talent asks the client a question about a job before applying (decision 3). Contact details are held and
  warned about (D18).
- **The contract room** after award: the same conversation continues. Every job event appears as a card in
  the timeline: funded, start proof submitted and accepted, drafts, deliveries, change requests, extension
  requests and answers, approval, payout. Actions are taken from the cards (accept the start proof, request
  changes), so the conversation and the job are one place.
- **King Domain conversations:** the "find someone for me" shortlist, support, and disputes each get a
  conversation with the team.

### 5.2 What can be sent
- Text, **voice notes** (up to 5 minutes each), photos, and files. Large files (video work) upload straight
  to storage with progress and resume, the same path as the video portfolio.
- **No executable files** (APK, EXE) and no links before award; both are common scam tools.
- **Voice and video calls** inside the app (decision 1). Calls are not recorded; the call shows in the
  timeline (who, when, how long), and after a call the app asks both sides to write down what was agreed,
  because only what is written counts in a dispute.

### 5.3 Light on data
- Voice notes and photos compressed before sending; photos show a small preview first.
- Videos and large files are never downloaded automatically on mobile data; the size is shown before
  download. A data-saver setting turns off auto-download entirely.
- Messages typed offline are queued and sent when the connection returns; sent, delivered and read ticks.

### 5.4 Safety and records
- D18 rules: held messages, warnings, one-tap report on every message.
- **Blocking is not available while a contract is active** (as on Upwork); reporting is, and a report on a
  contract alerts the team at once.
- **Messages in a contract room can't be deleted**; they can be edited for a short time with an "edited"
  mark, and the original is kept for a dispute (decision 2).
- Notifications per message, with quiet hours the user sets; the response-time stat (D24) is computed from
  these conversations and the talent sees how.

## 6. What this changes in the app

A messages tab; conversation screens with event cards; voice note recording and playback; file transfer
with resume; calls; real-time delivery (Socket.IO, as in Pendu); the detection and warnings; report flows;
the data-saver setting; message retention rules in the privacy policy.

## 7. Unknowns (🔴)

- Call quality on weak networks and low-end phones: test on Victor's phone and a cheap Android before
  launch.
- The cost of running a media server for calls at King Domain's scale.

## 8. Decisions for Victor

1. **Voice and video calls inside the app** (not recorded, logged in the timeline, with a "write down what
   you agreed" prompt after)? Pendu's stack shows how.
2. **Contract-room messages can't be deleted** (short edit window, original kept), because they are the
   evidence in a dispute?
3. **Before applying, may a talent ask the client a question** about the job (a private conversation, held
   to the D18 rules), or only reply once the client messages them?

### Answered by Victor, 2026-10-30 (carry into the PRD as decisions)

- **D26. Voice and video calls in the app, with an AI note-taker.** Design that follows from the evidence:
  - The note-taker is switched on per call and **both sides must agree before it starts**; a visible
    "Notes on" marker shows for the whole call (NDPA s.26–27: affirmative consent, told the purpose first).
  - The AI writes a **draft** of what was agreed (scope, price, deadline, changes) into the conversation as
    a card. **It only counts once both sides confirm it**, and either can correct it first.
  - Why a draft, not a record: speech recognition handles Nigerian English reasonably (word error rates
    about 17–19% for Google, Microsoft and WhisperX) but **fails on Pidgin (65–83%)**, normalising it towards
    English and losing its meaning (Tosin & Mair); Whisper Large's error rate on African-accented English
    benchmarks is 26–38% (AfriVox, EACL 2026). A summary nobody checked would mislead a dispute.
  - The audio is deleted once the summary is confirmed; the confirmed summary stays with the job.
- **D27. Contract-room messages can't be deleted** (short edit window, "edited" mark, original kept).
- **D28. Asking a client a question before applying: Victor leans towards a paid premium feature for
  talents**, like LinkedIn's paid messaging. To settle in the money topic, because it touches two earlier
  decisions: the safety rule that a talent never pays anyone to get work (the app's anti-scam message must
  stay unambiguous), and fairness to the broke students the product exists for. One middle path: premium
  talents can ask, and the client's answer is added to the job for every applicant to read.

## Sources

- Nababa & Nasidi, "Utilization of WhatsApp for Business Communication among Traders in Kano", Zaria
  Journal of Communication 10(1) (2025); Bassey, "I Surveyed 100 Nigerian SMBs on Their Digital Tools
  Adoption" (2021); BusinessDay, "MSMEs tap WhatsApp to unlock revenue streams" (Jun 2025).
- BusinessDay, "Consumers pay 65% more for 1GB after tariff hike" (Mar 2025); MTN Nigeria data plans page;
  Technext24 data price list (Apr 2025); P.M. News (Jan 2025).
- Upwork Help: "How to use Upwork Messages"; "Get to know each other before a contract"; "Circumvention".
  Fiverr Help: "Stay protected: Fiverr's off-platform policy". Airbnb Help, article 1121.
- Pendu backend in this workspace (`src/chat`, `src/socket/handlers`, `package.json`: socket.io, mediasoup).
