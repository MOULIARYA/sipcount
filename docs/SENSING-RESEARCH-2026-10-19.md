# Sipcount sensing research: getting off Accessibility without going blind

Research date: 2026-10-19. Read-only research, nothing in the repo was changed.
How to read the labels: **[V]** means verified on a primary source and quoted below. **[S]** means it comes from a secondary source (press, forum, third-party guide). **[U]** means unverified, my own inference, or something that needs a device test.

---

## 0. Summary

1. **Why banks block us.** It isn't vague. HSBC India writes it down: *"If our app detects accessibility permissions that are incompatible with its safeguards, it will show an alert and stop you using the app."* Its fix list also includes *"Reset your keyboard to default"* and blocking developer mode. **[V]** Google's Play Integrity "app access risk" verdict flags apps that can **capture, control or overlay**. It leaves out only *"verified accessibility services"*. **[V]** A local VPN, Usage Access, and an in-app browser fall into none of those three categories. Our own **overlay** permission (SYSTEM_ALERT_WINDOW) or screen capture **would** fall into one, so we must not add either.
2. **Accessibility is getting harder for non-tools.** Since Android 16, banking apps can mark views `accessibilityDataSensitive`. Any service without `isAccessibilityTool=true` is then *"denied access to that view"* **[V]**. Press reports say Android 17 Advanced Protection Mode revokes accessibility from non-tools **[S]**. An always-on Accessibility service should no longer be the default sensor.
3. **No mobile competitor exists.** Every "AI water/carbon tracker" I found is a desktop browser extension: ByteThirst, AI Impact Tracker, Water Usage Tracker for ChatGPT, ChatGPT CO2 Tracker, Footprint AI, EcoPrompt, GPTFootprint (research). I found no Android or iOS app that measures AI-app usage. **[S]** A working mobile story would set Sipcount apart.
4. **Recommended approach.** Use one estimator for all surfaces. **Precise sensors** feed a per-user **calibration profile**, and **coarse sensors** are scaled by that profile:
   - Precise sensors: desktop extension, an in-app "Sipcount browser" on phones, Safari/Firefox/Edge mobile extensions, and optional vendor-export reconciliation.
   - Coarse sensors: Android Usage Access foreground minutes, iOS Shortcuts "app opened/closed" automations.

   This removes the banking conflict on Android by default. Precise per-turn measurement becomes opt-in per session.
5. **Android order** (detail in section 5):
   - ① Usage Access coarse mode as the default.
   - ② In-app Sipcount browser for ChatGPT/Claude web, reusing the extension script.
   - ③ Periodic import of the vendor data export for ground truth.
   - ④ Accessibility "session mode": switched on by the user via shortcut or tile, and it calls `disableSelf()` when the user leaves AI apps.
   - ⑤ Local VPN metering, only behind a feature flag after bank-app device tests.

---

## 1. Already established (cited as known, not re-researched)

- NetworkStatsManager buckets are hours long. In our real-phone test, per-app counters flushed minutes apart, so they can't resolve single prompts.
- VpnService is allowed for "App usage tracking". Play requires encryption to the tunnel endpoint and two videos of 90 s or less.
- iOS can't read another app's content. Per-app VPN needs MDM. NEVPNManager needs an organisation account. The DeviceActivityReport extension can't make network requests.

---

## 2. Findings by question

### A. How other apps watch "what the user does elsewhere", and whether banks object

| App / class | Mechanism (Android unless stated) | Banking conflict | Store status / source |
|---|---|---|---|
| **one sec** | Accessibility by default. Offers a fallback that is **Usage Access only**. | Accessibility mode: yes (same class as us). Usage mode: none known. | [V] one sec help: *"we decided to allow users to use one sec without the accessibility service – with our old legacy approach using the app usage permission. It has some downsides … but it's better than not being able to use one sec at all."* It lists the downsides as accessibility being *"more stable"*, having *"faster response time"*, and *"receiving passive events instead of actively polling activity data"*. https://feedback.one-sec.app/help/articles/6315890 |
| **ActionDash / Digital Wellbeing-style dashboards** | `PACKAGE_USAGE_STATS` (Usage Access). Some versions add notification access. | None reported. | [S] Exodus permission reports list PACKAGE_USAGE_STATS and no accessibility service. 9to5Google: *"just a single permission"*. |
| **StayFree, Opal, ScreenZen, BlockerX, AppBlock** | Usage Access for stats. Accessibility and/or overlay for **blocking** and website tracking. | AppBlock documents banking apps breaking, caused by its Strict Mode blocking Settings. | [V] https://appblock.app/my-banking-app-payment-app-or-wallet-is-blocked-but-i-didnt-block-it/ . Opal Android using accessibility is [S] (product listing only). ScreenZen: nothing found [U]. |
| **Opal / one sec / ScreenZen on iOS** | Screen Time (FamilyControls / ManagedSettings / DeviceActivity). They block and display usage; they can't export it. | None (iOS) | See F. |
| **Google Family Link / Digital Wellbeing** | Privileged system components. Not available to third parties. | n/a | [U] Not replicable. |
| **Qustodio / Bark** | Accessibility, VPN, device admin (MDM-like). | Likely the same class as us. | [U] Not verified. |
| **Wispr Flow (Android dictation)** | Accessibility plus a bubble overlay. It ships **banking-app detection** that hides itself in PhonePe, Google Pay, etc. | Yes. They engineered around it. | [V] *"Android can independently restrict accessibility in banking apps, briefly interrupting Flow's connection when you enter or leave one."* and *"Coverage includes banks, payment, wallet, and fintech apps, such as PayPal, Cash App, Google Wallet, PhonePe, and Wise."* https://wispr-knowledge-base.help.usepylon.com/articles/4909908692 |
| **Keyboards (Gboard/SwiftKey/3rd-party IME)** | An IME sees only what the user types (prompt length plus a "send" heuristic), never the reply. | **Yes for some banks.** HSBC India tells users to *"Reset your keyboard to default"*. | [V] https://www.hsbc.bank.in/help/faqs/rasp/ |
| **NetGuard / RethinkDNS / AdGuard (local VPN)** | VpnService. Traffic is handled on-device, with no remote server. | Anecdotal: "VPN detected" warnings, and ICICI "doesn't work … even while being whitelisted when using a VPN". Not confirmed by any bank or NPCI document. | NetGuard and Rethink are both on Play [V]. Bank reports are [S]: Lemmy and GrapheneOS forum threads. |
| **AI footprint trackers** | **All are desktop browser extensions** with content scripts or token counting. ByteThirst also has a CLI for Claude Code / Codex etc. | n/a | [V] ByteThirst site: *"Free Chrome extension that measures the water, electricity, and CO₂ cost of every ChatGPT, Claude, Gemini, and Perplexity prompt. Tracks 14 AI platforms."* https://bytethirst.com/ . Others [S] on the Chrome Web Store: AI Impact Tracker, Water Usage Tracker for ChatGPT (Unofficial), ChatGPT CO2 Tracker, Footprint AI, AI Water Footprint, EcoPrompt, ChatGPT Energy Tracker (uses EcoLogits methodology). Academic: GPTFootprint (Princeton), PromptFootprint (Vanderbilt YSJ), Carbon Tracker (Polimi). EcoLogits itself is a Python library for API calls, not a consumer tracker. **No mobile app found.** [S] |

**Bank-side detection: primary evidence**
- HSBC India RASP FAQ [V], https://www.hsbc.bank.in/help/faqs/rasp/
  - *"If our app detects accessibility permissions that are incompatible with its safeguards, it will show an alert and stop you using the app."*
  - *"Turn off accessibility permissions for all apps. Reset your keyboard to default. On some devices, you may also need to turn off screen reading in your phone settings."*
  - *"No, the app will suspend access if developer mode is on."*
  - The FAQ says **nothing about VPN or usage access**.
- HDFC has a page titled "SmartWealth App Trusted Screen Reader". This suggests an allowlist approach, but the body text didn't render in my fetch, so its content is [U]. https://www.hdfc.bank.in/important-messages/smartwealth-app-trusted-screen-reader
- RBI's Authentication Directions 2025 (effective 1 Apr 2026) cover 2FA and device binding. I found no clause on accessibility or VPN [S]. A claim that "all Indian banking apps have been instructed to not allow the use of VPN slot" appears only in a Lemmy post, with no source **[U, treat as rumour]**.

**Play Integrity app access risk** [V] https://developer.android.com/google/play/integrity/verdicts
- `KNOWN_CAPTURING`: *"There are apps running that have permissions enabled that could be used to view the screen while your app is running. This excludes any verified accessibility services known to Google Play running on the device."*
- `KNOWN_CONTROLLING`: *"…could be used to control the device and directly control inputs into your app…"*
- `KNOWN_OVERLAYS`: *"…could be used to display overlays on your app."*
- *"App access risk automatically excludes verified accessibility services that have been through an enhanced Google Play accessibility review … ensuring that your app has the `isAccessibilityTool` flag set to true."*
- **Implication:** VPN, Usage Access, notification listener and WebView are not capture, control or overlay, so they shouldn't trip this verdict. I infer this from the category definitions [U]; a device test should confirm it.

**Accessibility is closing for non-tools**
- Android Developers Blog, Dec 2025 [V], https://android-developers.googleblog.com/2025/12/enhancing-android-security-stop-malware.html
  - On `accessibilityDataSensitive`: *"any app requesting accessibility permission that hasn't explicitly declared itself as a legitimate accessibility tool (isAccessibilityTool=true) is denied access to that view."*
  - *"If an app is not an accessibility tool but requests accessibility permissions and sets isAccessibilityTool=true, Play will reject it and Google Play Protect will block it on user devices."*
  - Revolut is quoted as adopting it, so banks will use it.
- Play policy [V], https://support.google.com/googleplay/android-developer/answer/16558241
  - *"only services designed to help people with disabilities … are eligible to declare themselves as accessibility tools … For all other uses … you will be required to complete an accessibility declaration in Play Console and must implement a clear in-app disclosure…"*
  - *"The Accessibility API is not designed and cannot be requested for: remote call audio recording; an app that autonomously initiates, plans, and executes actions or decisions."*
  - Our counts-only use stays permitted with a declaration.
- Android 17 Advanced Protection Mode reportedly revokes accessibility from non-tools: Security Affairs, Help Net Security, Malwarebytes [S]. Google's AAPM developer page doesn't list it [V-absent]: https://developer.android.com/privacy-and-security/advanced-protection-mode . AAPM is opt-in and aimed at at-risk users, so few people are affected.

### B. Local VPN: banks, precision, Play

- **Play policy** [V], https://support.google.com/googleplay/android-developer/answer/12564964
  - *"Only apps that use the VpnService and have VPN as their core functionality can create a secure device-level tunnel to a remote server. Exceptions include apps that require a remote server for core functionality such as: … App usage tracking …"*
  - *"Apps that use the VpnService must: Document use of the VpnService in the Google Play listing, must encrypt the data from the device to the VPN tunnel endpoint…"*
  - The declaration also needs a video of 90 s or less of the VPN in use, and a separate video of the prominent disclosure.
- **How NetGuard lives on Play with no server.** The README says *"The only way to build a no-root firewall on Android is to use the Android VPN service. Android doesn't allow chaining of VPN services…"* [V] https://github.com/M66B/NetGuard . It is on Play (`eu.faircode.netguard`) and offers *"record network usage per application per address"*. That is exactly per-UID, per-destination byte accounting.
  - The policy text is about tunnels *"to a remote server"*. A purely local packet-processing VPN arguably isn't creating one. How reviewers apply the encryption clause to local-only VPNs is **[U]**: there's no public statement from Google, NetGuard or Rethink.
  - **Licence:** NetGuard is **GPL-3.0** (README), which isn't permissive. We would need a permissively licensed tun stack or our own.
- **Banks and VPN.** Only anecdotes [S]:
  - "AdGuard DNS (uses the VPN slot) … the app works normally" once turned off.
  - "ICICI banking app doesn't work … even while being whitelisted when using a VPN".
  - No bank help page or NPCI note was found [U].
  - **Mitigation idea [U]:** run the VPN only while an AI app is in the foreground. After the one-time `VpnService.prepare()` consent, the app can start and stop the VPN itself. Foreground detection then needs Usage Access polling, which costs battery.
- **Can a VPN count turns and reply size without decrypting?** Literature says yes, and with alarming precision:
  - Weiss et al., USENIX Security 2024: packet sizes in encrypted streaming leak per-token lengths. They report *"many vendors, including OpenAI and Microsoft, had this side-channel prior to our disclosure."* https://usenix.org/system/files/usenixsecurity24-weiss.pdf [S-summary of primary paper]
  - Whisper Leak (arXiv 2511.03675): sizes and timings reveal prompt **topic** even with token batching. https://arxiv.org/pdf/2511.03675 [S]
  - **For Sipcount:**
    - Burst count per UID gives turns: a good signal [U].
    - Total downstream bytes give reply length: OK after a padding correction (vendors added padding after disclosure) [U].
    - Burst duration gives "model worked" time [U].
  - **Caution:**
    - The same channel can infer topics, so the privacy framing must say *"we keep only byte totals and timings per flow and never inspect payloads."*
    - QUIC/HTTP3 multiplexing and app telemetry on the same hosts add noise [U].
    - `ConnectivityManager.getConnectionOwnerUid()` exists for mapping a flow to a UID. Its VPN-only restriction and API 29 level are **[U]** (signature confirmed, description not retrieved).
- **Battery:** user-space packet forwarding has a real cost, and NetGuard's FAQ #4/#32 discuss it [V-title]. Expect a few percent per day [U].

### C. "Sipcount is where you use AI": in-app browser

- **Android WebView can inject our script.** `WebViewCompat.addDocumentStartJavaScript` *"Adds a JavaScript script to the WebView which will be executed in any frame whose origin matches allowedOriginRules when the document begins to load."* [V-snippet of developer.android.com AndroidX reference]. iOS WKWebView has `WKUserScript` [U-known API, not re-quoted].
- **Custom Tabs / SFSafariViewController can't inject.** The Android Developers Custom Tabs overview says *"WebView is going to be the right technology to use if you are exclusively hosting your own content inside your app, or if you need to inject javascript directly from your app."* [V-snippet] https://developer.android.com/develop/ui/views/layout/webapps/overview-of-android-custom-tabs . The Chromium Custom Tabs security FAQ says the host app gets *"very limited access to web page data"* [S]. SFSafariViewController has the same restriction [U-known].
- **Sign-in is the blocker.**
  - **Google accounts are blocked in WebViews.** The Google Developers Blog (2021) says *"Embedded webviews implementing or extending Android WebView do not comply with Google's secure browser policy"* and the same for WKWebView. The error is `disallowed_useragent` [S-quoted via search of the primary blog]: https://developers.googleblog.com/upcoming-security-changes-to-googles-oauth-20-authorization-endpoint-in-embedded-webviews/ . So **Gemini web (Google sign-in only) is effectively unusable in a WebView**, and so is "Continue with Google" on ChatGPT and Claude.
  - Email/password, passkeys and Apple sign-in on chatgpt.com, and email-code sign-in on claude.ai, *may* work. Cloudflare/Turnstile challenges in WebView are **[U]**, a device test is needed.
  - **Out-of-the-box variant:** embed **GeckoView** (Mozilla, MPL-2.0) and ship our content script as a built-in WebExtension (`WebExtensionController.installBuiltIn`, "built-in extensions don't need signatures and have access to native messaging to the app") [V-snippet] https://firefox-source-docs.mozilla.org/mobile/android/geckoview/consumer/web-extensions.html . Whether Google sign-in accepts a GeckoView-based app is **[U]**; Firefox itself works, but an embedder might be classed as an "embedded browser framework". It also adds about 50–80 MB to the APK [U].
- **Store and ToS risk**
  - Apple [V] https://developer.apple.com/app-store/review/guidelines/
    - 5.2.2: *"If your app uses, accesses, monetizes access to, or displays content from a third-party service, ensure that you are specifically permitted to do so under the service's terms of use. Authorization must be provided upon request."*
    - 4.2: *"…elevate it beyond a repackaged website."*
    - 2.5.6: *"Apps that browse the web must use the appropriate WebKit framework…"*
  - Play's "Webviews and Affiliate Spam" bans apps whose **primary purpose** is *"provide a webview of a website without permission from the website owner or administrator"* [S-paraphrase of https://support.google.com/googleplay/android-developer/answer/9899034]. Sipcount's primary purpose is tracking, so this is arguable but not safe.
  - OpenAI Terms of Use (effective 1 Jan 2026) [V] https://openai.com/policies/row-terms-of-use/ prohibit you from: *"Automatically or programmatically extract data or Output (defined below)."* **This applies to the existing Chrome extension too.** Counting lengths in the DOM without storing text is a grey zone. Get a legal read before marketing it as "reads ChatGPT". I didn't check Anthropic or Google consumer terms [U].

### D. Mobile browser extensions (same content script)

| Browser | Status | Source |
|---|---|---|
| **Safari iOS / iPadOS** | Safari Web Extensions run content scripts. They need a containing app on the App Store and per-site permission granted by the user. | [S] Apple Safari extensions page plus WWDC21 "Meet Safari Web Extensions on iOS". Dev-forum reports of content scripts not injecting until permission is granted. |
| **Firefox Android** | Open extension ecosystem since Dec 2023. Extensions marked Android-compatible are installable from AMO. | [S] Mozilla blog https://blog.mozilla.org/en/mozilla/new-extensions-youll-love-now-available-on-firefox-for-android/ |
| **Edge Android** | Extensions in **stable** since v134 (Mar 2025): a curated list of about 20, marked Beta. Canary allows install by ID. A public submission path for new extensions is **[U]**. | [S] Android Authority, Beebom |
| **Kiwi** | **Discontinued** Jan 2025 and removed from Play. Its extension code went into Edge Canary. | [S] Android Authority, Neowin |
| **Samsung Internet** | Has its own add-on platform with a selected API subset. One source says MV3 distribution started Apr 2026 [S]. | https://developer.samsung.com/internet/android/extension-guide.html [S] |
| **Chrome Android** | **No extensions** for users as of Aug 2026. An experimental desktop-class Chromium build for Android PCs exists. | [S] itechguides 2026, Android Authority |
| **Opera Android / Vivaldi Android** | Opera: no [U]. Vivaldi: single unverified claim of Web Store support from Sep 2026 [U]. | — |

Firefox Android, plus Safari iOS, are realistic ports of the existing content script. Most Android users use Chrome, so on Android this covers only a minority [U].

### E. Vendor-side data

- **ChatGPT export** [V] https://help.openai.com/en/articles/7260999
  - *"Available for ChatGPT Free, Go, Plus, Pro, and eligible ChatGPT Edu workspaces."*
  - *"Exports can take up to 7 days to arrive."*
  - *"The download link expires 24 hours after you receive it."*
  - The ZIP holds `conversations.json`. That file reportedly has per-message `create_time` and model metadata (`model_slug`) **[S/U, verify on a real export]**.
  - **It covers the phone app too**, because conversations are account-level.
- **Claude export** [V] https://support.claude.com/en/articles/9450526
  - *"Data exports are available to individual Claude users on Free, Pro, and Max plans."*
  - *"It's not possible to run an export from Claude for iOS or Android."*
  - *"The download link will expire 24 hours after delivery."*
- **Gemini:** Google Takeout → My Activity → "Gemini Apps", in JSON. Prompts, responses and timestamps per third-party guides **[S]**. Workspace accounts may come out empty [S].
- **How it would work.** The user downloads the ZIP and opens it with Sipcount ("Share to Sipcount" or a file picker). We parse it **on-device**, count turns per day, prompt/reply lengths and model per turn, then **discard the file**. Content never leaves the device, consistent with zero retention.
  - **Dedup** against turns the extension already measured, by timestamp window.
  - **Limits:** manual, up to 7 days of latency, deleted chats excluded, no "model worked" duration (except possibly the gap between create_times [U]), and Temporary Chats aren't exported [U].
- **Usage APIs:** no consumer per-user usage API from any of the three [U-none found].
- **Published per-response footprints**
  - Google (Aug 2025): median Gemini Apps text prompt **0.24 Wh, 0.03 gCO₂e, 0.26 mL water**. That is comprehensive serving (TPU + host + idle + PUE). The active-chip-only figure is 0.10 Wh and 0.12 mL. https://cloud.google.com/blog/products/infrastructure/measuring-the-environmental-impact-of-ai-inference [S-summary of primary]
  - OpenAI (Altman, "The Gentle Singularity", Jun 2025): **0.34 Wh and 0.000085 gal (~0.32 mL)** per average query. No methodology was published [S].
  - Mistral LCA (Jul 2025): a 400-token Le Chat response is **1.14 gCO₂e, 45 mL water, 0.16 mg Sb eq**. This is life-cycle, including amortised hardware, so it isn't comparable to Google's operational figure. https://mistral.ai/news/our-contribution-to-a-global-environmental-standard-for-ai [S-summary of primary]

### F. OS-level hooks

**Android**
- **Usage Access (`PACKAGE_USAGE_STATS`)**
  - `queryEvents` gives `ACTIVITY_RESUMED` / `ACTIVITY_PAUSED` with timestamps per package. The user grants it in Settings (`ACTION_USAGE_ACCESS_SETTINGS`). Events are kept for only a few days, so we must harvest daily [S-snippet of developer.android.com UsageStatsManager / UsageEvents.Event].
  - **Play:** PACKAGE_USAGE_STATS doesn't appear on Play's "Permissions and APIs that Access Sensitive Information" page I fetched; that page covers Accessibility, VpnService, etc. So no special declaration appears to be needed **[V-by-absence, treat as likely]**.
  - **Banks:** not a capture, control or overlay permission; not mentioned by HSBC.
  - **Gives:** sessions and minutes per AI app. **Doesn't give:** sends, lengths, model.
  - **Downside:** no push callback, so real-time needs polling.
- **Accessibility "session mode"**
  - The `AccessibilityService` reference says a service stops when the user turns it off *"or when it calls AccessibilityService.disableSelf()"*, and starting is *"triggered exclusively by the user explicitly turning the service on in device settings"* [V-snippet].
  - `android:tileService`: *"the fully qualified class name of the TileService associated with this accessibility service for one to one mapping"*. API 33 per the API diff [V-snippet / S].
  - So the user flips a Quick Settings tile or the accessibility shortcut when starting an AI session. We auto-`disableSelf()` on leaving AI apps or after N idle minutes.
  - Whether a tile or shortcut re-enable counts as "explicit" (it should, since the user acts) and works without visiting Settings needs a **device test [U]**.
  - Banking apps that check at launch would then see nothing [U]. Ones that check continuously would still trip if the user banks mid-session [U].
- **Notification listener:** only sees notifications. The AI apps don't notify per turn when in the foreground [U]. Banks' stance: none found. Low value.
- **Android 16/17 AppFunctions and Gemini integrations** expose *our* app's functions to agents; they don't observe other apps [U-design reading]. No public Digital Wellbeing data API exists beyond UsageStats [U].
- **Avoid:** SYSTEM_ALERT_WINDOW overlays and MediaProjection, which both trip app access risk [V-by category definition].

**iOS**
- **Screen Time.**
  - DeviceActivityReport [V-snippet of Apple docs]: *"To protect the user's privacy, your extension runs in a sandbox. This sandbox prevents your extension from making network requests or moving sensitive content outside the extension's address space."* It can display minutes in ChatGPT but can't hand them to our sync.
  - DeviceActivityMonitor `eventDidReachThreshold` can write to an App Group (developers do this) [S]. Setting thresholds every N minutes for the ChatGPT app token would yield "≥N minutes today" in coarse steps. The 6 MB memory limit [S] makes it fiddly, and the policy view is [U].
- **Shortcuts personal automation** [V] Apple Shortcuts guide, https://support.apple.com/guide/shortcuts/apde31e9638b/ios
  - *"Is Opened: Triggers your automation when you open or switch to the selected app."*
  - *"Is Closed: Triggers your automation when you close or switch from the selected app."*
  - Our App Intent "Log AI session start/end" runs silently when "Ask Before Running" is off [S].
  - **This gives exact session durations per AI app on iOS with no Screen Time entitlement.** The user has to set up two automations per app; we can ship a guided setup. An iOS 26.6 bug fires "Is Closed" on opening Control Center [S].
- **Vendor App Intents**
  - Claude: *"Ask Siri to 'Ask Claude'"* plus a Shortcuts action [S] https://support.claude.com/en/articles/10263469
  - ChatGPT: an "Ask ChatGPT" Shortcuts action with model choice [S].
  - If the user asks through *our* shortcut wrapper, we see prompt and reply lengths. That is a niche habit, not a sensor.
- **Safari Web Extension:** see D.

**Windows / macOS**
- **Browser extension:** already working.
- **Native ChatGPT/Claude desktop apps**
  - Windows UI Automation and the macOS Accessibility (AX) API can read other apps' text trees with user consent. There are no banking apps to conflict with on desktop. A Mac App Store sandbox likely forbids AX, so we'd distribute via Developer ID [U].
  - ETW kernel-network events give per-PID bytes but need admin [U].
- **macOS network filter:** LuLu (open source) uses a Network Extension filter approved by the user in System Settings, with no MDM [S] https://objective-see.org/products/lulu.html . On iOS, a content filter needs supervision/MDM, per Apple DTS on the forums [S].

### G. Out-of-the-box ideas

1. **Time-in-app × calibrated rate.** This is the backbone, see section 4.
2. **Export reconciliation.** A monthly "true-up" that turns estimates into measurements retroactively, across *all* surfaces including the phone apps. It is the strongest calibration source we can get without any sensor.
3. **On-phone in-app browser as the calibration instrument.** Even if a user only occasionally chats inside Sipcount's browser, those sessions measure *their phone behaviour* precisely, so the coarse rate is fitted on-device.
4. **Session mode.** A Quick Settings tile ("Count this AI session") arms the Accessibility service or a VPN only while the user is chatting, then auto-disarms. It is honest and explicit, and nothing is left running when banking.
5. **Share-to-Sipcount.** Sharing a ChatGPT/Claude share link or text to Sipcount counts it on-device. Low adoption; ToS grey zone.
6. **MCP / ChatGPT Apps / Claude connectors / Gemini extensions.** **Not viable for counting all turns.** The model calls a tool only when it decides to: "ChatGPT decides when your tools fire based on the metadata you provide" [S]. Forcing a call every turn would *add* compute and water.
7. **Claude Code / Codex CLI hooks.** **Viable for developer tools.** Claude Code hooks receive `UserPromptSubmit` (with `prompt`) and `Stop` (with `last_assistant_message`) [S-summary of https://code.claude.com/docs/en/hooks]. A Sipcount hook could count lengths locally; ByteThirst already ships a CLI for this.
8. **Vendor partnership.** Google publishes per-prompt numbers, so a "footprint" API is plausible to ask for. Nothing exists today [U].
9. **Wearable / notification prompts.** At most a nudge ("You've been in ChatGPT for 20 min, log a session?"). Not a sensor.

---

## 3. Matrix: mechanism × platform

Column key:
- **Send / P / R / M / D** = detects send / prompt length / reply length / model or tier / model-worked duration.
- ✓ = measured, ~ = estimated or heuristic, ✗ = none.
- **Bank** = conflict with Indian banking/UPI apps.

| # | Mechanism | Platform | Send | P | R | M | D | Accuracy | Privacy | Store-policy risk | Bank | Battery | Build effort |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Content-script extension (today) | Desktop Chrome/Edge/Firefox | ✓ | ✓ | ✓ | ✓ | ✓ | High | Counts only on-device | Low (CWS); OpenAI ToS grey | n/a | Negligible | Done |
| 2 | Same script as a mobile extension | Safari iOS, Firefox Android, Edge Android (curated), Samsung Internet | ✓ | ✓ | ✓ | ✓ | ✓ | High | Same | Low–med: App Store review needed for Safari; Edge submission [U] | None | Low | Med (Safari wrapper app, per-browser quirks) |
| 3 | In-app browser (WebView/WKWebView + injected script) | Android, iOS, desktop | ✓ | ✓ | ✓ | ✓ | ✓ | High where sign-in works | Same; we host the session (cookies stay on device) | **Med–high**: Apple 5.2.2/4.2, Play webview-spam, vendor ToS; Google sign-in blocked | None (WebView isn't capture/control) [U-test] | Low–med | Med |
| 3b | In-app GeckoView + built-in WebExtension | Android | ✓ | ✓ | ✓ | ✓ | ✓ | High | Same | Same as 3; APK size | None [U] | Med | Med–high |
| 4 | Always-on AccessibilityService (today) | Android | ✓ | ✓ | ~ (not built) | ~ | ~ | Med–high | Reads screen text in AI apps only | Med (declaration + disclosure); AAPM revocation [S] | **Yes** (HSBC [V]; others reported) | Low–med | Done |
| 5 | Accessibility **session mode** (tile/shortcut on, auto `disableSelf`) | Android 13+ | ✓ | ✓ | ~ | ~ | ~ | Same while on; 0 when off | Better: off by default | Same as 4 | **Low** if off when banking [U-test] | Low | Low–med |
| 6 | Usage Access foreground sessions × calibrated rate | Android | ~ | ~ | ~ | ~ | ~ | Low per turn, OK per day once calibrated [U] | Excellent (no content) | **Low** (no declaration found) | **None known** | Low (daily harvest); med if polled live | Low |
| 7 | Local VpnService flow metering (bytes/timing per UID+host) | Android | ✓ [U] | ~ | ~ (good) | ✗/~ (endpoint hints) | ✓ [U] | Med–high [U] | Good if only byte totals kept; topic-leak risk must be designed out | **Med**: declaration, 2 videos, "encrypt to endpoint" clause for local VPN [U]; GPL code not reusable | **Possible** (anecdotal VPN blocks); mitigated by foreground-only VPN [U] | Med | High |
| 8 | NetworkStatsManager | Android | ✗ | ✗ | ~ (hourly) | ✗ | ✗ | Too coarse (known) | Good | Low | None | Low | Low |
| 9 | Notification listener | Android | ✗ | ✗ | ✗ | ✗ | ~ | Very low | Reads notifications | Low–med | Unknown | Low | Low |
| 10 | Custom keyboard (IME) | Android, iOS | ✓ | ✓ | ✗ | ✗ | ✗ | Med (prompt only) | Sees all typing (bad optics) | Med | **Yes** (HSBC "reset keyboard" [V]) | Low | High |
| 11 | Shortcuts "App Is Opened/Closed" → our App Intent | iOS | ✗ | ✗ | ✗ | ✗ | session min | Session-exact; turns estimated | Excellent | Low | n/a | Negligible | Low |
| 12 | DeviceActivityMonitor thresholds | iOS | ✗ | ✗ | ✗ | ✗ | ~minutes buckets | Low | Excellent | Med (Family Controls entitlement) | n/a | Low | Med |
| 13 | DeviceActivityReport | iOS | ✗ | ✗ | ✗ | ✗ | display only | Can't sync [V] | — | — | n/a | — | — |
| 14 | Vendor export import (ChatGPT/Claude/Takeout) | Any (parse on-device) | ✓ | ✓ | ✓ | ✓ [U] | ~ [U] | **Highest (ground truth), lagged** | Content handled transiently on-device then deleted | Low | None | Negligible | Med (3 parsers, dedup) |
| 15 | Windows UIA / macOS AX on native AI apps | Desktop app | ✓ | ✓ | ✓ | ~ | ✓ | Med–high [U] | Reads AI app text only | Low (outside Mac App Store) | n/a | Low | Med–high |
| 16 | ETW / macOS NE filter flow metering | Desktop app | ✓ | ~ | ~ | ✗ | ✓ | Med [U] | Good | Low–med | n/a | Low | High |
| 17 | MCP / ChatGPT Apps / connectors | In AI tools | ✗ (only when called) | — | — | — | — | Not viable | — | — | — | — | — |
| 18 | Claude Code / CLI hooks | Desktop dev tools | ✓ | ✓ | ✓ | ✓ | ✓ | High | Local | Low | n/a | Negligible | Low |
| 19 | Manual / session button / share | Any | ~ | ~ | ~ | ~ | ~ | Low | Excellent | Low | None | Negligible | Low |

---

## 4. Recommended cross-platform architecture

**One event model, two event kinds**
- `TurnEvent { day, surface, vendor, modelTier, promptChars?, replyChars?, workSeconds?, source, confidence }`. Precise sources emit these: extension, mobile extension, in-app browser, session-mode accessibility, VPN, CLI hooks, export import.
- `SessionEvent { day, surface, vendor, foregroundSeconds, source }`. Coarse sources emit these: Usage Access, iOS Shortcuts automations, Screen Time thresholds.

**One estimator** turns `SessionEvent`s into expected turns and tokens using a `CalibrationProfile` per user and vendor:
`turnsPerForegroundMinute`, prompt/reply length distributions, reasoning share, and workSeconds distribution.
- Population priors ship in `models.json`, consistent with the existing `calibration` block plan in `docs/SENSING-REVIEW.md`.
- A per-user posterior is updated on-device from precise data.
- Footprint conversion (Wh → mL) stays the same for both kinds.

**DayTotals (the canonical sync doc)** keeps three sub-totals per vendor and surface:
- `measured`: from TurnEvents.
- `estimated`: from SessionEvents × profile, with an uncertainty band.
- `reconciled`: from export import, account-wide.

**Sync rules**
- Per-device measured and estimated totals add across devices; each device reports only its own usage.
- When a reconciled export covers a day, it **replaces** estimated values for that vendor-day. Measured turns that match export turns (±60 s) are de-duplicated rather than added.
- The UI shows "measured / estimated / verified", so honesty is built in.

**How desktop calibration transfers to phones (three layers)**
1. **Desktop → profile.** The extension already knows foreground tab time and turns, so it fits `turnsPerForegroundMinute`, lengths, reasoning share and duration per vendor. This syncs as part of the profile, which is a few numbers and no content.
2. **Phone-specific correction.** Mobile chats are probably shorter and more frequent [U]. The phone's own in-app browser sessions (and Safari/Firefox extension sessions) fit a `mobileFactor` on-device. Without those, use a prior and show a wider band.
3. **Ground-truth true-up.** Each export gives the true turns for day d. Subtract desktop-measured turns to get mobile-app turns, then regress on Usage Access minutes for day d to get a per-user mobile rate. A single export of 30 days of history can calibrate a new phone user immediately.

**Per-platform plan**

| Surface | Precise | Coarse | Truth-up |
|---|---|---|---|
| Desktop browsers | Extension (today) | — | Export |
| Desktop native apps (Inc 5) | UIA/AX reader (opt-in) | Foreground-window time | Export |
| Android app | In-app browser; session-mode accessibility; (later) VPN | **Usage Access (default)** | Export |
| iOS app | In-app browser; Safari extension | **Shortcuts open/close automations** | Export |
| Mobile browsers | Safari iOS, Firefox Android, Edge Android extensions | — (Chrome Android: Usage Access treats Chrome as one app and can't tell sites [U]) | Export |
| CLI tools | Hooks | — | — |

---

## 5. Android shortlist (ranked, with the banking problem solved)

1. **Usage Access "coarse mode" as the default sensor.** Replaces always-on Accessibility.
   - Harvest `queryEvents` daily, plus on app open, for the AI packages. Build sessions and multiply by the calibration profile.
   - No banking conflict known, no Play declaration found, minimal battery.
   - Precedent: one sec ships exactly this fallback.
   - Weakness: estimates only. Mitigated by 2 and 3.
2. **In-app "Sipcount browser" for chatgpt.com and claude.ai.**
   - `WebViewCompat.addDocumentStartJavaScript` with the **same content script** as the extension; counts only, no storage of text.
   - Gives precise turns on the phone and powers the `mobileFactor`.
   - Gemini via Google sign-in likely fails (Google's WebView ban). Test GeckoView as plan B.
   - Before Play/App Store submission: check the webview-spam / 5.2.2 framing and get a ToS read.
3. **Export import ("Verify my month").**
   - File picker or share target; parse ChatGPT `conversations.json`, Claude export, and Gemini Takeout on-device; delete after counting.
   - Highest accuracy, includes native-app usage, zero runtime footprint.
4. **Accessibility session mode** for users who want per-turn precision in the native apps.
   - Keep the service, but off by default. Turn on via a QS tile (`android:tileService`, API 33) or the accessibility shortcut. Auto-`disableSelf()` 2–5 min after leaving AI apps.
   - Also check `AdvancedProtectionManager` and hide the option when AAPM is on.
   - Keep the Play declaration and in-app disclosure; never set `isAccessibilityTool`.
   - Add a "banking app detected → session ended" safeguard like Wispr Flow's. Usage Access tells us the foreground package even with accessibility off.
5. **Local VPN metering (experimental flag only).**
   - Only after device tests with SBI YONO, HDFC, ICICI iMobile, Axis, Kotak, PhonePe, Google Pay, Paytm and BHIM show that VPN-on isn't blocked, or that "VPN only while an AI app is foreground" avoids it.
   - High build cost; GPL reference code can't be reused; Play declaration plus videos.
   - Not recommended as a near-term increment.

Not recommended: a custom keyboard (banks flag it, and it only sees prompts), a notification listener, overlays or screen capture (trip app access risk), or MCP-based counting.

---

## 6. Open questions that need a real device

1. **Banking/UPI matrix** on two phones: SBI YONO, HDFC, ICICI iMobile, Axis, Kotak, PhonePe, GPay, Paytm, BHIM, CRED, plus HSBC as the documented baseline. For each app, test:
   - (a) Usage Access granted
   - (b) local VPN active
   - (c) accessibility enabled-but-idle
   - (d) accessibility disabled via `disableSelf()` before launch
   - (e) accessibility toggled on mid-session while the bank app is open (does it re-check continuously?)
   - (f) our app holding notification-listener access

   Record warning text and whether the app blocks or only warns.
2. Does re-enabling an accessibility service via **QS tile / accessibility shortcut** after `disableSelf()` work without opening Settings, on Pixel (Android 16/17), Samsung One UI and Xiaomi HyperOS?
3. Does Play Integrity app-access-risk return empty (no CAPTURING/CONTROLLING) with only Usage Access or VPN active? Use a debug app that requests the verdict.
4. **WebView sign-in:** chatgpt.com with email/password, passkey and Apple; claude.ai with an email code; gemini.google.com. Does Cloudflare/Turnstile challenge the WebView? Same tests in a GeckoView build.
5. **Export content:** confirm that ChatGPT `conversations.json` has per-message `create_time` and `model_slug`; whether Claude's export has timestamps per message and a model; whether the Gemini Takeout JSON has response text and timestamps; whether Temporary/incognito chats are excluded.
6. **Usage Access fidelity:** are `ACTIVITY_RESUMED/PAUSED` reliable for ChatGPT/Claude/Gemini apps, including split-screen and bubbles (Android 17)? What is the harvest window before events expire?
7. **VPN signal quality** (only if pursued): per-UID burst detection vs. ground truth from the in-app browser, the padding effect on reply-length estimates, QUIC handling, and battery over 24 h.
8. **iOS Shortcuts automations:** do "Is Opened/Is Closed" automations run our App Intent silently every time on iOS 26.x? How should we handle the Control Center false "closed"?
9. **Edge Android:** can a third party get an extension into the mobile catalogue today? Does Firefox Android accept our MV3 manifest unchanged?
10. **Legal:** get a read on OpenAI's *"Automatically or programmatically extract data or Output"* clause for DOM counting, plus Apple 5.2.2 for the in-app browser. This affects the existing extension too.

---

## 7. Primary sources used (quoted above)

- Play Integrity verdicts / app access risk: https://developer.android.com/google/play/integrity/verdicts
- Play VpnService policy: https://support.google.com/googleplay/android-developer/answer/12564964
- Play sensitive permissions (Accessibility, VpnService): https://support.google.com/googleplay/android-developer/answer/16558241
- Android Developers Blog, accessibilityDataSensitive: https://android-developers.googleblog.com/2025/12/enhancing-android-security-stop-malware.html
- Android 17 Beta 2 blog: https://android-developers.googleblog.com/2026/02/the-second-beta-of-android-17.html
- AAPM developer page: https://developer.android.com/privacy-and-security/advanced-protection-mode
- HSBC India RASP FAQ: https://www.hsbc.bank.in/help/faqs/rasp/
- Wispr Flow banking detection: https://wispr-knowledge-base.help.usepylon.com/articles/4909908692-banking-app-detection-support-in-wispr-flow
- one sec, no-accessibility mode: https://feedback.one-sec.app/help/articles/6315890
- AppBlock banking note: https://appblock.app/my-banking-app-payment-app-or-wallet-is-blocked-but-i-didnt-block-it/
- NetGuard README: https://github.com/M66B/NetGuard
- OpenAI Terms of Use: https://openai.com/policies/row-terms-of-use/
- ChatGPT export: https://help.openai.com/en/articles/7260999
- Claude export: https://support.claude.com/en/articles/9450526
- Claude iOS App Intents: https://support.claude.com/en/articles/10263469
- Apple App Review Guidelines (2.5.6, 4.2, 4.7, 5.2.2, VPN): https://developer.apple.com/app-store/review/guidelines/
- Apple Shortcuts triggers: https://support.apple.com/guide/shortcuts/apde31e9638b/ios
- Apple DeviceActivityReport: https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
- Custom Tabs overview: https://developer.android.com/develop/ui/views/layout/webapps/overview-of-android-custom-tabs
- GeckoView WebExtensions: https://firefox-source-docs.mozilla.org/mobile/android/geckoview/consumer/web-extensions.html
- Google OAuth WebView policy (2021 blog): https://developers.googleblog.com/upcoming-security-changes-to-googles-oauth-20-authorization-endpoint-in-embedded-webviews/
- ByteThirst: https://bytethirst.com/
- Google inference footprint: https://cloud.google.com/blog/products/infrastructure/measuring-the-environmental-impact-of-ai-inference
- Mistral LCA: https://mistral.ai/news/our-contribution-to-a-global-environmental-standard-for-ai
- Side channels: https://usenix.org/system/files/usenixsecurity24-weiss.pdf , https://arxiv.org/pdf/2511.03675
- Claude Code hooks: https://code.claude.com/docs/en/hooks
- LuLu: https://objective-see.org/products/lulu.html
