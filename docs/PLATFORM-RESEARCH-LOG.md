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

## 2026-10-28 — scheduled three-day pass (all five areas)

**Trigger:** the standing cadence (automated run). Brief from 10-25: (1) the live chatgpt.com and
gemini.google.com pickers (I-69); (2) Mouli's answer on reasoning levels; (3) an on-device
VpnService exemption, or `PACKAGE_USAGE_STATS` named in a declaration requirement; (4) India in a
developer-verification wave; (5) an Android 18 preview page, or a QPR2 behaviour change touching
usage stats or accessibility; (6) iOS 27.2 final or a 27.3 beta touching NetworkExtension or Screen
Time; (7) a production input-vs-output token energy split; (8) a working direct fetch for my own
verification.

**Answer: nothing moved that affects our plan.** Every Android, Chrome-policy and desktop item is
unchanged. **iOS 27.2 shipped final on 26 Oct** (brief 6). Its release notes have nothing on
NetworkExtension, Screen Time or Safari extensions. ChatGPT added a model, GPT-6.1 Terra, on 26
Oct, but it is for Work and Codex and *"not available in Chat"*, so our picker reading is not
affected. `ISSUES.md` and the matrix are untouched, because nothing shipped is invalidated.
**One record is still unresolved:** whether Greenpixie 2609.33965 has a v2 (see The numbers). It
decides nothing.

**Method note.** Three parallel sub-sweeps (Android; iOS; extension + desktop + numbers), all with a
cache-busting query string. The OpenAI help pages, the gitiles `ConnectivityManager.java`, the
Android 18 status and the arXiv pages were read in a browser tab, because the fetcher returned empty
or truncated pages. **Brief 8: partly working.** I re-read the decisive iOS items myself: the
releases RSS feed and the 27.2 release-notes JSON. Both are quoted below. My arXiv re-read hit the
fetcher's rate limit (HTTP 429) three times and returned one empty page. **Not done:** the live
chatgpt.com and gemini.google.com pickers. They need a signed-in browser, which an unattended run
does not have. Brief 2 (Mouli's answer) is not in `ISSUES.md`; I-69 is unchanged since 10-19.

**Android** — *(sub-sweep)*, all unchanged

- **VpnService policy: unchanged, and still no on-device exemption (brief 3: no).** *"Only apps that use the
  VpnService and have VPN as their core functionality can create a secure device-level tunnel to a
  remote server."* "App usage tracking" is still listed. *"must encrypt the data from the device to
  the VPN tunnel endpoint"* is still there, and both videos are still *"(90 seconds or shorter)"*. The page
  has no wording about local, on-device or loopback VPNs. —
  https://support.google.com/googleplay/android-developer/answer/12564964. Policy Center: *"Must
  encrypt the data from the device to VPN tunnel end point"*. The "Changes are coming" banner still
  lists only Location and Contacts, effective 27 Jan 2027. —
  https://support.google.com/googleplay/android-developer/answer/16558241
- **Accessibility policy: unchanged.** *"Other examples of apps that are not accessibility tools
  are: antivirus software, automation tools, assistants, monitoring apps, cleaners, password
  managers, and launchers."* — https://support.google.com/googleplay/android-developer/answer/10964491
- **Play Protect: unchanged** ("Last updated 2026-08-18"). *"Note: This protection is active in
  select markets."* The blocked permissions are the same four, including ACCESSIBILITY. —
  https://developers.google.com/android/play-protect/warning-dev-guidance
- **Developer verification: unchanged, and India is still not named (brief 4: no).** *"Protections begin for
  all users who install apps from participating stores in Brazil, Indonesia, Singapore, and Thailand
  on certified devices running Android 7+."* and *"Verification capability will be expanded globally
  for all apps on certified Android devices in 2027."* The FAQ is still "Last updated 2026-09-30". The
  Guides page ("Last updated 2026-08-18") names the same four countries. —
  https://developer.android.com/developer-verification,
  https://developer.android.com/developer-verification/guides/faq
- **`getConnectionOwnerUid`: unchanged.** *"@throws SecurityException if the caller is not the active
  VpnService for the current user."* —
  https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework/src/android/net/ConnectivityManager.java
- **`NetworkStatsManager` / `TrafficStats`: unchanged** (from AOSP source). *"Since bucket length is
  in the order of hours, this method cannot be used to measure data usage on a fine grained time
  scale."* and *"Starting in {@link android.os.Build.VERSION_CODES#N} this will only report traffic
  statistics for the calling UID."* — …/framework-t/src/android/app/usage/NetworkStatsManager.java,
  …/framework-t/src/android/net/TrafficStats.java
- **`UsageStatsManager`: unchanged.** *"Query for events in the given time range. Events are only
  kept by the system for a few days."* —
  https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/app/usage/UsageStatsManager.java
- **`PACKAGE_USAGE_STATS` on Play: still not named (brief 3: no).** *"If your app requests the use of
  high-risk or sensitive permissions (for example, SMS or Call Log), you may be required to complete
  the Permissions Declaration Form"*. The Policy Center has no match for it either. —
  https://support.google.com/googleplay/android-developer/answer/9214102. This is an absence, not a
  quote. Re-check before the P10 declaration.
- **Newest API level: unchanged; no Android 18 page (brief 5: no).** The Android 17 page is still
  "Last updated 2026-10-23", and its only network line is still *"Beginning with Android 17,
  cross-profile loopback traffic is no longer permitted by default."* /about/versions/18 returns HTTP
  404. **New to this log:** the QPR2 release notes (Beta 7.1, "Last updated 2026-10-16") say *"This
  incremental update has no planned behavior changes, minimizing the need for compatibility
  testing."* Their only accessibility item is a bug fix in `AccessibilityNodeInfo.toString()`. —
  https://developer.android.com/about/versions/17/behavior-changes-all,
  https://developer.android.com/about/versions/17/qpr2/release-notes
- **Play target API: unchanged** ("Last updated 2026-10-16"). *"Starting August 31 2026: New apps
  and app updates must target Android 16 (API level 36) or higher to be submitted to Google Play"*.
  There is no API 37 deadline yet. — https://developer.android.com/google/play/requirements/target-sdk

**iOS** — *(sub-sweep; release feed and release notes re-read by me)*

- **iOS 27.2 is final, and nothing in it is for us (brief 6: answered, no).** Feed, read by me:
  *"iOS 27.2 (24B119)"* and *"iOS 27.2 (24B91020)"*, both *"Mon, 26 Oct 2026 10:00:00 PDT"*, with
  lastBuildDate *"Mon, 26 Oct 2026 10:00:00 PDT"*. There is no 27.3 beta, and Xcode is still at
  *"Xcode 27.2 RC (27B48)"*. — https://developer.apple.com/news/releases/rss/releases.rss. The
  release notes, read by me, have the same sections as at RC: App Tracking Transparency, Health,
  Nearby Interaction, Quest Lab Appointments, Shortcuts, Simulator, StoreKit Testing in Xcode,
  UIKit. Nothing is on NetworkExtension, Screen Time or Safari extensions. The page still says *"The
  redesigned Health app is not included in this beta"*, so it may not yet be revised for final. —
  https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27_2-release-notes
- **TN3134: unchanged.** The latest revision is still 2025-08-19, the packet tunnel row still says
  *"per-app mode requires managed device"*, and there are no new provider types. —
  https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
- **Per-app VPN: unchanged.** *"To use per-app VPN in iOS, iPadOS, watchOS 10, and visionOS 1.1, a
  device management service needs to manage the app."* — https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web
- **App Review Guidelines: unchanged** ("Last Updated: October 16, 2026"). 5.4: *"Apps offering VPN
  services must utilize the NEVPNManager API and may only be offered by developers enrolled as an
  organization."* 5.5: *"Such apps may only be offered by commercial enterprises, educational
  institutions, or government agencies, and in limited cases, companies using MDM for parental
  control services or device security."* — https://developer.apple.com/app-store/review/guidelines/
- **DeviceActivityReport: unchanged.** *"This sandbox prevents your extension from making network
  requests or moving sensitive content outside the extension's address space."* —
  https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
- **Safari Web Extensions: unchanged.** *"In iOS, you must make your background page
  nonpersistent."* — https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari
- **Reading another app's content: still nothing.** *"If a third-party app needs to access
  information other than its own, it does so only by using services explicitly provided by iOS,
  iPadOS, and visionOS."* — https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- **Developer news: nothing after 22 Oct.** The newest item is still "Offer your subscriptions to
  businesses and schools". — https://developer.apple.com/news/rss/news.rss

**Browser extension** — *(sub-sweep)*

- **MV3: unchanged.** The newest "What's new" entry is still Chrome 153 (25 Aug). *"After 30 seconds
  of inactivity. Receiving an event or calling an extension API resets this timer."* —
  https://developer.chrome.com/docs/extensions/whats-new,
  https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle
- **Web Store policy: unchanged** ("Last updated 2025-05-22"). *"Request access to the narrowest
  permissions necessary to implement your Product's features or services."* —
  https://developer.chrome.com/docs/webstore/program-policies/policies
- **ChatGPT: three new entries, none in Chat (brief 1 still open).** 21 Oct "MoMo payments in
  Vietnam" (billing); 26 Oct "GPT-6.1 Terra"; 27 Oct "iCloud Mail and Calendar plugins" (connectors).
  The models article now says *"GPT-6.1 Terra is a model option for ChatGPT Work and Codex. It is not
  available in Chat."* The Terra note also mentions a level called "Light" in Work's Power presets,
  which is not one of the Chat names. The Chat level names are unchanged: *"When **GPT-6** is
  selected, **GPT-6 Sol** powers **Instant**, **Medium**, **High**, and **Extra High**; **Pro** uses
  GPT-6 Pro, powered by **GPT-6 Astra**."* The article still does not say where the chosen level is
  shown. **Reading:** we read the Chat surface, so Terra and "Light" do not reach our tier table.
  If Terra later comes to Chat, the vendor map will not know its name. —
  https://help.openai.com/en/articles/6825453-chatgpt-release-notes,
  https://help.openai.com/en/articles/20001354-gpt-6-and-other-models-in-chatgpt
- **Gemini: unchanged.** The newest release note is still 2026.10.13 (Argon). The models page still has
  *"Low, Medium, High"* and *"If you don't select a thinking level, it will default to Low."* —
  https://gemini.google/release-notes/, https://support.google.com/gemini/answer/18648722
- **Claude: unchanged.** The newest release note is still 21 Oct (Claude Duet). —
  https://support.claude.com/en/articles/12138966-release-notes

**Desktop** — *(sub-sweep)*, all unchanged

- *"The SetPerTcpConnectionEStats function can only be called by a user logged on as a member of the
  Administrators group."* — https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getpertcpconnectionestats
- *"EV certificates no longer bypass SmartScreen."* — https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation.
  Artifact Signing: *"Individual developers must be located in the United States or Canada."* The
  Public Trust list still excludes India. — https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart
- *"Beginning in macOS 10.15, all software built after June 1, 2019, and distributed with Developer
  ID must be notarized."* — https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

**The numbers** — *(sub-sweep)*

- **Brief 7: no production input/output split, and no new vendor or peer-reviewed per-query energy or
  water figure after 25 Oct.**
- **Greenpixie 2609.33965: unresolved.** Read in a browser tab, the sub-sweep saw *"[v2] Tue, 29 Sep
  2026 16:02:14 UTC (339 KB)"*. It also reported that the fetcher served an older copy that showed
  only v1. That would explain why the 10-22 and 10-25 entries said "only v1" against the 10-19 entry.
  My own re-read failed (HTTP 429 three times, one empty page). The two versions are the same size,
  and the abstract is reported unchanged. **It decides nothing**, because we do not use its figure. The
  next pass should settle it in a browser tab. — https://arxiv.org/abs/2609.33965
- 2508.15734 is still v1, 2509.20241 is still v2 (Joule), and 2610.19819 is still v1.
- **Not in earlier entries (dated 20 Oct):** arXiv 2610.28576, "The Token-Energy Law of LLM Decode".
  It is a lab benchmark on Hopper and Blackwell GPUs that measures decode (output) tokens only, so it
  gives no input/output split. *"Using fixed coefficients and observed decode time, held-out
  condition-mean energy estimates differ from measurements by at most 3.73%."* —
  https://arxiv.org/abs/2610.28576. It does not bear on D-22.

**Decisions:**
- **No change anywhere.** D-22 stays at 5×, and the I-69 interim rule stands. Usage Access stays the
  default estimate and accessibility stays the exact Android sensor. The tunnel stays parked behind
  the endpoint-encryption clause, and the iPhone plan is unchanged. `ISSUES.md` and
  `TRACEABILITY.md` are untouched.
- The two Android follow-ups from 10-22 are still with the Android track. This pass did not touch code.

**What would change our mind next pass:** (1) the live chatgpt.com and gemini.google.com pickers
(I-69), which need an attended, signed-in session; (2) Mouli's answer on which levels count as
reasoning; (3) GPT-6.1 Terra, or the "Light" level, reaching Chat; (4) Play adding an on-device
VpnService exemption, or naming `PACKAGE_USAGE_STATS` in a declaration requirement; (5) India in a
developer-verification wave; (6) an Android 18 preview page, or a QPR3 beta with behaviour changes;
(7) a 27.3 beta, or a revised 27.2 release-notes page, touching NetworkExtension or Screen Time;
(8) any production (batched) input-vs-output token energy split; (9) settling the 2609.33965 v2
question in a browser tab.

**Next pass due:** 2026-10-31.

## 2026-10-25 — scheduled three-day pass (all five areas)

**Trigger:** the standing cadence (automated run). Brief from 10-22: (1) the live chatgpt.com and
gemini.google.com pickers (I-69); (2) Mouli's answer on reasoning levels; (3) an on-device
VpnService exemption, or `PACKAGE_USAGE_STATS` named in a declaration requirement; (4) India in a
developer-verification wave; (5) an Android 18 preview page; (6) iOS 27.2 final or a 27.3 beta
touching NetworkExtension or Screen Time; (7) a production input-vs-output token energy split;
(8) a re-read of `getConnectionOwnerUid`.

**Answer: nothing moved that affects our plan.** Every item in all five areas is unchanged. The only
movement is two page edits with no relevant content: Android 17's behaviour-changes page has a new
"Last updated" date, and OpenAI's GPT-6 models article was edited on the day of this pass without
changing the level names or saying where the level is shown. Brief item 8 is now closed:
`getConnectionOwnerUid` was read in full for the first time since 10-19. `ISSUES.md` and the matrix
are untouched, because nothing shipped is invalidated.

**Method note.** Three parallel sub-sweeps (Android; iOS; extension + desktop + numbers), all with a
cache-busting query string. Apple pages were read through their JSON/.md data endpoints. The
`ConnectivityManager.java` source was decoded in full in a browser tab, as the 10-22 brief
suggested. **My own verification fetches all failed this pass** ("operation was aborted", three
attempts on developer.android.com and one on support.google.com). So I verified differently: I
grepped this log for the two sentences the sub-sweeps flagged as possibly new, and both were already
on record (accessibility "autonomously initiate…" at 10-07 and 10-19; "Starting in Android 18…" at
10-13). No decision rests on the two items I could not re-read myself. Both are date or edit stamps,
not content. **Not done:** the live chatgpt.com and gemini.google.com pickers. They need a signed-in
browser, which an unattended run does not have.

**Android** — *(sub-sweep)*

- **VpnService policy: unchanged, and still no on-device exemption (brief 3: no).** *"Only apps that use the
  VpnService and have VPN as their core functionality can create a secure device-level tunnel to a
  remote server."* "App usage tracking" is still listed. *"must encrypt the data from the device to
  the VPN tunnel endpoint"* is still there, and both videos are still *"(90 seconds or shorter)"*. The only "on-device" match on the page is
  about Health Connect. — https://support.google.com/googleplay/android-developer/answer/12564964.
  Policy Center: *"Must encrypt the data from the device to VPN tunnel end point"*. Its "Changes are
  coming" banner still lists only Location and Contacts, effective 27 Jan 2027. —
  https://support.google.com/googleplay/android-developer/answer/16558241
- **Accessibility policy: unchanged.** *"Other examples of apps that are not accessibility tools
  are: antivirus software, automation tools, assistants, monitoring apps, cleaners, password
  managers, and launchers."* — https://support.google.com/googleplay/android-developer/answer/10964491
- **Play Protect: unchanged** ("Last updated 2026-08-18"). *"Note: This protection is active in
  select markets."* The blocked permissions are still RECEIVE_SMS, READ_SMS, NOTIFICATION_LISTENER and
  ACCESSIBILITY. — https://developers.google.com/android/play-protect/warning-dev-guidance
- **Developer verification: unchanged, and India is still not named (brief 4: no).** *"Protections begin for
  all users who install apps from participating stores in Brazil, Indonesia, Singapore, and Thailand
  on certified devices running Android 7+."* and *"Verification capability will be expanded globally
  for all apps on certified Android devices in 2027."* The FAQ is still "Last updated 2026-09-30". —
  https://developer.android.com/developer-verification,
  https://developer.android.com/developer-verification/guides/faq
- **`getConnectionOwnerUid`: re-read in full, unchanged in meaning (brief 8: closed).** *"@throws
  SecurityException if the caller is not the active VpnService for the current user."* and *"@return
  {@code uid} if the connection is found and the app has permission to observe it (e.g., if it is
  associated with the calling VPN app's VpnService tunnel) or {@link
  android.os.Process#INVALID_UID} if the connection is not found."* —
  https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework/src/android/net/ConnectivityManager.java.
  It is still usable only from inside our own tunnel, so it adds nothing outside the parked tunnel
  design.
- **`NetworkStatsManager` / `TrafficStats`: unchanged** (from AOSP source). *"Since bucket length
  is in the order of hours, this method cannot be used to measure data usage on a fine grained time
  scale."*; *"Starting in {@link android.os.Build.VERSION_CODES#N} this will only report traffic
  statistics for the calling UID. It will return {@link #UNSUPPORTED} for all other UIDs for privacy
  reasons."* —
  https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework-t/src/android/app/usage/NetworkStatsManager.java,
  …/framework-t/src/android/net/TrafficStats.java
- **`UsageStatsManager` (estimate mode, I-73): unchanged.** *"Query for events in the given time
  range. Events are only kept by the system for a few days."* —
  https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/app/usage/UsageStatsManager.java
- **`PACKAGE_USAGE_STATS` on Play: still not named (brief 3: no).** The only examples on the Permissions
  Declaration page are in *"high-risk or sensitive permissions (for example, SMS or Call Log)"*. —
  https://support.google.com/googleplay/android-developer/answer/9214102. As on 10-22, this is an
  absence, not a quote. Re-check before the P10 declaration.
- **Newest API level: content unchanged, date bumped.** The Android 17 page is now "Last updated
  2026-10-23" (it was 2026-10-16). Its only network line is unchanged: *"Beginning with Android 17,
  cross-profile loopback traffic is no longer permitted by default."* It adds no VPN, traffic-stats
  or usage-stats item. The sidebar now lists QPR2 Beta (API 37.2). /about/versions/18 returns 404
  (brief 5: no). — https://developer.android.com/about/versions/17/behavior-changes-all
- **Play target API: unchanged.** *"Starting August 31 2026: New apps and app updates must target
  Android 16 (API level 36) or higher to be submitted to Google Play"*. There is no API 37 deadline yet. —
  https://developer.android.com/google/play/requirements/target-sdk

**iOS** — *(sub-sweep)*, all unchanged

- **TN3134:** the latest revision is still 2025-08-19. The packet tunnel row still says *"per-app mode
  requires managed device"*, and there are no new provider types. —
  https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
- **Per-app VPN:** *"To use per-app VPN in iOS, iPadOS, watchOS 10, and visionOS 1.1, a device
  management service needs to manage the app."* — https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web
- **App Review Guidelines:** still "Last Updated: October 16, 2026". 5.4: *"Apps offering VPN services must
  utilize the NEVPNManager API and may only be offered by developers enrolled as an organization."*
  5.5 is unchanged (MDM limited to *"commercial enterprises, educational institutions, or government
  agencies"*). — https://developer.apple.com/app-store/review/guidelines/
- **DeviceActivityReport:** *"This sandbox prevents your extension from making network requests or
  moving sensitive content outside the extension's address space."* —
  https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
- **Safari Web Extensions:** *"In iOS, you must make your background page nonpersistent."* —
  https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari
- **Reading another app's content: still nothing.** *"If a third-party app needs to access
  information other than its own, it does so only by using services explicitly provided by iOS,
  iPadOS, and visionOS."* — https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- **iOS 27.2: still at RC (brief 6: no).** The newest iOS item in the feed is still *"iOS 27.2 RC
  (24B115)"*, dated 19 Oct. The feed was last built *"Thu, 22 Oct 2026 14:00:00 PDT"*, and the only
  newer items are TestFlight 4.4.1 and an App Store Connect update. The release-notes index has no
  page for 27.2 final or 27.3. — https://developer.apple.com/news/releases/rss/releases.rss
- **Developer news:** the only item after 16 Oct is "Offer your subscriptions to businesses and
  schools" (22 Oct, about multiseat subscriptions). It is not relevant to us. —
  https://developer.apple.com/news/rss/news.rss

**Browser extension** — *(sub-sweep)*

- **MV3: unchanged.** The newest "What's new" entry is still Chrome 153 (25 Aug). The service-worker
  lifecycle page still says *"After 30 seconds of inactivity. Receiving an event or calling an
  extension API resets this timer."* —
  https://developer.chrome.com/docs/extensions/whats-new,
  https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle
- **Web Store policy: unchanged** ("Last updated 2025-05-22"). *"Request access to the narrowest
  permissions necessary to implement your Product's features or services."* —
  https://developer.chrome.com/docs/webstore/program-policies/policies
- **ChatGPT: no new release-note entry since 20 Oct, and the models article was edited (brief 1 still
  open).** The article was "Updated: 23 minutes ago" when fetched. The level names are unchanged: *"When **GPT-6** is
  selected, **GPT-6 Sol** powers **Instant**, **Medium**, **High**, and **Extra High**; **Pro** uses
  GPT-6 Pro, powered by **GPT-6 Astra**."* It still reads *"Use the **Thinking** slider to choose
  your effort"*. The FAQ adds *"Use the model picker to choose how much ChatGPT thinks."* None of
  this says which element shows the chosen level, and what the edit changed is unknown. Our interim rule maps
  every one of these names, so nothing breaks. —
  https://help.openai.com/en/articles/6825453-chatgpt-release-notes,
  https://help.openai.com/en/articles/20001354-gpt-6-and-other-models-in-chatgpt
- **Gemini: unchanged.** The newest release note is still 2026.10.13 (Argon). The models page still has
  *"Low, Medium, High"* and *"Tip: If you don't select a thinking level, it will default to Low."* —
  https://gemini.google/release-notes/, https://support.google.com/gemini/answer/18648722
- **Claude: unchanged.** The newest release note is still 21 Oct (Claude Duet), and nothing touches
  the composer or the picker. — https://support.claude.com/en/articles/12138966-release-notes

**Desktop** — *(sub-sweep)*, all unchanged

- *"The SetPerTcpConnectionEStats function can only be called by a user logged on as a member of the
  Administrators group."* — https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getpertcpconnectionestats
- *"EV certificates no longer bypass SmartScreen."* — https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation.
  Artifact Signing: *"Individual developers must be located in the United States or Canada."* The
  Public Trust country list is unchanged, and India is still excluded. — https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart
- *"Beginning in macOS 10.15, all software built after June 1, 2019, and distributed with Developer
  ID must be notarized."* — https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

**The numbers** — *(sub-sweep)*, unchanged

- No paper on our list has a new version. 2609.33965 still shows only *"[v1] Sun, 27 Sep 2026 22:10:47 UTC (339 KB)"*.
  2508.15734 is still v1, 2509.20241 still v2 (Joule) and 2610.19819 still v1. — https://arxiv.org/abs/2609.33965
  and siblings.
- **Brief 7: no production input/output split, and no new vendor or peer-reviewed per-query energy or
  water figure since 19 Oct.** The nearest work is still 2610.19819, which is a lab measurement on
  A100s, not production. The search index may lag a few days.

**Decisions:**
- **No change anywhere.** D-22 stays at 5×, and the I-69 interim rule stands. Usage Access stays the
  default estimate and accessibility stays the exact Android sensor. The tunnel stays parked behind
  the endpoint-encryption clause, and the iPhone plan is unchanged. `ISSUES.md` and `TRACEABILITY.md`
  are untouched.
- The two Android follow-ups from 10-22 (estimate-mode copy about the "few days" limit, and pairing
  resume/pause per package) are still with the Android track. This pass did not touch code.

**What would change our mind next pass:** (1) the live chatgpt.com and gemini.google.com pickers,
and which element shows the thinking level (I-69). This needs a signed-in browser, so it is a job for
an attended session, not this cadence. (2) Mouli's answer on which levels count as reasoning. (3) Play adding an
on-device VpnService exemption, or naming `PACKAGE_USAGE_STATS` in a declaration requirement.
(4) India in a developer-verification wave. (5) An Android 18 preview page, or a QPR2 behaviour change
touching usage stats or accessibility. (6) iOS 27.2 final or a 27.3 beta touching NetworkExtension or
Screen Time. (7) Any production (batched) input-vs-output token energy split. (8) A working direct
fetch for my own verification, since this pass's failed.

**Next pass due:** 2026-10-28.

## 2026-10-22 — scheduled three-day pass (all five areas)

**Trigger:** the standing cadence (automated run). Brief from 10-19: (1) the live chatgpt.com and
gemini.google.com pickers (I-69); (2) Mouli's answer on which levels are reasoning; (3) an on-device
VpnService exemption; (4) India in a developer-verification wave; (5) an Android 18 preview page;
(6) iOS 27.2 RC notes touching NetworkExtension or Screen Time; (7) a production (batched)
output-vs-input token energy measurement. **Added this pass:** Rel 1.4's estimate mode (I-73) now
depends on `UsageStatsManager` and `PACKAGE_USAGE_STATS`, so both join the Android checklist.

**Answer: nothing moved that affects our plan.** Every Android, iOS, Chrome-policy and desktop item
is unchanged. Two new vendor release-note entries (ChatGPT locked chats, 20 Oct; Claude Duet, 21
Oct) do not touch any picker or composer. **Two corrections to the 10-19 entry**, both verified by
me: iOS 27.2 was already at RC on 19 Oct (not Beta 4), and Greenpixie 2609.33965 has **no v2** —
the 10-19 "correction" was itself wrong. `ISSUES.md` and the matrix are untouched: nothing shipped
is invalidated.

**Method note.** Three parallel sub-sweeps (Android; iOS; extension + desktop + numbers), all with a
cache-busting query string. I re-read the two items that differ from the last entry myself: the
arXiv abstract page for 2609.33965 and Apple's releases RSS feed. The developer.android.com
reference pages returned navigation only, so the Android API quotes this pass come from the AOSP
source on android.googlesource.com (same Javadoc). **Not done:** `getConnectionOwnerUid` (truncated
in both places — **not checked**, not "unchanged"); the live chatgpt.com and gemini.google.com
pickers (need a signed-in browser; not done on an unattended run).

**Android** — *(sub-sweep)*

- **VpnService policy — unchanged; no on-device exemption (brief 3: no).** *"Only apps that use the
  VpnService and have VPN as their core functionality can create a secure device-level tunnel to a
  remote server."*; "App usage tracking" still listed; *"must encrypt the data from the device to the
  VPN tunnel endpoint"*; both videos *"(90 seconds or shorter)"*. —
  https://support.google.com/googleplay/android-developer/answer/12564964; Policy Center same
  (*"Must encrypt the data from the device to VPN tunnel end point"*) —
  https://support.google.com/googleplay/android-developer/answer/16558241. "Changes are coming"
  banner unchanged (Location, Contacts; 27 Jan 2027).
- **Accessibility policy — unchanged.** *"Google Play permits the use of the AccessibilityService
  API for a wide range of applications."*; *"Other examples of apps that are not accessibility tools
  are: antivirus software, automation tools, assistants, monitoring apps, cleaners, password
  managers, and launchers."* — https://support.google.com/googleplay/android-developer/answer/10964491
- **Play Protect — unchanged** ("Last updated 2026-08-18"). *"Note: This protection is active in
  select markets."* — https://developers.google.com/android/play-protect/warning-dev-guidance
- **Developer verification — unchanged; India not named (brief 4: no).** *"Protections begin for
  all users who install apps from participating stores in Brazil, Indonesia, Singapore, and Thailand
  on certified devices running Android 7+."*; FAQ ("Last updated 2026-09-30") *"if users sideload
  your app directly, these new verification requirements won't apply to your app yet."* —
  https://developer.android.com/developer-verification,
  https://developer.android.com/developer-verification/guides/faq
- **`getConnectionOwnerUid` — NOT CHECKED this pass** (reference page and AOSP file both truncated
  before the method). Last verified 10-19.
- **`NetworkStatsManager` / `TrafficStats` — unchanged** (from AOSP source). *"Since bucket length
  is in the order of hours, this method cannot be used to measure data usage on a fine grained time
  scale."*; *"Starting in {@link android.os.Build.VERSION_CODES#N} this will only report traffic
  statistics for the calling UID."* —
  https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework-t/src/android/app/usage/NetworkStatsManager.java,
  …/framework-t/src/android/net/TrafficStats.java
- **`UsageStatsManager` (estimate mode, I-73) — first entry here; consistent with what we built.**
  *"Query for events in the given time range. Events are only kept by the system for a few days."*
  and *"Starting from {@link android.os.Build.VERSION_CODES#R Android R}, if the user's device is not
  in an unlocked state … then {@code null} will be returned."* —
  https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/app/usage/UsageStatsManager.java.
  `ACTIVITY_RESUMED` / `ACTIVITY_PAUSED` are *"reported for each activity that moves to foreground"*
  (`onResume()` / `onPause()`) — …/core/java/android/app/usage/UsageEvents.java. **Reading:** we
  harvest when the app is opened, so the device is unlocked (the `null` case does not arise); but
  "a few days" means **minutes in AI apps are lost if Sipcount is not opened for several days** —
  an under-count, never an over-count, and already implicit in I-73's design. Worth one line in the
  estimate-mode copy, not a change. Multiple activities per package each fire events, so the
  harvest must pair per package, not per event — to confirm in `UsageHarvest` on the next Android
  session (not checked here; no code was read for this).
- **`PACKAGE_USAGE_STATS` on Play — no declaration requirement found.** The Permissions Declaration
  page names only *"high-risk or sensitive permissions (for example, SMS or Call Log)"* —
  https://support.google.com/googleplay/android-developer/answer/9214102; the Policy Center page has
  no match for "usage access" or "UsageStats". Absence of a match is weaker than a quote: re-check
  before the P10 declaration. Consistent with I-73's "not on Play's sensitive-permissions list".
- **Newest API level — unchanged** (Android 17 page "Last updated 2026-10-16", same as 10-19); no
  Android 18 page (brief 5: no, empty body). Only network line still *"Beginning with Android 17,
  cross-profile loopback traffic is no longer permitted by default."* —
  https://developer.android.com/about/versions/17/behavior-changes-all
- **Play target API — unchanged.** *"Starting August 31 2026: New apps and app updates must target
  Android 16 (API level 36) or higher to be submitted to Google Play"*; no API 37 deadline yet. —
  https://developer.android.com/google/play/requirements/target-sdk

**iOS** — *(sub-sweep; release feed re-read by me)*

- **TN3134 — unchanged.** Latest revision still 2025-08-19; *"per-app mode requires managed
  device"*; no new provider types. —
  https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
- **Per-app VPN — unchanged.** *"To use per-app VPN in iOS, iPadOS, watchOS 10, and visionOS 1.1, a
  device management service needs to manage the app."* — https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web
- **App Review Guidelines — unchanged since 16 Oct** ("Last Updated: October 16, 2026"). 5.4 *"Apps
  offering VPN services must utilize the NEVPNManager API and may only be offered by developers
  enrolled as an organization."*; 2.5.19 as recorded. — https://developer.apple.com/app-store/review/guidelines/
- **Family Controls / DeviceActivity — unchanged.** *"This sandbox prevents your extension from
  making network requests or moving sensitive content outside the extension's address space."* —
  https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
- **Safari Web Extensions — unchanged.** *"In iOS, you must make your background page
  nonpersistent."* — https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari
- **Reading another app's content — still nothing.** *"If a third-party app needs to access
  information other than its own, it does so only by using services explicitly provided by iOS,
  iPadOS, and visionOS."* — https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- **iOS 27.2 — at RC, nothing for us (brief 6: answered, no).** Feed, read by me: *"iOS 27.2 RC
  (24B115)"*, pubDate *"Mon, 19 Oct 2026 10:00:00 PDT"* — https://developer.apple.com/news/releases/rss/releases.rss.
  **Correction to 10-19**, which said "still Beta 4". RC release notes sections *(sub-sweep)*: App
  Tracking Transparency, Health, Nearby Interaction, Quest Lab Appointments, Shortcuts, Simulator,
  StoreKit Testing, UIKit — nothing on NetworkExtension, Screen Time or Safari extensions. —
  https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27_2-release-notes
- **Developer news — nothing after 16 Oct** relevant to us (newest relevant: guideline update and
  2.5.19 post, both 16 Oct). — https://developer.apple.com/news/

**Browser extension** — *(sub-sweep)*

- **MV3 — unchanged.** Newest "What's new" still Chrome 153 (25 Aug). *"After 30 seconds of
  inactivity. Receiving an event or calling an extension API resets this timer."* —
  https://developer.chrome.com/docs/extensions/whats-new,
  https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle
- **Web Store policy — unchanged** ("Last updated 2025-05-22"). *"Request access to the narrowest
  permissions necessary to implement your Product's features or services."* —
  https://developer.chrome.com/docs/webstore/program-policies/policies
- **ChatGPT — one new entry, not for us (brief 1 still open).** 20 Oct "Introducing locked chats"
  (PIN-hidden chats via the ••• menu). The GPT-6 article was edited today but still reads *"Use the
  **Thinking** slider to choose your effort."* and still does not say where the chosen level is
  shown. It now also has a section *"GPT-6.1 Sol is a model option for ChatGPT Work and Codex"* —
  outside the chat surface we read; not yet known when it was added. —
  https://help.openai.com/en/articles/6825453-chatgpt-release-notes,
  https://help.openai.com/en/articles/20001354-gpt-6-and-other-models-in-chatgpt
- **Gemini — unchanged.** Release notes newest still 2026.10.13 (Argon). Models help still *"Low,
  Medium, High"* for every plan and *"Tip: If you don't select a thinking level, it will default to
  Low."*; models still Flash-Lite, Flash, Pro, Argon. — https://gemini.google/release-notes/,
  https://support.google.com/gemini/answer/18648722
- **Claude — one new entry, not for us.** 21 Oct: *"Claude Duet research preview for Pro and Max
  plans… a new app where Claude works as a proactive agent."* A separate app, not claude.ai's
  composer; no picker or extended-thinking change. If Duet later surfaces inside claude.ai, unseen
  agent work is what N9's timing rule already charges. —
  https://support.claude.com/en/articles/12138966-release-notes

**Desktop** — *(sub-sweep)* all unchanged

- *"The SetPerTcpConnectionEStats function can only be called by a user logged on as a member of the
  Administrators group."* — https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getpertcpconnectionestats
- *"EV certificates no longer bypass SmartScreen."* — https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation;
  Artifact Signing (metadata updated 2026-10-08, text unchanged): *"Individual developers must be
  located in the United States or Canada."*; *"Public Trust certificates are available to
  organizations in the United States, Canada, the European Union, the United Kingdom, Australia, New
  Zealand, Japan, South Korea, Singapore, Switzerland, Norway, and Israel."* — India still excluded.
  — https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart
- *"Beginning in macOS 10.15, all software built after June 1, 2019, and distributed with Developer
  ID must be notarized."* — https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

**The numbers**

- **Greenpixie 2609.33965 — only v1 exists (read by me).** Submission history lists one version:
  *"[v1] Sun, 27 Sep 2026 22:10:47 UTC (339 KB)"* — https://arxiv.org/abs/2609.33965. **Correction
  to the 10-19 entry**, whose "v2 dated 29 Sep" was wrong; the 10-16 "still v1" was right.
- Google 2508.15734 still v1; Microsoft 2509.20241 still v2; Ruf & Detyniecki 2610.19819 still v1
  *(sub-sweep)*.
- **Brief 7 — no production input/output split.** Nearest item *(sub-sweep; vendor blog, corroborates
  only)*: Crusoe, 9 Oct 2026, a batched production stack (256 concurrent requests, 1,024 in / 256
  out), reports *"26.9% less energy per output token (1.686 → 1.232 J/tok)"* but gives no
  input-vs-output split, no per-query and no water figure — https://www.crusoe.ai/resources/blog/how-green-is-crusoes-inference-engine.
  Does not bear on D-22.
- **No new vendor or peer-reviewed per-query energy or water figure** since 19 Oct.

**Decisions:**
- **No change anywhere.** D-22 stays at 5×; I-69 interim rule (High and above = reasoning) stands;
  accessibility stays the exact Android sensor and Usage Access the default estimate; tunnel stays
  parked behind the endpoint-encryption clause; iPhone plan unchanged. `ISSUES.md` and
  `TRACEABILITY.md` untouched.
- **Two small follow-ups for the Android track, not issues:** say in estimate-mode copy that minutes
  older than a few days can't be recovered if the app isn't opened; and confirm the harvest pairs
  resume/pause per package when an AI app has several activities.

**What would change our mind next pass:** (1) the live chatgpt.com and gemini.google.com pickers —
which element shows the thinking level (I-69); (2) Mouli's answer on which levels are reasoning;
(3) Play adding an on-device VpnService exemption, or naming `PACKAGE_USAGE_STATS` in a declaration
requirement; (4) India in a developer-verification wave; (5) an Android 18 preview page; (6) iOS
27.2 final or a 27.3 beta touching NetworkExtension or Screen Time; (7) any production (batched)
input-vs-output token energy split; (8) `getConnectionOwnerUid` re-read (the fetcher truncated it
again this pass; try a browser tab).

**Next pass due:** 2026-10-25.

## 2026-10-19 — scheduled three-day pass (all five areas)

**Trigger:** the standing cadence (automated run). Brief from 10-16: (1) live chatgpt.com Thinking
element (I-69); (2) live Gemini label for Argon and whether it reasons by default; (3) full text of
arXiv 2610.19819; (4) an on-device VpnService exemption; (5) India in a verification wave; (6)
`getConnectionOwnerUid` re-read; (7) an Android 18 preview page.

**Answer: no platform moved in a way that changes our plan. One thing widens an open issue:**
**Gemini now has a Low / Medium / High thinking level beside every model, exactly like ChatGPT** —
so I-69's silent under-count applies on a second site when a user raises the level. Default is Low,
which we price correctly. Raised in I-69, N13 note corrected (it said "Gemini unaffected"), matrix
and register re-stamped. Apple published new App Review Guidelines on 16 Oct; 5.4/5.5 are
word-for-word unchanged, but a new 2.5.19 (hidden/dormant features) is worth noting for the demo
gate. The paper behind last pass's 150–850× ratio is now read in full: single request, no batching,
7–8B models — it does not describe production serving, which confirms keeping 5×.

**Method note.** Three parallel sub-sweeps (Android; iOS; extension + desktop + numbers). Two pages
were read in a browser tab after the fetcher returned only navigation or hit HTTP 429. I re-read the
two decisive items myself: the Gemini models help page and Apple's 16 Oct guideline changelog.
**Still not done:** the live chatgpt.com and gemini.google.com pickers (need a signed-in browser;
not done on an unattended run).

**Android** — *(sub-sweep)*

- **VpnService policy — unchanged; no on-device exemption (brief 4: no).** *"Only apps that use the
  VpnService and have VPN as their core functionality can create a secure device-level tunnel to a
  remote server."*; "App usage tracking" still listed; *"must encrypt the data from the device to the
  VPN tunnel endpoint"*; both videos *"(90 seconds or shorter)"*. "local"/"on-device" match nothing
  relevant. — https://support.google.com/googleplay/android-developer/answer/12564964; Policy Center
  same (*"Must encrypt the data from the device to VPN tunnel end point"*) —
  https://support.google.com/googleplay/android-developer/answer/16558241. "Changes are coming"
  banner unchanged (Location, Contacts; 27 Jan 2027).
- **Accessibility policy — unchanged.** *"Google Play permits the use of the AccessibilityService
  API for a wide range of applications."* The sub-sweep also recorded, for the first time, *"Any use
  of the Accessibility API that enables an app to autonomously initiate, plan, and execute actions or
  decisions is strictly prohibited."* and that "monitoring apps" are listed among apps that are not
  accessibility tools. Not known to be new (no earlier quote to compare); we initiate no actions, so
  the first does not touch us; the second is the existing declaration risk (I-3). —
  https://support.google.com/googleplay/android-developer/answer/10964491
- **Play Protect — unchanged** ("Last updated 2026-08-18"). *"Note: This protection is active in
  select markets."* — https://developers.google.com/android/play-protect/warning-dev-guidance
- **Developer verification — unchanged; India not named (brief 5: no).** *"Protections begin for
  all users who install apps from participating stores in Brazil, Indonesia, Singapore, and Thailand
  on certified devices running Android 7+."*; FAQ ("Last updated 2026-09-30") *"if users sideload
  your app directly, these new verification requirements won't apply to your app yet."* —
  https://developer.android.com/developer-verification,
  https://developer.android.com/developer-verification/guides/faq
- **`getConnectionOwnerUid` — read at last (brief 6: closed), from the reference page.** *"Returns:
  uid if the connection is found and the app has permission to observe it (e.g., if it is associated
  with the calling VPN app's VpnService tunnel)"*; *"Throws SecurityException if the caller is not the
  active VpnService for the current user."* — https://developer.android.com/reference/android/net/ConnectivityManager#getConnectionOwnerUid(int,%20java.net.InetSocketAddress,%20java.net.InetSocketAddress)
  (Last updated 2026-08-03). Consistent with what we planned: it is a secondary signal **inside** a
  VpnService, not a way round one.
- **`NetworkStatsManager` / `TrafficStats` — unchanged** (both "Last updated 2026-08-03"). *"Since
  bucket length is in the order of hours, this method cannot be used to measure data usage on a fine
  grained time scale."*; *"Starting in Build.VERSION_CODES.N this will only report traffic statistics
  for the calling UID."* — https://developer.android.com/reference/android/app/usage/NetworkStatsManager,
  https://developer.android.com/reference/android/net/TrafficStats
- **Newest API level — Android 17 page re-dated ("Last updated 2026-10-16"), nothing for us; no
  Android 18 page (brief 7: no, 404).** Only network line: *"Beginning with Android 17, cross-profile
  loopback traffic is no longer permitted by default."* — not used by us. —
  https://developer.android.com/about/versions/17/behavior-changes-all
- **Play target API — unchanged** (page re-dated 2026-10-16). *"Starting August 31 2026: New apps
  and app updates must target Android 16 (API level 36) or higher to be submitted to Google Play"* —
  https://developer.android.com/google/play/requirements/target-sdk

**iOS** — *(sub-sweep; changelog re-read by me)*

- **TN3134 — unchanged.** Latest revision still 2025-08-19; *"per-app mode requires managed
  device"*; no new provider types. —
  https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
- **Per-app VPN — unchanged.** *"To use per-app VPN in iOS, iPadOS, watchOS 10, and visionOS 1.1, a
  device management service needs to manage the app."* — https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web
- **App Review Guidelines — re-issued 16 Oct 2026; 5.4 and 5.5 unchanged.** 5.4 still *"Apps
  offering VPN services must utilize the NEVPNManager API and may only be offered by developers
  enrolled as an organization."* — https://developer.apple.com/app-store/review/guidelines/.
  Changelog (read by me): *"2.5.19: New guideline clarifies long-standing policy on hidden, dormant,
  or undocumented features, formerly covered in Guideline 2.3.1."* — https://developer.apple.com/news/?id=92th7e5i.
  Its text (sub-sweep): *"Don't include any hidden, dormant, or undocumented features in your app;
  your app's functionality should be clear to end users and App Review."* Relevance: our demo row
  is gated by the `SIPCOUNT_DEMO` build flag (I-58/I-67). That is fine **provided the store build
  is compiled without the demo code**, not merely with it switched off — to be checked before any
  iOS submission. No iOS build exists yet, so nothing shipped is affected.
- **Family Controls / DeviceActivity — unchanged.** *"This sandbox prevents your extension from
  making network requests or moving sensitive content outside the extension's address space."* —
  https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
- **Safari Web Extensions — unchanged.** *"In iOS, you must make your background page
  nonpersistent."* — https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari
- **Reading another app's content — still nothing.** *"If a third-party app needs to access
  information other than its own, it does so only by using services explicitly provided by iOS,
  iPadOS, and visionOS."* — https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- **iOS 27.2 — still Beta 4, nothing for us**; no beta 5/RC; latest public iOS 27.0.1. —
  https://developer.apple.com/news/releases/

**Browser extension**

- **MV3 — unchanged** *(sub-sweep)*. Newest "What's new" still Chrome 153 (25 Aug). *"After 30
  seconds of inactivity. Receiving an event or calling an extension API resets this timer."* —
  https://developer.chrome.com/docs/extensions/whats-new,
  https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle
- **Web Store policy — unchanged** ("Last updated 2025-05-22"). *"Request access to the narrowest
  permissions necessary to implement your Product's features or services."* —
  https://developer.chrome.com/docs/webstore/program-policies/policies
- **ChatGPT — two new entries (16 Oct), neither about the picker** *(sub-sweep)*: "Create and
  collaborate on slides in ChatGPT"; "Updates to GPT-6 Pro model in ChatGPT" (faster, better tools,
  *"Multiple agents that can work on different parts of a task in parallel"*). Parallel agents mean
  more unseen work per Pro turn; N9's timing rule already charges by active time, so no change. GPT-6
  article unchanged: *"Use the **Thinking** slider to choose your effort."* — still silent on where
  the chosen level is displayed. **Brief 1 still open.** —
  https://help.openai.com/en/articles/6825453-chatgpt-release-notes,
  https://help.openai.com/en/articles/20001354-gpt-6-and-other-models-in-chatgpt
- **Gemini — the finding of this pass (brief 2: answered in part), read by me.** *"Gemini Pro: An
  advanced reasoning model designed for complex prompts"*; *"Gemini Argon: Top-tier intelligence,
  dynamic deep reasoning, and the highest performance for complex workflows."*; every plan's
  *"Thinking Levels"* column reads *"Low, Medium, High"*; *"(Optional) Select your preferred thinking
  level"*; *"Tip: If you don't select a thinking level, it will default to Low."*; the level persists
  for the conversation. — https://support.google.com/gemini/answer/18648722. **Against our code:**
  `vendorMap.google` knows only `thinking` / `deep think` → reasoning and `flash` / `flash-lite` →
  lightweight; everything else is standard. So Pro or Argon at **High** prices as standard and passes
  `MODEL_OK` — I-69's fault, second site. At the default (Low) the standard price is right. The
  Gemini release notes still have nothing after 13 Oct. An API-default claim ("medium", cannot turn
  off) came only from a search summary and was **not verified** — the consumer app is what we read.
- **Claude — unchanged.** Newest entry still 7 Oct (Haiku 5.5). — https://support.claude.com/en/articles/12138966-release-notes

**Desktop** — *(sub-sweep)* all unchanged

- *"The SetPerTcpConnectionEStats function can only be called by a user logged on as a member of the
  Administrators group."* — https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getpertcpconnectionestats
- *"EV certificates no longer bypass SmartScreen."* — https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation;
  Artifact Signing: *"Individual developers must be located in the United States or Canada."*,
  organisation list still excludes India. — https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart
- *"Beginning in macOS 10.15, all software built after June 1, 2019, and distributed with Developer
  ID must be notarized."* — https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

**The numbers**

- **arXiv 2610.19819 — full text read (brief 3: answered)** *(sub-sweep)*, still v1. The ratio is
  mean energy per output token over mean energy per input token, GPU power only: *"we isolate the
  prefill phase by setting the generation length to exactly 1 token"*, then *"we derive the mean
  energy per output token E_out=(E_total−E_prefill)/G"* with G = 128. Conditions: *"fixed synthetic
  inputs, greedy decoding, no batching"*, single A100, Llama-3.1 8B and Qwen-2 7B. The authors
  themselves note batching would *"compress the decode-phase energy disparity"*. No whole-request
  figure for a typical prompt. — https://arxiv.org/html/2610.19819v1. **Reading:** this is a
  one-request-at-a-time lab ratio. Production serving batches heavily, which is precisely what
  shrinks the gap, so 750–850× is an upper bound for a setting we do not model. It explains the
  disagreement with Caravaca rather than overturning 5×.
- **Correction to the 10-16 entry:** Greenpixie 2609.33965 has a **v2 dated 29 Sep 2026**, so
  "still v1" last pass was wrong (it predates that pass; not a new event; v1/v2 diff not read).
  Google 2508.15734 still v1; Microsoft 2509.20241 still v2.
- **No new vendor or peer-reviewed per-query energy or water figure** since 16 Oct.

**Decisions:**
- **I-69 widened to Gemini** (ISSUES.md, matrix N13 note, RELEASES.md, stamps to 2026-10-19). No
  code change from a help page: the live gemini.google.com picker must be read to know which element
  carries the level, as with ChatGPT. Mouli's pending question becomes one question for both sites:
  *which thinking levels count as reasoning?*
- **D-22 stays at 5×.** The full paper confirms the 150–850× figure is unbatched lab serving.
  Recommendation from 10-16 stands: option (a), cite it in `TOKEN-ECONOMICS.md` as an upper bracket.
- **Apple 2.5.19** — no action now; add "store build compiled without the demo path" to the iOS
  submission checklist when one exists.
- Everything else unchanged: accessibility listener stays the Android sensor; tunnel stays parked
  behind the endpoint-encryption clause; `getConnectionOwnerUid` confirmed VPN-only; iPhone plan
  unchanged.

**What would change our mind next pass:** (1) the live chatgpt.com **and** gemini.google.com
pickers — which element shows the thinking level (I-69); (2) Mouli's answer on which levels are
reasoning; (3) Play adding an on-device VpnService exemption; (4) India in a developer-verification
wave; (5) an Android 18 preview page; (6) iOS 27.2 RC notes touching NetworkExtension or Screen
Time; (7) any production (batched) measurement of output vs input token energy.

**Next pass due:** 2026-10-22.

## 2026-10-16 — scheduled three-day pass (all five areas)

**Trigger:** the standing cadence (automated run). Brief from 10-13: (1) the live chatgpt.com
Thinking-level element (I-69); (2) an on-device VpnService exemption; (3) India in a
developer-verification wave; (4) a numeric output:input ratio; (5) `getConnectionOwnerUid` re-read;
(6) an Android 18 preview page.

**Answer: no platform moved. Two things are new, and neither changes shipped code today.**
(a) **The first published *number* for output vs input token energy has appeared (brief item 4:
yes)** — and it is ~150–850×, not the 3–10× our 5× placeholder was chosen from. Run through our own
engine, it barely moves an ordinary chat (+5%) but cuts a long pasted document by 3–8×. That is a
decision for Madhur and Mouli, not a fix to make from one workshop paper (see Decisions).
(b) **Gemini launched a new model, "Gemini 4 Argon", on 13 Oct.** Our code prices it as standard
and the health check accepts it, which is consistent with how we treat Gemini Pro — but if Argon
thinks by default, it is the same silent under-count as I-69. Every Android, iOS, Chrome-policy and
desktop item is unchanged. `ISSUES.md` and the matrix are untouched: nothing shipped is invalidated
(N4 "output weighted above input" is *supported*; N5 "replaceable in one line" still holds).

**Method note.** Three parallel sub-sweeps fetched the pages (all with a cache-busting query
string). I re-read the two items that could change anything myself: the arXiv abstract of
2610.19819 and the Gemini release notes. **The paper's full text was not read** — my two attempts
at the HTML version hit the fetcher's rate limit (HTTP 429), so what the ratio exactly measures
(marginal per-token energy, at what batch size) is from the abstract only. Still **not** done: the
live chatgpt.com picker (needs a signed-in browser; not done on an unattended run) and
`getConnectionOwnerUid` from source (truncation again).

**Android** — *(sub-sweep)*

- **VpnService policy — unchanged; no on-device exemption (brief item 2: no).** *"Only apps that
  use the VpnService and have VPN as their core functionality can create a secure device-level
  tunnel to a remote server. Exceptions include apps that require a remote server for core
  functionality such as:"* — "App usage tracking" still listed; *"must encrypt the data from the
  device to the VPN tunnel endpoint"*; both videos *"(90 seconds or shorter)"*. The words "local"
  and "on-device" do not appear. — https://support.google.com/googleplay/android-developer/answer/12564964;
  Policy Center same (*"Must encrypt the data from the device to VPN tunnel end point"*) —
  https://support.google.com/googleplay/android-developer/answer/16558241. The Policy Center's
  "Changes are coming" banner (effective 27 Jan 2027) covers Location and Contacts permissions only.
- **Accessibility policy — unchanged.** *"Google Play permits the use of the AccessibilityService
  API for a wide range of applications."*; *"This does not prohibit deterministic, rule-based
  automation"*; Policy Center *"Apps must use more narrowly scoped APIs and permissions in lieu of
  the Accessibility API when possible to achieve the desired functionality."* —
  https://support.google.com/googleplay/android-developer/answer/10964491
- **Play Protect — unchanged** ("Last updated 2026-08-18"). *"Note: This protection is active in
  select markets."*; same four permissions incl. `ACCESSIBILITY`. —
  https://developers.google.com/android/play-protect/warning-dev-guidance
- **Developer verification — unchanged; India not named (brief item 3: no).** *"September 30,
  2026 | Protections begin for all users who install apps from participating stores in Brazil,
  Indonesia, Singapore, and Thailand on certified devices running Android 7+."* /
  *"Verification capability will be expanded globally for all apps on certified Android devices in
  2027."* — https://developer.android.com/developer-verification. FAQ ("Last updated 2026-09-30")
  still *"if users sideload your app directly, these new verification requirements won't apply to
  your app yet."* — https://developer.android.com/developer-verification/guides/faq
- **`NetworkStatsManager` — unchanged.** *"Since bucket length is in the order of hours, this
  method cannot be used to measure data usage on a fine grained time scale."*; `forceUpdate()`
  still `@hide`, `@SystemApi(client = MODULE_LIBRARIES)`. —
  https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework-t/src/android/app/usage/NetworkStatsManager.java
- **`TrafficStats` — unchanged.** *"Starting in {@link android.os.Build.VERSION_CODES#N} this will
  only report traffic statistics for the calling UID. It will return {@link #UNSUPPORTED} for all
  other UIDs for privacy reasons."* — …/framework-t/src/android/net/TrafficStats.java
- **`getConnectionOwnerUid` — not checked (brief item 5: still open).** Gitiles HTML, `?format=TEXT`
  and the developer.android.com reference all truncate before the method; `+log` returned empty.
  A search snippet repeats the 10-10 wording, but a snippet is not a read. Recorded as **not
  checked**, second pass running. Next time: a local `git clone --depth 1` of the Connectivity module.
- **Newest API level — still Android 17, page unchanged ("Last updated 2026-10-01"); no Android 18
  preview page (brief item 6: no)** — versions/18 returns empty. Nothing on VpnService, network
  stats, accessibility or sideloading. — https://developer.android.com/about/versions/17/behavior-changes-all
- **Play target API — unchanged.** *"Starting August 31 2026: New apps and app updates must target
  Android 16 (API level 36) or higher to be submitted to Google Play"* —
  https://developer.android.com/google/play/requirements/target-sdk

**iOS** — all *(sub-sweep)*, via the JSON variants of the Apple pages

- **TN3134 — unchanged.** Latest revision still 2025-08-19; *"per-app mode requires managed
  device"*; *"When a provider's per-app configuration is restricted to managed devices, the targeted
  apps must be installed using MDM."* No new provider types. —
  https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
- **Per-app VPN — unchanged.** *"To use per-app VPN in iOS, iPadOS, watchOS 10, and visionOS 1.1, a
  device management service needs to manage the app."* — https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web
- **ASRG 5.4 / 5.5 — unchanged** ("Last Updated: June 8, 2026"). *"Apps offering VPN services must
  utilize the NEVPNManager API and may only be offered by developers enrolled as an organization."*
  — https://developer.apple.com/app-store/review/guidelines/
- **Family Controls / DeviceActivity — unchanged.** *"This sandbox prevents your extension from
  making network requests or moving sensitive content outside the extension's address space."* —
  https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
- **Safari Web Extensions — unchanged.** *"In iOS, you must make your background page
  nonpersistent."* — https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari
- **Reading another app's content — still nothing.** *"If a third-party app needs to access
  information other than its own, it does so only by using services explicitly provided by iOS,
  iPadOS, and visionOS."* — https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- **iOS 27.2 now Beta 4 — nothing for us.** Sections: App Tracking Transparency, Health, Nearby
  Interaction, Shortcuts, StoreKit Testing, UIKit and others; nothing on NetworkExtension, screen
  content or Family Controls. — https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27_2-release-notes
- **Developer news — nothing after 13 Oct** (newest: Licence Agreement update, 13 Oct). The 1 Oct
  Developer ID Sub-CA and 2 Oct Full Disk Access notices stand as recorded. — https://developer.apple.com/news/

**Browser extension**

- **MV3 — unchanged** *(sub-sweep)*. Newest "What's new" entries still Chrome 153 (25 Aug, 3 Aug).
  *"After 30 seconds of inactivity. Receiving an event or calling an extension API resets this
  timer."* — https://developer.chrome.com/docs/extensions/whats-new,
  https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle
- **Web Store policy — unchanged** *(sub-sweep)*. "Last updated 2025-05-22". *"Request access to
  the narrowest permissions necessary to implement your Product's features or services."* —
  https://developer.chrome.com/docs/webstore/program-policies/policies
- **ChatGPT — unchanged for us** *(sub-sweep)*. Three 15 Oct entries (GPT-Live-1.1 voice, Rosalind
  academic plan, Site limits) — none touches the model picker, composer or Thinking display. The
  GPT-6 help article is unchanged ("Updated: 6 days ago"): both 10-13 quotes present verbatim; it
  says only *"Use the **Thinking** slider to choose your effort"* and nothing about whether the
  chosen level is shown beside the model name. Older release notes place the picker: *"On web, it
  appears directly in the message composer."* (10 Jun 2026) and *"We're also moving thinking effort
  controls into the model picker."* (28 Apr 2026) — https://help.openai.com/en/articles/6825453-chatgpt-release-notes,
  https://help.openai.com/en/articles/20001354-gpt-6-and-other-models-in-chatgpt. **Brief item 1
  still open** — the vendor text cannot say which element our selector reads. Luna discrepancy
  unchanged (help article "GPT-5.6 Luna", release note "GPT-6 Luna"); tier-irrelevant.
- **Gemini — new model, read by me.** 2026.10.13: *"Starting today, Gemini 4 Argon is rolling out
  globally for Google AI Pro & Ultra subscribers in the Gemini app. 4 Argon is our newest frontier
  model, built to take your most complex tasks from start to finish."* —
  https://gemini.google/release-notes/. **Run through our code, not reasoned about:** "gemini 4
  argon" passes `MODEL_OK` (contains "gemini") and `resolveTier('google', …)` returns
  **standard** (no `pro`/`flash`/`thinking`/`deep think` substring). That matches how we price Gemini
  Pro, so it is correct *if* Argon answers like Pro. The release note does not say whether Argon
  reasons by default; if it does, this is I-69's silent under-count on a second site. Watch item,
  not an issue yet — the label on the live page decides it, as with ChatGPT.
- **Claude — unchanged for us** *(sub-sweep)*. Newest entry still 7 Oct (Haiku 5.5). —
  https://support.claude.com/en/articles/12138966-release-notes

**Desktop** — *(sub-sweep)*

- **Windows attribution — unchanged.** *"The SetPerTcpConnectionEStats function can only be called
  by a user logged on as a member of the Administrators group."* —
  https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getpertcpconnectionestats
- **Code signing — unchanged.** *"EV certificates no longer bypass SmartScreen."* —
  https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation.
  Artifact Signing: *"Individual developers must be located in the United States or Canada."*;
  organisation list still excludes India. — https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart
- **macOS — unchanged.** *"Beginning in macOS 10.15, all software built after June 1, 2019, and
  distributed with Developer ID must be notarized."* —
  https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

**The numbers**

- **Google 2508.15734 still v1; Greenpixie 2609.33965 still v1; Microsoft 2509.20241 still v2**
  *(sub-sweep)*. No new vendor per-query energy or water disclosure found.
- **New, abstract read by me: Ruf & Detyniecki, arXiv 2610.19819 (14 Oct 2026), accepted at
  HotCarbon'26** (peer-reviewed workshop). Llama-3.1 and Qwen-2 on A100s: *"we characterise the
  energy disparity between input and output tokens, demonstrating that optimised serving (vLLM)
  causes this ratio to narrow (from ≈850× to 750×) as context scales due to high decode efficiency,
  whereas unoptimised baselines show a much smaller, roughly constant gap (≈150--230×) because their
  prefill is itself expensive."* — https://arxiv.org/abs/2610.19819. **Brief item 4: yes, a
  number — but it disagrees with our other measured source by two orders of magnitude.** Caravaca
  (10-07) implied ~4–8× from whole-prompt energy on vLLM. The likeliest reconciliation is that
  Ruf measures *marginal* per-token energy (the abstract's "sub-linear marginal cost of input
  tokens"), while Caravaca's ratio includes the fixed cost every prompt pays — but that is my
  reading of an abstract, not the paper's statement. Not production hardware, not a vendor figure.
  **What it would do to us, run through our own `estimate()` (standard tier, US region; the
  reference prompt is pinned at 0.30 Wh by design):**

  | Turn | 5× (today) | 10× | 150× | 800× |
  |---|---|---|---|---|
  | Reference, 100 in / 300 out | 0.30 Wh | 0.30 | 0.30 | 0.30 |
  | Short chat, 50 / 600 | 0.572 | 0.585 | 0.599 | 0.600 |
  | Pasted doc, 4,000 / 400 | 1.125 | 0.774 | 0.426 | 0.405 |
  | Big paste, 20,000 / 500 | 4.219 | 2.419 | 0.632 | 0.525 |

  Ordinary chat moves ≤5%; turns dominated by pasted input fall 2.8× (4k) to 8× (20k). Note that
  N5's swap test only covers 3×–10×; at 150×+ the code still works (the run above), but no
  assertion pins it.

**Decisions:**
- **No code change.** D-22 stays a placeholder at 5×; N4 and N5 stay ✅ (direction supported,
  swap still one line). Reason: one workshop paper on open models, abstract only, contradicting a
  second measured source — the calibration (I-30) is still the right replacement, not this.
- **For Madhur / Mouli to decide (not urgent):** the literature range our 5× was picked from
  (3–10×) is no longer the whole literature. Options: (a) keep 5× and add the new paper to
  `TOKEN-ECONOMICS.md` as the upper bracket; (b) move to ~10× now as a hedge (+2% on chat, −31% on
  a 4k paste). My recommendation is (a) until someone reads the full paper and the desktop
  calibration runs — the only users it materially affects are heavy pasters, where the context
  factor (N10) already adds cost.
- **Gemini 4 Argon** joins I-69 as a "read the live label" check; no fixture until we see it.
- Everything else unchanged: accessibility listener stays the Android sensor; tunnel stays parked
  behind the endpoint-encryption clause; iPhone plan unchanged.

**What would change our mind next pass:** (1) the live chatgpt.com picker — which element shows the
Thinking level (I-69); (2) the live Gemini label for Argon, and whether it reasons by default;
(3) the full text of arXiv 2610.19819 — what the ratio measures, at what batch size; (4) Play adding
an on-device VpnService exemption; (5) India in a developer-verification wave; (6)
`getConnectionOwnerUid` from a local clone; (7) an Android 18 preview page.

**Next pass due:** 2026-10-19.

## 2026-10-13 — scheduled three-day pass (all five areas)

**Trigger:** the standing cadence (automated run). Brief from 10-10: (1) the live chatgpt.com model
labels (I-69); (2) an on-device VpnService exemption; (3) India in a developer-verification wave;
(4) a numeric output:input ratio (Greenpixie v2, or the Microsoft Joule paper read in full);
(5) Play's "minimum scope alternatives" page (answer/16935362).

**Answer: no platform moved. The one live item, I-69, got sharper — and the fault is in a
different place from where we thought.** OpenAI's own help article now lists the exact ChatGPT
picker labels. Users never see "Astra": they pick **GPT-6** and a **Thinking** level
(Instant / Medium / High / Extra High / Pro). Run through our code, "Pro" still prices as
reasoning (the 10-10 "Astra ~10× low" worry does not happen), but **Medium, High and Extra High —
the thinking turns — price as standard**, and a bare "GPT-6" label passes our model-name check, so
the H4 "cannot read the model" warning **will not fire**. That is a silent under-count, worse than
the loud one we expected. I-69 updated; N13 stays 🟡; `RELEASES.md` row corrected. Every Android,
iOS, Chrome-policy and desktop item is unchanged.

**Method note.** Three parallel sub-sweeps fetched the pages. I re-fetched the two items that
decide anything myself — the OpenAI help article and Play answer/16935362 — by adding a dummy
query string to get past the fetcher's one-hour de-duplication (the trick that failed us on 10-10).
Everything else is *(sub-sweep)*. Still **not** done: looking at the live chatgpt.com picker. The
help article is a primary vendor source for the labels, but not for **which DOM element our
selector reads** — that is the one thing only the live page can answer.

**Android** — *(sub-sweep)* unless marked

- **VpnService policy — unchanged; no on-device exemption (brief item 2: no).** *"Only apps that
  use the VpnService and have VPN as their core functionality can create a secure device-level
  tunnel to a remote server. Exceptions include apps that require a remote server for core
  functionality such as:"* — "App usage tracking" still listed; *"encrypt the data from the device
  to the VPN tunnel endpoint"*; videos *"(90 seconds or shorter)"*; *"Apps using VpnService outside
  of the permitted functionalities will be rejected."* — https://support.google.com/googleplay/android-developer/answer/12564964;
  Policy Center same text — https://support.google.com/googleplay/android-developer/answer/16558241
- **Accessibility policy — unchanged.** *"Google Play permits the use of the AccessibilityService
  API for a wide range of applications."*; autonomy ban unchanged and still adds *"This does not
  prohibit deterministic, rule-based automation"*; Policy Center still *"Apps must use more narrowly
  scoped APIs and permissions in lieu of the Accessibility API when possible to achieve the desired
  functionality."* — https://support.google.com/googleplay/android-developer/answer/10964491
- **"Minimum scope alternatives" page — read by me (brief item 5 closed: nothing for us).** It
  covers only Contacts and Photos/Videos: *"Your app should only request and carry the sensitive
  permissions below if minimum scope alternatives are not sufficient to provide core app
  functionality."* and *"Apps that target Android 17 or later (API level 37+) may only request the
  `READ_CONTACTS` permission if the Android Contact Picker is not sufficient"*. No mention of
  AccessibilityService or passive listeners. — https://support.google.com/googleplay/android-developer/answer/16935362.
  We request neither permission, so P10 is unaffected.
- **Play Protect — unchanged.** *"Note: This protection is active in select markets."* Same four
  permissions incl. `ACCESSIBILITY`; "Last updated 2026-08-18"; no countries named. —
  https://developers.google.com/android/play-protect/warning-dev-guidance
- **Developer verification — unchanged; India not named (brief item 3: no).** *"September 30,
  2026: Protections begin for all users who install apps from participating stores in Brazil,
  Indonesia, Singapore, and Thailand on certified devices running Android 7+."* /
  *"Verification capability will be expanded globally for all apps on certified Android devices in
  2027."* — https://developer.android.com/developer-verification. FAQ ("Last updated 2026-09-30")
  still *"If users sideload your app directly, these new verification requirements won't apply to
  your app yet"*. — https://developer.android.com/developer-verification/guides/faq
- **`NetworkStatsManager` — unchanged.** *"Since bucket length is in the order of hours, this
  method cannot be used to measure data usage on a fine grained time scale."*; `forceUpdate()`
  still *"@hide"*, `@SystemApi(client = MODULE_LIBRARIES)`. —
  https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework-t/src/android/app/usage/NetworkStatsManager.java
- **`TrafficStats` — unchanged.** *"Starting in {@link android.os.Build.VERSION_CODES#N} this will
  only report traffic statistics for the calling UID. It will return {@link #UNSUPPORTED} for all
  other UIDs for privacy reasons."* — …/framework-t/src/android/net/TrafficStats.java
- **`getConnectionOwnerUid` — not re-fetched this pass** (the method sits past the fetcher's
  ~115k-character cut-off in every variant tried). Last verified 10-10; recorded as not checked,
  not as unchanged.
- **Newest API level — still Android 17; nothing on VpnService, network stats, accessibility
  listeners or sideloading.** No Android 18 preview page (versions/18 returns empty). New forward
  note, irrelevant to us: *"Starting in Android 18, the system will no longer automatically grant
  these permissions"* (implicit URI grants on share/capture intents). —
  https://developer.android.com/about/versions/17/behavior-changes-all ("Last updated 2026-10-01")
- **Play target API — unchanged.** *"Starting August 31 2026: New apps and app updates must target
  Android 16 (API level 36) or higher"* — https://developer.android.com/google/play/requirements/target-sdk

**iOS** — all *(sub-sweep)*, via the JSON variants of the Apple pages

- **TN3134 — unchanged.** Latest revision still 2025-08-19; *"per-app mode requires managed
  device"*; *"When a provider's per-app configuration is restricted to managed devices, the targeted
  apps must be installed using MDM."* No new provider types. —
  https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
- **Per-app VPN — unchanged.** *"To use per-app VPN in iOS, iPadOS, watchOS 10, and visionOS 1.1, a
  device management service needs to manage the app."* — https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web
- **ASRG 5.4 / 5.5 — unchanged** ("Last Updated: June 8, 2026"; developer news shows only Licence
  Agreement updates since). *"Apps offering VPN services must utilize the NEVPNManager API and may
  only be offered by developers enrolled as an organization."* — https://developer.apple.com/app-store/review/guidelines/
- **Family Controls / DeviceActivity — unchanged.** *"This sandbox prevents your extension from
  making network requests or moving sensitive content outside the extension's address space."* —
  https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
- **Safari Web Extensions — unchanged.** *"In iOS, you must make your background page
  nonpersistent."* — https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari
- **Reading another app's content — still nothing.** *"If a third-party app needs to access
  information other than its own, it does so only by using services explicitly provided by iOS,
  iPadOS, and visionOS."* — https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- **iOS 27 / 27.2 beta 3 release notes — unchanged for us.** NetworkExtension still only the
  CarPlay `excludeLocalNetworks` fix; 27.2 beta 3 has nothing on networking or screen content. —
  https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes

**Browser extension**

- **MV3 — unchanged** *(sub-sweep)*. Newest "What's new" entries still Chrome 153 (25 Aug, 3 Aug).
  *"After 30 seconds of inactivity. Receiving an event or calling an extension API resets this
  timer."* — https://developer.chrome.com/docs/extensions/whats-new,
  https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle
- **Web Store policy — unchanged** *(sub-sweep)*. "Last updated 2025-05-22". *"Request access to
  the narrowest permissions necessary to implement your Product's features or services."* —
  https://developer.chrome.com/docs/webstore/program-policies/policies
- **ChatGPT — the picker labels, read by me (brief item 1: answered from the vendor, not yet from
  the live page).** *"In the model menu, **GPT-6** replaces **Latest**. … Use the **Thinking**
  slider to choose your effort. When **GPT-6** is selected, **GPT-6 Sol** powers **Instant**,
  **Medium**, **High**, and **Extra High**; **Pro** uses GPT-6 Pro, powered by **GPT-6 Astra**."*
  and *"Look for **GPT-6** in the model menu; it is not labeled Sol."* Free and Go: *"Free and Go
  users can use **Think** for harder questions. Think uses GPT-5.6 Luna"*. Older models stay
  selectable: *"explicit **GPT-5.6 Sol** selections stay on GPT-5.6"*. —
  https://help.openai.com/en/articles/20001354-gpt-6-and-other-models-in-chatgpt ("Updated: 3 days
  ago"). Release note of 7 Oct confirmed by the sub-sweep this time: *"Plus, Pro, Business, and
  Enterprise use GPT-6 Sol; Free and Go use GPT-6 Luna."* —
  https://help.openai.com/en/articles/6825453-chatgpt-release-notes. **Discrepancy, recorded not
  smoothed:** the help article says Free and Go get *GPT-5.6* Luna; the release note and OpenAI's
  announcement say *GPT-6* Luna. Either way it is the small model, so it does not change our tier
  for those users.
  **What it does to us — run through our own `resolveTier` and `MODEL_OK`, not reasoned about:**

  | Label as it might appear | Passes `MODEL_OK` | Our tier | Right tier |
  |---|---|---|---|
  | GPT-6 / GPT-6 Instant | yes | standard | standard ✔ |
  | GPT-6 Medium / High / Extra High | yes | **standard** | reasoning (thinking) ✘ |
  | Medium / High / Extra High (slider alone) | **no** | standard | reasoning ✘ — H4 would warn |
  | GPT-6 Pro / Pro | yes | reasoning | reasoning ✔ |
  | Think (Free/Go) | no | standard | arguably lightweight-reasoning; open |
  | GPT-5.6 Sol Pro | yes | reasoning | reasoning ✔ |

  So the 10-10 worry ("Astra prices as standard") does not arise — users see "Pro", which we price
  correctly. **The real gap is the thinking levels**: if our selector reads only the "GPT-6" button,
  every Medium/High/Extra High turn is priced standard *and* the label looks valid, so the health
  check stays green. The unseen-work timer (N9) recovers part of this from duration, but not the
  tier. Two things the live page must answer: which element shows the slider level, and whether
  that text is readable without capturing content.
  Also new *(sub-sweep)*: 6 Oct "Audio uploads in ChatGPT" (a new attachment type in the composer;
  `content.js` already classes any attachment as `long_context`); 9 Oct "Composer predictions" is
  Codex-only. No chat-composer redesign reported.
- **Claude — unchanged for us** *(sub-sweep)*. Newest entry still 7 Oct (Haiku 5.5). —
  https://support.claude.com/en/articles/12138966-release-notes
- **Gemini — unchanged for us** *(sub-sweep)*. Newest entry still 30 Sep; *"Skills will soon
  replace Gems"* — no composer or model rename. — https://gemini.google/release-notes/

**Desktop** — *(sub-sweep)*

- **Windows attribution — unchanged.** *"The SetPerTcpConnectionEStats function can only be called
  by a user logged on as a member of the Administrators group."*; `GetExtendedTcpTable` still has no
  admin requirement. — https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getpertcpconnectionestats
- **Code signing — unchanged.** *"EV certificates no longer bypass SmartScreen."* —
  https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation.
  Artifact Signing: *"Individual developers must be located in the United States or Canada."*;
  organisation list still excludes India. — https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart
- **macOS — unchanged for the design; two dated notices worth knowing.** Notarisation text
  unchanged. macOS 27 release notes have no Network Extension / content-filter / Endpoint Security
  section. New on developer news: (a) 2 Oct, Full Disk Access — *"we will introduce additional
  controls to ensure that users who genuinely wish to grant an app this extraordinary level of
  access can only do so with very explicit user action"*; our desktop design does not use Full Disk
  Access. (b) 1 Oct — *"The original Developer ID Certification Authority (Sub-CA) expires on
  February 1, 2027… Starting February 1, 2027, .pkg files signed with an affected certificate will
  no longer install."* We hold no Developer ID yet; when we get one it will come from the new (G2)
  authority, so no action — but note it before any macOS `.pkg` work. — https://developer.apple.com/news/

**The numbers**

- **Google arXiv 2508.15734 — unchanged, still v1** *(sub-sweep)*.
- **Greenpixie arXiv 2609.33965 — unchanged, no v2** *(sub-sweep)*; quote as on 10-10.
- **Microsoft (Joule 2026, arXiv 2509.20241 v2, 2026-06-09) — now read** *(sub-sweep)*. Per-query:
  *"For frontier-scale models (>200B parameters) on H100 nodes, we estimate a median energy of 0.31
  Wh/query (IQR 0.16-0.60)… In test-time scaling scenarios 15x longer than typical queries, the
  median energy rises 13x to 3.91 Wh"*. **No per-token output:input ratio** — it assumes the
  opposite simplification: *"Since the output tokens dominate energy use, we approximate L_eff ~
  L_out and fix L_in = 500"*. Supports "output dominates" (D-22's direction), does not give a number
  (brief item 4: no). Older listings quote v1's 0.34 / 4.32 Wh — use v2.
- No new vendor per-query energy or water figure found since 27 Sep (OpenAI's GPT-6 pages carry
  none).

**Decisions:**
- **I-69 re-scoped, still open; N13 stays 🟡.** The fix is no longer "add Astra". It is: on
  chatgpt.com, find which element shows the Thinking level and read it alongside "GPT-6"; then map
  Medium/High/Extra High → reasoning and Pro → reasoning in `vendorMap`, with a fixture per label.
  **One product question for Mouli** before that line is written: should "Medium" ("Standard
  thinking") count as a reasoning turn, or only High and above? It changes a Plus user's number
  materially. `RELEASES.md` class-B note corrected to match.
- Everything else unchanged: accessibility listener stays the Android sensor; tunnel stays parked
  behind the endpoint-encryption clause; iPhone plan unchanged; 5× stays a placeholder.

**What would change our mind next pass:** (1) the live chatgpt.com picker — which element shows the
Thinking level (the I-69 check, now the only open item); (2) Play adding an on-device VpnService
exemption; (3) India in a developer-verification wave; (4) a numeric output:input ratio from any
vendor or peer-reviewed measurement; (5) `getConnectionOwnerUid` re-read from a local AOSP checkout
or a browser, since the fetcher cannot reach it; (6) an Android 18 preview page appearing.

**Next pass due:** 2026-10-16.

## 2026-10-10 — scheduled three-day pass (all five areas)

**Trigger:** the standing cadence (automated run). Brief from 10-07: (1) an on-device exemption to
Play's VpnService encryption clause; (2) India in a developer-verification wave; (3) a
ChatGPT/Claude/Gemini composer redesign after 2026-09-30, or H4 firing; (4) a vendor output:input
energy ratio; (5) the `getConnectionOwnerUid` restriction text.

**Answer: one thing moved, and it is on the extension, not the phones.** ChatGPT switched to new
model names on 2026-10-07 (GPT-6 Sol / Luna / Astra) and our tier table does not know them — the
Pro reasoning model would be priced as an ordinary one, roughly 10× too low. Raised as **I-69**;
matrix row **N13 moved ✅ → 🟡**. Every Android, iOS, Chrome-policy and desktop item is unchanged.

**Method note.** Three parallel sub-sweeps fetched the pages. I re-fetched the ChatGPT release notes
and the Greenpixie paper myself; the fetcher's de-duplication and truncation blocked my own re-read
of the Play, AOSP and developer-verification pages, so those are marked *(sub-sweep)*. **One
discrepancy recorded rather than smoothed over:** my own fetch of the ChatGPT release notes
(page "Updated: 9 hours ago") showed nothing newer than 4 August 2026 — not even the 7 August entry
cited on 10-07 — while the sub-sweep's fetch showed entries to 9 October. The GPT-6 change is
therefore corroborated by press, not by a primary page I read myself (see below). It is the only
item this pass that changes anything, so it is the one to confirm by looking at chatgpt.com.

**Android** — all *(sub-sweep)*

- **VpnService policy — unchanged; no on-device exemption (brief item 1: no).** *"Only apps that
  use the VpnService and have VPN as their core functionality can create a secure device-level
  tunnel to a remote server. Exceptions include apps that require a remote server for core
  functionality such as:"* — "App usage tracking" still listed; *"must encrypt the data from the
  device to the VPN tunnel endpoint"*; both videos *"(90 seconds or shorter)"*. Neither page
  mentions local or on-device VPNs. — https://support.google.com/googleplay/android-developer/answer/12564964,
  https://support.google.com/googleplay/android-developer/answer/16558241
- **`NetworkStatsManager` — unchanged; no public flush.** *"Since bucket length is in the order of
  hours, this method cannot be used to measure data usage on a fine grained time scale."*
  `forceUpdate()` still `@hide` `@SystemApi(client = MODULE_LIBRARIES)`. —
  https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework-t/src/android/app/usage/NetworkStatsManager.java
- **`TrafficStats` — unchanged.** *"Starting in {@link android.os.Build.VERSION_CODES#N} this will
  only report traffic statistics for the calling UID. It will return {@link #UNSUPPORTED} for all
  other UIDs for privacy reasons."* — …/framework-t/src/android/net/TrafficStats.java
- **`getConnectionOwnerUid` — restriction text now fetched (brief item 5 closed).** *"@throws
  SecurityException if the caller is not the active VpnService for the current user."* and
  *"@return {@code uid} if the connection is found and the app has permission to observe it (e.g.,
  if it is associated with the calling VPN app's VpnService tunnel)"* —
  https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/framework/src/android/net/ConnectivityManager.java.
  **Consequence:** it is not an independent "secondary signal" as I-60 phrased it; it exists only
  *inside* a tunnel. That changes nothing shipped (no tunnel exists) but the tunnel design should
  treat it as part of the VpnService, not a fallback without one.
- **Accessibility policy — unchanged.** *"Google Play permits the use of the AccessibilityService
  API for a wide range of applications."*; autonomy ban word-for-word the same. —
  https://support.google.com/googleplay/android-developer/answer/10964491. The "narrowly scoped
  APIs" sentence recorded on 10-07 came from the Policy Center page (16558241), not this one; not
  re-checked there this pass. New sidebar link "Understanding Restricted Permissions with minimum
  scope alternatives" (answer/16935362) — **not fetched; read it before the P10 declaration.**
- **Play Protect sideload blocking — unchanged.** *"This protection is active in select markets."*
  Same four permissions incl. `ACCESSIBILITY`. Page still "Last updated 2026-08-18". —
  https://developers.google.com/android/play-protect/warning-dev-guidance
- **Developer verification — unchanged; India not named (brief item 2: no).** *"September 30,
  2026: Protections begin for all users who install apps from participating stores in Brazil,
  Indonesia, Singapore, and Thailand on certified devices running Android 7+."* and *"2027 and
  beyond: Verification capability will be expanded globally for all apps on certified Android
  devices in 2027."* — https://developer.android.com/developer-verification. FAQ (updated
  2026-09-30) still: *"if users sideload your app directly, these new verification requirements
  won't apply to your app yet."* — https://developer.android.com/developer-verification/guides/faq
- **Newest API level — nothing on VpnService, network stats, accessibility listeners or
  sideloading.** Android 17 page updated 2026-10-09; `ACCESS_LOCAL_NETWORK` as recorded on 10-07.
  Newly noted: *"Beginning with Android 17, cross-profile loopback traffic is no longer permitted by
  default."* — same-profile only matters to us, unaffected. —
  https://developer.android.com/about/versions/17/behavior-changes-all. No Android 18 preview page.
- **Play target API — recorded for the first time:** *"Starting August 31 2026: New apps and app
  updates must target Android 16 (API level 36) or higher to be submitted to Google Play"* —
  https://developer.android.com/google/play/requirements/target-sdk. Matches I-23's "target SDK 36".

**iOS** — all *(sub-sweep)*, via the JSON variants of the Apple pages

- **TN3134 — unchanged.** Latest revision still 2025-08-19; *"per-app mode requires managed
  device"*; *"When a provider's per-app configuration is restricted to managed devices, the targeted
  apps must be installed using MDM."* No new provider types. —
  https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment.
  **Correction to the 10-07 entry:** the sentence *"The system performs URL filtering on your behalf
  according to your configuration and URL data set."* is on the `NEURLFilterManager` page, not
  TN3134 — https://developer.apple.com/documentation/networkextension/neurlfiltermanager
- **Per-app VPN — unchanged, still needs management.** *"To use per-app VPN in iOS, iPadOS, watchOS
  10, and visionOS 1.1, a device management service needs to manage the app."* —
  https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web
- **ASRG 5.4 / 5.5 — unchanged** ("Last Updated: June 8, 2026"; no newer guideline item on
  developer.apple.com/news). *"Apps offering VPN services must utilize the NEVPNManager API and may
  only be offered by developers enrolled as an organization."* —
  https://developer.apple.com/app-store/review/guidelines/
- **Family Controls / DeviceActivity — unchanged.** *"This sandbox prevents your extension from
  making network requests or moving sensitive content outside the extension's address space."* —
  https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
- **Safari Web Extensions — unchanged.** *"In iOS, you must make your background page
  nonpersistent."* — https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari
- **Reading another app's content — still nothing.** *"If a third-party app needs to access
  information other than its own, it does so only by using services explicitly provided by iOS,
  iPadOS, and visionOS."* — https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- **iOS 27 / 27.2 beta 3 release notes — no relevant Network Extension change.** Only a CarPlay
  `excludeLocalNetworks` fix. — https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes

**Browser extension**

- **MV3 — unchanged** *(sub-sweep)*. Newest "What's new" entries still Chrome 153 (25 Aug, 3 Aug).
  Lifecycle page: *"After 30 seconds of inactivity. Receiving an event or calling an extension API
  resets this timer."* — https://developer.chrome.com/docs/extensions/whats-new,
  https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle
- **Web Store policy — unchanged** *(sub-sweep)*. "Last updated 2025-05-22". *"Request access to
  the narrowest permissions necessary to implement your Product's features or services."* —
  https://developer.chrome.com/docs/webstore/program-policies/policies
- **ChatGPT — changed (brief item 3: yes, in part).** Sub-sweep quote from the release notes,
  7 October 2026, "GPT-6 and Intelligent UI in ChatGPT": *"Plus, Pro, Business, and Enterprise use
  GPT-6 Sol; Free and Go use GPT-6 Luna."* and *"GPT-6 can also begin answering while it continues
  to think or use tools, then add more findings without another prompt."* —
  https://help.openai.com/en/articles/6825453-chatgpt-release-notes. **Not visible in my own fetch
  of that page** (see method note). Corroborated by press, which also reports *"The Pro reasoning
  option continues to use GPT-6 Astra"* and *"Intelligent UI is available from Instant through
  Extra High reasoning"* — https://www.macrumors.com/2026/10/07/chatgpt-intelligent-ui/ (blog;
  corroborates, does not decide).
  **What it does to us, checked by running our own code rather than reasoning about it:**
  `resolveTier('openai', label)` returns **standard** for "GPT-6 Sol", "GPT-6 Luna" and
  **"GPT-6 Astra"**; "Pro" and "Thinking" still return reasoning; "Instant" and "Extra High" fail
  `MODEL_OK` altogether (so H4's "cannot read the model" warning would fire after two days, which is
  the alarm working). If the picker shows "Astra" or "Extra High" for a reasoning turn, that turn is
  priced ~10× low — the same fault class as I-42(b). Two further risks, unmeasured: answers that are
  now partly charts, buttons and forms may be under-read by the reply-length counter (N7), and an
  answer that "adds more findings without another prompt" may arrive after the stop control
  disappears, which is when we finalise. Composer itself not reported changed.
- **Claude — unchanged for us** *(sub-sweep)*. Only post-cutoff entry is 7 Oct (Haiku 5.5 launch);
  "haiku" already maps to lightweight. — https://support.claude.com/en/articles/12138966-release-notes
- **Gemini — unchanged for us** *(sub-sweep)*. 30 Sep "skills" entry; no composer change. —
  https://gemini.google/release-notes/

**Desktop** — *(sub-sweep)*

- **Windows attribution — unchanged.** *"The SetPerTcpConnectionEStats function can only be called
  by a user logged on as a member of the Administrators group."* —
  https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getpertcpconnectionestats
- **Code signing — unchanged.** *"EV certificates no longer bypass SmartScreen."* —
  https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation.
  Artifact Signing still *"Individual developers must be located in the United States or Canada."*;
  organisation list still excludes India. — https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart
- **macOS — unchanged.** *"Beginning in macOS 10.15, all software built after June 1, 2019, and
  distributed with Developer ID must be notarized."* —
  https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.
  No primary-source macOS 27 Network Extension change found; macOS 27 release notes not opened.

**The numbers**

- **Google arXiv 2508.15734 — unchanged, still v1** *(sub-sweep)*.
- **New, and read by me: Greenpixie, arXiv 2609.33965 (27 Sep 2026)** — a vendor methodology
  paper, not peer-reviewed. *"Notably, the per-token decode energy and wall clock time is found to be
  roughly an order of magnitude larger than prefill. The exact multiplicative factor between the two
  token types cannot be inferred from the figures."* — https://arxiv.org/html/2609.33965v1.
  **Brief item 4: not quite.** It is a published output:input statement, but qualitative and
  explicitly not a number. "An order of magnitude" points above our 5×, not below; together with
  Caravaca's bracket it is a reason to keep D-22 open, not a figure to swap in.
- Microsoft Research (Joule 2026, arXiv 2509.20241) — **not fetched**; search snippets only, not
  recorded as findings. No new OpenAI, Anthropic, Mistral or Meta per-query disclosure found by
  search.

**Decisions:**
- **I-69 raised; N13 ✅ → 🟡.** The fix is cheap but must not be written from a press report: open
  chatgpt.com, read the model picker's actual labels for each mode, then add them to `vendorMap`
  (shared, so phone and desktop inherit it) with a fixture per label. Until then the extension
  under-reports ChatGPT reasoning turns — class B in `RELEASES.md` (only Madhur's unpacked copy is
  in the field).
- Everything else unchanged: accessibility listener stays the Android sensor; tunnel stays parked
  behind the endpoint-encryption risk; iPhone plan unchanged; 5× stays a placeholder.

**What would change our mind next pass:** (1) the live chatgpt.com model labels — the I-69 check;
(2) Play adding an on-device VpnService exemption; (3) India in a developer-verification wave;
(4) a numeric output:input ratio from any vendor or a peer-reviewed measurement (Greenpixie v2, or
the Microsoft Joule paper read in full); (5) Play's "minimum scope alternatives" page
(answer/16935362) saying anything about read-only accessibility listeners.

**Next pass due:** 2026-10-13.

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
  **Correction 2026-10-19 (I-70): this was false when written.** The listener measured the prompt
  only; every reply was an assumed 300 tokens. Reply measuring was built on 2026-10-19.
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
