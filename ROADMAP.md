# Leo Theme Roadmap

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
