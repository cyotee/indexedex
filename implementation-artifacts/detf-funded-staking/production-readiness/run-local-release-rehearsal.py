"""Run the maintained release workflow only on the owned strict local fork.

This runner never accepts a public RPC or signing key. It preserves prior
records and isolates both deployment manifests and Phase 09 frontend exports.
"""
from datetime import datetime, timezone
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from Crypto.Hash import keccak
from eth_abi import encode

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture, readiness_provenance_matches, unchanged_fork_evidence_matches

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('stage', choices=('architecture', 'lifecycle'))
parser.add_argument('--resume-architecture', type=Path, help='Preserved failed architecture record; resume only reviewed stage 06/09')
args = parser.parse_args()
runtime = art / 'current-robinhood-rehearsal-production-readiness-lifecycle-fixed'
rpc_url = 'http://127.0.0.1:18665'
owner = '0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B'
record_path = runtime / (args.stage + '-run.json')
log_path = runtime / (args.stage + '.log')
assert not record_path.exists() and not log_path.exists(), 'Preserve previous attempts; review before resuming a stage.'
provenance = capture(root)
keys = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')
queue = json.loads((art / 'current-implementation-queue.json').read_text())
sequence = json.loads((art / queue['active_sequence_record']).read_text())
build = json.loads((art / 'implementation-full-build.json').read_text())
forks = json.loads((art / 'v3-retained-live-pool-production-readiness-run.json').read_text())
assert sequence['status'] == 'REPOSITORY_CHECKS_PASSED_REHEARSAL_AND_ACCEPTANCE_REMAIN'
assert build['exit_code'] == 0 and forks['status'] == 'PASS_ALL_EIGHT_RETAINED_CASES'
assert forks['sources_unchanged']
assert all(provenance[key] == build['provenance'][key] for key in keys)
assert readiness_provenance_matches(root, provenance, sequence['provenance'])
assert (readiness_provenance_matches(root, provenance, forks['provenance'])
        or unchanged_fork_evidence_matches(root, provenance, art / 'v3-retained-live-pool-production-readiness-run.json'))
artifacts = json.loads((here / 'release-artifact-manifest.json').read_text())
assert artifacts['all_artifacts_current_linked_and_eip170_compliant']
assert all(provenance[key] == artifacts['provenance'][key] for key in keys)
node = json.loads((runtime / 'node.json').read_text())
assert node['rpc'] == rpc_url and node['fork_block'] == 56118361
assert node['code_size_limit'] == 24576 and node['block_gas_limit'] == 32000000

def rpc(method, params):
    assert method in ('anvil_nodeInfo', 'anvil_impersonateAccount', 'anvil_setBalance',
                      'eth_chainId', 'eth_getBlockByNumber', 'eth_getCode')
    request = urllib.request.Request(rpc_url, data=json.dumps(
        {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode(),
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=60) as response:
        result = json.load(response)
    assert 'error' not in result, 'Local RPC failed: ' + method
    return result['result']

info = rpc('anvil_nodeInfo', [])
assert int(rpc('eth_chainId', []), 16) == 4663
assert info['environment']['chainId'] == 4663
assert int(info['environment']['gasLimit'], 16) == 32000000
assert info['forkConfig']['forkBlockNumber'] == 56118361
assert info['hardFork'].lower() == 'prague'
node_evidence = {'chain_id': 4663, 'configured_gas_limit': 32000000, 'code_size_limit': node['code_size_limit'],
                 'fork_block': info['forkConfig']['forkBlockNumber'], 'hardfork': info['hardFork']}

def address_exports():
    directory = root / 'frontend/packages/protocol/src/addresses'
    return {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(directory.rglob('*')) if path.is_file()}

frontend_before = address_exports()
deployments = runtime / 'deployments'
broadcast = runtime / 'broadcast'
core_prediction = None
resumed_architecture = None
if args.resume_architecture:
    assert args.stage == 'architecture'
    resumed_architecture = json.loads(args.resume_architecture.read_text())
    assert resumed_architecture['status'] == 'FAILED_REQUIRES_REVIEW' and resumed_architecture['exit_code'] != 0
    assert readiness_provenance_matches(root, provenance, resumed_architecture['provenance'])
    assert deployments.is_dir() and broadcast.is_dir()
    assert not (deployments / 'phase06_stage09_balancer_stable_hook_pkg.json').exists(), 'Failed stage must have no successful manifest.'
if args.stage == 'architecture':
    if resumed_architecture is None:
        assert not deployments.exists() and not broadcast.exists(), 'Fresh corrected core requires fresh manifests.'
    # Read only this public configuration field; do not record resolved RPC secrets.
    config = json.loads(subprocess.check_output(['forge', 'config', '--json'], cwd=root))
    create2_deployer = config['create2_deployer']
    code = json.loads((root / 'out/Create3Factory.sol/Create3Factory.json').read_text())['bytecode']['object']
    constructor_args = encode(['address'], [owner])
    creation = bytes.fromhex(code.removeprefix('0x')) + constructor_args
    salt = keccak.new(digest_bits=256, data=encode(['address', 'string', 'string'], [owner, 'RhMain', 'Create3Factory'])).digest()
    init_hash = keccak.new(digest_bits=256, data=creation).digest()
    predicted = '0x' + keccak.new(digest_bits=256,
        data=b'\xff' + bytes.fromhex(create2_deployer.removeprefix('0x')) + salt + init_hash).digest()[-20:].hex()
    occupied = rpc('eth_getCode', [predicted, 'latest']) != '0x'
    if resumed_architecture:
        assert occupied and predicted == resumed_architecture['core_prediction']['address']
        assert json.loads((deployments / 'phase02_stage01_create3_factory.json').read_text())['create3Factory'].lower() == predicted.lower()
    else:
        assert not occupied, 'Corrected core prediction is occupied; review before reusing it.'
    core_prediction = {'address': predicted, 'create2_deployer': create2_deployer,
                       'salt': '0x' + salt.hex(), 'init_code_keccak256': '0x' + init_hash.hex(),
                       'constructor_args': '0x' + constructor_args.hex(), 'unoccupied_before_deployment': not occupied}
    if resumed_architecture:
        assert core_prediction['init_code_keccak256'] == resumed_architecture['core_prediction']['init_code_keccak256']
        core_prediction = resumed_architecture['core_prediction']
    if resumed_architecture is None:
        deployments.mkdir()
        broadcast.mkdir()
    seed = root / 'deployments/anvil_robinhood_main'
    pins = []
    for name in ('phase01_stage01_permit2.json', 'phase01_stage02_weth.json', 'phase01_stage03_uniswap_v4.json'):
        data = json.loads((seed / name).read_text())
        assert data['chainId'] == 4663
        for role, address in data.items():
            if isinstance(address, str) and re.fullmatch(r'0x[0-9a-fA-F]{40}', address):
                code = rpc('eth_getCode', [address, 'latest'])
                assert code != '0x', 'Missing actual Phase 01 dependency: ' + role
                pins.append({'role': role, 'address': address, 'runtime_sha256': hashlib.sha256(bytes.fromhex(code[2:])).hexdigest()})
        if resumed_architecture:
            assert (deployments / name).read_bytes() == (seed / name).read_bytes()
        else:
            shutil.copy2(seed / name, deployments / name)
    rpc('anvil_impersonateAccount', [owner])
    rpc('anvil_setBalance', [owner, '0xd3c21bcecceda1000000'])
else:
    architecture = json.loads((runtime / 'architecture-run.json').read_text())
    assert architecture['exit_code'] == 0 and architecture['sources_unchanged']
    assert readiness_provenance_matches(root, provenance, architecture['provenance'])
    pins = []

cache = runtime / 'cache_forge'
cache.mkdir(exist_ok=True)
cache_seed = None
if args.stage == 'lifecycle':
    seed_cache = art / 'v3-live-pool-validation-cache/solidity-files-cache.json'
    assert json.loads(seed_cache.read_text())['paths']['sources'] == 'contracts'
    old_cache = cache / 'solidity-files-cache.json'
    use_warm_fork_cache = old_cache.exists() and json.loads(old_cache.read_text())['paths']['tests'].endswith('test/foundry/fork')
    if old_cache.exists() and not use_warm_fork_cache:
        archived_cache = runtime / 'before-lifecycle-default-cache.json'
        if archived_cache.exists():
            # A failed lifecycle compilation can resume with its existing warm
            # fork cache. Preserve both the architecture checkpoint and cache.
            assert (runtime / 'before-rehearsal-import-fix/lifecycle-run.json').is_file()
        else:
            shutil.copy2(old_cache, archived_cache)
    if not use_warm_fork_cache:
        shutil.copy2(seed_cache, old_cache)
    selected_cache = old_cache if use_warm_fork_cache else seed_cache
    cache_seed = {'path': str(selected_cache.relative_to(root)),
                  'sha256': hashlib.sha256(selected_cache.read_bytes()).hexdigest(),
                  'evidence': 'v3-retained-live-pool-production-readiness-run.json',
                  'reason': 'Reuse the current warm fork cache when available; otherwise seed the completed V3 fork-profile cache. Forge still validates every source and configuration before reuse.'}
elif not (cache / 'solidity-files-cache.json').exists():
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
           ANVIL_HOST='127.0.0.1', ANVIL_PORT='18665', ANVIL_LOG_DIR=str(runtime / 'wrapper-runtime'),
           OUT_DIR_OVERRIDE=str(deployments), FOUNDRY_BROADCAST=str(broadcast),
           REHEARSAL_DIR=str(runtime), REHEARSAL_CORE_DIR=str(deployments),
           FRONTEND_ADDRESS_EXPORT_DIR=str(runtime / 'frontend/chain/4663'),
           GAS_ESTIMATE_MULTIPLIER='120', REHEARSAL_TEST_THREADS='1')
command = ['bash', 'scripts/shell/anvil_robinhood_main.sh']
command += (['all', '--from-phase', '06', '--from-stage', '09'] if resumed_architecture
            else ['all', '--from-phase', '02']) if args.stage == 'architecture' else ['rehearse-lifecycle']
command += ['--rpc-url', rpc_url]
record = {'status': 'RUNNING', 'started_at_utc': datetime.now(timezone.utc).isoformat(),
          'provenance': provenance, 'command': command, 'scope': __doc__, 'node': node_evidence,
          'external_pins': pins, 'frontend_before': frontend_before,
          'core_prediction': core_prediction,
          'isolated_frontend_export': env['FRONTEND_ADDRESS_EXPORT_DIR'],
          'isolated_warm_cache': str(cache.relative_to(root)),
          'matching_fork_cache_seed': cache_seed,
          'local_broadcast': args.stage == 'architecture', 'public_broadcast': False,
          'maintained_catalog': 'scripts/shell/lib/rh_4663_stages.sh',
          'note': 'The script harness allowance is not the deployed runtime limit. Node EIP-170 and 32M blocks remain enforced. Lifecycle calls retain their explicit 30M gas bounds. Local legacy 2-gwei broadcast costs are not a public funding quote.'}
if resumed_architecture:
    record['resumed_architecture'] = {'path': str(args.resume_architecture), 'sha256': hashlib.sha256(args.resume_architecture.read_bytes()).hexdigest(), 'reason': 'Only the failed launch library changed; preserve successful stages, receipts, core, node and manifests. Resume maintained catalog at 06/09, then isolated export.'}
    record['reused_execution_source_provenance'] = str((here / 'pr08-script-only-evidence-reuse.json').relative_to(root))
record_path.write_text(json.dumps(record, indent=2) + '\n')
start = time.monotonic()
with os.fdopen(os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as log:
    result = subprocess.run(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
current = capture(root)
record.update(exit_code=result.returncode, seconds=round(time.monotonic() - start, 3),
              finished_at_utc=datetime.now(timezone.utc).isoformat(),
              sources_unchanged=all(current[key] == provenance[key] for key in keys),
              frontend_after=address_exports(), log_sha256=hashlib.sha256(log_path.read_bytes()).hexdigest())
record['frontend_preserved'] = record['frontend_before'] == record['frontend_after']
passed = result.returncode == 0 and record['sources_unchanged'] and record['frontend_preserved']
if args.stage == 'architecture' and result.returncode == 0:
    deployed = json.loads((deployments / 'phase02_stage01_create3_factory.json').read_text())['create3Factory']
    record['core_prediction_matches'] = deployed.lower() == core_prediction['address'].lower()
    passed &= record['core_prediction_matches']
if args.stage == 'lifecycle':
    lines = log_path.read_text(errors='replace').split('\nFailing tests:', 1)[0].splitlines()
    record.update(passed=sum(line.startswith('[PASS]') for line in lines),
                  failed=sum(line.startswith('[FAIL') for line in lines),
                  skipped=sum(line.startswith('[SKIP') for line in lines), expected_cases=39)
    passed &= record['passed'] == 39 and record['failed'] == record['skipped'] == 0
record['status'] = ('PASS_REQUIRES_RECEIPT_AND_CODE_RECONCILIATION' if args.stage == 'architecture'
                    else 'PASS_ALL_39_STRICT_LIFECYCLE_CASES') if passed else 'FAILED_REQUIRES_REVIEW'
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({key: record[key] for key in ('status', 'exit_code', 'seconds', 'sources_unchanged', 'frontend_preserved')}), flush=True)
raise SystemExit(0 if passed else 1)
