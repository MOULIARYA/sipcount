# Android sensing after the banking-app problem: decision note

*For Madhur and Mouli, 2026-10-19. Full research with every quote and URL:
`docs/SENSING-RESEARCH-2026-10-19.md`. Issue: I-72.*

## The problem in one paragraph

With Sipcount's Accessibility service switched on, banking apps refuse to run, and users switch
it off. This happens by design, and nothing in our own code can stop it:

- **Banks read the list of switched-on accessibility services and block anything they don't
  trust.** HSBC India puts it in writing: *"If our app detects accessibility permissions that are
  incompatible with its safeguards, it will show an alert and stop you using the app."*
  (https://www.hsbc.bank.in/help/faqs/rasp/)
- **Google's own fraud check, which banks can call, flags every such service except verified
  disability tools.** *"App access risk automatically excludes verified accessibility services
  that have been through an enhanced Google Play accessibility review"*
  (https://developer.android.com/google/play/integrity/verdicts).
- **We can't claim to be a disability tool.** Play lists *"monitoring apps"* among apps that are not
  accessibility tools (https://support.google.com/googleplay/android-developer/answer/10964491).

Narrowing which apps we watch makes no difference. Banks see that the service is switched on, not
what it watches.

## What other apps do

- **one sec, a screen-time app, faced the same choice and shipped a fallback that uses only Usage
  Access:** *"we decided to allow users to use one sec without the accessibility service – with our
  old legacy approach using the app usage permission. It has some downsides … but it's better than
  not being able to use one sec at all."* (https://feedback.one-sec.app/help/articles/6315890)
- **Wispr Flow, a dictation app, keeps Accessibility but detects banking apps and steps aside
  while one is open.**
- **Every AI water or carbon tracker we found is a desktop browser extension.** None works on a
  phone, so a working phone version would set us apart.

## Options, best first

| | What it is | Measures | Banking apps | Effort |
|---|---|---|---|---|
| **1** | **Usage Access (default).** Minutes spent in each AI app, converted to prompts using a rate learned from the user's own precise data | Time in each app; prompts and water are *estimated* | No known conflict. It isn't a capture, control or overlay permission | Low |
| **2** | **Sipcount browser.** chatgpt.com and claude.ai open *inside* Sipcount, running the same script as the Chrome extension | Everything, precisely, as on desktop | None expected | Medium. Google sign-in is blocked inside embedded browsers, so Gemini likely won't work. Store wording and terms of service need a read |
| **3** | **"Verify my month."** The user imports their ChatGPT or Claude data export, or their Google Takeout. We count prompts on the phone, then delete the file | The real number, after the fact, from every device including the phone apps | None | Medium |
| **4** | **Accessibility "session mode".** The current sensor, now *off by default*. The user turns it on with one tap for an AI session, and it turns itself off afterwards | Precise, while on | Low, provided it is off while banking (to be tested) | Low |
| 5 | Local VPN that meters traffic per app | Prompts and reply size from traffic timing | Unknown. Some bank users report VPN blocks | High. Play's VPN rules are awkward for a local VPN |

Not recommended: a custom keyboard (banks flag those too, and it only sees what you type), overlay
or screen capture (they trip Google's fraud check), or hooks inside ChatGPT or Claude (they only
fire when the model decides to call them).

## How it fits every platform and the later sync

- **Every surface feeds the same daily totals, split three ways: *measured*, *estimated* and
  *verified*.**
- **Precise sources:** the desktop extension, the Sipcount browser, Safari and Firefox mobile
  extensions, and session mode.
- **Estimated sources:** Usage Access on Android, and on iPhone, Shortcuts automations that log
  when an AI app opens and closes.
- **Verified source:** imported exports. When an export covers a day, it *replaces* that day's
  estimates rather than adding to them.
- **How the estimate learns:** the desktop extension gives each user's rate (prompts per minute,
  typical reply length). That rate travels with sync, so the phone's estimate is calibrated from
  day one. The UI says which kind of number it is showing.

## Update, 2026-10-19 (later the same day)

Madhur: no bank test needed — banks will not allow Accessibility, and people who have it off will
not turn it on. **Option 1 is built into Rel 1.4 (I-73)** as the recommended default; Accessibility
stays as an optional exact mode. Still open for Mouli: options 2 and 3, the one-tap pause for
option 4, and the thinking-level rule (I-69, interim: High and above = reasoning).

## Decisions needed

1. **Make Usage Access the Android default, with Accessibility opt-in?** Recommended. It removes
   the banking problem for everyone. The cost is that phone numbers become estimates until they are
   calibrated.
2. **Build the Sipcount browser?** It is the only way to get precise phone numbers without
   Accessibility. Get a legal read first: OpenAI's terms forbid you to *"Automatically or
   programmatically extract data or Output"* (https://openai.com/policies/row-terms-of-use/). That
   clause bears on the Chrome extension too.
3. **Run the banking-app test on Madhur's phone first?** Recommended before building anything.
   Test SBI YONO, HDFC, ICICI, PhonePe, GPay, Paytm and BHIM in four states: with Usage Access only,
   with Accessibility on, with Accessibility switched off before opening the bank app, and with a
   VPN on. It takes an afternoon and tells us whether option 4 alone would be enough.

**What ships today regardless:** reply measuring (I-70) improves Accessibility for as long as we
use it. If we move to session mode, it carries over unchanged.
