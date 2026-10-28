"""Read Actions secrets without printing their contents. Never commits keys."""
import base64
import os
from pathlib import Path

names = ('KEYSTORE', 'STORE_PASSWORD', 'KEY_PASSWORD', 'KEY_ALIAS')
values = {name: os.environ.get(name, '') for name in names}
if any(values.values()) and not all(values.values()):
    raise SystemExit('Signing secrets incomplete: all four values are required')
if all(values.values()):
    key = Path('android/app/personal.jks')
    key.write_bytes(base64.b64decode(values['KEYSTORE'], validate=True))
    key.chmod(0o600)

    def escape(value):
        return value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('=', '\\=').replace(':', '\\:').replace(' ', '\\ ')

    Path('android/key.properties').write_text(
        'storeFile=personal.jks\n'
        f"storePassword={escape(values['STORE_PASSWORD'])}\n"
        f"keyPassword={escape(values['KEY_PASSWORD'])}\n"
        f"keyAlias={escape(values['KEY_ALIAS'])}\n"
    )
    with open(os.environ['GITHUB_ENV'], 'a') as handle:
        handle.write('HAS_SIGNING=true\n')
