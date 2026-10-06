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
