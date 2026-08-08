# Leo Theme Technical Doc

- **VS Code source of truth:** [`themes/leo-dark-color-theme.json`](themes/leo-dark-color-theme.json) — edit it directly.
- **Zed source of truth:** [`themes/leo-dark.json`](themes/leo-dark.json) — schema `v0.2.0`, edit it directly.
- **Base type:** `vs-dark`. Anything not overridden falls back to VS Code's vs-dark defaults.
- The two files are maintained by hand and nothing propagates between them. A fix
  applied to one is not applied to the other until you do it.

## How it's installed for local editing (no packaging)

```bash
python3 install-dev.py            # both editors
python3 install-dev.py --status   # report what's linked, change nothing
python3 install-dev.py --uninstall
```

Link rather than copy. A copied Zed theme goes stale silently and the next parity
pass compares against the old colors — `--status` reports a stale copy as such.

VS Code gets a **separate extension**, `leo-dev.leo-theme-dev`, labelled
**"Leo Dark (Dev)"** in the theme picker, whose `themes/` is a symlink to this
repo. The marketplace install is left alone, for two reasons:

- `~/.vscode/extensions/extensions.json` pins `leoshell.leo-theme` with
  `"source": "gallery"`. That directory belongs to VS Code's extension manager,
  and an auto-update overwrites anything put there — reverting to the published
  colors mid-session, silently.
- Extension identity is `publisher.name`. Two folders claiming
  `leoshell.leo-theme` get deduped, and which one loads is not defined.

The side effect is useful: dev and published builds sit in the picker together,
so a change can be A/B'd against the last release. `install-dev.py` is in
`.vscodeignore` and never ships.

Zed gets a symlink at `~/.config/zed/themes/leo-dark.json`; an existing real
file is moved to `.json.bak` first. Zed watches the themes directory, so an edit
behind a symlink may not trigger a reload — restart Zed if a change doesn't show.

## Editing workflow

1. Open the theme file for the editor you're changing.
2. Change a color / add a rule.
3. **Cmd+Shift+P → Developer: Reload Window** to see changes. No `settings.json`
   juggling, no "can't override that key" limits, fully portable to any machine.

> Tip: with the theme active, **Cmd+Shift+P → Developer: Inspect Editor Tokens and Scopes**
> shows the exact TextMate scope + semantic token under the cursor, plus which theme rule
> is coloring it. That's how you find the right `scope` to add.

## Hue contract

One hue means one idea, in both files. A colour that appears everywhere stops
being a highlight, so the default is neutral and a role has to earn a hue.

| Hue | Means |
|:--|:--|
| `#5996db` blue **bold** | keyword — bold means keyword and nothing else |
| `#5996db` blue | the language's own literals: `nil`, `true`, `iota`, `self` |
| `#9cdcfe` light blue | type, package, builtin call, attribute, label |
| `#b5cea8` pale green | number, enum member |
| `#dec078` gold | string, including import paths and runes · `#d5b466` escape sequence |
| `#649158` green | comment |
| `#956ccc` purple | operator and bracket — never bold |
| `#d4d4d4` neutral | everything a program names for itself |

That last row is the largest by design, and it is what makes the rest read as
highlights. It covers variables, parameters, constants, functions, methods,
struct fields and property accesses, plus `.` `,` `:`. A declaration already
looks like a declaration, a call already has its parentheses, and a comma does
not look like a letter — colouring any of them repeats what the code says. What
earns a hue is the part you cannot infer from the shape of the line: which words
belong to the language, which name a type or a package, and which are literals.

`len`, `make`, `append` and friends sit on the light blue row for the same
reason types do: they are the language's own vocabulary, not a name anyone in
this repo chose. A user-defined call stays neutral.

Neither engine can tell a standard-library call from a locally defined one.
gopls sets `defaultLibrary` on exactly one condition, `obj.Pkg() == nil`, which
is universe scope — `len`, `make`, `int`, `nil` — never `fmt.Println`. Go's
TextMate grammar is no better: `entity.name.function.support.go` is
`(?:...(\b\w+)...(?=\())`, any word followed by a paren, so it matches every call
in the file. Only the `.builtin` variant is selective, and any rule targeting
that scope must include the segment.

Three traps when editing the VS Code side:

- `foreground` and `fontStyle` resolve **independently** through the scope trie,
  so a later rule that sets only `foreground` still inherits bold from an
  ancestor rule. `keyword.operator` is a child of `keyword`; clearing its bold
  needs an explicit `"fontStyle": ""`, not an omitted one. So is
  `keyword.other.unit`, which is why the `0x` of a hex literal needs the same
  treatment.
- Style also inherits **down the scope stack**, not just along the dotted name. A
  token scoped `entity.name.import.go` nested inside `string.quoted.double.go`
  is already gold with no rule of its own, and the same goes for
  `constant.other.rune.go` inside `string.quoted.rune.go`. Read the whole stack
  before adding a rule, or you will write one that changes nothing.
- A semantic token only overrides its TextMate scope **if the theme styles it**.
  Every role a language server reports therefore has to be repeated in
  `semanticTokenColors`, or the TextMate colour silently stands.

Brackets carry no `tokenColors` entry — `editorBracketHighlight.foreground1‑6`
are all `#956ccc`, which is what puts them in the purple slot.

### A package is only a package where the parser can prove it

`gopls.ui.semanticTokens` defaults to **false**, and vscode-go does not turn it
on, so nothing in a Go buffer is coloured semantically — every hue there comes
from the TextMate grammar, and `semanticTokenColors` is inert for Go. That makes
the two editors behave the same way, both working from a parse tree alone:

| Where | VS Code | Zed | Recognised? |
|:--|:--|:--|:--|
| `package main`, import block | `entity.name.type.package` | `(package_identifier)` | yes |
| `context.Context` — a qualified **type** | `entity.name.type` | `(qualified_type)` → `(package_identifier)` | yes |
| `time.NewTimer(…)` — an expression | `variable.other` | `(selector_expression)` → `(identifier)` | no |

So the same package is light blue in `ctx context.Context` and neutral in
`context.DeadlineExceeded`. That is not drift: in an expression the qualifier is
indistinguishable from a local variable without cross-file knowledge, and both
engines say so. Setting `"gopls": {"ui.semanticTokens": true}` would colour every
qualifier in VS Code — and diverge from Zed permanently, since Zed ignores LSP
semantic tokens.

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

Zed is the narrower of the two. A syntax style under schema `v0.2.0` accepts only
`color`, `background_color`, `font_style` (`normal` / `italic` / `oblique`) and
`font_weight`. VS Code's `fontStyle: strikethrough` and `fontStyle: underline`
have no Zed equivalent, so struck-through deprecated symbols and underlined links
are permanently VS Code-only — chasing them in the Zed theme is wasted effort.

Zed's `theme_overrides` in the user's `settings.json` is applied on top of the
theme file and wins. It is the Zed-side analogue of
`editor.tokenColorCustomizations`, and the same first thing to rule out.

Neither can a theme see further than its engine. Zed highlights from tree-sitter
alone and ignores LSP semantic tokens, so anything requiring cross-file knowledge
is invisible to it, and a theme cannot add tree-sitter queries. VS Code can go
further where a server is configured to help — see
[the package-qualifier case](#a-package-is-only-a-package-where-the-parser-can-prove-it)
for what that costs in parity.
