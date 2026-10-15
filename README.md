# MD Preview

A small macOS app to read and edit Markdown files. Double-click a `.md` file and it opens formatted, GitHub style. Double-click any word to edit the raw text at that spot. Press **Cmd+E** to go back to the preview.

![MD Preview](docs/screenshot.png)

- GitHub-style preview, light and dark mode
- Double-click to edit where you click
- Saves automatically
- Code colors, LaTeX math, tables, task lists, footnotes, GitHub alerts, emoji

## Install

With Homebrew:

```sh
brew install devinjones812/tap/md-preview
ln -sf "$(brew --prefix md-preview)/MD Preview.app" /Applications/
```

From source (needs Xcode Command Line Tools and [pandoc](https://pandoc.org)):

```sh
brew install pandoc
git clone https://github.com/devinjones812/md-preview.git
cd md-preview
./build.sh --install
```

Then open MD Preview and choose **MD Preview → Set as Default for .md Files**.

## Shortcuts

| Key | Action |
|---|---|
| Double-click | Edit at that spot |
| Cmd+E | Switch between preview and edit |
| Cmd+S | Save (also saves when you switch or close) |
| Cmd+O | Open a file |

## How it works

A Swift/AppKit app with a WebKit view. [pandoc](https://pandoc.org) converts Markdown to HTML and tags each word with its source line and column, which makes double-click-to-edit possible. Math renders as MathML. Code colors come from [highlight.js](https://highlightjs.org).

## Credits

- Stylesheet based on [QLMarkdown](https://github.com/sbarex/QLMarkdown) by sbarex (GPL-3.0)
- [highlight.js](https://highlightjs.org) (BSD-3-Clause)
- [pandoc](https://pandoc.org) (GPL-2.0-or-later), installed separately

## License

GPL-3.0. See [LICENSE](LICENSE).
