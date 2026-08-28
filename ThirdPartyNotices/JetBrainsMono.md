# JetBrains Mono interface-font notice

Councis distributes the unmodified JetBrains Mono font family as its Latin
interface and message typeface.

## Upstream and immutable source

- Upstream: <https://github.com/JetBrains/JetBrainsMono>
- Release/tag: `v2.304`
- Commit: `cd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9`
- Release asset: `JetBrainsMono-2.304.zip`
- Release asset SHA-256:
  `6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf`
- Reuse type: `vendored`, unmodified font binaries
- Typeface license: SIL Open Font License 1.1
- Upstream copyright notice:
  `Copyright 2020 The JetBrains Mono Project Authors`

The upstream repository source code is separately offered under Apache-2.0,
but Councis does not copy or build that source. This adoption consists only of
the release's 16 standard (non-`NL`) static TTF files and its exact `OFL.txt`.

## Distributed inventory

The font payload is stored at
`Packages/CouncisSharedUI/Sources/Resources/Fonts/` and copied by SwiftPM into
the `CouncisSharedUI` resource bundle. It contains:

- 8 weights from Thin through ExtraBold;
- a matching italic face for every weight;
- 16 TTF files totaling 4,422,040 bytes;
- the unmodified 4,399-byte `OFL.txt`;
- a Councis-authored `SHA256SUMS` inventory.

Per-file hashes are authoritative in that adjacent `SHA256SUMS`. The complete
OFL text is also exposed through
`ThirdPartyNotices/Licenses/JetBrainsMono-2.304-OFL-1.1.txt`; both copies have
SHA-256
`30f0c136e3c88e422d0791acd97238870f9054a9729bc34cf2ff0d4ed8cac4ad`.

## Runtime boundary

`CouncisTypography` creates Core Text descriptors directly from the bundled
files. It does not depend on a user-installed font and does not globally
register or replace fonts in the operating system. Each interface font uses an
explicit same-weight cascade to the Apple system family PingFang SC for
Simplified Chinese; PingFang itself is a platform font and is not redistributed
by Councis. Missing, unreadable, or identity-mismatched JetBrains Mono files
fail explicitly instead of silently selecting another Latin family.

JetBrains Mono is also supplied to the existing Markdown renderer for prose,
headings, lists, tables, inline code, code blocks, and the text-selection
surface. It is not supplied to iosMath. Inline and display LaTeX continue to
use iosMath's independently bundled mathematical typeface and layout tables.

No JetBrains logo, IDE asset, product screenshot, UI design, source code,
installer, script, webfont, variable font, or `JetBrains Mono NL` file is
distributed by this adoption.

