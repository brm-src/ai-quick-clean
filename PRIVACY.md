# Privacy notes

ai quick clean is a local Omarchy interface with an online rewrite action.

## What stays local

- The plugin reads the Wayland primary selection or clipboard only to prefill the editor.
- Source text and proposed text remain in memory inside the running Quickshell process.
- The plugin does not create a history file, cache, database, KV namespace, R2 object, or local state file for text.
- Copying the proposal happens only after the user presses `copy`.

## What leaves the computer

When the user presses `clean` or `improve`, the current text is sent over HTTPS to the public aismell rewrite Worker. The Worker runs the aismell analyzer and Cloudflare Workers AI to produce one proposal and a list of edits.

The Worker does not have application storage for submitted text and returns `Cache-Control: no-store`. Cloudflare still handles the request as infrastructure, so this tool is not appropriate for passwords, private keys, regulated information, confidential client material, or text that must stay offline. Cloudflare's own service and retention policies apply to infrastructure outside this repository.

The plugin does not request an API key, install packages, use sudo or pkexec, execute downloaded code, or send telemetry from the desktop.
