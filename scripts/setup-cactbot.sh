#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cactbot_dir="$project_dir/.deps/cactbot"
revision="$(tr -d '[:space:]' < "$project_dir/cactbot.version")"
repository="https://github.com/OverlayPlugin/cactbot.git"

mkdir -p "$project_dir/.deps"
if [[ ! -d "$cactbot_dir/.git" ]]; then
    git clone "$repository" "$cactbot_dir"
fi

git -C "$cactbot_dir" remote set-url origin "$repository"
git -C "$cactbot_dir" fetch origin "$revision"
git -C "$cactbot_dir" checkout --detach "$revision"
npm --prefix "$cactbot_dir" ci
npm --prefix "$cactbot_dir" run build

printf 'Cactbot %s built in %s/dist\n' "$revision" "$cactbot_dir"
