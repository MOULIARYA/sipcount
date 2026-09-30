// Sipcount content script — runs on chatgpt.com, claude.ai, gemini.google.com.
// PRIVACY BOUNDARY: this file may look at the page to detect a "send". It measures
// the prompt's LENGTH and reads the MODEL NAME shown in the UI. It never copies,
// stores, or transmits the prompt text. The only thing that leaves this file is the
// PromptEvent below (counts + hints), sent to the extension's own background script.
(() => {
  const host = location.hostname;
  const vendor = host.includes('chatgpt') || host.includes('openai') ? 'openai' : host.includes('claude') ? 'anthropic' : host.includes('gemini') ? 'google' : 'unknown';

  // Per-site hints. Sites change their markup often, so every selector has a generic fallback.
  //
  // Checked against the live sites 2026-09-27 (see ISSUES I-42). Three things were wrong:
  //   • ChatGPT's composer is no longer `#prompt-textarea` — it is a plain <textarea>, and this
  //     list had no bare `textarea` fallback, so NOTHING was counted on chatgpt.com at all.
  //   • `model` was a comma list passed to querySelector, which returns whichever match comes
  //     first IN THE DOCUMENT, not the first selector that matches. A generic `button[aria-
  //     haspopup="menu"]` higher up the page beat the real model picker, so Gemini reported
  //     "Settings" and Claude reported "More" — everything fell back to the standard tier and
  //     reasoning models were undercounted by roughly 10×. `model` is now an ordered array.
  //   • Gemini renders its send button only once the composer has text. Not a bug; noted so the
  //     next person does not go looking for it on an empty page.
  const SITE = {
    openai:    { composer: '#prompt-textarea, #mobile-composer-prompt, textarea[data-id], textarea[aria-label*="ChatGPT" i], div[contenteditable="true"], textarea',
                 send: '[data-testid="send-button"], button[aria-label*="Send" i]',
                 model: ['[data-testid="model-switcher-dropdown-button"]', '[data-testid*="model" i]', 'button[aria-label*="model" i]'] },
    anthropic: { composer: 'div[contenteditable="true"].ProseMirror, div[contenteditable="true"], textarea',
                 send: 'button[aria-label*="Send" i]',
                 model: ['[data-testid="model-selector-dropdown"]', 'button[aria-label*="model" i]', 'button[aria-haspopup="menu"]'] },
    google:    { composer: '.ql-editor, div[contenteditable="true"], textarea',
                 send: 'button.send-button, button[aria-label*="Send" i], [role="button"][aria-label*="Send" i]',
                 model: ['[data-test-id="bard-mode-menu-button"]', 'button[aria-label*="mode picker" i]', 'button[aria-haspopup="menu"]'] },
    unknown:   { composer: 'div[contenteditable="true"], textarea', send: 'button[aria-label*="Send" i], button[type="submit"]', model: [] }
  }[vendor];

  // A model name looks like a model name. Without this, a generic fallback happily reports
  // "Settings" or "More" and we silently price a reasoning prompt as a standard one.
  const MODEL_OK = /\b(gpt|chatgpt|claude|gemini|opus|sonnet|haiku|flash|lite|pro|mini|nano|turbo|thinking|deep\s?think|reasoning|extended|o[1345]\b|\d\.\d)/i;

  const IMAGE_WORDS = /\b(generate|create|make|draw|design|render)\b[^.?!]{0,40}\b(image|picture|photo|illustration|logo|poster|icon|artwork|drawing)s?\b(?!-)|\b(image of|picture of|photo of)\b/i;
  const CODE_WORDS = /```|\b(function|class|def |import |const |let |var |SELECT |public static|#include|=>)\b|\b(write|fix|debug|refactor)\b[^.?!]{0,30}\b(code|script|function|bug|regex|sql|python|javascript|typescript|java|c#|kotlin|swift)\b/i;
  const LONG_CONTEXT_CHARS = 6000; // ~1,500 tokens of pasted material

  function composerEl() {
    const a = document.activeElement;
    if (a && (a.isContentEditable || a.tagName === 'TEXTAREA')) return a;
    const all = [...document.querySelectorAll(SITE.composer)].filter(e => e.offsetParent !== null);
    return all.sort((x, y) => (y.innerText || y.value || '').length - (x.innerText || x.value || '').length)[0] || null;
  }
  function composerText(el) { return el ? (el.tagName === 'TEXTAREA' ? el.value : el.innerText) || '' : ''; }
  // Try each selector IN ORDER and take the first that yields something that reads like a model
  // name. Order matters: the specific, site-owned selector must win over the generic fallback.
  function modelHint() {
    for (const sel of (SITE.model || [])) {
      for (const el of document.querySelectorAll(sel)) {
        const t = ((el.innerText || '') + ' ' + (el.getAttribute('aria-label') || '')).trim();
        if (t && MODEL_OK.test(t)) return t.slice(0, 60).toLowerCase();
      }
    }
    return null;   // unknown model → the engine's default tier, which is the honest fallback
  }
  function attachmentCount(el) {
    const form = el && (el.closest('form') || el.parentElement?.parentElement) || document;
    return form.querySelectorAll('img[alt*="attach" i], [data-testid*="attachment" i], [aria-label*="Remove" i][aria-label*="file" i], [class*="attachment" i]').length;
  }
  // Classify without keeping the text: regex tests run on a local string that is discarded immediately.
  function classify(text, attachments) {
    if (IMAGE_WORDS.test(text)) return 'image';
    if (attachments > 0 || text.length >= LONG_CONTEXT_CHARS) return 'long_context';
    if (CODE_WORDS.test(text)) return 'code';
    return 'text';
  }

  /* ---- measuring the reply (I-18 / TOKEN-ECONOMICS §4) -------------------------------------
     The answer is where nearly all the water goes: an output token costs about five times an
     input one, so for a normal question ~99% of the number comes from the reply. Until now the
     reply was a fixed assumption (300 tokens for text), which made the measurement close to
     meaningless — a one-line question producing a three-page essay was priced the same as "hi".

     We measure it the same way we measure the prompt: LENGTH ONLY, never content, nothing kept.
     Rather than chase per-site selectors for the answer bubble — three sites that rewrite their
     markup constantly — we watch how much text the conversation gained. That works identically
     on all three and survives their redesigns, including Gemini, whose stream re-sends the whole
     answer each chunk and would double-count a naive byte measure. */
  /* The shared engine is loaded alongside this file by the manifest. Guard anyway: a content
     script that throws counts NOTHING, and does it silently on a page that looks perfectly
     normal — which is exactly what happened on 2026-09-30. Falling back to the English ratio is
     wrong by a few per cent; throwing is wrong by everything. */
  const scriptClass = t => { try { return SIP.scriptOf(t); } catch (_) { return 'latin'; } };
  const convoEl = () => document.querySelector('main') || document.body;
  const convoChars = () => (convoEl().innerText || '').length;

  /* "Still writing?" — a stop control is on screen for exactly as long as the model is generating,
     which is a far better signal than silence. Models pause mid-answer (thinking, tool use, rate
     limits), and an early first attempt at this finalised after a 1.8s gap and measured 190
     characters of a 4,000-character answer. */
  const STOP_BTN = 'button[aria-label*="Stop" i], [data-testid="stop-button"], button[aria-label*="Cancel" i]';
  const generating = () => !!document.querySelector(STOP_BTN);

  let turnSeq = 0;
  function watchReply(turnId, promptChars, tSend) {
    const base = convoChars();
    let firstGrowth = 0, lastActive = tSend, settle = 0, idle = 0, cap = 0, reported = -1, done = false;

    /* Reports are cumulative and repeatable: the background applies the difference from whatever
       it last recorded. So a premature report is not a lost measurement — the next one corrects
       it. Getting this wrong in the other direction (report once, hope it was the end) is what
       produced a number five times too low. */
    const report = () => {
      const grew = Math.max(0, convoChars() - base - promptChars);   // the echoed prompt is not the reply
      if (grew === reported) return;
      reported = grew;
      try {
        chrome.runtime.sendMessage({ type: 'prompt_reply', reply: {
          v: 1, turnId, reply_chars: grew,
          reply_script: scriptClass((convoEl().innerText||'').slice(-4000)),
          ttft_ms: firstGrowth ? firstGrowth - tSend : null,
          /* How long the model was working — the last moment the page changed or the stop
             control was up. Not Date.now(), which would include our own settle delay. */
          active_ms: Math.max(0, lastActive - tSend),
          duration_ms: Date.now() - tSend
        }});
      } catch (_) { /* extension reloaded mid-answer; the last figure stands */ }
    };
    const stopAll = () => { if (done) return; done = true; obs.disconnect();
      clearTimeout(settle); clearTimeout(idle); clearTimeout(cap); report(); };

    const obs = new MutationObserver(() => {
      if (done) return;
      if (!firstGrowth && convoChars() > base + promptChars + 8) firstGrowth = Date.now();
      lastActive = Date.now();
      clearTimeout(settle);
      settle = setTimeout(() => { if (generating()) { lastActive = Date.now(); return; } report(); }, 2500);
      clearTimeout(idle);
      idle = setTimeout(stopAll, 25000);          // 25s of complete stillness = the turn is over
    });
    obs.observe(convoEl(), { childList: true, subtree: true, characterData: true });
    idle = setTimeout(stopAll, 25000);
    cap = setTimeout(stopAll, 300000);            // never watch forever
  }

  let lastSent = 0;
  function emit(reason) {
    const el = composerEl();
    const text = composerText(el);
    if (text.trim().length === 0) return;
    const now = Date.now();
    if (now - lastSent < 1200) return; // one event per send, even if both keydown and click fire
    lastSent = now;
    const attachments = attachmentCount(el);
    const turnId = `${now}-${++turnSeq}`;
    const event = {
      v: 1, source: 'browser_ext', vendor, turnId,
      model_hint: modelHint(),
      task: classify(text, attachments),
      char_count: text.length,
      script: scriptClass(text),            // a label, not the text — see engine.js scriptOf()
      attachment_count: attachments,
      ts: Math.floor(now / 1000)
    };
    // `text` goes out of scope here and is never referenced again.
    try { chrome.runtime.sendMessage({ type: 'prompt_event', event }); } catch (_) { /* extension reloaded; ignore */ }
    // Count immediately on the assumption so the badge reacts, then correct it when the answer
    // lands. A user who closes the tab mid-answer keeps the estimate rather than losing the turn.
    watchReply(turnId, text.length, now);
  }

  /* ---- test bridge ---------------------------------------------------------------------------
     Chrome will not let an automated test read chrome.storage, and "we could not test it" is how
     three faults reached Madhur in a week. So on a page carrying ?sipcount_debug=1 — and only
     there — the content script answers a postMessage by writing the extension's COUNTS (the same
     numbers the popup shows: no text, nothing new) into a DOM node the test can read.
     Off on every ordinary page. Must stay gated, or be removed, before the store build. */
  if (/[?&]sipcount_debug=1/.test(location.search)) {
    window.addEventListener('message', ev => {
      if (ev.source !== window || ev.data?.sipcount !== 'state?') return;
      chrome.runtime.sendMessage({ type: 'debug_state' }, res => {
        let n = document.getElementById('sipcount-debug');
        if (!n) { n = document.createElement('script'); n.type = 'application/json'; n.id = 'sipcount-debug'; document.documentElement.appendChild(n); }
        n.textContent = JSON.stringify(res || { ok: false });
      });
    });
    document.documentElement.setAttribute('data-sipcount', 'active');   // proves the script is running
  }

  // Enter (without Shift) inside the composer = send on all three sites.
  document.addEventListener('keydown', e => {
    if (e.key !== 'Enter' || e.shiftKey || e.isComposing) return;
    const a = document.activeElement;
    if (a && (a.isContentEditable || a.tagName === 'TEXTAREA')) emit('enter');
  }, true);

  // Click on the send button.
  document.addEventListener('pointerdown', e => {
    const b = e.target.closest && e.target.closest('button');
    if (!b) return;
    if (b.matches(SITE.send) || /send/i.test(b.getAttribute('aria-label') || '') || b.getAttribute('data-testid') === 'send-button') emit('click');
  }, true);
})();
