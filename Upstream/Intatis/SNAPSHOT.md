# Intatis source snapshot

This directory is a frozen, read-only reference copy for the Councis wrapper.
Councis implementation work must not edit files in this directory; copy or
adapt changes into the normal Councis source tree instead.

## Provenance

- Source repository: `/Users/vita/Vitemis/Intatis`
- Source branch: `main`
- Source Git HEAD: `437fcb8a962ad8a833cf23eee956c3f92a088a9c`
- Source Git tree: `7a10f2a2ad9dda8ff5e8c115ebab52c65d7c6a3f`
- Source commit subject: `v0.26`
- Snapshot time (UTC): `2026-07-26T01:33:50Z`
- Source state: clean current working tree; local `origin/main` was 0 commits
  ahead and 0 commits behind without performing a network fetch
- Snapshot method: the 434 tracked files from `git archive HEAD`, which exactly
  represented the clean source working tree at snapshot time
- Snapshot file-content manifest SHA-256 (excluding this file):
  `9770e4ba257e19fd69fbe8ef93f42fad76c278c211ebc58cc7531e34a19f3aa0`

The source was clean, so a Git archive captured the complete current source
state while avoiding ignored build products, generated projects, local runtime
state, and secret-bearing local configuration. This records the latest local
source state known at snapshot time; no network fetch was performed.

## Manifest algorithm

The aggregate manifest hashes sorted lines of `<file SHA-256><two spaces><path>`
for every regular file except `SNAPSHOT.md`:

```sh
find . -type f ! -path './SNAPSHOT.md' -print \
  | LC_ALL=C sort \
  | while IFS= read -r snapshot_file; do
      snapshot_digest=$(shasum -a 256 "$snapshot_file" | awk '{print $1}')
      printf '%s  %s\n' "$snapshot_digest" "${snapshot_file#./}"
    done \
  | shasum -a 256
```

The source tree had no tracked symlinks, submodules, nested Git repositories, or
newline-containing tracked paths at snapshot time.

## Included

- `Apps/`
- `Packages/` and tests
- `Vendor/SwiftStreamingMarkdown/`, its license, patch ledger, sources, and tests
- `ThirdPartyNotices/`
- `docs/`
- root SwiftPM/XcodeGen/build scripts, including `Package.resolved`
- tracked source-side reports and design documentation present in HEAD

## Excluded

- `.git/` (prevents a nested repository)
- `.build/`, `.swiftpm/`, `DerivedData/`
- generated `Intatis.xcodeproj/` and Xcode user state
- `.DS_Store`
- local `.intatis/` / `.councis/` runtime state
- ignored local secret/config patterns such as `.env`, `*.env`, `secrets.json`,
  and `Config.local.*`
- certificates, private keys, provisioning profiles, auth files, and other
  local credentials

No API keys, auth files, build caches, generated app binaries, or runtime
session data are part of this snapshot.
