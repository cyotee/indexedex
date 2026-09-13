"""Read pinned public EtherFi quote inputs; never print RPC credentials."""
from pathlib import Path
from datetime import datetime, timezone
import json
import os
import urllib.request
from Crypto.Hash import keccak

art = Path(__file__).resolve().parent
block = hex(24_000_000)
url = 'https://eth-mainnet.g.alchemy.com/v2/' + os.environ['ALCHEMY_KEY']
eeth = '0x35fA164735182de50811E8e2E824cFb9B6118ac2'
pool = '0x308861A430be4cce5502d0A12724771Fc6DaF216'
manager = '0xDadEf1fFBFeaAB4f68A9fD181395F68b4e4E7Ae0'
sentinel = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'


def rpc(method, params):
    request = urllib.request.Request(url, data=json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode(), headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            result = json.load(response)
    except Exception as error:
        return {'transport_error_type': type(error).__name__}
    if 'error' in result:
        return {'rpc_error_code': result['error'].get('code')}
    return result['result']


def call(address, signature, argument=None):
    selector = keccak.new(digest_bits=256, data=signature.encode()).hexdigest()[:8]
    data = '0x' + selector + (argument[2:].rjust(64, '0') if argument else '')
    raw = rpc('eth_call', [{'to': address, 'data': data}, block])
    return {'target': address, 'signature': signature, 'argument': argument, 'raw': raw,
            'words': [int(raw[i:i + 64], 16) for i in range(2, len(raw), 64)] if isinstance(raw, str) and raw.startswith('0x') else []}


out = {'recorded_at_utc': datetime.now(timezone.utc).isoformat(), 'alias': 'ethereum_mainnet_alchemy',
       'block': 24_000_000, 'broadcast': False, 'chain': rpc('eth_chainId', [])}
assert out['chain'] == '0x1', 'Ethereum read-only preflight failed; no endpoint printed.'
out['calls'] = [call(eeth, 'totalShares()'), call(pool, 'getTotalPooledEther()'),
                call(pool, 'totalValueInLp()'), call(pool, 'etherFiRedemptionManager()'),
                call(manager, 'tokenToRedemptionInfo(address)', sentinel),
                call(manager, 'treasury()')]
out['status'] = 'PUBLIC_INPUT_READS_ONLY_NOT_PROJECTION_VALIDATION'
(art / 'etherfi-projection-input-preflight.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps(out, indent=2))
