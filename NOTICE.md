# NOTICE

## Clean-room statement

Councis and Intatis are covered by the same clean-room boundary. Councis is a first-party product wrapper over the Intatis source and runtime; copying or adapting code between those two first-party trees does not import third-party implementation material.

All Councis/Intatis protocols, prompts, code, names, and UI assets are original to this project. Neither product copies, links against, or runs the source code, private prompts, icons, trademarks, or brand copy of DeepCode, Codex / Codex CLI, Claude Code, OpenCode, or any other product. Public capabilities and interaction patterns may inform product requirements, but the implementation, naming, assets, and wire protocol remain independent.

The frozen `Upstream/Intatis` directory is retained solely as provenance for the first-party wrapper work. It must not be confused with a third-party dependency or a nested repository.

## Third-party dependencies

### Current

- None. The project uses the Swift standard library, Foundation, and Apple-platform SwiftUI / AppKit / Security supplied by the OS toolchain.

### Planned, not vendored

- **libgit2 / SwiftGit2**: considered for in-process Git inside an App Store sandbox. libgit2 is GPLv2 with a linking exception; adoption requires a separate license review.

Update this file whenever a dependency or clean-room boundary changes.
