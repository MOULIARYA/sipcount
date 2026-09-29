# Testing the extension — 5 minutes, no money, no build

*The first time anyone checks whether Sipcount counts a real prompt on a real site. Until this is
done we do not know that the product works at all.*

## Install it

1. Open Chrome (or Edge) and go to **chrome://extensions**
2. Turn on **Developer mode**, top right
3. Click **Load unpacked**
4. Choose the folder `C:\dev\sipcount\browser_extension`

It appears as a puzzle-piece icon — there is no artwork yet (I-9) and that is fine. Pin it so you
can see the popup.

## Set it up

Click the icon. Set **Where your AI runs** to the region you want to test — pick **India** if you
want the figures that apply to you. A typical prompt reads ≈ 2.33 mL for India, ≈ 1.30 mL for the US.

## Then just use AI normally

Go to **chatgpt.com**, **claude.ai** or **gemini.google.com** and send a few prompts — anything real,
a short question, a long one, a coding question, an image request. Come back to the popup.

## What to tell me

Nothing here is a failure — every answer is useful, and "it counted nothing" is the most useful of all.

| | |
|---|---|
| **Did the count move at all?** | Per site: ChatGPT, Claude, Gemini |
| **One prompt = one count?** | Or did one send count twice, or not at all |
| **Does the model name come through?** | The popup's last-prompt line names a tier — light, standard, reasoning. If you were on a thinking model and it says standard, the model detection missed |
| **Long vs short** | A long question should cost visibly more than a short one |
| **Anything odd** | Counts appearing when you did not send, counts while just scrolling, the popup showing nothing at all |

### If nothing counts at all

Right-click the page → **Inspect** → **Console**, send a prompt, and tell me what appears (or that
nothing does). Also on **chrome://extensions**, click **service worker** under Sipcount and check
that console. That tells me whether the page hook is failing or the counting is.

## What this test decides

The send detection is written against how these three sites looked in September, and they change
their pages constantly. **This is the check that tells us whether our detection is sound or needs a
different approach** — and the same heuristics are what Android and the desktop build will use, so
what we learn here we do not pay for three more times.

## What it deliberately does not do

- No network permission at all — the extension cannot phone home, and the manifest says so
- Nothing you type is read, kept or sent; only a character count leaves the page hook
- Counts stay in this browser
