# Leo Theme Technical Doc

- **VS Code source of truth:** [`themes/leo-dark-color-theme.json`](themes/leo-dark-color-theme.json) — edit it directly.
- **Zed source of truth:** [`themes/leo-dark.json`](themes/leo-dark.json) — schema `v0.2.0`, edit it directly.
- **Base type:** `vs-dark`. Anything not overridden falls back to VS Code's vs-dark defaults.
- The two files are maintained by hand and nothing propagates between them. A fix
  applied to one is not applied to the other until you do it.

## How it's installed for local editing (no packaging)

```bash
ln -sfn "{REPO_PATH}" "$HOME/.vscode/extensions/leo-theme"
ln -sfn "{REPO_PATH}/themes/leo-dark.json" "$HOME/.config/zed/themes/leo-dark.json"
```

Link rather than copy. A copied Zed theme goes stale silently and the next parity
pass compares against the old colors.

## Editing workflow

1. Open the theme file for the editor you're changing.
2. Change a color / add a rule.
3. **Cmd+Shift+P → Developer: Reload Window** to see changes. No `settings.json`
   juggling, no "can't override that key" limits, fully portable to any machine.

> Tip: with the theme active, **Cmd+Shift+P → Developer: Inspect Editor Tokens and Scopes**
> shows the exact TextMate scope + semantic token under the cursor, plus which theme rule
> is coloring it. That's how you find the right `scope` to add.

## VS Code → Zed key mapping

| VS Code | Zed (`style`) |
|---------|---------------|
| `editor.background` | `editor.background` |
| `sideBar.background` | `panel.background` / `surface.background` |
| `tab.activeBackground` | `tab.active_background` |
| `tab.inactiveBackground` | `tab.inactive_background` |
| `statusBar.background` | `status_bar.background` |
| `titleBar.activeBackground` | `title_bar.background` |
| `terminal.background` | `terminal.background` |
| `list.activeSelectionBackground` | `element.selected` / `ghost_element.selected` |
| TextMate `tokenColors` | `syntax.{name}.color` |

Zed has no TextMate-scope system. Syntax is keyed by a fixed set of tree-sitter
capture names (46 of them in this theme: `function`, `string`, `keyword`, `type`,
`comment`, `variable`, `variant`, `preproc`, `selector`, …), so the scope → name
mapping is manual. A handful have no VS Code counterpart at all — `hint`,
`predictive`, `primary`.

## Parity corpus

[`preview/`](preview/) holds one sample file per language, sized to the languages
actually in use, plus [`preview/CHECKLIST.md`](preview/CHECKLIST.md) for the
surfaces a file cannot show (selection, tabs, widgets, diffs, terminal). Open the
same files in both editors and compare.

The folder is in `.vscodeignore` and never ships in the `.vsix`.

`go/` and `rust/` carry their own manifests so gopls and rust-analyzer emit full
semantic tokens — outside a module they degrade to partial analysis, and you end
up comparing Zed's complete output against VS Code's incomplete one.

`make check` (run from `preview/`) re-verifies that the Go, Rust, C, Python, JSON
and shell samples still parse.

## What a color theme cannot do

Themes carry workbench `colors` and editor `tokenColors[].settings.fontStyle`.
There is no workbench font-weight, font-family or font-size key — UI chrome
typography is not themeable. If tab labels or the sidebar change weight, look at
`workbench.experimental.modernUI`, not at the theme.
