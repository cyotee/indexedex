"""Renew dependency-invalidated provider evidence on read-only pinned forks."""
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

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture

parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
destination = here / ('provider-renewal-' + args.label)
assert not destination.exists(), 'Choose a fresh evidence label.'
keys = ('source_and_config_sha256', 'crane_head',
        'crane_tracked_contract_and_config_diff_sha256', 'crane_source_and_config_sha256', 'forge_version')
provenance = capture(root)
build = json.loads((art / 'implementation-full-build.json').read_text())
queue = json.loads((art / 'current-implementation-queue.json').read_text())
sequence = json.loads((art / queue['active_sequence_record']).read_text())
assert build['exit_code'] == 0
assert sequence['status'] == 'REPOSITORY_CHECKS_PASSED_REHEARSAL_AND_ACCEPTANCE_REMAIN'
for key in keys:
    assert provenance[key] == build['provenance'][key] == sequence['provenance'][key], key

sources = [
    'test/foundry/fork/eth_main/staking/ethereum/LidoService_Fork.t.sol',
    'test/foundry/fork/eth_main/vaults/staking/etherfi/EtherFiWeETHStandardExchange_Fork.t.sol',
    'test/foundry/fork/eth_main/vaults/staking/rocket-pool/RocketPoolRETHStandardExchange_Fork.t.sol',
    'test/foundry/fork/eth_main/vaults/standard/erc4626/ERC4626StandardExchange_SfrxETH_Fork.t.sol',
]
cases = [
    ('lido', 'LidoStandardExchangeProjectionFork', None, 4, 24000000),
    ('etherfi', 'EtherFiStandardExchangeProjectionFork', 'test_etherFiLive', 5, 24000000),
    ('rocket', 'RocketPoolStandardExchangeProjectionFork', 'test_rocketLive', 7, 24000000),
    ('sfrxeth', 'ERC4626StandardExchange_SfrxETH_ProjectionFork', 'test_sfrxProjection', 4, 24000000),
    ('rocket-v4', 'RocketPoolStandardExchangeProjectionFork', 'test_rocketLive', 7, 25934585),
]
destination.mkdir()
tests = destination / 'tests'
tests.mkdir()
(tests / 'ProviderRenewal.t.sol').write_text(
    '// SPDX-License-Identifier: BSL-1.1\npragma solidity ^0.8.0;\n' +
    '\n'.join(f'import * as Provider{i} from "{source}";' for i, source in enumerate(sources)) + '\n')
cache = art / 'provider-renewal-validation-cache'
cache.mkdir(exist_ok=True)
if not (cache / 'solidity-files-cache.json').exists():
    shutil.copy2(root / 'cache_forge/solidity-files-cache.json', cache / 'solidity-files-cache.json')
env = os.environ.copy()
env.pop('FOUNDRY_SCRIPT', None)
env.update(FOUNDRY_PROFILE='fork', FOUNDRY_TEST=str(tests), FOUNDRY_CACHE_PATH=str(cache))
record = {
    'status': 'RUNNING', 'started_at_utc': datetime.now(timezone.utc).isoformat(),
    'provenance': provenance, 'broadcast': False, 'expected_cases': 27,
    'reason': 'PR-04 changes shared deployed core dependencies; renew all five previously matched provider forks.',
    'test_sources': {s: hashlib.sha256((root / s).read_bytes()).hexdigest() for s in sources},
    'production_source_root': 'contracts', 'steps': [],
}
record_path = destination / 'run.json'

def save():
    record_path.write_text(json.dumps(record, indent=2) + '\n')

save()
commands = [('build', ['forge', 'build', '--offline', '--contracts', 'contracts'], None, None)]
for label, contract, prefix, count, block in cases:
    command = ['forge', 'test', '--offline', '--contracts', 'contracts', '--match-contract', '^' + contract + '$',
               '--etherscan-api-key', '', '--threads', '1', '-vvv']
    if prefix:
        command += ['--match-test', '^' + prefix]
    commands.append((label, command, count, block))
failed = False
for label, command, count, block in commands:
    log = destination / (label + '.log')
    if block is not None:
        env['ROCKET_QUOTE_FORK_BLOCK'] = str(block)
    start = time.monotonic()
    with os.fdopen(os.open(log, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as output:
        result = subprocess.run(command, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT)
    lines = log.read_text(errors='replace').split('\nFailing tests:', 1)[0].splitlines()
    step = {'name': label, 'command': command, 'exit_code': result.returncode,
            'seconds': round(time.monotonic() - start, 3), 'log': str(log.relative_to(root)),
            'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
    if count is not None:
        step.update(pinned_ethereum_block=block, expected=count,
                    passed=sum(line.startswith('[PASS]') for line in lines),
                    failed=sum(line.startswith('[FAIL') for line in lines),
                    skipped=sum(line.startswith('[SKIP') for line in lines))
        step['validation_passed'] = result.returncode == 0 and step['passed'] == count and step['failed'] == step['skipped'] == 0
    else:
        step['validation_passed'] = result.returncode == 0
    current = capture(root)
    step['changed_fingerprints'] = [key for key in keys if current[key] != provenance[key]]
    step['validation_passed'] &= not step['changed_fingerprints']
    record['steps'].append(step)
    failed |= not step['validation_passed']
    save()
    print(json.dumps({key: value for key, value in step.items() if key != 'command'}), flush=True)
    selected = [line for line in lines if line.startswith(('Compiling ', 'Solc ', 'Compiler run ', '[PASS]', '[FAIL', 'Suite result:', 'Ran '))]
    print(re.sub(r'https?://[^\s\"\']+', '<rpc endpoint>', '\n'.join(selected)[-3000:]), flush=True)
    if label == 'build' and failed or step['changed_fingerprints']:
        break
record.update(status='FAILED_REQUIRES_REVIEW' if failed else 'PASS_ALL_27_PROVIDER_CASES',
              finished_at_utc=datetime.now(timezone.utc).isoformat())
save()
raise SystemExit(1 if failed else 0)
