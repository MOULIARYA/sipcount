# Sipcount for Android — install & test guide

No developer tools needed. The APK is built automatically by GitHub every time the `app/` folder changes.

## 1. Get the APK

1. On your Android phone, open <https://github.com/mouliarya/sipcount/releases/tag/android-latest>.
2. Under **Assets**, tap `sipcount-android.apk`.
3. Chrome will warn that the file "might be harmful" — this is the standard warning for any app not from the Play Store. Tap **Download anyway**.
4. Open the download. Android asks to allow installs from Chrome: **Settings → Allow from this source**, then go back and tap **Install**.

Android 8+ required. Tested target: Android 13–15.

### If Google Play Protect blocks the install

In India and some other countries, Play Protect blocks *every* sideloaded app that declares an accessibility service, with a generic warning about "sensitive data / identity theft". It is not a finding about this app. Either tap **More details → Install anyway**, or (more reliable): open the **Play Store → profile picture → Play Protect → ⚙ → turn off "Scan apps with Play Protect"**, install the APK, then turn scanning back on.

## 2. Turn on counting

Since build 30 there are two ways, and you can use either or both:

**A. Estimate from time in AI apps (recommended — works alongside banking apps).**

1. Open Sipcount → tap **Open Usage Access settings**.
2. Find **Sipcount** in the list → toggle **Permit usage access** on.
3. Back in Sipcount, Settings → *How Sipcount counts* shows **Estimate from time in AI apps: on**.
4. From now on, each time you open Sipcount it reads how long ChatGPT, Claude and Gemini were open since the last time and adds an estimate (half a prompt per minute, priced as a typical prompt). The Today card says *includes an estimate* when it does. Android only keeps this history for a few days, so open Sipcount at least every couple of days.

**B. Exact counting (Accessibility — banking apps will refuse to run while it is on).**

1. Open Sipcount → Settings → *How Sipcount counts* → **Change** next to *Exact counting*.
2. Find **Sipcount prompt counter** (usually under *Downloaded apps* / *Installed services*) → toggle **On** → **Allow**.
3. Android shows a warning that the service can "view and control your screen". That is the OS's generic text for every accessibility service; Sipcount's code only reads button labels and text *length* (see *Privacy* below).
4. Back in Sipcount the pill in the top-right turns green: **Listening**.

### If the toggle is grey ("Restricted setting")

Android 13+ locks accessibility for sideloaded apps until you unlock it per app: **Settings → Apps → Sipcount → ⋮ (top-right) → Allow restricted settings**, then repeat step 2. On Samsung the item is in the same ⋮ menu; on Xiaomi/HyperOS look under *App info → Restrictions*.

## 3. Test it

1. Open ChatGPT, Claude or Gemini (app or in Chrome), type a prompt, tap **Send**.
2. Switch back to Sipcount: the droplet fills, the mL counter moves, a nudge appears if a lighter model would have done.
3. No Accessibility permission yet? Use the **Try it (demo)** buttons at the bottom of the Today screen — they add fake prompts through exactly the same path.
4. **Estimate mode:** spend ten minutes in Gemini, then open Sipcount. Expect about 5 estimated prompts and roughly 6–12 mL depending on your region, with *includes an estimate* on the Today card.
5. **Reply measuring (build 30):** ask one long question in each app and note what Sipcount shows for it. A long answer should read several times more than a one-line one.

## 4. What to report back

- Which app / model you used, and whether the counter moved (expected: roughly 1–1.5 mL for a normal question, ~13 mL for a reasoning model or an image).
- Any prompt that was **not** counted (tell me the app and how you sent it — Send button vs keyboard Enter).
- Any double-count.

## Privacy, in one paragraph

The app has **no internet permission** — Android will not let it send anything anywhere. The accessibility service is restricted to four apps (ChatGPT, Claude, Gemini, Chrome) and three event types. When you tap Send it measures how many characters were in the text box, looks for a model name on short UI labels (e.g. "o3", "Flash"), then forgets everything except a single number: millilitres, added to today's total. Totals are excluded from cloud backup. **Settings → Delete all totals** wipes them.

## Known limitations (v0.3)

- Detection in the ChatGPT and Gemini apps relies on the text box emptying when you send (their UI toolkit hides button taps from accessibility services). Clearing a typed prompt with select-all + delete will be counted as a send.
- Image *generation* is not distinguished from a normal prompt; attaching a file or image counts as "long context".
- Hidden reasoning tokens cannot be seen, so reasoning-model estimates use a fixed 10× multiplier (low confidence).
- Other browsers (Firefox, Samsung Internet, Edge) are not yet whitelisted.
