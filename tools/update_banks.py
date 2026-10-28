"""Download public bank metadata only; never handles payment/account data."""
import base64
import datetime
import json
import pathlib
import re
import urllib.request

URL = 'https://api.vietqr.io/v2/banks'
request = urllib.request.Request(URL, headers={'User-Agent': 'TaxiXanh-bank-snapshot/0.3'})
with urllib.request.urlopen(request, timeout=45) as response:
    raw = response.read(1024 * 1024 + 1)
if len(raw) > 1024 * 1024:
    raise ValueError('Bank response too large')
body = json.loads(raw)
if body.get('code') != '00':
    raise ValueError('Bank API unsuccessful')
banks = []
seen = set()
for bank in body['data']:
    bin_code = str(bank['bin'])
    if not re.fullmatch(r'[0-9]{6}', bin_code) or bin_code in seen:
        raise ValueError('Invalid or duplicate BIN')
    seen.add(bin_code)
    banks.append({k: bank[k] for k in ('name', 'code', 'bin', 'shortName', 'logo', 'transferSupported')})
if len(banks) < 30:
    raise ValueError('Incomplete bank response')
result = {'source': URL, 'retrievedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'banks': banks}
encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
path = pathlib.Path('assets/banks_vn.json')
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(encoded)
print(f'Validated {len(banks)} public bank entries')
# Public data is also emitted so the repository owner can review/commit via API.
b64 = base64.b64encode(encoded.encode()).decode()
for offset in range(0, len(b64), 4096):
    print('BANKS_B64 ' + b64[offset:offset + 4096])
