"""Read network limits only; never sign or send a transaction or print an RPC credential."""
from pathlib import Path
import datetime
import json
import os
import subprocess
import urllib.request

art = Path(__file__).resolve().parent
url = 'https://robinhood-mainnet.g.alchemy.com/v2/' + os.environ['ALCHEMY_KEY']

def rpc(method, params):
    request = urllib.request.Request(
        url,
        data=json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode(),
        headers={'Content-Type': 'application/json'},
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            result = json.load(response)
    except Exception as error:
        return {'transport_error_type': type(error).__name__}
    if 'error' in result:
        return {'rpc_error_code': result['error'].get('code')}
    return result['result']

chain = rpc('eth_chainId', [])
out = {
    'timestamp_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'chain_id_raw': chain,
    'rpc_alias': 'robinhood_mainnet_alchemy',
    'broadcast': False,
}
if chain == hex(4663):
    block = rpc('eth_getBlockByNumber', ['latest', False])
    out['block'] = {key: block.get(key) for key in ['number', 'hash', 'timestamp', 'gasLimit', 'gasUsed']}
    for name in ['getGasAccountingParams()', 'getMaxTxGasLimit()']:
        selector = subprocess.check_output(['cast', 'calldata', name], text=True).strip()
        result = rpc('eth_call', [{'to': '0x000000000000000000000000000000000000006c', 'data': selector}, block['number']])
        out[name] = {
            'result': result,
            'decoded_uint256': [int(result[index:index + 64], 16) for index in range(2, len(result), 64)],
        } if isinstance(result, str) and result.startswith('0x') and len(result) > 2 else result
out['source_urls'] = [
    'https://docs.robinhood.com/chain/connecting/',
    'https://raw.githubusercontent.com/OffchainLabs/nitro/master/precompiles/ArbGasInfo.go',
]
(art / 'robinhood-live-gas-parameters.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps(out, indent=2))
