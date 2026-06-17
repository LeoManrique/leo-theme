# Leo Theme

A nice dark them that doesn't make your editor look like a rainbow. Inspired by VS Code's "Visual Studio Dark".


- **Source of truth:** [`themes/leo-dark-color-theme.json`](themes/leo-dark-color-theme.json) — edit it directly.
- **Base type:** `vs-dark`.

## Daily workflow (this is the whole point)

1. Open [`themes/leo-dark-color-theme.json`](themes/leo-dark-color-theme.json).
2. Change a color / add a rule.
3. **Cmd+Shift+P → Developer: Reload Window.** Done — no `settings.json` juggling, no
   "can't override that key" limits, fully portable to any machine.

> Tip: with the theme active, **Cmd+Shift+P → Developer: Inspect Editor Tokens and Scopes**
> shows the exact TextMate scope + semantic token under the cursor, plus which theme rule
> is coloring it. That's how you find the right `scope` to add.
