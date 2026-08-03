# Upstream snapshot boundary

Everything under `Upstream/` is a frozen reference snapshot.

- Read files freely for comparison, porting, and provenance checks.
- Do not edit, format, generate into, build inside, or delete snapshot files.
- Do not treat a snapshot as a nested Git repository.
- Apply all Councis changes in the normal project source tree outside
  `Upstream/`.
- If Intatis must be refreshed later, create a new reviewed snapshot or perform
  an explicit whole-snapshot refresh; never make ad-hoc changes in place.

The copied repository's own `AGENTS.md` is retained as source provenance. This
parent rule is more specific to the snapshot's role inside Councis and makes the
tree read-only for agent work.
