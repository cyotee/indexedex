"""Build then exercise complete affected suites using the unchanged default profile.

Narrow import roots reduce unnecessary fixture compilation during remediation.
The final unfiltered repository run remains a separate required gate.
"""
from pathlib import Path
from datetime import datetime, timezone
from collections import Counter
import argparse, hashlib, json, os, re, shutil, subprocess, time
from build_provenance import capture, hermetic_environment

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--group', choices=['stata', 'surfaces', 'balancer-se', 'v4-gold', 'v4-policy', 'v4-providers', 'v4-provider-precheck'], required=True)
parser.add_argument('--label', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
record_path = art / ('hermetic-remediation-' + args.group + '-' + args.label + '.json')
assert not record_path.exists(), 'Use a new label to preserve execution history.'
queue = json.loads((art / 'current-implementation-queue.json').read_text())
sequence = json.loads((art / queue['active_sequence_record']).read_text())
assert sequence.get('finished_at_utc') and sequence['status'] != 'RUNNING', 'Let the complete frozen sequence exit first.'
application = json.loads((art / queue['last_application_record']).read_text())
assert application['status'] == 'APPLIED_RUNTIME_VALIDATION_PENDING'

v4 = 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
if args.group == 'stata':
    source = 'contracts/protocols/lending/aave/v3.6'
    tests = sorted(p.relative_to(root).as_posix() for p in (root / 'test/foundry/spec/protocol/lending/aave/v3.6').rglob('*.t.sol'))
elif args.group == 'surfaces':
    source = 'contracts/hooks/uniswap/v4'
    tests = sorted(row['path'] for row in json.loads((art / 'current-surface-fixture-followups-prepared.json').read_text())['changes'])
elif args.group == 'balancer-se':
    source = 'contracts/protocols/dexes/balancer/v3/pools'
    tests = sorted(p.relative_to(root).as_posix() for p in (root / 'test/foundry/spec/protocols/dexes/balancer/v3/pools').rglob('*.t.sol'))
    tests.append('test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol')
elif args.group == 'v4-policy':
    source = 'contracts/hooks/uniswap/v4'
    failed_sources = set()
    active_source = None
    with (art / 'hermetic-remediation-v4-gold-first-runtime-test.log').open() as stream:
        for line in stream:
            if line.startswith('Failing tests:'):
                break
            match = re.match(r'Ran \d+ tests? for (.+\.sol):', line)
            if match:
                active_source = match[1]
            elif line.startswith('[FAIL'):
                assert active_source
                failed_sources.add(active_source)
    assert failed_sources
    tests = sorted(failed_sources | {
        'test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVaultDFPkg_Deploy.t.sol',
        'test/foundry/spec/vaults/detf/common/core/DETFFundedStakingMath.t.sol',
        'test/foundry/spec/vaults/detf/common/core/DETFEpochNaturalExpansionLib.t.sol',
        'test/foundry/spec/oracles/fee/VaultFeeOracle_BondTermsFallback.t.sol',
        v4 + '/pons/UniswapV4Detf_PonsV2Se_ProductLaw.t.sol',
    })
elif args.group == 'v4-gold':
    source = 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf'
    tests = sorted(p.relative_to(root).as_posix() for p in (root / v4).glob('*.t.sol'))
    # Exercise every gold decimal policy binding along with all gold native cases.
    tests += sorted(p.relative_to(root).as_posix() for p in (root / v4 / 'decimals').glob('*Policy_*.t.sol'))
elif args.group == 'v4-provider-precheck':
    source = 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf'
    providers = root / v4 / 'prod-se'
    # Every native reserve/provider binding gets its complete money-path suite.
    # Broader policy and decimal inheritance remains in the required unfiltered
    # final run, avoiding two compilations of all 477 provider source files.
    basic = [path for path in providers.glob('*.t.sol')
             if not path.name.endswith(('_Policy.t.sol', '_ProductLaw.t.sol'))]
    weighted_policy = list(providers.glob('UniswapV4Detf_Weighted_*_Policy.t.sol'))
    gold_decimals = list((root / v4 / 'decimals').glob('UniswapV4Detf_Weighted_ProductLaw_B_*.t.sol'))
    assert len(basic) == 25 and len(weighted_policy) == 7 and len(gold_decimals) == 8
    selected = basic + weighted_policy + gold_decimals
    selected += [providers / name for name in (
        'UniswapV4Detf_Cp_Univ3Se_Policy.t.sol',
        'UniswapV4Detf_Orbital_Univ4Se_Policy.t.sol',
        'UniswapV4Detf_Quad_MorphoMix_Policy.t.sol',
        'UniswapV4Detf_Cp_Univ3Se_ProductLaw.t.sol',
        'UniswapV4Detf_Weighted_MorphoBlueSe_ProductLaw.t.sol',
        'UniswapV4Detf_Weighted_MorphoMix_ProductLaw.t.sol',
        'UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw.t.sol',
        'UniswapV4Detf_Orbital_MorphoMix_ProductLaw.t.sol',
    )]
    selected += [providers / 'decimals' / name for name in (
        'UniswapV4Detf_Cp_Univ3Se_ProductLaw_H9.t.sol',
        'UniswapV4Detf_Weighted_Univ3Se_Lifecycle_B_P9_R18.t.sol',
        'UniswapV4Detf_Orbital_Univ4Se_Lifecycle_B_P9_R18.t.sol',
        'UniswapV4Detf_Quad_MorphoMix_Lifecycle_B_P9_R18.t.sol',
    )]
    tests = sorted(path.relative_to(root).as_posix() for path in selected)
    assert len(tests) == len(set(tests)) == 52
else:
    source = 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf'
    tests = sorted(p.relative_to(root).as_posix() for p in (root / v4 / 'prod-se').rglob('*.t.sol'))
    # The same funded lifecycle fixes also cover the eight gold decimal books
    # that failed in the full run; retain every method in those concrete suites.
    tests += sorted(p.relative_to(root).as_posix() for p in (root / v4 / 'decimals').glob('UniswapV4Detf_Weighted_ProductLaw_B_*.t.sol'))
assert tests and all((root / path).is_file() for path in tests)
assert all('slipstream' not in path.lower() and '/vaults/detf/protocols/dexes/balancer/' not in path for path in tests)
test_root = art / ('hermetic-remediation-' + args.group + '-imports')
test_root.mkdir(exist_ok=True)
import_source = '// SPDX-License-Identifier: BSL-1.1\npragma solidity ^0.8.0;\n' + ''.join(
    'import * as AffectedSuite' + str(index) + ' from "' + path + '";\n'
    for index, path in enumerate(tests)
)
if args.group in ('v4-gold', 'v4-policy'):
    # The negative dual-hook deployment test loads this registered package by
    # vm.getCode; it is not part of the ordinary four-reserve artifact seed.
    import_source += 'import * as DualHookPackage from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol";\n'
(test_root / 'AffectedSuites.t.sol').write_text(import_source)
cache = art / ('hermetic-remediation-' + args.group + '-cache')
cache.mkdir(exist_ok=True)
cache_seed = None
if not (cache / 'solidity-files-cache.json').exists():
    if args.group == 'v4-policy':
        seed = art / 'hermetic-remediation-v4-gold-cache'
    elif args.group == 'v4-provider-precheck':
        # This preceding build includes current Crane and universal DETF seeds.
        # Reuse its metadata; the compiler still checks every source/config hash.
        preceding = json.loads((art / 'hermetic-remediation-balancer-se-artifact-seed-root.json').read_text())
        assert preceding.get('build', {}).get('exit_code') == 0
        assert preceding.get('finished_at_utc'), 'Let the preceding run finish first.'
        seed = art / 'hermetic-remediation-balancer-se-cache'
    else:
        seed = root / 'cache_forge'
    shutil.copy2(seed / 'solidity-files-cache.json', cache / 'solidity-files-cache.json')
    cache_seed = str(seed.relative_to(root))
env, emptied = hermetic_environment(root)
# Keep the existing artifact-seed libraries in a direct compiler root. Merely
# retaining their old cache entries/out files does not make vm.getCode resolve
# Crane's token facets in this narrowed project (observed in Balancer SE setup).
script_root = ('contracts/utils/foundry' if args.group in
               ('balancer-se', 'v4-providers', 'v4-provider-precheck') else
               'contracts/vaults/detf/common/core')
env.update(FOUNDRY_TEST=str(test_root), FOUNDRY_SCRIPT=script_root, FOUNDRY_CACHE_PATH=str(cache))
record = {'status': 'RUNNING', 'group': args.group, 'provenance': capture(root),
          'started_at_utc': datetime.now(timezone.utc).isoformat(), 'test_sources': tests,
          'explicitly_empty_rpc_environment_keys': emptied, 'artifact_seed_root': script_root,
          'new_cache_seed': cache_seed,
          'scope': 'Complete selected existing suites, including inherited tests; no reduced fuzz runs, profiles, viaIR, or artifact clearing. Final unfiltered default validation remains required.'}
record_path.write_text(json.dumps(record, indent=2) + '\n')

def run_phase(phase, command):
    log = art / ('hermetic-remediation-' + args.group + '-' + args.label + '-' + phase + '.log')
    assert not log.exists()
    started = time.monotonic()
    with log.open('w') as output:
        result = subprocess.run(command, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT)
    lines = log.read_text(errors='replace').split('\nFailing tests:', 1)[0].splitlines()
    details = {'command': command, 'exit_code': result.returncode, 'seconds': round(time.monotonic() - started, 3),
               'log': log.name, 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
    record[phase] = details
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    print(phase, json.dumps({k: v for k, v in details.items() if k != 'command'}), flush=True)
    # Keep the full raw log; summarize identical setup errors once at the CLI.
    messages = Counter(line for line in lines if line.startswith(
        ('Compiling ', 'Solc ', 'No files changed', '[FAIL', 'Error')))
    for line, occurrences in messages.items():
        suffix = ' [reported ' + str(occurrences) + ' times]' if occurrences > 1 else ''
        bounded = line if len(line) <= 1600 else line[:1600] + ' [see complete log]'
        print(bounded + suffix, flush=True)
    return result.returncode, lines

code, _ = run_phase('build', ['forge', 'build', '--offline', '--contracts', source])
if code:
    record['status'] = 'BUILD_FAILED_REQUIRES_REVIEW'
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    raise SystemExit(code)
expected = {}
metadata = json.loads((cache / 'solidity-files-cache.json').read_text())
for path in tests:
    entry = metadata['files'].get(path)
    assert entry is not None, 'Selected source missing from current compile cache: ' + path
    for name, versions in entry['artifacts'].items():
        for profiles in versions.values():
            info = profiles.get('default')
            if info is None:
                continue
            artifact = json.loads((root / 'out' / info['path']).read_text())
            methods = [item for item in artifact['abi'] if item.get('type') == 'function' and item.get('name', '').startswith(('test', 'invariant'))]
            if methods and artifact['deployedBytecode']['object'].removeprefix('0x'):
                expected[path + ':' + name] = len(methods)
assert expected, 'Refuse empty test selection.'
record['expected_compiled_suites'] = expected
record_path.write_text(json.dumps(record, indent=2) + '\n')
names = sorted({suite.rsplit(':', 1)[1] for suite in expected})
code, lines = run_phase('test', ['forge', 'test', '--offline', '--contracts', source,
                               '--match-contract', '^(' + '|'.join(re.escape(name) for name in names) + ')$', '-vvv'])
actual = {}
for line in lines:
    match = re.match(r'Ran (\d+) tests? for (.+)', line)
    if match:
        actual[match[2]] = int(match[1])
passed = sum(line.startswith('[PASS]') for line in lines)
failed = sum(line.startswith('[FAIL') for line in lines)
missing = {suite: {'expected': count, 'reported': actual.get(suite)} for suite, count in expected.items() if actual.get(suite) != count}
unchanged = capture(root)['source_and_config_sha256'] == record['provenance']['source_and_config_sha256']
record['test'].update(passed=passed, failed=failed, actual_suites=actual, missing_or_incomplete_suites=missing,
                      validation_passed=code == 0 and passed == sum(expected.values()) and not missing and unchanged)
record.update(status='PASS_SELECTED_SUITES' if record['test']['validation_passed'] else 'RUNTIME_FAILED_REQUIRES_REVIEW',
              finished_at_utc=datetime.now(timezone.utc).isoformat(), sources_unchanged=unchanged)
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'status': record['status'], 'passed': passed, 'failed': failed,
                  'expected_methods': sum(expected.values()), 'incomplete_suites': len(missing)}), flush=True)
raise SystemExit(0 if record['test']['validation_passed'] else 1)
