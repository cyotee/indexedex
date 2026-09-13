"""Read pinned sfrxETH conversion inputs without sending any transactions."""
from pathlib import Path
from datetime import datetime, timezone
from Crypto.Hash import keccak
import json
import os
import urllib.request

art = Path(__file__).resolve().parent
block = hex(24_000_000)
url = 'https://eth-mainnet.g.alchemy.com/v2/' + os.environ['ALCHEMY_KEY']
vault = '0xac3E018457B222d93114458476f3E3416Abbe38F'
minter = '0xbAFA44EFE7901E04E39Dad13167D089C559c1138'
calls = []

def call(target, signature, argument=None):
    selector = keccak.new(digest_bits=256, data=signature.encode()).hexdigest()[:8]
    data = '0x' + selector + ('' if argument is None else format(argument, '064x'))
    request = urllib.request.Request(url, data=json.dumps({
        'jsonrpc': '2.0', 'id': 1, 'method': 'eth_call', 'params': [{'to': target, 'data': data}, block]
    }).encode(), headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            result = json.load(response)
    except Exception as error:
        raise SystemExit('Read-only input request failed: ' + type(error).__name__)
    if 'error' in result:
        raise SystemExit('Read-only input RPC error code: ' + str(result['error'].get('code')))
    value = int(result['result'], 16)
    calls.append({'target': target, 'signature': signature, 'argument': argument, 'value': value})
    return value

assets = call(vault, 'totalAssets()')
supply = call(vault, 'totalSupply()')
full_shares = call(vault, 'convertToShares(uint256)', assets)
full_assets = call(vault, 'convertToAssets(uint256)', supply)
unit = 10**18
deposit = call(vault, 'previewDeposit(uint256)', unit)
withdraw = call(vault, 'previewWithdraw(uint256)', unit)
redeem = call(vault, 'previewRedeem(uint256)', unit)
virtual_probe = call(vault, 'convertToShares(uint256)', assets + 1)
cycle = {key: call(vault, key + '()') for key in ['rewardsCycleEnd', 'rewardsCycleLength', 'lastSync', 'lastRewardAmount']}
paused = bool(call(minter, 'submitPaused()'))
checks = {
    'full_supply_conversion': full_shares == supply and full_assets == assets,
    'deposit_floor': deposit == unit * supply // assets,
    'withdraw_ceiling': withdraw == (unit * supply + assets - 1) // assets,
    'redeem_floor': redeem == unit * assets // supply,
    'virtual_offset_snapshot_rejected': virtual_probe < supply + 1,
    'existing_minter_enabled': not paused,
}
record = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(), 'block': int(block, 16),
    'status': 'PUBLIC_INPUT_READS_ONLY_NOT_PROJECTION_EXECUTION', 'broadcast': False,
    'checks': checks, 'reward_cycle': cycle, 'calls': calls,
    'primary_sources': ['https://raw.githubusercontent.com/FraxFinance/frxETH-public/master/src/sfrxETH.sol',
                        'https://raw.githubusercontent.com/corddry/ERC4626/main/src/xERC4626.sol'],
}
(art / 'sfrxeth-projection-input-preflight.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'block': int(block, 16), 'checks': checks, 'reward_cycle': cycle}, indent=2))
if not all(checks.values()):
    raise SystemExit(1)
