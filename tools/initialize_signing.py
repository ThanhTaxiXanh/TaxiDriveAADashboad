"""One-time Actions bootstrap: publish only AES256-encrypted personal keystore."""
import os
from pathlib import Path
import subprocess
import tempfile

password = os.environ.get('ANDROID_SIGNING_PASSWORD', '')
if len(password) < 20 or '\n' in password or '\r' in password:
    raise SystemExit('Set ANDROID_SIGNING_PASSWORD secret to a random password of at least 20 characters')
target = Path('android/signing/personal.jks.gpg')
if target.exists():
    raise SystemExit('Encrypted keystore already exists. Refusing to rotate signing identity')
target.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as folder:
    key = Path(folder) / 'personal.jks'
    subprocess.run([
        'keytool', '-genkeypair', '-keystore', str(key), '-storetype', 'PKCS12',
        '-alias', 'dashboard', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000',
        '-dname', 'CN=Taxi Xanh Personal Dashboard',
        '-storepass:env', 'ANDROID_SIGNING_PASSWORD', '-keypass:env', 'ANDROID_SIGNING_PASSWORD',
    ], check=True, capture_output=True)
    subprocess.run([
        'gpg', '--batch', '--yes', '--pinentry-mode', 'loopback', '--passphrase-fd', '0',
        '--symmetric', '--cipher-algo', 'AES256', '--output', str(target), str(key),
    ], input=password.encode(), check=True, capture_output=True)
print('Encrypted keystore created; unencrypted temporary keystore removed')
