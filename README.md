# Leo Dark

A nice dark them that doesn't make your editor look like a rainbow. Inspired by VS Code's "Visual Studio Dark".


- **Source of truth:** [`themes/leo-dark-color-theme.json`](themes/leo-dark-color-theme.json) — edit it directly.
- **Base type:** `vs-dark`. Anything I don't list falls back to VS Code's standard
  `vs-dark` defaults — i.e. exactly what plain "Visual Studio Dark" does for those keys.

## How it's installed (editable, no packaging)

```bash
ln -sfn "{REPO_PATH}" "$HOME/.vscode/extensions/leo-theme"
```

## Daily workflow (this is the whole point)

1. Open [`themes/leo-dark-color-theme.json`](themes/leo-dark-color-theme.json).
2. Change a color / add a rule.
3. **Cmd+Shift+P → Developer: Reload Window.** Done — no `settings.json` juggling, no
   "can't override that key" limits, fully portable to any machine.

> Tip: with the theme active, **Cmd+Shift+P → Developer: Inspect Editor Tokens and Scopes**
> shows the exact TextMate scope + semantic token under the cursor, plus which theme rule
> is coloring it. That's how you find the right `scope` to add.

## What I customized (vs. plain Visual Studio Dark)

## v2 — porting to Zed (notes, not done yet)
Zed themes are a single JSON file with a `style` object. Rough mapping:

| VS Code | Zed (`style`) |
|---------|---------------|
| `editor.background` | `editor.background` |
| `sideBar.background` | `panel.background` / `surface.background` |
| `tab.activeBackground` | `tab.active_background` |
| `tab.inactiveBackground` | `tab.inactive_background` |
| `statusBar.background` | `status_bar.background` |
| `titleBar.activeBackground` | `title_bar.background` |
| `terminal.background` | `terminal.background` |
| TextMate `tokenColors` | `style.syntax.{name}.color` (e.g. `function`, `string`, `keyword`) |

Zed has no direct TextMate-scope system — syntax is keyed by a fixed set of capture names
(`function`, `string`, `keyword`, `type`, `comment`, `variable`, ...), so the scope → name
mapping is manual. Defer to v2.
