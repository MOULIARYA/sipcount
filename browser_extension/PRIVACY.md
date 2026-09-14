# Sipcount browser extension — Privacy

**Sipcount cannot send data anywhere.** The extension requests no network permission, so the browser itself blocks it from contacting any server. You can verify this in `manifest.json`: the only permission is `storage` (to keep your daily totals in your own browser).

**What it looks at.** When you press Send on chatgpt.com, claude.ai or gemini.google.com, the extension measures how long your prompt is (a character count), reads the model name shown on screen (e.g. "GPT-5"), and checks whether the prompt looks like a request for an image or code. That check happens in memory and the text is discarded immediately.

**What it keeps.** Daily totals only: number of prompts, millilitres of water by AI tool, model type and task type. No prompt text, no conversation titles, no account details, no browsing history. Totals live in your browser's local extension storage and never leave your device.

**What you control.** "Clear data" in the popup deletes everything. Uninstalling the extension deletes everything. "Copy CSV" puts your totals on your clipboard — you decide where they go.

**Why the install warning?** Chrome says the extension can "read and change your data" on those three sites because it must see the page to notice when you press Send. It does not change anything on the page. The code is open source in this repository so anyone can check.

Constants and methodology: see `app/assets/calc/models.json` and `ARCHITECTURE.md`.
