# Token economics → water: measurement model for Sipcount (v1, 2026-09-20)

Purpose: quantify what goes *out* (the prompt) and what comes *in* (the answer) on every platform we sense — mobile apps, Windows/Mac apps, browser extension — and turn it into energy and water with stated confidence. Sources are cited; confidence: **H** measured/vendor-documented · **M** one solid source or consistent inference · **L** derived/assumed, needs our own calibration.

## 1. What the science says

**Reading is cheap, writing is expensive.** Processing the prompt ("prefill") is compute-bound and runs the chips at full tilt for a short burst; generating the answer ("decode") happens one token at a time, is memory-bound, and leaves the chips under-used — so each output token costs several times an input token. Evidence: Splitwise (ISCA 2024) and Stojkovic et al. 2024 on prefill/decode characteristics **H**; Fernandez et al. (ACL 2025) "decoding is more energy intensive per token than prefill… decoding energy dominates" **H**; TokenPowerBench (2026): raising input 16→2,048 tokens with output fixed left energy ≈ constant **H**; Husom et al. 2024: energy predicted by response length with R²=0.996 **H**; API prices put output at 4–8× input **H (as proxy)**; Epoch AI's FLOP model implies ≈2.7× **M**.
→ **Energy per output token ÷ per input token: central 5×, plausible 3–10×** for production chat serving. **M**

**Long contexts raise the cost of every output token** (attention re-reads the growing cache): ≈ +8 % per extra 1,000 tokens of context at production batch (ML.ENERGY v3, one model) **H**; +3–8 %/1k recommended as a modelling range **M**. Re-used history is served from cache at roughly a tenth of fresh input cost (priced at 10 %) **M**.

**Batching matters more than model size**: 3–5× per-token savings from batching (ML.ENERGY); a 30B mixture-of-experts model is 3.6× cheaper per token than a dense 32B **H**. This is why GPU-only bench figures (0.15–0.31 J per output token) sit 2–3× below full-stack production estimates.

**Anchors for absolute scale (full stack):** Google, Aug 2025 — median Gemini text prompt 0.24 Wh, 0.26 mL on-site water **H**; Epoch AI, Feb 2025 — 0.3 Wh for a GPT-4o query with 500 output tokens **M**; Mistral LCA — 45 mL water per 400-token exchange (full life-cycle, incl. embodied) **H**; ML.ENERGY v3 — 0.151 J/output token text, 0.312 J/token reasoning, GPU-only, B200 **H**.

**Reasoning models** don't cost more per token; they emit 1,000–15,000 *hidden* tokens per answer (Anthropic budget ≥1,024; Gemini default 8,192; measured 7,845 mean on math/code benchmarks) **H/M**. Everyday chat with thinking on: median ≈ 2k hidden tokens **L**.

**Images**: generating one costs ≈1–3 Wh (Luccioni 2023: 2.9 Wh SDXL-class; 2025 studies show a 20–46× spread across models) **L central**; *reading* an image costs 1.1–5.2× text energy per token **H**; token accounting per vendor is documented (OpenAI 85 + 170/tile; Gemini 258/image; Anthropic w×h/750) **H**.

## 2. Typical message sizes

| Source | User prompt (tokens) | Assistant reply (tokens) |
|---|---|---|
| LMSYS-Chat-1M (2023) | mean 70 (sd 143) | mean 216 |
| WildChat (2023–24) | mean 296 (heavy tail: pasted text) | mean 441 |
| ShareGPT | mean 95 | mean 349 |
| ML.ENERGY v3 real prompts, 2025 models | — | mean **717** text · **6,988** reasoning |

Medians are lower than means: **user prompt median ≈ 30–60 tokens; reply median 200–350 (2023 models), 400–700 (2025 models)** **M**. Coding/technical conversations use ≈2× the tokens of others (Anthropic Economic Index) **H**. OpenAI's Sept 2025 usage paper publishes topic shares but **no length statistics**.

**Characters per token** (why "characters typed" is not a language-neutral measure): English ≈4 chars/token on all three vendors' tokenizers **H**; Hindi in Devanagari ≈1.4–1.8× more tokens than English for the same meaning (≈3–3.5 chars/token on GPT-4o's o200k, far worse on older tokenizers) **M**; Hinglish ≈2.3× English **M**; code ≈3–3.5 chars/token **L**; emoji 1–3 tokens each **L**. UTF-8 makes bytes worse still: English ≈4 bytes/token, Devanagari ≈9–10. **Any bytes-only sensor needs a language prior; the extension should tokenize exactly.**

## 3. The equation Sipcount should use

```
E_turn (Wh) = PUE × [ a·T_in_fresh + 0.1·a·T_in_cached + b(L)·T_out + b·T_hidden + Σ(a·m_img·T_img_in) + n_gen·E_img ]
b(L) = b0 × (1 + k · L/1000)     L = total context tokens (history + prompt)
water_mL = E_turn × (WUE_site + EWIF_grid)          (PUE already applied)
```

| Tier | a — input, Wh/1k | b0 — output, Wh/1k | hidden reasoning | k | conf. |
|---|---|---|---|---|---|
| Light (Flash / mini / Haiku) | 0.02–0.04 | 0.10–0.20 | — | 0.05 | M |
| Standard (GPT-5 default / Gemini Pro / Sonnet) | 0.06–0.12 (0.10) | 0.40–0.60 (0.50) | — | 0.05 | M |
| Reasoning (o3 / Thinking / Deep Think / extended) | 0.10 | 0.6–0.9 | same as b, × 1k–15k tokens | 0.08 | L/M |
| Image generation | — | — | — | 1–3 Wh per image (2) | L |

Consistency check: standard tier, 70 in + 500 out → ≈0.26 Wh, between Google's 0.24 and Epoch's 0.30. Our engine's calibrated reference (100 in + 300 out = 0.30 Wh) is on the conservative side of this range — acceptable, and flagged.

**Change applied to `engine.js` today:** input weight 0.25 → **0.20** (output = 5× input, the central estimate), re-normalised so the reference prompt stays 0.30 Wh. Reasoning tier stays at 10× per visible token, which is equivalent to ≈2k hidden tokens on a 300-token answer — inside the measured range. Context-length factor k, cached-history discount and per-image input multiplier are **not yet in the engine** (need history length, which only the extension can see) — see §5.

## 4. What each sensor can observe, and how it becomes tokens

| Signal | Browser extension | Desktop app (Win/Mac) | Mobile doorman |
|---|---|---|---|
| Prompt text | **Exact** (DOM / request body) → tokenize exactly (o200k for ChatGPT; ≈3.5 chars/token Claude; ≈4 Gemini) | Bytes up only | Bytes up only |
| Reply text | **Exact** (SSE deltas; Gemini via diffing cumulative chunks) | Bytes down + timing | Bytes down + timing |
| Model | Label in UI / stream metadata | Not visible (accessibility API could read the window title/label — optional) | Not visible |
| Attachments | Count + image dimensions | Upload burst size | Upload burst size |
| Timing | t_send, first byte, last byte | same | same |

**Wire facts that shape the byte→token mapping** (from public reverse-engineering; verify in our own captures):
- **ChatGPT**: sends only the new message + conversation id (history stays server-side) → upstream bytes ≈ prompt + a fixed header overhead. Reply is SSE with compact `{"v":"tok"}` deltas ≈ 20–30 B per delta, several tokens per delta → expect **15–40 wire bytes per token** before compression. Prefers HTTP/3 (QUIC).
- **Claude**: same "new message only" pattern; verbose SSE envelope ≈100+ B per delta → **50–150 B/token**.
- **Gemini**: each chunk carries the **cumulative text so far**, so downstream bytes grow ≈ quadratically with reply length — use the *final chunk size* or duration, never total bytes. Prefers HTTP/3.
- Mobile apps use the same back-ends over TLS; on the doorman, blocking UDP/443 to these hosts forces HTTP/2 over TCP and makes per-turn flow boundaries visible (a common firewall trick; earlier decision D-1 said "don't block QUIC" — this is the one exception to test).
- **Timing signatures** (Artificial Analysis, Sept 2026): non-reasoning models answer first byte in ≈1.4–1.5 s; reasoning at high effort 100–140 s; output speeds 70–125 tokens/s. → **TTFT > ~8 s ⇒ reasoning tier; T_out ≈ tokens/s × streaming duration; T_hidden ≈ tokens/s × (TTFT − 1.5 s).**

## 5. Calibration protocol (Part 3 — Madhur runs, Claude analyses)

**Record per turn** (extension in calibration mode; doorman/desktop sensor alongside): platform, host, model label, t_send, t_first_byte, t_last_byte, bytes_up, bytes_down, n_chunks, prompt_chars, prompt_utf8_bytes, reply_chars, script class (Latin / Devanagari / mixed / code), exact tokens (o200k via `gpt-tokenizer`; Anthropic `count_tokens` and Gemini `countTokens` run offline on our own text), attachment flag + image dims, thinking flag, TTFT.

**Experiment matrix** (same scripted prompts everywhere):
- Prompts: 10 short questions (≈30 tokens) · 10 long pastes (≈800 tokens) · 5 "write me 600 words" · 5 code tasks · 5 Hindi · 5 Hinglish · 3 image uploads · 3 image generations · 5 with thinking/reasoning on.
- Surfaces: ChatGPT, Claude, Gemini × {phone app, desktop app (Win + Mac), browser} = up to 9 paths per prompt; the browser run is the ground truth for the other two.
- Target: **≈200 English + ≈100 Hindi/Hinglish turns per platform** (coefficient CV ≈30 % → ±5 % CI on slopes); medians in the tokenizer study stabilised by n≈50, so a first useful pass is 50 turns per platform.

**Fitting**: (1) `tokens_in = (bytes_up − h_platform) / bytes_per_token_script` — robust linear fit per platform × script; (2) ChatGPT/Claude `tokens_out = β0 + β1·bytes_down`; Gemini `log tokens_out ≈ β0 + β1·log bytes_down` (expect β1≈0.5) or final-chunk bytes; (3) `tokens_out = tps × streaming duration`, tier by logistic fit on TTFT. **Acceptance**: per-turn error < 15 %, daily aggregate error < 5 % on a hold-out set. Re-run monthly — the wire formats changed at least twice in the past year, and Google reports a 33× efficiency gain in 12 months, so b0 needs revisiting at least annually.

## 6. What stays uncertain, honestly
1. No vendor publishes an input/output energy split — the 5× is inferred (3–10× range).
2. Google's median prompt token count is undisclosed; Epoch's 0.3 Wh is a model, not a measurement.
3. SSE compression and QUIC framing overheads must come from our own captures.
4. Hidden reasoning token averages for consumer chat are unpublished — TTFT is our only handle.
5. Hindi/Hinglish tokenization on Claude/Gemini is proxied from open tokenizers until we run `count_tokens`.

Principal sources: Patel et al. Splitwise (ISCA 2024); Stojkovic et al. arXiv 2403.20306; Fernandez et al. arXiv 2504.17674; TokenPowerBench arXiv 2512.03024; Delavande et al. arXiv 2601.22362; ML.ENERGY Leaderboard v3 (arXiv 2601.22076); Husom et al. arXiv 2407.16893; Samsi et al. arXiv 2310.03003; Epoch AI "How much energy does ChatGPT use" (2025); Elsworth et al. arXiv 2508.15734 (Google); Mistral LCA (Jul 2025); Jegham et al. arXiv 2505.09598; Zheng et al. LMSYS-Chat-1M; Zhao et al. WildChat arXiv 2405.01470; Poddar et al. arXiv 2506.08686; Anthropic Economic Index (2025–26); Chatterji et al. NBER w34255; Petrov et al. NeurIPS 2023; Ahia et al. 2023; OpenAI/Anthropic/Gemini token and pricing docs; Luccioni et al. FAccT 2024; Bertazzini et al. arXiv 2506.17016; Artificial Analysis (Sept 2026); unofficial API clients for chatgpt.com / claude.ai / gemini.google.com.
