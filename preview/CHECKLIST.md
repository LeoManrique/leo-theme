# Parity checklist

Open these files side by side in VS Code and Zed and compare. The corpus covers
**tokens**; this checklist covers everything a file cannot show — selection,
hover, dirty tabs, git decorations, widgets, diffs, terminal.

The folder is listed in `.vscodeignore`, so none of it ships in the `.vsix`.

## 0. Prerequisites

### Both editors must be running the current theme

`~/.config/zed/themes/leo-dark.json` is a **copy**, not a symlink, so it goes
stale every time `themes/leo-dark.json` changes. Check before every pass:

```bash
diff ~/.config/zed/themes/leo-dark.json themes/leo-dark.json
```

Replace the copy with a link once and the problem goes away:

```bash
ln -sfn "$PWD/themes/leo-dark.json" ~/.config/zed/themes/leo-dark.json
```

On the VS Code side, `leoshell.leo-theme` is installed from the marketplace,
which is also a snapshot. To test unreleased edits, link the repo instead:

```bash
ln -sfn "$PWD" ~/.vscode/extensions/leo-theme
```

Reload both editors afterwards.

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

## 5. Re-verify the samples still parse

```bash
cd preview && make check
```

Covers Go, Rust, C, Python, JSON and shell. The rest are not compiled here.
