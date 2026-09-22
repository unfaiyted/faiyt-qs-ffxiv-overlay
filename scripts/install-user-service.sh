#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
template="$project_dir/systemd/faiyt-qs-ffxiv-overlay.service"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
unit_path="$unit_dir/faiyt-qs-ffxiv-overlay.service"

mkdir -p "$unit_dir"
escaped_project_dir="${project_dir//&/\\&}"
sed "s|@PROJECT_DIR@|$escaped_project_dir|g" "$template" > "$unit_path"

systemctl --user daemon-reload
systemctl --user reenable faiyt-qs-ffxiv-overlay.service
systemctl --user restart faiyt-qs-ffxiv-overlay.service

printf 'Installed and started %s\n' "$unit_path"
