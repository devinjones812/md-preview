# MD Preview

Open Markdown files on your Mac in a clean, simple viewer and editor.

There was no simple, free, bare-bones Markdown viewer and editor for Mac, so I built one.

Double-click a `.md` file to read it formatted. Double-click any word to edit the text there. Cmd+E switches back.

Built-in PDF export: click **PDF** in the toolbar (or Cmd+P) to save the document as a PDF that looks like the preview.

```sh
brew tap devinjones812/md-preview https://github.com/devinjones812/md-preview
brew trust devinjones812/md-preview
brew install md-preview
```

Or from source: `brew install pandoc && ./build.sh --install`. Then choose **MD Preview → Set as Default for .md Files**.

Built with Swift, [pandoc](https://pandoc.org), and [highlight.js](https://highlightjs.org). Stylesheet from [QLMarkdown](https://github.com/sbarex/QLMarkdown). GPL-3.0.
