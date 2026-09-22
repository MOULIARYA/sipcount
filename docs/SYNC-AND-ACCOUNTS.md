# Sync across devices — and the account question

**Decision date:** 2026-09-22 · **Decided by:** Madhur · **Status of Phase 2:** logged requirement, not built
**Built in:** prototype v16 (`sipcount.html`, `engine.js`)

---

## 1. What was asked for

> "We spoke about having an option of login so that data can sync across various platforms that the
> same user may be using — browser on mobile, browser extension, desktop app on Win and Mac. Can we
> give optional login on the launch page and also add it in Settings where people can see their
> account and logout/login. To begin with we can allow login via Google and iCloud."

## 2. What was decided

The goal — one water total across every surface — is right. Login is only one way to reach it, and
it is the expensive one: it brings identity, a privacy policy, mandatory account deletion, age law
and a server that holds personal data about people whose median age we are aiming *below* 18.

So the work was split:

| Phase | What it is | Status |
|---|---|---|
| **1** | **Pair code.** A 25-character code generated on the device. Any device given the code joins the same room and the totals add up. No account, no email, no identity. | **Built** (client side; relay still to be hosted) |
| **2** | **Sign in with Google / Apple**, purely as a way to recover a lost pair code. | **Requirement logged — not built.** See §6. |

Phase 1 is the whole feature for most people. Phase 2 exists only for "I lost my code", and it is
the phase that needs a lawyer, a privacy policy and an age-verification story — so it ships only if
users actually ask for recovery.

## 3. How Phase 1 works

**The code is the identity.** 25 Crockford base32 characters (no `I`, `L`, `O` or `U`, so nothing
can be mistyped into someone else's room), shown as five blocks of five, generated with
`crypto.getRandomValues` on the device. 125 bits.

Two different values are derived from it:

| Derived | Goes to the server? | Purpose |
|---|---|---|
| `room = SHA-256("sipcount-room-v1\|" + code)[0..32]` | yes | which pile of blobs this device belongs to |
| `dataKey = SHA-256("sipcount-data-v1\|" + code)` | **never** | AES-GCM key for the payload |

The server therefore stores encrypted blobs under an opaque room id and **cannot read a single
number it holds**. That is what lets the app keep saying nothing readable leaves the device.

**Losing the code loses the cloud copy.** There is no recovery, because there is no account to
recover it against. Each device keeps every number it counted itself; they simply stop adding up
together. This is stated plainly in the pairing screen — it is a fair trade for daily water totals,
and it would not be for, say, a password manager.

## 4. The 18+ gate — the part that is not optional

Sipcount targets Gen Z **and Gen Alpha**, most of whom are under 18.

- **India — DPDP Rules, notified November 2025.** A "child" is anyone **under 18**. Processing their
  data requires *verifiable* parental consent: verifying the child's age *and* that the consenting
  adult is real, with Aadhaar-linked virtual tokens as the expected mechanism. Tracking and
  behavioural monitoring of children are prohibited outright. Full compliance by **mid-May 2027**.
- **US — COPPA:** parental consent under 13.
- **Google and Apple** will not issue an account to an under-13 anyway.

Today Sipcount is legally almost invisible: nothing leaves the device, so there is no processing and
no consent question. Sync would end that.

**So sync is offered only to 18+.** The answer on the age screen sets `S.adult`; under-18s see one
line saying so and keep the app exactly as it is — fully local, no server, no consent to obtain.
Changing the age answer to an under-18 one disconnects any existing sync and drops the paired
devices. There is nothing to verify because there is nothing to process.

## 5. What travels, and what never does

**Sent** (encrypted, once per device): day totals — date, prompt count, image count, mL scope 1 and
scope 2, input and output token counts, the per-brand and per-tier breakdown — plus the daily budget
and the region setting.

**Never sent:** anything typed (it is never captured in the first place), **any timestamp finer
than a date**, the age answer, an email address, a device fingerprint, an IP-derived location.

Day granularity is deliberate. Per-prompt timestamps would turn this into a log of when someone
works — precisely the thing the product promises not to build. The regression suite asserts it:
every field of every day is one of nine known aggregates and every leaf is a number, so there is no
slot a prompt could travel in even by accident.

## 6. The merge rule — the part that is easy to get wrong

A naïve design syncs `days[date] = 340`. Two devices then fight over one value and a later write
silently erases the other's number: the user watches their total *drop*, and never trusts the app
again.

Instead, **a device only ever writes its own totals.**

```
S.days                    ← this device's days. Only this device writes it.
S.peers[devId].days       ← a paired device's days, parked untouched. Only that device writes it.
store.days()              ← what every screen reads: the two summed per date.
```

Writers never overlap, so there is nothing to resolve — no merge logic, no server-side arbitration,
works offline. The worst case is a peer that is out of date, which shows as a total that is briefly
too low, never as data that is lost. A pull replaces one peer's map wholesale.

It also happens to be true: the extension on a laptop and the app on a phone really did see
different prompts. That makes a future screen easy — *"60% of your water came from your desktop."*

With nothing paired, `store.days()` returns the existing map untouched, so an unsynced install
behaves byte-for-byte as it did before this change. No migration was needed and no stored data moved.

## 7. Where it appears in the app

| Place | What is there | Why |
|---|---|---|
| Age screen | small text link: *"Already syncing? Use my code"* | the only real first-run case — a returning user setting up a new device, before it has any data. The code is held until the age answer lands; an under-18 answer drops it. |
| Settings › **Your devices** | status, device list, add a device, show my code, stop syncing | the permanent home |
| One notification, once | *"Keep your streak on every device"* — after 7 days alive or the second character unlock | sync sells itself once there is a streak and a character worth protecting; before that it is friction |

**Sign-in was deliberately kept off the launch page.** First-run friction is where this audience
leaves, the app is fully useful with no account, and asking for identity before showing a single
number inverts the product's own argument.

## 8. Phase 2 — the logged requirement

**Requirement:** optional sign in with Google or Apple, so a user who loses their pair code can
recover it, and so Settings can show "signed in as…" with a sign-out.

What it commits us to, none of which Phase 1 needs:

1. **Apple Guideline 4.8.** If a third-party login sets up the primary account, the app must also
   offer an equivalent option limiting collected data to name and email, letting the user hide the
   email, and not tracking for advertising. Sign in with Apple qualifies. So it is **Google *and*
   Apple, or neither** — and note the user's wording "iCloud login" means Sign in with Apple.
2. **Apple Guideline 5.1.1(v).** Once accounts exist, **in-app account deletion is mandatory** — not
   just sign-out.
3. **Apple Developer Program, $99/yr.** Needed for iOS anyway; record it as the project's first
   accepted exception to the zero-licensing-cost rule.
4. **Chrome extension.** Apple requires https redirect URIs and will not accept
   `chrome-extension://`, so auth has to run in a hosted page the extension opens. Google is fine
   via `launchWebAuthFlow`.
5. **Store paperwork.** Privacy policy URL, Play Data Safety form, App Store privacy labels.
6. **Age.** The 18+ gate from §4 applies at least as hard, and an account makes it auditable.

**Identity minimisation when it is built:** do not store the email. It arrives in the token and is
discarded. Persist only `sha256(provider + subject + server pepper)` against the room. There are no
password resets and no mail to send, so holding an address would be pure liability.

## 9. Hosting — the shopping list

Nothing syncs for real until a relay exists. Total cost ≈ **$5–6/month plus a domain**.

**Buy:**

| Item | What to get | Cost |
|---|---|---|
| VPS | Hetzner CX22, DigitalOcean or Vultr — 1 vCPU / 2 GB, Ubuntu 24.04 LTS | ~$5/mo |
| Domain | anything; `sync.<domain>` is all that is needed | ~$12/yr |
| TLS | Caddy gets a Let's Encrypt certificate automatically | free |

**Software:** [PocketBase](https://pocketbase.io) — MIT, a single Go binary with SQLite, and it
already has the OAuth2 providers Phase 2 would need. Alternative: Supabase (Apache 2.0) if this ever
outgrows one box. Not Firebase — free tier, but proprietary and Google-locked.

**Setup, once the box exists:**

1. Point `sync.<domain>` at the VPS (A record).
2. `ufw allow 22,80,443/tcp && ufw enable`; create a non-root user; disable password SSH.
3. Install Caddy, reverse-proxy `sync.<domain>` → `127.0.0.1:8090`. TLS is automatic.
4. Drop in the PocketBase binary, run it as a systemd unit, create the admin account.
5. One collection, `blobs`: `room` (text, indexed), `dev` (text), `body` (text), `updated` (auto).
   Unique index on `(room, dev)`. API rule: read and write allowed only with both `room` and `dev`
   supplied — there is nothing secret to protect *inside* a blob, because it is already encrypted.
6. A nightly job deleting rows untouched for 180 days, so abandoned rooms do not accumulate.
7. In `sipcount.html`, set `SYNC.endpoint = 'https://sync.<domain>'`. That single line switches
   sync on across the app.

**Also still to do when the relay lands:** a QR code on the pairing screen (it is pointless until
there is a transport; it needs a small MIT encoder vendored in, e.g. `qrcode-generator`), rate
limiting per room, and porting the same pair code into the browser extension.

## 10. Open question

**Who owns and pays for the relay?** Madhur is sourcing the VPS and domain (2026-09-22). Worth
noting: routing it through firm infrastructure pulls the project into corporate IT and security
review, which is slower than a personal $5 box for a prototype.
