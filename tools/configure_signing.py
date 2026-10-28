"""Read Actions secrets without printing their contents. Never commits keys."""
import base64
import os
import subprocess
from pathlib import Path

names = ('KEYSTORE', 'STORE_PASSWORD', 'KEY_PASSWORD', 'KEY_ALIAS')
values = {name: os.environ.get(name, '') for name in names}
if any(values.values()) and not all(values.values()):
    raise SystemExit('Signing secrets incomplete: all four values are required')
encrypted = Path('android/signing/personal.jks.gpg')
password = os.environ.get('ANDROID_SIGNING_PASSWORD', '')
if not any(values.values()) and encrypted.exists():
    if not password:
        raise SystemExit('Encrypted keystore exists but ANDROID_SIGNING_PASSWORD is missing')
    key = Path('android/app/personal.jks')
    subprocess.run(['gpg', '--batch', '--yes', '--pinentry-mode', 'loopback',
                    '--passphrase-fd', '0', '--output', str(key), '--decrypt', str(encrypted)],
                   input=password.encode(), check=True, capture_output=True)
    import base64
    values = dict(KEYSTORE=base64.b64encode(key.read_bytes()).decode(),
                  STORE_PASSWORD=password, KEY_PASSWORD=password, KEY_ALIAS='dashboard')
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
