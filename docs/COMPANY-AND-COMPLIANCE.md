# Track E — Company, accounts and compliance

*2026-09-27. Owner: Madhur. Not code, and the critical path anyway: the longest lead times in the
whole programme sit here, and it is the track most likely to slip because nothing visible happens.*

**I am not a lawyer or an accountant.** Everything below is procedural and factual, gathered to help
you sequence the work and brief the people who are qualified. The items marked ⚖️ need one.

---

## Two corrections to what I told you earlier

1. **EV code-signing certificates no longer buy instant SmartScreen trust.** Microsoft removed that
   in 2024; OV and EV now build reputation the same way, through clean downloads over time. EV is
   only mandatory for kernel drivers, which we do not ship. **So buy OV, not EV** — listed from
   about **$219/yr**. My earlier steer was out of date.
2. **Google Play only requires a D-U-N-S number for *organisation* accounts.** A personal Play
   account does not need one. That matters for sequencing — see below.

Still true: certificate reputation accrues over time whichever type you buy, so buying early has
value beyond the paperwork.

---

## Sequence, with what depends on what

### Start immediately — nothing blocks these

| | Item | Cost | Notes |
|---|---|---|---|
| E1 | ⚖️ **Read your Xebia employment contract** | — | IP assignment, moonlighting, conflict-of-interest clauses. Do this *before* registering anything. If the contract claims work product, that is far cheaper to resolve now than after a company exists and a product ships. |
| E2 | ⚖️ **Founders' agreement with Mouli** | — | Who owns the IP, the split, what happens if one of you leaves, who decides what. You are already several weeks into real work with a clear division of labour and no document. |
| E3 | **Apple Developer Program, individual** | $99/yr | Unblocks all iPhone and macOS development and testing immediately. Does not need the company. Buy now. |
| E4 | **Chrome Web Store developer account** | $5 one-time | Unblocks shipping the extension — the nearest surface to release. |
| E5 | **Domain** | ~$12/yr | Needed for the privacy policy URL, which every store requires. |
| E6 | ⚖️ **Trademark check on "Sipcount"** | varies | Worth a proper class-based search before more brand investment. A casual web search is not this. |

### Then — the company

| | Item | Depends on | Notes |
|---|---|---|---|
| E7 | ⚖️ **Register the company** | E1, E2 | Entity type is a question for your CA — it affects the D-U-N-S, the bank account and the tax position. |
| E8 | **D-U-N-S number** | E7 | Free from Dun & Bradstreet. Allow **2–4 weeks in India**. One D-U-N-S serves both Apple and Google. |
| E9 | **Company bank account** | E7 | Stores require payout details even for free apps. |
| E10 | **Apple Developer Program, organisation** | E8 | The only route to the full iPhone build — Apple does not let individuals publish the traffic-tunnel kind of app. The app can be transferred from the individual account later, but deciding before publishing is cleaner. |
| E11 | **Google Play developer account** | — (personal) / E8 (organisation) | **A personal account needs no D-U-N-S.** See the sequencing note below. |
| E12 | **Windows code-signing certificate, OV** | E7 | From ~$219/yr. Since June 2023 the private key must live on a hardware token or cloud HSM — **no downloadable file** — so CI signing needs a cloud-HSM service, not a secret in GitHub Actions. Validity is capped at 460 days from March 2026, so plan on annual renewal. |

### Compliance, needed before any store submission

| | Item | Notes |
|---|---|---|
| E13 | **Privacy policy at a public URL** | Required by Play, the App Store and the Chrome Web Store, even though we collect nothing. The words already exist in the app; they need a page. I can draft it. |
| E14 | **Terms of service** | Same. |
| E15 | ⚖️ **Children's-app rules** | The audience includes under-18s, so Google's Families policy applies to the whole app, Apple's age rating and Kids rules apply, and India's DPDP treats everyone under 18 as a child. We have already gated sync at 18 and sharing at 13 (D-23, decision 4), but the store declarations are a separate exercise. |
| E16 | **Play Data Safety form and App Store privacy labels** | Mechanical once E13 exists. |

---

## The sequencing insight worth acting on

**Android does not have to wait for the company.** A personal Play account needs no D-U-N-S, so
track C can publish as soon as its sensor works — months before the company paperwork completes.

Only the **full iPhone build** genuinely requires the organisation account. Everything else —
extension, Android, macOS desktop, lighter iPhone — can ship on individual accounts.

That changes the shape of the plan: the company is on the critical path for *one* surface, not four.
Start it now because of the D-U-N-S wait, but do not let anything else queue behind it.

---

## Indicative costs

| | |
|---|---|
| Company registration | ⚖️ get a quote — varies with entity type and professional fees |
| D-U-N-S | free |
| Apple Developer | $99/yr |
| Google Play | $25 one-time |
| Chrome Web Store | $5 one-time |
| Windows code signing (OV) | from ~$219/yr, plus the token or cloud-HSM service |
| Domain | ~$12/yr |
| Sync relay VPS (1.1) | ~$5/month |

Roughly **$350–400 in the first year** outside company registration and any legal fees.

---

## What I can do on this track

Draft the privacy policy and terms; draft the store listings and the Data Safety answers; research
specific requirements and write up what a given form actually asks for; keep this document current.

What I cannot do: give legal advice, choose an entity type, or tell you what your employment
contract means. Those are the ⚖️ rows.

**Sources:** [Microsoft — SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation) · [Microsoft — code signing options](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options) · [SSL.com — EV vs OV](https://www.ssl.com/faqs/which-code-signing-certificate-do-i-need-ev-ov/) · [Play Console — choose an account type](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en) · [Play Console — verify developer identity](https://support.google.com/googleplay/android-developer/answer/10841920?hl=en)
