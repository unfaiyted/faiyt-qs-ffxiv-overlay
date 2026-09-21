#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="$project_dir/.venv-piper/bin/python"
model="$project_dir/assets/voices/en_US-lessac-medium.onnx"

if [[ "${1:-}" == "--check" ]]; then
    [[ -x "$python_bin" && -f "$model" ]]
    exit
fi

text="${1:-}"
volume="${2:-0.8}"
[[ -n "$text" ]] || exit 0

wav_file="$(mktemp --suffix=.wav)"
trap 'rm -f -- "$wav_file"' EXIT

"$python_bin" -m piper \
    --model "$model" \
    --length-scale 0.88 \
    --sentence-silence 0.05 \
    --volume "$volume" \
    --output-file "$wav_file" \
    -- "$text"

pw-play "$wav_file"

