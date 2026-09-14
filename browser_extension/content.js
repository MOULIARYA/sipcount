// Sipcount content script — runs on chatgpt.com, claude.ai, gemini.google.com.
// PRIVACY BOUNDARY: this file may look at the page to detect a "send". It measures
// the prompt's LENGTH and reads the MODEL NAME shown in the UI. It never copies,
// stores, or transmits the prompt text. The only thing that leaves this file is the
// PromptEvent below (counts + hints), sent to the extension's own background script.
(() => {
  const host = location.hostname;
  const vendor = host.includes('chatgpt') || host.includes('openai') ? 'openai' : host.includes('claude') ? 'anthropic' : host.includes('gemini') ? 'google' : 'unknown';

  // Per-site hints. Sites change their markup often, so every selector has a generic fallback.
  const SITE = {
    openai:    { composer: '#prompt-textarea, textarea[data-id], div[contenteditable="true"]', send: '[data-testid="send-button"], button[aria-label*="Send" i]', model: '[data-testid="model-switcher-dropdown-button"], button[aria-haspopup="menu"][aria-label*="model" i]' },
    anthropic: { composer: 'div[contenteditable="true"].ProseMirror, div[contenteditable="true"], textarea', send: 'button[aria-label*="Send" i]', model: '[data-testid="model-selector-dropdown"], button[aria-haspopup="menu"]' },
    google:    { composer: '.ql-editor, div[contenteditable="true"], textarea', send: 'button.send-button, button[aria-label*="Send" i]', model: '[data-test-id="bard-mode-menu-button"], button[aria-haspopup="menu"]' },
    unknown:   { composer: 'div[contenteditable="true"], textarea', send: 'button[aria-label*="Send" i], button[type="submit"]', model: '' }
  }[vendor];

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
  function modelHint() {
    if (!SITE.model) return null;
    const el = document.querySelector(SITE.model);
    const t = el && (el.innerText || el.getAttribute('aria-label') || '').trim();
    return t ? t.slice(0, 60).toLowerCase() : null;
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

  let lastSent = 0;
  function emit(reason) {
    const el = composerEl();
    const text = composerText(el);
    if (text.trim().length === 0) return;
    const now = Date.now();
    if (now - lastSent < 1200) return; // one event per send, even if both keydown and click fire
    lastSent = now;
    const attachments = attachmentCount(el);
    const event = {
      v: 1, source: 'browser_ext', vendor,
      model_hint: modelHint(),
      task: classify(text, attachments),
      char_count: text.length,
      attachment_count: attachments,
      ts: Math.floor(now / 1000)
    };
    // `text` goes out of scope here and is never referenced again.
    try { chrome.runtime.sendMessage({ type: 'prompt_event', event }); } catch (_) { /* extension reloaded; ignore */ }
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
