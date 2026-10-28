"""Emit public package versions/hashes for reproducible API-only CI updates."""
import base64
import pathlib
value = base64.b64encode(pathlib.Path('pubspec.lock').read_bytes()).decode()
for offset in range(0, len(value), 4096):
    print('LOCK_B64 ' + value[offset:offset + 4096])
