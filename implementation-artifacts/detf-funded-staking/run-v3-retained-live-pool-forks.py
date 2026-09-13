"""Build V3 artifacts and execute every retained Base/Robinhood fork smoke case."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, json, os, re, shutil, subprocess, time
from build_provenance import capture

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
record_path = art / ('v3-retained-live-pool-' + args.label + '-run.json')
assert not record_path.exists(), 'Preserve previous execution records.'
prepared = json.loads((art / 'v3-fork-fixture-followup-prepared.json').read_text())
import hashlib
for change in prepared['changes']:
    assert hashlib.sha256((root / change['path']).read_bytes()).hexdigest() == change['after_sha256'], 'Apply the checked current fixture first.'

queue = json.loads((art / 'current-implementation-queue.json').read_text())
sequence = json.loads((art / queue['active_sequence_record']).read_text())
assert sequence.get('finished_at_utc'), 'Let the entire current full-run sequence finish first.'
assert sequence['status'] == 'REPOSITORY_CHECKS_PASSED_REHEARSAL_AND_ACCEPTANCE_REMAIN'
provenance = capture(root)
full_build = json.loads((art / 'implementation-full-build.json').read_text())
assert full_build['exit_code'] == 0
fingerprints = ('source_and_config_sha256', 'crane_head',
    'crane_tracked_contract_and_config_diff_sha256', 'crane_source_and_config_sha256', 'forge_version')
for key in fingerprints:
    assert full_build['provenance'][key] == provenance[key], 'Full build mismatch: ' + key
    assert sequence['provenance'][key] == provenance[key], 'Full sequence mismatch: ' + key

# Use the normal production source graph for FactoryService artifact discovery.
# Only the retained fork tests are selected; source roots are not narrowed.
source = 'contracts'
v3_source = 'contracts/protocols/dexes/uniswap/v3'
test_dir = art / 'v3-retained-live-pool-tests'
test_dir.mkdir(exist_ok=True)
(test_dir / 'RetainedV3Forks.t.sol').write_text(
    '// SPDX-License-Identifier: BSL-1.1\npragma solidity ^0.8.0;\n' +
    '\n'.join('import * as RetainedFork' + str(index) + ' from "' + change['path'] + '";'
        for index, change in enumerate(prepared['changes'])) + '\n')
cache = art / 'v3-live-pool-validation-cache'
cache.mkdir(exist_ok=True)
cache_seed = None
provider_record = art / 'production-readiness/provider-renewal-core-final/run.json'
provider_cache = art / 'provider-renewal-validation-cache/solidity-files-cache.json'
if (provider_record.exists() and provider_cache.exists()
        and json.loads(provider_record.read_text()).get('status') == 'PASS_ALL_27_PROVIDER_CASES'):
    provider = json.loads(provider_record.read_text())
    assert provider['status'] == 'PASS_ALL_27_PROVIDER_CASES', 'Provider cache must come from a completed pass.'
    assert all(provider['provenance'][key] == provenance[key] for key in (
        'source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')), 'Provider cache candidate differs.'
    old_cache = cache / 'solidity-files-cache.json'
    if old_cache.exists():
        archived_cache = art / ('v3-retained-live-pool-' + args.label + '-prior-cache.json')
        assert not archived_cache.exists(), 'Preserve prior cache evidence.'
        shutil.copy2(old_cache, archived_cache)
    shutil.copy2(provider_cache, old_cache)
    cache_seed = {'path': str(provider_cache.relative_to(root)),
                  'sha256': hashlib.sha256(provider_cache.read_bytes()).hexdigest(),
                  'evidence': str(provider_record.relative_to(root)),
                  'reason': 'Reuse current successful fork-profile compilation; preserve previous metadata and the normal default cache.'}
elif not (cache / 'solidity-files-cache.json').exists():
    seed = root / 'cache_forge'
    shutil.copy2(seed / 'solidity-files-cache.json', cache / 'solidity-files-cache.json')
    cache_seed = str(seed.relative_to(root))
env = os.environ.copy()
env.pop('FOUNDRY_SCRIPT', None)
env.update(FOUNDRY_PROFILE='fork', FOUNDRY_TEST=str(test_dir),
    FOUNDRY_CACHE_PATH=str(cache),
    BASE_FORK_BLOCK='45446736', ROBINHOOD_FORK_BLOCK='56118361')
components = sorted(path for path in (root / v3_source).glob('Uniswap*StandardExchange*.sol')
    if path.stem.endswith(('Facet', 'DFPkg', 'Delegate')))
expected = {'UniswapV3StandardExchange_Fork_Test': 5, 'UniswapV3StandardExchange_Robinhood_Test': 3}
record = {'status': 'RUNNING', 'provenance': provenance,
    'started_at_utc': datetime.now(timezone.utc).isoformat(), 'broadcast': False,
    'production_source_root': source,
    'new_cache_seed': cache_seed,
    'scope': 'All seven retained declarations plus inherited Base sanity on actual pinned pools. Real manager/registry/facets, no SUT mocks or skipped tests.',
    'fork_blocks': {'base': 45446736, 'robinhood': 56118361}, 'expected_suites': expected}
commands = [('build', ['forge', 'build', '--offline', '--contracts', source]),
    ('test', ['forge', 'test', '--offline', '--contracts', source, '--match-contract',
        '^UniswapV3StandardExchange_(Fork|Robinhood)_Test$', '--etherscan-api-key', '', '--threads', '1', '-vvv'])]
for phase, command in commands:
    log = art / ('v3-retained-live-pool-' + args.label + '-' + phase + '.log')
    started = time.monotonic()
    fd = os.open(str(log), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as output:
        result = subprocess.run(command, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT)
    record[phase] = {'command': command, 'exit_code': result.returncode, 'seconds': round(time.monotonic() - started, 3)}
    lines = log.read_text(errors='replace').split('\nFailing tests:', 1)[0].splitlines()
    if phase == 'build' and result.returncode == 0:
        sizes = {}
        for path in components:
            data = json.loads((root / 'out' / path.name / (path.stem + '.json')).read_text())
            sizes[path.stem] = len(data['deployedBytecode']['object'].removeprefix('0x')) // 2
        record[phase]['runtime_bytes'] = sizes
        record[phase]['validation_passed'] = bool(sizes) and all(0 < size <= 24576 for size in sizes.values())
    if phase == 'test':
        actual = {}
        for line in lines:
            match = re.match(r'Ran (\d+) tests? for .*\.sol:(\S+)', line)
            if match:
                actual[match[2]] = int(match[1])
        record[phase].update(passed=sum(line.startswith('[PASS]') for line in lines),
            failed=sum(line.startswith('[FAIL') for line in lines), executed_suites=actual)
        record[phase]['validation_passed'] = result.returncode == 0 and actual == expected and record[phase]['passed'] == 8
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    print(phase, json.dumps({key: value for key, value in record[phase].items() if key not in ('command', 'runtime_bytes')}), flush=True)
    selected = [line for line in lines if line.startswith(('Compiling ', 'Solc ', 'Compiler run ', 'No files changed', '[PASS]', '[FAIL', 'Suite result:', 'Ran '))]
    print(re.sub(r'https?://[^\s\"\']+', '<rpc endpoint>', '\n'.join(selected)[-3500:]), flush=True)
    if result.returncode or not record[phase].get('validation_passed'):
        record['status'] = 'FAILED_REQUIRES_REVIEW'
        record_path.write_text(json.dumps(record, indent=2) + '\n')
        raise SystemExit(result.returncode or 1)
record['status'] = 'PASS_ALL_EIGHT_RETAINED_CASES'
record['finished_at_utc'] = datetime.now(timezone.utc).isoformat()
current = capture(root)
record['changed_fingerprints'] = [key for key in fingerprints if current[key] != provenance[key]]
record['sources_unchanged'] = not record['changed_fingerprints']
record_path.write_text(json.dumps(record, indent=2) + '\n')
assert record['sources_unchanged'], 'Source changed while validating.'
