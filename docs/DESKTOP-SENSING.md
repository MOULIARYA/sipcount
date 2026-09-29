# Counting prompts in desktop apps

*2026-09-27. Madhur: "How can we track when people are using desktop apps like Claude, ChatGPT, Copilot?"*

## The problem

The desktop ChatGPT, Claude and Copilot apps are ordinary programs talking HTTPS to their own servers. We have to notice that a prompt was sent, and roughly how big the answer was, **without ever seeing what was typed** — that constraint is the product, not a nicety.

Good news: desktop is the *easiest* of the five surfaces. Nobody gatekeeps what you install on a laptop, both operating systems publish per-process network statistics to ordinary user programs, and we need none of the entitlements that make iOS hard.

## Four ways in, least invasive first

### 1. Per-process network counters — **recommended primary signal**

Windows and macOS both tell any user-level program how many bytes each running process has sent and received. Poll a few times a second and a prompt has an unmistakable shape: **a small upload, then a larger download that arrives gradually** as the answer streams back.

What we see: *"ChatGPT.exe sent 4 KB and received 40 KB just now."*
What we never see: the prompt, the answer, or anything decrypted. No certificate is installed, no traffic is redirected, nothing leaves the machine.

- **Windows:** `GetExtendedTcpTable` for per-process connections, `GetPerTcpConnectionEStats` for bytes. No administrator rights for the user's own processes.
- **macOS:** the same through the system's network statistics interface (what `nettop` reads). Unprivileged for your own processes.

Limitation: it gives **bytes, not tokens**. We infer tokens from bytes — which is exactly the coefficient the calibration is going to measure (see below).

### 2. Which app is in front — supporting signal

Both systems let a program see the frontmost application with no special permission (`GetForegroundWindow` on Windows, `NSWorkspace.frontmostApplication` on macOS). This gives *"ChatGPT was in front for 22 minutes."*

Two jobs: attributing traffic when several AI tools are open at once, and acting as the coarse fallback if signal 1 is unavailable. Note that reading window **titles** on macOS needs the Accessibility permission — we don't need titles, so we don't ask.

### 3. A local proxy — fallback, more invasive

Point the apps at a proxy running on the same machine. It sees the destination hostname and the byte counts, still without decrypting anything (no certificate, no interception of content). More reliable than per-process counting, and the only thing that cleanly identifies Copilot.

The cost is that it changes the user's system proxy settings, which is a much bigger thing to ask for and a much bigger thing to get wrong. Hold it in reserve.

### 4. Reading the interface — rejected

Both systems have accessibility interfaces that could literally watch the Send button. Most accurate, and we are not doing it. It requires a permission that frightens people, it is fragile, and an app that promises never to read your prompts should not be asking for the ability to read your prompts.

## Copilot is the awkward one

**Copilot often has no process of its own.** In the Edge sidebar it is Edge. In Word it is Word. On the Windows taskbar it is a system component. Per-process counting cannot separate it from whatever it is embedded in, and attributing Word's traffic to "AI" would be wrong.

Only the **destination hostname** distinguishes it, which means Copilot needs signal 3 rather than signal 1.

**Recommendation: do not promise Copilot in the first desktop release.** Ship ChatGPT and Claude, which are real, separate applications, and add Copilot when the proxy path is built and tested. Saying "we cannot see Copilot yet" is fine. Silently attributing Office traffic to it is not.

## Why desktop is where we finally measure the 5×

The output-token multiplier is a placeholder (D-22): 5×, the central estimate of a 3–10× range, standing in until real data replaces it.

**Desktop is the only surface where we can get ground truth.** We can run a scripted prompt, so we know exactly what went in and what came back, and read the byte counters at the same moment. That gives two coefficients we currently guess:

1. bytes on the wire → tokens
2. input tokens → output tokens (the 5×)

Both then transfer to Android and iOS, which use the same byte-shape signal from a different vantage point. So the desktop build is not just another product — **it is the measuring instrument for the whole programme** (I-30), and that is a reason to build it earlier than its user numbers alone would justify.

`engine.js` is already built for the swap: `OUTPUT_PER_INPUT` is a single constant, everything else derives from it, and `docs/test/parity.js` proves the calibrated reference prompt stays at 0.30 Wh at 3×, 5×, 8× and 10×.

## Build notes

- **Tauri** (Rust, MIT) over Electron: a few MB instead of a hundred, no bundled browser, and the interface is the web code we already have. Fits the open-source and lightweight constraints.
- **Windows:** unsigned downloads trigger SmartScreen warnings. A code-signing certificate is roughly $100–400/yr, and reputation takes time to build even with one.
- **macOS:** needs notarisation, which needs the Apple developer account — the same one the iPhone work needs.
- Distribution is direct download, so there is no store review on either platform.

## While sync is off

Each surface counts only what it can see, and they do not add up. A person with the extension and the phone app will see two different numbers and may reasonably think one is broken.

**The interface has to say so.** While sync is off, the dashboard's "Water today" should read as *this device's* total, not *your* total. One word of copy, and it stops the app making a claim it cannot support.

## Signing and the company

**Decided 2026-09-27 (Madhur): the Windows code-signing certificate goes under the same new Sipcount company** as the Apple organisation account.

That company is now on the critical path for three separate things:

| Needs the company | For |
|---|---|
| Apple **organisation** account | the full iPhone build — Apple does not let individuals publish the traffic-tunnel kind of app |
| Apple **notarisation** | the macOS desktop build (the $99 individual account covers this one, but the org account supersedes it) |
| **Windows code-signing certificate** | desktop downloads, or every user meets a SmartScreen warning |

Nothing else shortens the clock on any of them, so registration is the highest-leverage thing to start. Note that code-signing reputation on Windows builds up over time even *with* a valid certificate, so buying it early has value beyond the paperwork.

## Counter, not viewer — decided 2026-09-27

The choice was a false one: **a counter contains the viewer.** The desktop app shows the dashboard either way; the only question was whether it also senses. It does.

1. **A viewer has nothing to show.** Sync is deferred, so it would open to an empty window, and even afterwards it would only mirror the phone.
2. **Desktop is where the expensive prompts are.** Coding, long documents, reasoning models. Our own engine puts a heavy desktop prompt at **28.3 mL against 1.3 mL** for a typical phone prompt — 22×. Counting only phones measures the small end of people's usage and feeds the "this number is trivial" problem identified in `PRE-BUILD-REVIEW.md` §7.
3. **Nothing else can replace the 5×.** A viewer measures nothing, so the multiplier stays a guess (D-25).
4. **It is the cheapest counter we will ever build.** No store review, no entitlements, no VpnService. Sensing is hardest on iOS, medium on Android, easy here — so build it here first and port the heuristics *down* to the harder platforms.

Clean division of labour: the browser extension already covers AI used in a browser, so the desktop app's unique job is precisely the native ChatGPT and Claude apps.

**Risk to watch:** a background process reading per-process network statistics can trip antivirus or endpoint security, particularly on managed work laptops — and a meaningful share of the audience is on one. Mitigations: the code-signing certificate (another reason to buy early rather than at launch), plain documentation of exactly what is read, and the foreground-app fallback, which touches nothing sensitive.

**Sequencing note:** if any one surface is ever pulled forward out of the queue, it should be this one — cheapest counter, and the instrument that fixes the multiplier for every other platform.

## Windows and macOS: both, in parallel — decided 2026-09-27

"Keep marching, release whatever is ready." In practice:

- **Windows can start now.** Unsigned builds are fine for our own testing; the certificate is only needed to distribute.
- **macOS waits on the $99 Apple account** for notarisation — the same account the iPhone work needs.

Same Tauri codebase and the same interface for both, so the second platform costs little beyond its own sensing layer.
