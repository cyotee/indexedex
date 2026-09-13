"""Run the complete maintained architecture simulation on a separate strict local fork."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture

runtime = art / 'current-robinhood-rehearsal-production-readiness-funding'
completed = art / 'current-robinhood-rehearsal-production-readiness-lifecycle-fixed'
rpc_url = 'http://127.0.0.1:18664'
owner = '0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B'
record_path = runtime / 'funding-quote.json'
log_path = runtime / 'funding-quote.log'
assert not record_path.exists() and not log_path.exists()
keys = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')
provenance = capture(root)
build = json.loads((art / 'implementation-full-build.json').read_text())
lifecycle = json.loads((completed / 'lifecycle-run.json').read_text())
assert build['exit_code'] == 0 and lifecycle['status'] == 'PASS_ALL_39_STRICT_LIFECYCLE_CASES'
assert all(provenance[key] == build['provenance'][key] == lifecycle['provenance'][key] for key in keys)
node = json.loads((runtime / 'node.json').read_text())
assert node['rpc'] == rpc_url and node['fork_block'] == 56118361
assert node['code_size_limit'] == 24576 and node['block_gas_limit'] == 32000000

def rpc(url, method, params):
    assert url in (rpc_url, 'http://127.0.0.1:18665')
    if url != rpc_url:
        assert method in ('eth_blockNumber', 'eth_getBlockByNumber')
    assert method in ('eth_chainId', 'anvil_nodeInfo', 'anvil_impersonateAccount',
                      'anvil_setBalance', 'eth_blockNumber', 'eth_getBlockByNumber')
    req = urllib.request.Request(url, data=json.dumps(
        {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode(),
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=60) as response:
        result = json.load(response)
    assert 'error' not in result, 'Local RPC failed: ' + method
    return result['result']

info = rpc(rpc_url, 'anvil_nodeInfo', [])
assert int(rpc(rpc_url, 'eth_chainId', []), 16) == 4663
assert info['forkConfig']['forkBlockNumber'] == 56118361
assert info['environment']['chainId'] == 4663 and int(info['environment']['gasLimit'], 16) == 32000000
assert info['hardFork'].lower() == 'prague'
assert int(rpc(rpc_url, 'eth_blockNumber', []), 16) == 56118361, 'Use the fresh funding fork.'
original_head = rpc('http://127.0.0.1:18665', 'eth_getBlockByNumber', ['latest', False])['hash']
rpc(rpc_url, 'anvil_impersonateAccount', [owner])
rpc(rpc_url, 'anvil_setBalance', [owner, '0xd3c21bcecceda1000000'])
deployments, broadcast = runtime / 'deployments', runtime / 'broadcast'
assert not deployments.exists() and not broadcast.exists()
deployments.mkdir()
broadcast.mkdir()
cache = runtime / 'cache_forge'
cache.mkdir()
seed_cache = root / 'cache_forge/solidity-files-cache.json'
seed_paths = json.loads(seed_cache.read_text())['paths']
assert seed_paths['sources'] == 'contracts' and seed_paths['tests'] == 'test/foundry/spec'
shutil.copy2(seed_cache, cache / 'solidity-files-cache.json')
env = os.environ.copy()
for key in ('FOUNDRY_TEST', 'FOUNDRY_SCRIPT', 'FOUNDRY_CACHE_PATH', 'ETH_RPC_URL',
            'FOUNDRY_ETH_RPC_URL', 'FOUNDRY_FORK_URL', 'DAPP_TEST_RPC_URL', 'ETH_GAS_PRICE',
            'ETH_PRIORITY_GAS_PRICE', 'ANVIL_FORK_URL'):
    env.pop(key, None)
env.update(FOUNDRY_PROFILE='default', FOUNDRY_CACHE_PATH=str(cache), PRIVATE_KEY='0', RPC_URL=rpc_url,
           CHAIN_ID='4663', NETWORK_PROFILE='anvil_robinhood_main', ANVIL_CHAIN_ID='4663', FORCE='0',
           SENDER=owner, DEPLOYER_ADDRESS=owner, DEV_ADDRESS=owner, OWNER=owner, UI_WALLET=owner,
           FOUNDRY_FORK_RPC_ALIAS='robinhood_mainnet_alchemy', ANVIL_FORK_BLOCK_NUMBER='56118361',
           ANVIL_HOST='127.0.0.1', ANVIL_PORT='18664', ANVIL_LOG_DIR=str(runtime / 'wrapper-runtime'),
           OUT_DIR_OVERRIDE=str(deployments), FOUNDRY_BROADCAST=str(broadcast),
           FRONTEND_ADDRESS_EXPORT_DIR=str(runtime / 'frontend/chain/4663'), FUND_ETH_BUFFER_BPS='2500')
command = ['bash', 'scripts/shell/anvil_robinhood_main.sh', 'simulate', '--dry-run', '--rpc-url', rpc_url]
record = {'status': 'RUNNING', 'started_at_utc': datetime.now(timezone.utc).isoformat(),
          'command': command, 'provenance': provenance, 'public_broadcast': False, 'local_broadcast': False,
          'rpc': rpc_url, 'fork_block': 56118361, 'completed_rehearsal_head_before': original_head,
          'isolated_warm_cache': str(cache.relative_to(root)),
          'fee_source_alias': env['FOUNDRY_FORK_RPC_ALIAS'], 'funding_buffer_bps': 2500,
          'scope': '19 maintained architecture stages, fresh corrected core, no customer instance or fund migration.'}
record_path.write_text(json.dumps(record, indent=2) + '\n')
start = time.monotonic()
with os.fdopen(os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as output:
    result = subprocess.run(command, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT)
current = capture(root)
record.update(exit_code=result.returncode, seconds=round(time.monotonic() - start, 3),
              finished_at_utc=datetime.now(timezone.utc).isoformat(),
              sources_unchanged=all(provenance[key] == current[key] for key in keys),
              log_sha256=hashlib.sha256(log_path.read_bytes()).hexdigest(),
              completed_rehearsal_head_after=rpc('http://127.0.0.1:18665', 'eth_getBlockByNumber', ['latest', False])['hash'])
passed = result.returncode == 0 and record['sources_unchanged'] and record['completed_rehearsal_head_after'] == original_head
if result.returncode == 0:
    funding_head = rpc(rpc_url, 'eth_getBlockByNumber', ['latest', False])
    assert int(funding_head['number'], 16) > 56118361, 'The local fee-sync block must have been mined.'
    assert int(funding_head['gasLimit'], 16) == 32000000, 'Locally mined funding-simulation blocks must enforce 32M gas.'
    record['local_fee_sync_block'] = {
        'number': int(funding_head['number'], 16), 'hash': funding_head['hash'],
        'gas_limit': int(funding_head['gasLimit'], 16),
    }
    path = broadcast / 'Script_SimulateArchitecture.s.sol/4663/dry-run/run-latest.json'
    data = json.loads(path.read_text())
    def number(value):
        return int(value, 16) if isinstance(value, str) and value.startswith('0x') else int(value)
    gas_limits = [number(t['transaction']['gas']) for t in data['transactions']]
    assert gas_limits and all(0 < g <= 32000000 for g in gas_limits), 'Every simulated transaction must fit the strict node.'
    log = log_path.read_text(errors='replace')
    quote = re.findall(r'Quote EIP-1559 baseFee=(\d+) wei .*?priority=(\d+) wei .*?eth_gasPrice=(\d+) wei', log)
    assert len(quote) == 1, 'Expected exactly one current upstream quote.'
    base, priority, gas_price = map(int, quote[0])
    price = gas_price or base + priority
    cost = sum(gas_limits) * price
    funding = cost * 12500 // 10000
    assert f'Simulated txs={len(gas_limits)} gas_limit_sum={sum(gas_limits)}' in log
    assert f'({cost} wei)' in log and f'({funding} wei)' in log
    record.update(dry_run_artifact=str(path.relative_to(root)),
                  dry_run_artifact_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                  transaction_count=len(gas_limits), total_transaction_gas_limits=sum(gas_limits),
                  max_transaction_gas_limit=max(gas_limits), upstream_base_fee_wei=base,
                  upstream_priority_fee_wei=priority, upstream_gas_price_wei=gas_price,
                  quoted_cost_wei=cost, buffered_funding_wei=funding,
                  warning='Point-in-time estimate, not a future fee guarantee. Refresh before any separately authorized public deployment.')
record['status'] = 'PASS_COMPLETE_ISOLATED_EIP1559_FUNDING_QUOTE' if passed else 'FAILED_REQUIRES_REVIEW'
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({key: record[key] for key in ('status', 'exit_code', 'seconds', 'sources_unchanged')}))
raise SystemExit(0 if passed else 1)
