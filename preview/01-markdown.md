# Heading one — the largest `title` capture

Markdown is the third-largest language in this corpus and the one most likely to be
open in a preview pane, so it earns a dense sample. Zed keys headings, emphasis, links
and list markers to separate captures; VS Code splits them across TextMate scopes.
This file walks every one of them.

## Heading two

### Heading three

#### Heading four

##### Heading five

###### Heading six

Alternate setext heading
========================

Alternate setext subheading
---------------------------

## Inline spans

Plain text, then *single emphasis*, then **strong emphasis**, then ***both at once***,
then _underscore emphasis_ and __underscore strong__. Inline `code spans` use the
`text.literal` capture, which should be distinguishable from surrounding prose without
shouting. ~~Strikethrough~~ matters here because Leo Dark uses strikethrough for
deprecated symbols elsewhere — the two should not be confusable.

A [inline link](https://zed.dev/docs/themes) splits into `link_text` and `link_uri`.
A [reference link][ref] resolves at the bottom. A bare autolink
<https://code.visualstudio.com/api/references/theme-color> is a third case. And a plain
unlinked URL https://github.com/LeoManrique/leo-theme is a fourth — some grammars
linkify it, some do not.

![An image, which is a link with a bang](../icon.png "Leo Dark icon")

Footnote reference[^1] and a second one[^note].

## Lists

- Unordered with a dash
- Second item
  - Nested one level
    - Nested two levels
      - Nested three levels, to check indent guides
- Back to the top level

* Unordered with an asterisk
+ Unordered with a plus

1. Ordered list
2. Second item
   1. Nested ordered
   2. Another
10. Non-sequential number
1. Lazy numbering

- [ ] Unchecked task
- [x] Checked task
- [ ] Task with **bold** and `code` inside

Term-style list:

Definition heading
: The colon form, supported by some renderers only.

## Block quotes

> A single-level quote.
>
> With a second paragraph, some **bold**, and a `code span`.
>
> > A nested quote, which should still be readable.
> >
> > > And a third level.

## Code blocks

An indented code block:

    not_fenced = True
    print("four-space indented")

A fenced block with no language — this should fall back to plain foreground:

```
$ git status
On branch main
nothing to commit, working tree clean
```

A fenced block with a language, which most editors highlight inline:

```go
func main() {
	greeting := "embedded Go inside markdown"
	fmt.Println(greeting, 42, true, nil)
}
```

```json
{ "workbench.colorTheme": "Leo Dark", "editor.fontSize": 12.5 }
```

```diff
- const old = "removed line"
+ const new = "added line"
```

A tilde fence, which is the less common form:

~~~sh
echo "tilde fenced"
~~~

## Table

| Surface        | VS Code key                  | Zed key                  | Note              |
| :------------- | :--------------------------- | -----------------------: | :---------------: |
| Editor         | `editor.background`          | `editor.background`      | direct            |
| Active tab     | `tab.activeBackground`       | `tab.active_background`  | direct            |
| Status bar     | `statusBar.background`       | `status_bar.background`  | direct            |
| Sidebar        | `sideBar.background`         | `panel.background`       | approximate       |
| Token: keyword | `tokenColors` scope `keyword`| `syntax.keyword.color`   | manual mapping    |

## Rules

Three dashes:

---

Three asterisks:

***

Three underscores:

___

## Raw HTML

<div align="center">
  <strong>Inline HTML block</strong> — tests the <code>embedded</code> capture.
  <br />
  <em>Second line</em>
</div>

An inline <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> sequence, and an
<a href="https://example.com">HTML anchor</a> mid-paragraph.

<!-- An HTML comment, which should read as a comment and not as prose. -->

## Escapes and edge cases

Escaped characters: \*not emphasis\*, \`not code\`, \# not a heading, \[not a link\].

Hard line break at the end of this line (two trailing spaces)  
and the continuation.

Backslash break at the end of this line\
and its continuation.

An empty link [](), a link with a title [titled](https://example.com "hover me"),
and a link containing `code` and **bold**: [**bold** `code` link](https://example.com).

[ref]: https://github.com/microsoft/vscode/blob/main/src/vs/platform/theme/common/colorRegistry.ts
[^1]: The first footnote body.
[^note]: The second footnote body, with a [link](https://example.com) inside it.
