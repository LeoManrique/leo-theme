# Leo Theme Technical Doc

- **Source of truth:** [`themes/leo-dark-color-theme.json`](themes/leo-dark-color-theme.json) — edit it directly.
- **Base type:** `vs-dark`. Anything not overridden falls back to VS Code's vs-dark defaults.

## How it's installed for local editing (no packaging)

```bash
ln -sfn "{REPO_PATH}" "$HOME/.vscode/extensions/leo-theme"
```

## Editing workflow

1. Open [`themes/leo-dark-color-theme.json`](themes/leo-dark-color-theme.json).
2. Change a color / add a rule.
3. **Cmd+Shift+P → Developer: Reload Window** to see changes. No `settings.json`
   juggling, no "can't override that key" limits, fully portable to any machine.

> Tip: with the theme active, **Cmd+Shift+P → Developer: Inspect Editor Tokens and Scopes**
> shows the exact TextMate scope + semantic token under the cursor, plus which theme rule
> is coloring it. That's how you find the right `scope` to add.
