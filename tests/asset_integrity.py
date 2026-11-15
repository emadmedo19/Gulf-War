"""Validate exact artwork bytes before Godot imports or exports them."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "assets/manifest.json").read_text())
for name, expected in manifest.items():
    data = (root / "assets" / name).read_bytes()
    assert len(data) == expected["bytes"], f"Artwork is incomplete: {name}"
    assert hashlib.sha256(data).hexdigest() == expected["sha256"], f"Artwork is corrupted: {name}"
    print(f"PASS: complete artwork {name}, {len(data)} bytes")
