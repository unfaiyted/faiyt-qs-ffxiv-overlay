#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
revision="${1:-}"

if [[ ! "$revision" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf 'Usage: %s <40-character-cactbot-revision>\n' "$0" >&2
    exit 2
fi

# Build first. setup-cactbot accepts an explicit revision without changing the
# tracked pin, so a failed fetch/install/build leaves cactbot.version untouched.
"$project_dir/scripts/setup-cactbot.sh" "$revision"
printf '%s\n' "$revision" > "$project_dir/cactbot.version"
printf 'Cactbot updated and repinned at %s\n' "$revision"
