# Parity checklist

Open these files side by side in VS Code and Zed and compare. The corpus covers
**tokens**; this checklist covers everything a file cannot show — selection,
hover, dirty tabs, git decorations, widgets, diffs, terminal.

The folder is listed in `.vscodeignore`, so none of it ships in the `.vsix`.

## 0. Prerequisites

### Both editors must be running the current theme

Comparing against a published snapshot is the fastest way to waste a pass.
`install-dev.py` links both editors at the working tree:

```bash
python3 install-dev.py --status   # report, change nothing
python3 install-dev.py            # link both
```

Pick **Leo Dark (Dev)** in VS Code and **Leo Dark** in Zed, then reload. The dev
extension is deliberately separate from the marketplace install so an
auto-update cannot quietly restore the published colors underneath you.

Zed's `theme_overrides` in `~/.config/zed/settings.json` wins over the theme
file. Check it is not scoped to Leo Dark before blaming a colour.

### Match the typography, or don't trust your eyes

The two editors are currently on different fonts, sizes and weights:

| | VS Code | Zed |
|:--|:--|:--|
| Family | `SF Mono` | default (Zed Plex Mono) |
| Size | 12.5 | 13.5 |
| Weight | 400 | 450 |
| Ligatures | off | on |

Zed Plex Mono ligates, so `---`, `___`, `=>` and `!=` render as single glyphs
there and as literal characters in VS Code. That is typography, not colour —
but it reads as a difference. Set `buffer_font_family` and `buffer_font_size`
in Zed to match before a pass, or discount anything that is purely shape.

### Match the inlay hints, or half the diff is not the theme

VS Code ships them on and Zed ships them off, so the same Go file shows parameter
names, type hints and constant values in one editor and not the other. That is a
large visual difference and none of it is colour. In `~/.config/zed/settings.json`:

```json
"inlay_hints": { "enabled": true },
"lsp": { "gopls": { "initialization_options": { "hints": {
  "assignVariableTypes": true, "compositeLiteralFields": true,
  "constantValues": true, "functionTypeParameters": true,
  "parameterNames": true, "rangeVariableTypes": true
} } } }
```

The hint colour itself already agrees at `#959595`.

### Grammars

A language with no grammar renders as flat plain text, which
looks **exactly** like a broken theme — this is the single most common way a
parity pass produces a false positive.

Open every sample once and check it is highlighted at all. Zed currently has
only `html`, `toml` and `zig` installed, so expect to need extensions for:

```
svelte · lua · swift · sql · scss · java · dockerfile · make · just
```

VS Code covers everything here except **Zig** — either from a built-in
TextMate grammar or from an extension you already have (`golang.go`,
`rust-analyzer`, `svelte.svelte-vscode`, `skellock.just`, `ms-azuretools.vscode-docker`).

Optional, for full semantic tokens in `02-react.tsx`:

```bash
cd preview && npm i
```

Without it the file still highlights correctly; only the `react` import shows
an unresolved-module error.

## 1. Quick pass

Five files, one of each engine behaviour. Enough to catch a regression.

| File | What it proves |
|:--|:--|
| `00-plain.txt` | `editor.foreground` baseline, selection, find matches |
| `rust/src/main.rs` | largest language, full LSP semantic tokens |
| `go/main.go` | second largest, doc comments and struct tags |
| `02-react.tsx` | JSX tags, the busiest UI language |
| `03-broken.ts` | errors, warnings, unused fade, deprecated strikethrough |

## 2. Full pass

Everything else in the folder. `go/` and `rust/` carry their own manifests on
purpose — outside a module, gopls and rust-analyzer degrade to partial
analysis and you end up comparing Zed's full output against VS Code's
half-output.

Two samples reach the `embedded` capture (a grammar inside another grammar):
`07-page.html` and `14-component.svelte`. If either block renders flat, that is
the grammar injection, not the theme.

## 3. Surfaces no file can show

### Tabs
- [ ] Active vs inactive background and foreground
- [ ] Dirty indicator (edit a file, don't save)
- [ ] Preview mode (single-click a file — italic label in VS Code)
- [ ] Pinned tab
- [ ] Modified-and-unsaved plus git-modified at the same time
- [ ] Tab hover
- [ ] Active tab top/bottom border

### Sidebar and file tree
- [ ] Selected row, focused vs unfocused
- [ ] Hover row
- [ ] Git-modified filename colour
- [ ] Git-untracked filename colour — create `preview/untracked.txt`, look, delete it
- [ ] Git-ignored filename colour — `preview/node_modules/` after `npm i`
- [ ] Folder expand/collapse chevron
- [ ] Indent guides (the `go/`, `rust/src/` nesting is there for this)

### Editor body
- [ ] Selection, and inactive selection with the editor unfocused
- [ ] Selection highlight — double-click a word, check the other occurrences
- [ ] Current-line highlight
- [ ] Multi-cursor (Cmd+Opt+Down)
- [ ] Bracket-pair match and mismatch
- [ ] Ruler at column 120 (`00-plain.txt` has a line that crosses it)
- [ ] Whitespace rendering (`Makefile` recipes use real tabs)
- [ ] Line numbers: active vs inactive
- [ ] Folded-region marker
- [ ] Scrollbar slider, hover and active

### Widgets
- [ ] Suggest widget — selected row contrast especially
- [ ] Command palette / quick open
- [ ] Hover card, including code inside it
- [ ] Signature help
- [ ] Rename box
- [ ] Find widget, and Find in Files
- [ ] Peek definition

### Diagnostics
- [ ] Error squiggle, warning squiggle
- [ ] Faded unused symbol
- [ ] Strikethrough on deprecated symbol
- [ ] errorLens inline text — its background must not fight `editor.background`
- [ ] Problems panel rows
- [ ] Gutter error/warning icons

### Inline
- [ ] Inlay hints (Go and Rust both emit them; you have all `go.inlayHints.*` on)
- [ ] Ghost text from Supermaven / Claude
- [ ] Bracket-pair colourisation

### Diff
- [ ] `15-patch.diff` — the *grammar* path
- [ ] A real `git diff` — the *diff editor* path, `diffEditor.*` and `editorGutter.*`
- [ ] Inline vs side-by-side (you run `renderSideBySide: false`)

### Chrome
- [ ] Status bar: normal, and while a remote/debug session is active
- [ ] Title bar (you use `titleBarStyle: custom`)
- [ ] Breadcrumbs
- [ ] Activity bar (yours is on top)
- [ ] Panel tabs: Terminal, Problems, Output
- [ ] Terminal, all 16 ANSI colours — `11-script.sh` prints coloured help
- [ ] Notification toast

## 4. Expected noise — do not "fix" these

- **`03-broken.ts` has eight deliberate errors.** They are the diagnostics
  sample. The header comment lists each one.
- **`02-react.tsx` cannot resolve `react`** until you run `npm i` here.
- **`Makefile`, `justfile`, `Dockerfile`, `Main.java` have no numeric prefix.**
  All four are detected by exact filename, and `19-Makefile` would not be.
- **`Makefile` and `justfile` overlap on purpose.** They look alike and colour
  nothing alike — tabs vs spaces, `$(var)` vs `{{ var }}`, `.PHONY` vs
  `[private]`. Compare them side by side.
- **`08-config.toml` and `rust/Cargo.toml` overlap.** The manifest exists so
  rust-analyzer works; the numbered file is the actual TOML token sample.
- **Zed cannot draw strikethrough or underline.** Schema `v0.2.0` allows only
  `color`, `background_color`, `font_style` and `font_weight` on a syntax style.
  So `~~strikethrough~~` in `01-markdown.md`, the deprecated symbol in
  `03-broken.ts`, and the underline VS Code puts under every detected link are
  all permanently VS Code-only. Not a theme bug, not fixable.
- **`align` is red in VS Code, blue in Zed** (`01-markdown.md`, Raw HTML section).
  VS Code's HTML grammar hard-codes `align|bgcolor|border` as
  `invalid.deprecated.entity.other.attribute-name.html` — they are deprecated
  presentational attributes. `href` next to it stays
  `entity.other.attribute-name.html`. VS Code is right; Zed's tree-sitter grammar
  has no deprecation concept. Not a theme bug.
- **A package qualifier is light blue in some places and neutral in others.**
  `context` is light blue in `ctx context.Context` and neutral in
  `context.DeadlineExceeded`, and `fmt`, `errors`, `time` are neutral throughout.
  Both editors do this, identically: a qualified *type* is a distinct parse node,
  a selector *expression* is not, and neither parser can tell `time` from a local
  variable there. `gopls.ui.semanticTokens` is off by default, so VS Code has no
  more information than Zed. Parser limit, not a theme bug — full reasoning in
  [TECHNICAL.md](../TECHNICAL.md#a-package-is-only-a-package-where-the-parser-can-prove-it).
- **Setext heading text is plain in VS Code.** Its markdown grammar scopes only
  the `===` / `---` underline as a heading, never the line above it. Zed's
  tree-sitter grammar captures the whole node, so the text is blue there.
  Grammar difference, nothing the theme can reach.

## 5. Re-verify the samples still parse

```bash
cd preview && make check
```

Covers Go, Rust, C, Python, JSON and shell. The rest are not compiled here.
