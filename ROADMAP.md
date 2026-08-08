# Leo Theme Roadmap

## Done

- **v2 — Zed port.** `themes/leo-dark.json` ships the full theme against schema
  `v0.2.0`. Key mapping lives in [TECHNICAL.md](TECHNICAL.md).
- **Parity corpus.** `preview/` — one sample per language plus a checklist for the
  state-driven surfaces.

## Next

- **Parity script.** `scripts/parity.mjs` holding the VS Code → Zed key map, reporting
  keys present in one theme but missing from the other, and colors that drifted apart.
  The corpus catches "this hex reads wrong in Zed"; the script catches "this fix only
  landed in one file", which is the failure that actually keeps happening.
- **Release the pending fixes.** The Zed selection-contrast change is committed but
  `package.json` is still at `1.0.2` and `CHANGELOG.md` has no entry for either the
  VS Code or the Zed selection work.
- **Screenshots for the marketplace.** `preview/` doubles as the source. Same window
  size, same files, one shot per editor, stored as a pair so releases stay diffable.
- **Light variant.** Not started, no palette yet.
