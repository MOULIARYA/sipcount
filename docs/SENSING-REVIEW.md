# Mobile sensing approach — pre-build review (2026-09-15)

Scope: the "layered sensor" direction recorded in `ISSUES.md` D-1…D-6. Purpose: find blockers and improvements *before* building, for a go-live on personal phones (Android + iOS). Nothing here depends on the UI review.

## 1. What we are relying on, and whether it still holds

| Assumption | Verdict | Evidence |
|---|---|---|
| A local VPN service can see which host each connection goes to (SNI) | **Eroding.** Chrome has had Encrypted Client Hello (ECH) on by default since 2024; Cloudflare (which fronts chatgpt.com and claude.ai) serves ECH keys; **Android 17 turns ECH on OS-wide** for apps targeting API 37. RFC 9849 published March 2026. Within 1–2 Android generations the hostname will usually be hidden. | CDT, packet.guru, gblock.app / TechTimes on Android 17 |
| Destination IP identifies the vendor | **No.** OpenAI and Anthropic sit behind Cloudflare shared ranges; Gemini behind Google front-ends shared with every Google service. |
| The vendor apps' traffic can be attributed without hostnames | **Yes, on Android.** The active VPN app may call `ConnectivityManager.getConnectionOwnerUid()` (API 29+) to learn which app owns a connection → ChatGPT / Claude / Gemini / Google app identified by package, independent of ECH. This is how NetGuard shows per-app traffic. **Not available on iOS** for consumer apps. |
| DNS reveals the host for browser traffic | **Mostly, for now.** The VPN can declare itself the DNS server and see plaintext queries. Chrome only auto-upgrades to DNS-over-HTTPS when the system resolver is a known DoH provider, so a VPN resolver keeps DNS visible. Apps that hard-code their own DoH (Firefox by default in some regions) bypass this. Android 17 may push DoH further — watch. |
| Reply size predicts output tokens | **Plausible, unproven.** Streaming (SSE) wraps every token in JSON, so bytes/token is 10–50× the raw text and vendor-specific; HTTP/2 multiplexes telemetry on the same connection. Needs the I-18 spike before we commit. |
| Time-to-first-byte separates reasoning from standard tier | Plausible; reasoning models routinely pause 5–30 s. Also unproven; same spike. |

## 2. Blockers, ranked

**B1 — iOS is a different product.** (High) Apple guideline 5.4: VPN-type apps must use `NEVPNManager`, and only **organisation** developer accounts (D-U-N-S number) may publish them; local "firewall" apps exist (Lockdown, Guardian) but approval is discretionary and has been refused for data-collection wording. There is no per-app attribution on iOS, Safari has no ECH yet but iCloud Private Relay hides Safari traffic entirely, and the vendor apps can set their own DoH. **Recommendation:** for iOS v1, do *not* build the doorman. Ship a **Safari Web Extension** (iOS 15+) ported from our Chrome extension — same code, covers chatgpt.com / claude.ai / gemini.google.com in Safari — plus the "usual model" manual/receipts path. Revisit the iOS network sensor only with an org account and after the Android sensor has proven itself.

**B2 — ECH/DoH erosion on Android.** (High, medium-term) Mitigation: make **UID attribution the primary signal** for the three native apps (immune to ECH), and use own-DNS-resolver + SNI only for browsers. Accept that Android browser coverage may degrade over 2027–28; the Android browser story can then move to a Firefox/Kiwi/Edge extension (Chrome on Android has no extensions).

**B3 — Google Play VpnService policy.** (Medium) `VpnService` is allowed only for core-VPN apps or listed use cases — "app usage tracking", "device security", "network tools" are on the list — with a mandatory declaration form, prominent in-app disclosure, listing text, and a ≤90 s demo video. Community threads show frequent "not a permitted use" rejections. Mitigations: frame the feature as *network usage measurement for the user's own AI apps*, never route or modify traffic, process on-device only, keep the disclosure screen before the permission prompt, and keep direct-APK distribution (already working) as fallback. Note that the Play Protect friction we hit (I-3) is *also* solved by Play publication, so the two decisions go together.

**B4 — One VPN at a time.** (Medium) Personal-phone users with Proton/Nord/etc. or a university VPN cannot run the doorman simultaneously. Android tells us when another VPN takes over; the app must degrade gracefully ("counting paused while your VPN is on") and fall back to the accessibility layer where granted. Quantify with a question in onboarding.

**B5 — Engineering weight and battery.** (Medium) A `VpnService` must forward *all* device traffic in user space (TCP/UDP reassembly, IPv6, MTU, DNS) and must run as a foreground service with a persistent notification. Do not write this from scratch: use a proven open-source tunnel engine — `hev-socks5-tunnel` (MIT) or `tun2socks` (MIT, Go via gomobile). NetGuard's engine is the best-known but GPLv3, which conflicts with our permissive-licence preference. Expect 2–5 % daily battery on the engine alone; measure on a mid-range phone.

**B6 — Detection accuracy.** (Medium, resolvable) Separating a prompt from background telemetry on a multiplexed HTTP/2 connection is a heuristic (upload burst → long streaming download). Only the spike can tell us the false-positive/negative rates. Set an acceptance bar now: ≥90 % of prompts detected, ≤10 % false positives, before the sensor replaces the accessibility layer as default.

**B7 — Under-18 users.** (Low–medium) Family Link–managed phones can block VPN apps; store age ratings must be 13+ regardless (the age-bracket picker is a display preference, not age collection). Privacy text must be readable by a 13-year-old.

**B8 — Calibration drift.** (Low, ongoing) Bytes/token and TTFB thresholds change whenever a vendor changes its streaming protocol or adds a model. Constants are already versioned; add a "calibration date" per vendor and surface confidence in the UI when constants are stale (>90 days).

## 3. Improvements to the design

1. **Signal priority on Android:** UID attribution → own-DNS hostname → SNI. Hostname only matters for browsers.
2. **Keep the `PromptEvent` boundary exactly as is.** Every sensor (accessibility, network, extension, receipts import) emits the same counts-only event; the engine and UI never know which sensor fired. This is what makes the whole plan UI-independent.
3. **Sensor status model:** `active / paused (other VPN) / not granted / unsupported (iOS)` shown in Settings and in the "Listening" pill, so users understand gaps instead of distrusting the numbers.
4. **Extension calibration mode (I-18)** using the browser's Resource Timing API (`transferSize`, `responseStart`) on same-origin requests — no new permissions, counts only. This is the instrument for everything else.
5. **Two-tier constants:** `models.json` gains `calibration: { vendor: { bytes_per_token_in, bytes_per_token_out, ttfb_reasoning_s, reply_bytes_p50 }, measured_on }`. Shipped in updates; optional download (I-20).

## 4. Store & legal checklist for go-live (both platforms)

- Play: VpnService declaration form, demo video, listing disclosure, Data safety form ("no data collected" is defensible: all processing on-device, nothing transmitted), accessibility-service declaration if that layer remains.
- Apple: organisation account (D-U-N-S) if the network sensor is ever attempted; privacy nutrition label; Safari extension review is routine.
- Privacy text: state that the network sensor sees *which apps and sites connect and how much*, never content; no upload; user can wipe. GDPR/India DPDP: on-device processing, no transfer — still disclose. Age 13+.
- Licences: engine MIT preferred; avoid GPL code in the app.

## 5. What can be built now without touching the UI

| # | Work | Why now | Output |
|---|------|---------|--------|
| P1 | Extension: fix/verify selectors on the three live sites (I-8) and add **calibration mode** (I-18) | Instrument for everything else; no UI dependency | Extension v0.3; first calibration table |
| P2 | Android **doorman feasibility spike**: bare test app (no Sipcount UI) using an MIT tunnel engine; logs `uid/package, host (DNS/SNI), up-bytes, down-bytes, TTFB` per flow — counts only — while the tester uses ChatGPT/Claude/Gemini apps and Chrome | Answers B2, B5, B6 with numbers | Go/no-go memo with detection rates and battery |
| P3 | Play policy dry run: draft the VpnService declaration answers, disclosure screen copy, 90-s video script | De-risks B3 before code exists | Text files in `docs/store/` |
| P4 | Port the Chrome extension to a **Safari Web Extension** skeleton (iOS/macOS) | Only viable iOS v1 path; needs an Apple developer account to test on device | `browser_extension_safari/` |
| P5 | Sync Android `models.json` to prototype v2 constants, re-derive golden tests (I-16) | Numbers, not UI | Green CI |
| P6 | Signing key (I-2) | Unblocks smooth updates for all future test rounds | Secrets set; one last reinstall |

Recommended order: P6 (10 min of Madhur's time) → P1 → P2 → P3 → P5 → P4.

## 7. Android validation (deep research, 2026-09-15) — supersedes §2 B2–B6 where different

**Verdict: the design works; change five things.**

| Keep | Change |
|---|---|
| Local `VpnService`, MIT engine (**hev-socks5-tunnel** first choice; `xjasonlyu/tun2socks` main branch also MIT — pin the tag) | **Route only the AI apps + browsers through the tunnel** (`addAllowedApplication`). Everything else never touches us → far lower battery, smaller blast radius, and the Play story becomes "monitors only these apps". Attribution for native apps becomes trivial: any flow inside the tunnel from `com.openai.chatgpt` *is* ChatGPT. |
| `getConnectionOwnerUid()` per new flow (API 29+, TCP+UDP, allowed for the active VPN, no extra permission; our floor is Android 12 so no `/proc/net` fallback needed) | **Drop the AccessibilityService from the Play build.** It is the single largest rejection risk (Play requires a separate prominent-disclosure video; combining it with VpnService doubles reviewer scrutiny), and **Android 17's Advanced Protection Mode silently disables all non-assistive accessibility services**. Keep it as a sideload/test-only module at most. |
| VPN-supplied DNS as primary browser hostname signal, SNI secondary | **Do not block QUIC/UDP 443** — just forward and account it. Gemini (Cronet) will be HTTP/3; blocking degrades Google apps for no gain. |
| Per-flow bytes + timing → counts-only `PromptEvent` | **Add a no-VPN "coarse mode"**: `UsageStats` foreground events + `NetworkStats` byte delta at app-pause gives "session in ChatGPT, N KB, T minutes" with no VPN at all. Fallback when another VPN is active or the user declines. Not prompt-level, nothing for browsers. |
| | Detect *strict* Private DNS via `getPrivateDnsServerName()` (not `isPrivateDnsActive()`, which is true in Automatic mode) and show a one-time hint. |

**Facts that de-risk earlier worries**
- ECH (Android 17) only activates when the app's networking library integrates it *and* the server publishes keys; otherwise SNI stays visible. Even with ECH, the ECH key lookup itself is a DNS query to our resolver → we still learn the hostname (unless strict Private DNS or app-level DoH). Cloudflare currently forces ECH only on *free* zones; Google front-ends have not deployed it.
- Chrome on Android only auto-upgrades to DNS-over-HTTPS when the current resolver is a known provider — a VPN resolver at a private IP keeps DNS in plaintext to us.
- Play Protect's sideload block ("blocked to protect your device") and Android 13+ "restricted settings" apply to internet-sideloaded apps only; **Play-installed apps are exempt**. `BIND_VPN_SERVICE` is not on the Play Protect trigger list.
- Data safety form: data processed on-device and never sent does not count as "collected".
- Precedent: **PCAPdroid** (local VPN, per-app flows, SNI/DNS decoding, no server) is live on Play; NetGuard, RethinkDNS, GlassWire likewise. Play tolerates local monitors; it rejects traffic manipulation for money.

**Remaining risks (ranked)**
1. Play "not a permitted use" rejection (medium likelihood, high impact). Declare **"App usage tracking"** (+ Network-related tools); listing text, disclosure screen and *both* required videos (≤90 s: VPN in use; disclosure + decline path) must tell one story: local, no server, only these apps, counts only. Expect one rejection round.
2. Prompt-vs-telemetry separation on multiplexed connections is a temporal heuristic (small upstream burst → downstream trickle lasting >1.5 s). Untested. The spike decides.
3. Another VPN preempts us (Samsung Secure Wi-Fi, Google One VPN, Proton, corporate): honour `onRevoke()`, never auto-reclaim, show "Paused", use coarse mode.
4. Gemini inside the Google app: most Google-app traffic is *not* Gemini → require `gemini.google.com` hostname or the burst signature; label as estimate.
5. Build requirements now: **target SDK 36** (Play deadline passed Aug 2026, extension to Nov 2026), **16 KB page size** for native libs (NDK r28+, AGP 8.5.1+).
6. Foreground service type `systemExempted` (VPN apps listed) → `specialUse` fallback; support always-on, discourage "block without VPN".
7. Battery: precedents say "hardly any" for filter-off firewalls; allowed-apps-only should land ≪2 %/day. Measure.
8. Work profile / Private Space traffic is invisible to a personal-profile VPN. Document, don't fix.

**Spike plan (≈2 weeks elapsed, ~10 working days)**
A. Attribution: 200 flows, ≥99 % non-INVALID_UID, IPv6 OK (2 d). B. Prompt signature: 30 scripted prompts × vendor × {short, long, image, voice} with ground truth; derive per-vendor thresholds; accept precision ≥90 % / recall ≥85 % native, ≥80/75 % Chrome, <1 false positive per idle hour; report whether TTFB/cadence tracks tier (4 d). C. Battery: 24 h × 3 devices (Pixel A17 beta, Samsung, budget MediaTek), ≤2 %/day (3 d passive). D. DNS/ECH matrix: Private DNS off/auto/strict × Chrome Secure DNS default/manual × Android 17 (1 d). E. Coexistence with another VPN (0.5 d). F. Play dry run on closed testing with both videos (parallel; accept ≤2 submissions). G. Coarse mode accuracy ±20 % bytes vs VPN (1 d).

**What stays estimated:** model tier (only ordinal proxies: TTFB, streaming cadence — treat as research); whether the native apps use their own DoH or WebSockets (spike B/D); battery on OEM-throttled devices; Play's acceptance of a sustainability meter under "App usage tracking".

**Consequence for Increment 3:** the accessibility-based Android build stays useful as the *test harness* for the next weeks (it works for ChatGPT and Claude today) but is not the release path. Do not invest further in accessibility heuristics beyond keeping the current build usable.

## 8. iOS — revised after consent-first research (2026-09-15)

Earlier §2 B1 ("not viable for v1") was too pessimistic. With user consent, iOS can approach Android parity:

| Layer | What it gives | Account | Review risk |
|---|---|---|---|
| **Safari Web Extension** (content script on the three sites; DOM send-hook + Resource Timing) | Exact events, characters, model label for web use | Individual OK | Low |
| **Local packet tunnel with `NEProxySettings` CONNECT proxy for listed domains** (Lockdown Privacy pattern, open source) | Hostname in plaintext (`CONNECT chatgpt.com`), exact per-connection up/down bytes and timing, native apps + Safari; only listed domains touched; takes precedence over iCloud Private Relay; unaffected by ECH | **Organisation account effectively required** (Guideline 5.4); capability itself is self-serve | Medium-high: Apple's TN3120 says tunnels are not *meant* for monitoring, though Lockdown/AdGuard/1Blocker ship it. Position as on-device privacy monitor, no server, nothing leaves the phone. |
| **Shortcuts personal automations** ("when ChatGPT opens/closes → run Sipcount", iOS 17+, no confirmation) → our App Intent | Which AI app is in the foreground → attributes tunnel bytes to app vs Safari | Individual OK, no entitlement | Low (the "one sec" app is built on this) |
| **Screen Time API** (FamilyControls individual authorisation + DeviceActivityMonitor) | Minutes per AI app (5-min resolution) as sanity check | Individual OK; Family Controls distribution entitlement requested per app, days–weeks | Medium (must be a wellbeing framing; no monetisation of Screen Time data) |

**Not viable / dead ends (confirmed):** per-app flow attribution (managed devices only), DNS proxy and content filter (supervised only), iOS 26 URL filter (reports nothing to the app), custom keyboard (no host-app ID, cannot see Send), ReplayKit screen capture (privacy/UX-hostile), any accessibility API (none exists for third parties).

**Sequence:** Android spike first (same heuristics) → individual Apple account ($99) for building/testing on our own iPhones (all capabilities incl. tunnel are self-serve for dev/test) → company entity + D-U-N-S (2–4 weeks in India) → organisation account → transfer app → App Store. iOS builds need a Mac; GitHub Actions macOS runners are free for public repos.

## 6. Decisions — **all four approved by Madhur, 2026-09-15**

1. Android release build = network sensor + coarse mode, **without** the accessibility service (§7)?
2. **Play Store** as the Android target (removes the Play Protect/restricted-settings friction), direct APK kept for testing?
3. Approve the Android spike (§7, ~10 working days) with its acceptance thresholds before any UI work on the sensor?
4. iOS: pursue the four-layer design (§8) — individual account now for dev/test, company entity + org account in parallel?

Sources: [Google Play VpnService policy](https://support.google.com/googleplay/android-developer/answer/12564964?hl=en) · [Play: permissions accessing sensitive information](https://support.google.com/googleplay/android-developer/answer/16585319?hl=en) · [Apple App Review Guidelines §5.4](https://developer.apple.com/app-store/review/guidelines/) · [iVPN on Apple VPN rules](https://www.ivpn.net/blog/insights-apple-app-store-rules-vpn-apps/) · [CDT on ECH](https://cdt.org/insights/encrypted-client-hello-closing-the-sni-metadata-gap/) · [Android 17 ECH](https://www.techtimes.com/articles/325959/20260829/android-17-hides-your-browsing-destinations-carriers-closing-https-privacy-gap.htm) · [ECH RFC 9849 overview](https://packet.guru/blog/ECH-Encrypted-Client-Hello-2026)
