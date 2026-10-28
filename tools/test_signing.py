"""Exercise signing round trip using disposable random test credentials."""
import os
from pathlib import Path
import secrets
import subprocess
import tempfile

root = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as folder:
    work = Path(folder)
    (work / 'android/app').mkdir(parents=True)
    (work / 'gnupg').mkdir(mode=0o700)
    env = dict(os.environ, GNUPGHOME=str(work / 'gnupg'),
               ANDROID_SIGNING_PASSWORD=secrets.token_urlsafe(32), GITHUB_ENV=str(work / 'env'))
    for name in ('KEYSTORE', 'STORE_PASSWORD', 'KEY_PASSWORD', 'KEY_ALIAS'):
        env.pop(name, None)
    for script in ('initialize_signing.py', 'configure_signing.py'):
        subprocess.run(['python3', str(root / script)], cwd=work, env=env, check=True)
    subprocess.run(['keytool', '-list', '-keystore', str(work / 'android/app/personal.jks'),
                    '-storepass:env', 'ANDROID_SIGNING_PASSWORD'], env=env, check=True, capture_output=True)
    assert (work / 'env').read_text() == 'HAS_SIGNING=true\n'
    repeat = subprocess.run(['python3', str(root / 'initialize_signing.py')], cwd=work, env=env, capture_output=True)
    assert repeat.returncode != 0, 'Must refuse silent key rotation'
    print('Signing round trip and refusal to rotate: OK')
