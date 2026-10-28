"""Emit formatter corrections as JSON so API-only clients can apply them."""
import json
import pathlib
import subprocess
for root in ('lib', 'test'):
    for path in sorted(pathlib.Path(root).rglob('*.dart')):
        result = subprocess.run(['dart', 'format', '--output=show', '--summary=none', str(path)],
                                check=True, capture_output=True, text=True)
        print('FORMAT_JSON ' + json.dumps({'path': str(path), 'content': result.stdout}, ensure_ascii=False))
