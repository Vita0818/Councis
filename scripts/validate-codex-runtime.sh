#!/bin/zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"
intatis_root="$(cd "$project_root/../Intatis" && pwd -P)"
validator="$intatis_root/scripts/validate-codex-runtime.sh"

[[ "$intatis_root" == "/Users/vita/Vitemis/Intatis" ]] || {
    print -u2 -- "error: ../Intatis resolved to unexpected root: $intatis_root"
    exit 1
}
[[ -x "$validator" ]] || {
    print -u2 -- "error: shared Intatis validate-codex-runtime entry is unavailable"
    exit 1
}

exec "$validator" "$@"

