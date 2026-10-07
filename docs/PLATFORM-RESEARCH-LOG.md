# Platform research log

*Every three days, re-check that our sensing approach is still the best available on each platform
— extension, Android, iOS, in-app browsers, desktop. Standing instruction from Madhur, 2026-10-05.*

**Why this is a cadence and not a one-off.** Twice in a week a decision was made on what I
remembered rather than what the platform documents said. The second time it cost three failed
builds and nearly produced a false experimental result on Madhur's phone. Platforms also genuinely
move: Android's per-app network APIs tightened in 7 and 10, iOS gated providers behind supervision,
ECH was standardised in March 2026, Play Protect began blocking sideloaded accessibility apps in
India. A decision that was right in September can be wrong in November without anyone touching our
code.

`docs/test/traceability.js` checks this file's freshness: it prints a note after three days and
**fails the build after ten**. Warn, then fail — a red build on day four would just teach us to
ignore the colour.

## What each pass must cover

Not a reading list. Each item is answered with a quote and a URL, or recorded as unchanged.

1. **Android** — `VpnService` (policy category, declaration, videos, the "encrypt to the tunnel
   endpoint" clause), `NetworkStatsManager` granularity, `TrafficStats` scope,
   `getConnectionOwnerUid`, `AccessibilityService` policy, Play Protect sideload blocking, and any
   behaviour change in the newest API level.
2. **iOS** — Network Extension provider types and which are supervised/MDM-only, ASRG 5.4 and 5.5,
   Family Controls, Safari Web Extension limits, and whether anything has appeared that reads
   another app's content (today: nothing, at any tier).
3. **Browser extension** — Manifest V3 changes, host-permission rules, Chrome Web Store policy, and
   whether the DOM selectors for ChatGPT, Claude and Gemini still hold. The selectors have broken
   once already and will again.
4. **Desktop** — Windows and macOS per-process network attribution, code-signing and notarisation
   requirements, and endpoint-security software that blocks per-process reads.
5. **The numbers** — any vendor or peer-reviewed publication of real per-query energy or water
   figures. Our `OUTPUT_PER_INPUT = 5` is still a placeholder (D-22) and a published figure would
   replace a guess that drives most of the headline number.

## Rules

- **Primary sources only** for anything that decides a design: developer.android.com,
  developer.apple.com, Play and App Store policy pages, AOSP. Blogs corroborate; they do not decide.
- **Quote the decisive sentence verbatim with its URL.** A finding without a quote is a memory, and
  memory is what went wrong.
- **Record "unchanged" explicitly.** A pass that found nothing is a result and is worth recording;
  a pass with no entry is indistinguishable from a pass that never happened.
- **State what would change our mind**, so the next pass knows what to look for.
- If a finding invalidates a shipped decision, raise it in `ISSUES.md` **and** move the matrix row
  in the same change. That coupling is the whole point of the cadence.

---

## 2026-10-07 — scheduled three-day pass (all five areas)

**Trigger:** the standing cadence (automated run). Brief from the last two entries: a documented
way to force a stats flush or a per-UID API with sub-minute guarantees; Google clarifying the
tunnel-endpoint clause for on-device VPNs; Apple relaxing per-app attribution outside MDM.

**Answer: nothing moved that changes a decision.** None of the three things we were watching for
has happened. Two findings worth knowing (Android developer verification; iOS URL filter) and
one clause we had not recorded (Play's "narrowly scoped APIs" line on accessibility) — none of
them invalidates a shipped decision, so `ISSUES.md` and the matrix are untouched.

**Method note.** Three parallel sub-sweeps fetched the pages; I re-fetched the decisive Play pages
myself (VpnService, Accessibility, Policy Center) and confirmed the quotes below. Items marked
*(sub-sweep)* were fetched live this session but not re-read by me — the fetcher de-duplicates
within the hour. developer.android.com reference pages truncate before the class docs in our
fetcher, so the Android API quotes come from the AOSP source the reference is generated from.

**Android**

- **VpnService policy — unchanged.** Clause still verbatim: *"must encrypt the data from the device
  to the VPN tunnel endpoint"*, and the framing still assumes a server: *"Exceptions include apps
  that require a remote server for core functionality such as: … App usage tracking"*. No
  on-device/local exemption. Two videos, each *"90 seconds or shorter"*.
  — https://support.google.com/googleplay/android-developer/answer/12564964 (re-fetched). Same text
  in the Policy Center: *"Must encrypt the data from the device to VPN tunnel end point"* —
  https://support.google.com/googleplay/android-developer/answer/16558241 (re-fetched).
- **`NetworkStatsManager` — unchanged; no public flush.** *"Since bucket length is in the order of
  hours, this method cannot be used to measure data usage on a fine grained time scale."* still
  present. `setPollOnOpen`, `setPollForce` and `forceUpdate()` are all `@hide`
  `@SystemApi(MODULE_LIBRARIES)`; the source says *"processes that don't hold the appropriate
  permissions can make no use of this API."* — https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework-t/src/android/app/usage/NetworkStatsManager.java
  *(sub-sweep)*. **This closes the 10-06 "what would change our mind" item: no.**
- **`TrafficStats` — unchanged.** *"Starting in {@link android.os.Build.VERSION_CODES#N} this will
  only report traffic statistics for the calling UID. It will return {@link #UNSUPPORTED} for all
  other UIDs for privacy reasons."* — https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework-t/src/android/net/TrafficStats.java *(sub-sweep)*
- **`getConnectionOwnerUid` — still public API** (`framework/api/current.txt`). Its caller
  restriction text could **not** be fetched this pass; recorded as unverified, not as unchanged.
- **Accessibility policy — unchanged in substance; one clause newly recorded by us.** Passive
  listening still permitted: *"Google Play permits the use of the AccessibilityService API for a
  wide range of applications."* The autonomy ban (*"Any use of the Accessibility API that enables an
  app to autonomously initiate, plan, and execute actions or decisions is strictly prohibited"*)
  does not touch a read-only listener. — https://support.google.com/googleplay/android-developer/answer/10964491 (re-fetched).
  **Not previously in our notes:** *"Apps must use more narrowly scoped APIs and permissions in lieu
  of the Accessibility API when possible to achieve the desired functionality."* —
  https://support.google.com/googleplay/android-developer/answer/16558241 (re-fetched). I cannot say
  whether it is new or simply unrecorded. **It helps us rather than hurts:** the 10-06 phone run is
  documented evidence that the narrower API (`NetworkStatsManager`) cannot resolve a prompt. That
  log belongs in the P10 declaration.
- **Play Protect sideload blocking — unchanged mechanism, no country list.** *"This protection is
  active in select markets."* Same four permissions incl. `ACCESSIBILITY`. Page updated 2026-08-18.
  — https://developers.google.com/android/play-protect/warning-dev-guidance *(sub-sweep)*. Assume
  India still covered; I-57 route (Play internal testing) stands.
- **New to our log — Android developer verification.** *"September 30, 2026: Protections begin for
  all users who install apps from participating stores in Brazil, Indonesia, Singapore, and
  Thailand"* and *"Verification capability will be expanded globally for all apps on certified
  Android devices in 2027."* — https://developer.android.com/developer-verification *(sub-sweep)*.
  FAQ: *"As a developer, you are free to install apps without verification with ADB"* and *"if users
  sideload your app directly, these new verification requirements won't apply to your app yet."*;
  a free limited-distribution account covers *"up to 20 specific devices"* —
  https://developer.android.com/developer-verification/guides/faq *(sub-sweep)*. **No effect today**
  (India not in the first wave; Madhur's APK installs unaffected). **In 2027 an unregistered
  sideloaded APK will stop installing** — another reason the Play internal track (I-57) is the
  testing route, and the package should be registered when the Play account is opened.
- **Newest API levels — nothing on VpnService, network stats or accessibility listeners.** Android
  17 adds `ACCESS_LOCAL_NETWORK` (*"enforcement is mandatory for apps that target Android 17 (API
  level 37) or higher"*); its definition of local network *"excludes cellular (WWAN) or VPN
  connections"* (Android 16 text), so a future tunnel is not caught by it. Accessibility changes are
  additive only. — https://developer.android.com/about/versions/17/behavior-changes-17,
  https://developer.android.com/about/versions/16/behavior-changes-16 *(sub-sweep)*

**iOS** — all *(sub-sweep)*, via the JSON variants of the Apple doc pages.

- **Provider table — one new type, no new sensing route.** TN3134 now lists a **URL filter**
  provider (iOS 26.0) with no managed-device restriction. It cannot help us: *"The system performs
  URL filtering on your behalf according to your configuration and URL data set."* The developer's
  extension only supplies a Bloom filter and never sees URLs or bytes; reporting of filtered URLs is
  *"available only from supervised devices."* — https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment,
  https://developer.apple.com/documentation/networkextension/neurlfiltermanager
- **Per-app VPN — unchanged, still needs management.** *"per-app mode requires managed device"*
  (TN3134); *"To use per-app VPN in iOS … a device management service needs to manage the app."* —
  https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web. **The 10-05 item
  "Apple relaxing per-app attribution outside MDM": no.**
- **ASRG 5.4 / 5.5 — unchanged** (page "Last Updated: June 8, 2026"). *"Apps offering VPN services
  must utilize the NEVPNManager API and may only be offered by developers enrolled as an
  organization."* — https://developer.apple.com/app-store/review/guidelines/
- **Family Controls / DeviceActivity — unchanged.** Per-app data is still duration, pickups and
  notifications; no bytes. *"This sandbox prevents your extension from making network requests or
  moving sensitive content outside the extension's address space."* —
  https://developer.apple.com/documentation/deviceactivity/deviceactivityreport. The 2026 "updates"
  pages for these two frameworks returned empty — not verified.
- **Safari Web Extensions — unchanged.** *"In iOS, you must make your background page
  nonpersistent."* — https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari
- **Reading another app's content — still nothing, at any tier.** *"If a third-party app needs to
  access information other than its own, it does so only by using services explicitly provided by
  iOS, iPadOS, and visionOS."* (now names visionOS; same substance) —
  https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web

**Browser extension** — *(sub-sweep)*

- **MV3 — unchanged for us.** The only Aug–Oct 2026 entries are `browser.publicSuffix` and default
  toolbar pinning (Chrome 153). Service-worker lifetime still *"thirty seconds of inactivity or if a
  single activity takes longer than 5 minutes"*. — https://developer.chrome.com/docs/extensions/whats-new
- **Web Store policy — unchanged.** Program Policies "Last updated 2025-05-22". *"Request access to
  the narrowest permissions necessary"* — consistent with D-31. —
  https://developer.chrome.com/docs/webstore/program-policies/policies
- **Selectors — no new break signal.** ChatGPT's release notes (corroboration only) record a
  composer change on 2026-08-07 (formatting kept on paste) and, on 2026-08-04, *"If you paste more
  than 10k characters into the composer, ChatGPT will automatically convert the content into an
  attachment"* — https://help.openai.com/en/articles/6825453-chatgpt-release-notes. Both predate our
  live ChatGPT verification of 2026-09-30 (E2), so the selectors survived them. `content.js` already
  classes an attachment as `long_context`, but **the pasted text's length is then not counted as
  input** — small, because input is a minor share of the number; watch item, not an issue yet.
  Claude and Gemini release notes show no composer redesign.

**Desktop** — *(sub-sweep)*

- **Windows attribution — unchanged.** `GetExtendedTcpTable` (PID per connection) carries no admin
  requirement; per-connection byte stats need admin: *"The SetPerTcpConnectionEStats function can
  only be called by a user logged on as a member of the Administrators group"* —
  https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getpertcpconnectionestats.
  ETW sessions likewise need elevation or Performance Log Users. Design in `DESKTOP-SENSING.md`
  should already assume this; re-check before track B starts.
- **Code signing — consistent with "buy OV, not EV".** *"EV certificates no longer bypass
  SmartScreen."* — https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation.
  Microsoft's cheaper Artifact Signing is **not open to us as individuals**: *"Individual developers
  must be located in the United States or Canada."* (organisations in the EU/UK/Singapore etc.
  qualify; India is not listed) — https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart.
  Smart App Control re-enablement change reported by blogs is unconfirmed by a primary source.
- **macOS — unchanged.** Notarisation required for Developer ID software; a content filter must be a
  system extension. — https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

**The numbers** — *(sub-sweep)*

- **No new vendor figure since our last look.** Google (Aug 2025): *"0.24 watt-hours … 0.26
  milliliters"* per median Gemini text prompt — https://arxiv.org/abs/2508.15734 (still v1).
  Nothing newer than Sept 2026 from any vendor.
- **Output-vs-input (D-22): evidence brackets 5×, does not replace it.** Caravaca et al. (arXiv
  2511.05597, measured, vLLM): *"P2 prompts consume 2.19 times more energy than P1, while P3 prompts
  consume 11.00 times more"* (P2 = 900 in/100 out, P3 = 100 in/900 out) —
  https://arxiv.org/html/2511.05597v1. The sub-sweep derived ~4.3× (one model) to ~8.4× (average)
  marginal output:input; **that derivation is ours, not the paper's**, so it supports keeping 5× but
  is not a published figure to swap in. One analytical workshop paper (arXiv 2607.26571) models the
  opposite direction; not a measurement, noted only.

**Decisions:** none changed. Accessibility listener stays the Android primary sensor; tunnel stays
parked behind the Play endpoint-encryption risk; iPhone plan unchanged; 5× stays a placeholder. Add
the 10-06 phone log to the P10 Play declaration as the "narrower API is insufficient" evidence.

**What would change our mind next pass:** (1) Play adding an on-device exemption to the VpnService
encryption clause; (2) India appearing in a developer-verification wave before Play internal
testing is set up; (3) a ChatGPT/Claude/Gemini composer redesign after 2026-09-30, or the H4
health warning firing; (4) any vendor publishing an output:input energy ratio; (5) the
`getConnectionOwnerUid` restriction text — fetch it directly next time.

**Next pass due:** 2026-10-10.

## 2026-10-06 — the no-VPN polling experiment, run on a real phone

**Trigger:** I-60. Madhur recorded ~8 minutes on his Android phone across ChatGPT, Claude and
Gemini, with the probe polling `querySummary` per UID once a second.

**Answer: no. Per-app byte counters cannot resolve an individual prompt.** They can see that a
session happened and roughly how big it was, which is useful but is not what the product needs.

What the log shows, out of ~430 rows:

- **Three rows exceed 1 kB. Three.** `20:28:37` ChatGPT +358,378 up / +624,173 down; `20:28:41`
  +1,190 / +361; `20:31:04` Claude +119,723 up / **+2,145,010 down**.
- **Everything else is jitter of 1–18 bytes, and about half of it is negative.** A byte counter
  cannot decrease, so those are not traffic: `querySummary` apportions a partially covered bucket
  by the fraction of it our window spans, and as the window end advances the rounding wobbles.
- **The counters are flushed in batches, minutes apart.** ChatGPT's `total_up` sat at exactly
  177,102 for over three minutes of active use, then one second dumped 358 kB. That is the system
  writing accumulated stats, not the traffic arriving.

**My diagnostic column was worthless and I should say so.** I added `bucket_span_s` expecting it to
reveal the data's granularity. It ran 3,643 → 4,109, rising by one per second — it was reporting
*our own query window*, because `querySummary` aggregates over time and returns buckets stamped
with the range you asked for. The thing that actually answered the question was the shape of the
deltas, which I had not planned to look at. The experiment worked; the instrument I was proudest of
did not.

**A second bug the run exposed:** no Gemini rows, although Madhur used Gemini. Gemini lives inside
the Google app (`com.google.android.googlequicksearchbox`) on most phones — **our own accessibility
config has said so since September** and I wrote the probe without reading it. Fixed.

**What is genuinely salvageable:** per-app *session* byte totals, with no VPN and no accessibility
permission. ~358 kB up / 624 kB down for a ChatGPT session, 2.1 MB down for Claude. That is a
legitimate cross-check against what the accessibility listener measures, and a coarse fallback for
apps we have no selectors for. It is not a prompt-level sensor and must never be described as one.

**Decisions:**
- Prompt-level byte accounting on Android requires a `VpnService`. Confirmed empirically, not
  assumed (I-60, I-55).
- The accessibility listener stays the primary sensor: it reads the prompt and the answer directly,
  which is what the extension does and what the number is built from.
- Keep the polling route only as a session-level cross-check, clearly labelled.

**What would change our mind next pass:** a documented way to force a stats flush, or a per-UID API
with sub-minute guarantees. Neither exists today.

**Next pass due:** 2026-10-09.

## 2026-10-05 — Android and iOS sensing, after Madhur challenged the accessibility plan

**Trigger:** Madhur asked whether traffic can be observed without the accessibility service, and
pointed out it would not work on iOS. Both challenges were correct.

**Android**

- `NetworkStatsManager.queryDetailsForUid` — ruled out verbatim: *"Since bucket length is in the
  order of hours, this method cannot be used to measure data usage on a fine grained time scale."*
  — https://developer.android.com/reference/android/app/usage/NetworkStatsManager
- `TrafficStats.getUidRxBytes` — *"Starting in Build.VERSION_CODES.N this will only report traffic
  statistics for the calling UID. It will return UNSUPPORTED for all other UIDs for privacy
  reasons."* — https://developer.android.com/reference/android/net/TrafficStats
- `querySummary(type, null, start, end)` returns a bucket per UID for every app of the calling user,
  and the manager sets `setPollOnOpen(true)`. **Whether a forced poll exposes the in-progress bucket
  is undocumented.** → this is now the live experiment (I-60).
- `VpnService` works and attributes by construction via `addAllowedApplication()`;
  `ConnectivityManager.getConnectionOwnerUid()` (API 29) exists expressly as the replacement for
  `/proc/net` reads.
- Play policy lists **"App usage tracking"** as a permitted VpnService category, but requires the app
  *"must encrypt the data from the device to the VPN tunnel endpoint"* — awkward for a local-only
  tunnel, and the largest single review risk.
  — https://support.google.com/googleplay/android-developer/answer/12564964
- Android 16 behaviour changes: **nothing** affecting per-app network observation.

**iOS**

- **No equivalent of `AccessibilityService` exists at any tier, including MDM.** The Android design
  does not port. *"If a third-party app needs to access information other than its own, it does so
  only by using services explicitly provided by iOS"* —
  https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- `NEPacketTunnelProvider` is the only Network Extension provider usable on an unmanaged consumer
  iPhone. Content filter is supervised-only, app proxy is *"managed devices only"*, DNS proxy is
  supervised-only, transparent proxy does not exist on iOS.
  — https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
- Per-app attribution needs per-app VPN mode, which needs a managed device. So on iPhone we can
  identify the **service**, not the app.
- **ASRG 5.4:** *"Apps offering VPN services must utilize the NEVPNManager API and may only be
  offered by developers enrolled as an organization."* — https://developer.apple.com/app-store/review/guidelines/
  → **registering the company is a precondition for iOS, not a nice-to-have.**
- Safari Web Extensions ship on iPhone, so the existing extension ports — web only, Safari only,
  non-persistent background pages, per-site permission prompts.
- Family Controls / DeviceActivity gives per-app **time**, never bytes, and the report extension's
  sandbox stops the host app reading the values.

**Decisions:** the VPN route is the only architecture consistent across both phones (I-60).
Accessibility becomes an Android fallback, not the foundation. Run the `querySummary` polling
experiment before committing to a tunnel.

**What would change our mind next pass:** Apple relaxing per-app attribution outside MDM; Google
clarifying the tunnel-endpoint encryption clause for on-device-only VPNs; the polling experiment
succeeding, which removes the need for either.

**Next pass due:** 2026-10-08.
