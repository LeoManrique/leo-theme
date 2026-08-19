# Leo Theme Roadmap

## Done

- **v2 — Zed port.** `themes/leo-dark.json` ships the full theme against schema
  `v0.2.0`. Key mapping lives in [TECHNICAL.md](TECHNICAL.md).
- **Parity corpus.** `preview/` — one sample per language plus a checklist for the
  state-driven surfaces.
- **Dev install.** `install-dev.py` links both editors at the repo, so a pass tests
  the working tree instead of a published snapshot.

## Parity pass

Per-file status. Procedure is in [preview/CHECKLIST.md](preview/CHECKLIST.md);
only the verdict belongs here.

- [x] `00-plain.txt`
- [x] `01-markdown.md` — 3 divergences found and fixed
- [ ] `02-react.tsx`
- [ ] `03-broken.ts`
- [ ] `04-mod.lua`
- [ ] `05-decomp.h` / `05-decomp.c`
- [ ] `06-styles.scss`
- [ ] `07-page.html`
- [ ] `08-config.toml`
- [ ] `09-config.json`
- [ ] `10-compose.yml`
- [ ] `11-script.sh`
- [ ] `12-queries.sql`
- [ ] `13-app.swift`
- [ ] `14-component.svelte`
- [ ] `15-patch.diff`
- [ ] `16-script.py`
- [ ] `17-main.zig`
- [x] `go/main.go` — 9 divergences, and a palette rework it triggered
- [ ] `rust/src/main.rs`
- [ ] `Main.java`
- [ ] `Makefile` / `justfile`
- [ ] `Dockerfile`
- [ ] Surfaces no file can show — [CHECKLIST.md](preview/CHECKLIST.md) §3

Fixes from the `01-markdown.md` pass:

- Markdown **bold and italic are light blue `#9cdcfe`** in both editors, keeping the
  bold/italic face, delimiters included. Same hue as types and packages in code:
  emphasis names something, and it stays clear of the keyword blue the headings
  use. Previously VS Code rendered both neutral and Zed rendered bold blue.
- Markdown link labels are neutral in both. VS Code's link rule covered
  `string.other.link.dest` and `.title` but not `.description`, so `[text]` fell
  through to the generic string rule and came out gold.
- Removed lines in a diff are **brick red `#d07e70`** in both, the perceptual
  midpoint of the two values that had drifted apart (VS Code salmon `#ce9178`,
  Zed `#d16969`). Added lines already agreed on `#b5cea8`.

Fixes from the `go/main.go` pass. It found nine divergences, eight of them VS Code
under-specifying, and exposed that colour was being spent everywhere rather than
where it informs. The [hue contract](TECHNICAL.md#hue-contract) came out of it:

- **Blue now means keyword.** Types moved off it onto light blue `#9cdcfe`,
  joining packages, struct fields and attributes as one family: a named, declared
  thing. Previously blue also meant type, enum, boolean and tag, so it had
  stopped distinguishing anything.
- **Punctuation is purple bold in both editors** — operators, brackets and
  `,` `;` `.` `:`. It is the highest-frequency token class in the corpus, and
  weight is what lets it mark where a call opens or a statement ends without
  being read; the names in between stay neutral by contrast. VS Code needed the
  per-grammar scopes spelled out (Go's `punctuation.other.*`, Rust's
  `punctuation.comma` / `punctuation.semi`, a dozen bracket spellings), Zed needed
  `punctuation.delimiter` moved onto the purple row. Digit separators, decimal
  points and exponent signs stay with the number on both sides. Verified by
  tokenising the whole corpus through the real grammars: 387 scope leaves changed
  style, every one a bracket, operator or separator; the five word-shaped
  operators (`new`, `sizeof`, `instanceof`, `is`, `not`) went blue-bold with the
  keywords.
- **VS Code learned the roles it was missing** — types, packages, escape
  sequences and printf placeholders had all been falling through to
  `editor.foreground`.
- **Neutral is now a decision, not a gap.** Struct fields, property accesses,
  declared constants, variables, parameters, functions and methods are all
  deliberately uncoloured in both editors: each is already legible from the shape
  of the line, so a hue there only competes with the ones that inform.
- **Builtin calls joined the light blue family** — `len`, `make`, `append`,
  `new`, `panic`. Same argument as types: language vocabulary, not a name from
  this repo. Gold now means string and nothing else.
- **The `0x` of a hex literal was bold.** `keyword.other.unit` is a child of
  `keyword` and inherited it; it needs an explicit `fontStyle: ""`. Found by
  tokenising the file rather than by looking at it.
- **Verified rather than eyeballed.** The file was run through the real Go
  TextMate grammar and Zed's real `highlights.scm`, and the two colour streams
  compared token by token: 1163 tokens, 3 disagreements, all of them grammar
  granularity in type-switch and conversion positions. Const names and struct
  fields are `#d4d4d4` in both — a perceived difference there is font weight
  (Zed 450 / 13.5 against VS Code 400 / 12.5), not colour.
- `nil` / `iota` / `true` / `false` are blue and unbolded in both.

### Open divergences

- [ ] **VS Code defines no diff-editor or git-decoration colors at all.** Zed has a
  full set — `deleted`, `created`, `modified`, `conflict`, `version_control.*`. The
  VS Code side falls back to vs-dark defaults, so `diffEditor.*`, `editorGutter.*`
  and `gitDecoration.*` cannot match by construction. Comes due at
  [CHECKLIST.md](preview/CHECKLIST.md) §3 Diff and Sidebar.
- [ ] **Two reds one step apart in the Zed theme.** Diff text is now `#d07e70`
  while the VCS status colors (`deleted`, `version_control.deleted`) are still
  `#d16969`. Different surfaces, so possibly fine — decide when the item above is
  settled, rather than drifting into it.
- [ ] **Standard-library calls cannot be told from local ones**, in either
  editor. gopls only flags universe scope, and Go's grammar scopes every call
  alike. Revisit only if gopls grows a modifier for it.
- [ ] **Three Go tokens still disagree, all in positions one grammar reads as a
  type and the other does not.** `int(s)` is a conversion — a type to VS Code,
  a call to Zed. `case nil:` and `case []Record:` in a type switch are types to
  Zed and plain identifiers to VS Code. Neither side can be corrected from a
  theme file; VS Code is the one under-colouring in two of the three.
- [ ] **Zed `variant` is still blue `#5996db`.** VS Code puts enum members on
  pale green `#b5cea8` via `variable.other.enummember`, so Rust's `Some` / `Ok`
  probably diverge. Verify at the `rust/src/main.rs` pass rather than guessing.
- [ ] **C and C++ builtin types.** Their grammars call `int` a `storage.type`,
  like Go's does, so they will come out blue-bold instead of teal until they get
  the same treatment `source.go storage.type` has. Due at the `05-decomp` pass.
- [ ] **`variable.other.enummember` is still pale green in VS Code** while Zed's
  `constant` is now neutral. Go never reaches it, so it did not show up here.
  Decide at the Rust and TSX passes, together with `variant`.

## Next

- **Parity script.** `scripts/parity.mjs` holding the VS Code → Zed key map, reporting
  keys present in one theme but missing from the other, and colors that drifted apart.
  The markdown emphasis drift above is exactly what it is for: the corpus caught it
  only because someone looked at the right file.
- **Release the pending fixes.** `package.json` is still at `1.0.2` and `CHANGELOG.md`
  has no entry for the Zed selection-contrast change or the markdown emphasis and
  link-label work above.
- **Screenshots for the marketplace.** `preview/` doubles as the source. Same window
  size, same files, one shot per editor, stored as a pair so releases stay diffable.
- **Light variant.** Not started, no palette yet.
