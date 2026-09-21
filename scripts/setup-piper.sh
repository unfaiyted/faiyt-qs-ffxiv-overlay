#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
venv_dir="$project_dir/.venv-piper"
voice_dir="$project_dir/assets/voices"

python3 -m venv "$venv_dir"
"$venv_dir/bin/python" -m pip install --upgrade pip piper-tts
install -d "$voice_dir"
"$venv_dir/bin/python" -m piper.download_voices \
    --data-dir "$voice_dir" \
    en_US-lessac-medium

echo "Piper and en_US-lessac-medium are ready."

