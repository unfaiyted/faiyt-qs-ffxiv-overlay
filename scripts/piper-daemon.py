#!/usr/bin/env python3
"""Persistent Piper process for low-latency overlay callouts."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import time
import wave
from pathlib import Path

from piper import PiperVoice, SynthesisConfig


def emit(message: dict[str, object]) -> None:
    print(json.dumps(message), flush=True)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: piper-daemon.py MODEL", file=sys.stderr)
        return 2

    model_path = Path(sys.argv[1])
    started = time.monotonic()
    voice = PiperVoice.load(model_path)
    emit({"type": "ready", "loadSeconds": round(time.monotonic() - started, 3)})

    for raw_line in sys.stdin:
        try:
            request = json.loads(raw_line)
            text = str(request.get("text", "")).strip()
            volume = float(request.get("volume", 0.8))
            if not text:
                continue

            synth_started = time.monotonic()
            with tempfile.NamedTemporaryFile(suffix=".wav") as wav_temp:
                with wave.open(wav_temp.name, "wb") as wav_file:
                    voice.synthesize_wav(
                        text,
                        wav_file,
                        SynthesisConfig(length_scale=0.88, volume=volume),
                    )
                synth_seconds = time.monotonic() - synth_started
                emit({"type": "playing", "text": text, "synthSeconds": round(synth_seconds, 3)})
                subprocess.run(
                    ["pw-play", wav_temp.name],
                    check=False,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            emit({"type": "finished", "text": text})
        except Exception as error:  # Keep later raid callouts alive after one bad request.
            emit({"type": "error", "message": str(error)})

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

