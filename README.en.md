# Monsieur Bézier — a Bézier pen for SketchUp 2024 / 2025 / 2026

[Русский](README.md) · **English**

A “Monsieur Bézier” toolbar (one button, shown on first launch, then it
remembers its state) plus the same under `Extensions → Monsieur Bézier`
(and “About…” — authors, version, repository link).

Made on request from an architects’ chat: “we’re missing Bézier splines too”.

## Download

[Release 1.0](https://github.com/B-A-community/monsieur-bezier/releases/tag/v1.0) —
two archives that differ only in the UI language:

| Russian UI | English UI |
|---|---|
| `monsieur_bezier-1.0-rus.zip` | `monsieur_bezier-1.0-eng.zip` |

Each archive contains the `.rbz` extension and a one-page PDF guide.

**Install:** SketchUp → `Window → Extension Manager → Install Extension` →
pick the `.rbz` → restart SketchUp. If the toolbar is gone —
`View → Toolbars → Monsieur Bézier`.

## The pen

The toolbar button or `Extensions → Monsieur Bézier → Bézier curve`. It works
like the pen in vector editors:

| Action | What happens |
|---|---|
| click | corner node without handles |
| click and drag | smooth node, you pull a handle (the other one mirrors it) |
| click the first node | close the curve (at least three nodes) |
| Enter or double-click | finish |
| Esc | step back: remove the last node (like the Line tool) |
| number in the input box + Enter | segments per span (1–200, default 12) |

Keys are deliberately not intercepted: Enter and Backspace belong to the input
box. SketchUp routes them itself — with an empty box Enter finishes the curve,
with a typed number it applies the number.

The result is one curve (`add_curve`) per span between nodes, not one for the
whole chain: a single click selects one span to edit it on its own, a triple
click selects the whole chain. A span between two corner nodes stays a single
edge, with no extra vertices on a straight line. SketchUp welds the joints into
shared vertices, so for Follow Me it is still one path. The whole curve is one
operation — Ctrl+Z removes it at once.

## Compatibility

Verified in live SketchUp: 2024 (24.0.484), 2025 (25.0.660) and 2026 (26.1.256) — Windows,
Ruby 3.2. Details in [CHANGELOG.md](CHANGELOG.md) (in Russian).

## Build

```bash
powershell -ExecutionPolicy Bypass -File tools\build_guides.ps1
powershell -ExecutionPolicy Bypass -File build.ps1
```

`tools\build_guides.ps1` prints `docs\guide-rus.html` / `guide-eng.html` to PDF
(headless Edge or Chrome). `build.ps1` builds both packages
`monsieur_bezier-<version>-rus.rbz` / `-eng.rbz` and the release archives
`monsieur_bezier-<version>-rus.zip` / `-eng.zip` (extension + PDF) into
`dist\`. A language build is the same source with the `LANG` line swapped in
`lang.rb` and `html/i18n.js`. Options: `-Lang ru|en` — one language,
`-NoZip` — `.rbz` only.

For development: `dev_install.ps1` copies `src\` into the SketchUp 2024 Plugins
folder (`-Version 2025|2026` for 2025/2026); `tools\su_exec.ps1` runs Ruby in a
live SketchUp through the `sketchup-mcp` bridge (`-Port` for the second and
third open SketchUp: the first one takes 8080, the others pick a free port and
record it in `%LOCALAPPDATA%\complex\instances\`).

## Tests

Plain Ruby 3.2, no SketchUp needed — on an API stub:

```bash
ruby test/test_bezier.rb
ruby test/test_lang.rb
```

`test_bezier.rb` — the pen: spans, joints, what goes into the model, the input
box. `test_lang.rb` — dictionaries: the same keys in both languages, matching
placeholders, every `data-t` in the dialog has a string, the build finds `LANG`.

## Structure

```
src/
  monsieur_bezier.rb               extension registration
  monsieur_bezier/
    main.rb                        entry point
    lang.rb                        Ruby-side strings (ru/en)
    settings.rb                    preferences in the SketchUp registry
    bezier.rb                      cubic curve and span chain
    bezier_tool.rb                 the pen
    about.rb                       “About” dialog
    toolbar.rb                     toolbar and menu
    html/about.html                “About” dialog markup
    html/i18n.js                   dialog strings (ru/en)
    icons/bezier.svg               toolbar icon
docs/
  guide-rus.html, guide-eng.html   guide sources
  monsieur_bezier-1.0-guide-*.pdf  ready guides (go into the release)
test/                              tests without SketchUp
tools/
  build_guides.ps1                 HTML → PDF
  su_exec.ps1                      Ruby in a running SketchUp
build.ps1                          builds .rbz and archives
dev_install.ps1                    copy into Plugins for development
```

Namespace — `BACommunity::MonsieurBezier`. Dialogs and icons follow the B&A
design code (`design/designcode.md` in
[RALNCS](https://github.com/B-A-community/ralncs)): light theme, `#2B6CB0`
accent, flat 24×24 icon. The “About” dialog is built the same way as in RALNCS.

## History

Edge chamfer and fillet lived in this extension from 0.1 to 0.3 and were moved
out into a separate extension in 0.4 — the code is in the repository history
(commit `010a355`), see [CHANGELOG.md](CHANGELOG.md).

## License

Apache 2.0, copyright holder — the B&A community organization (see `LICENSE`
and `AUTHORS`).
