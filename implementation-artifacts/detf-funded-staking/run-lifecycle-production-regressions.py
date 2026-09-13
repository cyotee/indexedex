"""Check the new security/boundary cases after the matching complete build."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import time
from build_provenance import capture, hermetic_environment

art = Path(__file__).resolve().parent
root = art.parent.parent
provenance = capture(root)
keys = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')
build = json.loads((art / 'implementation-full-build.json').read_text())
assert build['exit_code'] == 0
for key in keys:
    assert provenance[key] == build['provenance'][key], 'Build mismatch: ' + key
record_path = art / 'production-readiness/lifecycle-production-regressions.json'
log = record_path.with_suffix('.log')
assert not record_path.exists() and not log.exists(), 'Archive prior regression evidence before a new attempt.'
contracts = '^(UniswapV4Detf_Cp_Univ3Se_ResidualGas|UniswapV4StandardExchangeOrbitalBufferHook_LiquidityTest)$'
tests = '^test(Fuzz)?_(sphereNav|residualSweep)_'
command = ['forge', 'test', '--offline', '--match-contract', contracts, '--match-test', tests, '-vvv']
environment, empty_rpc_keys = hermetic_environment(root)
started = time.monotonic()
with log.open('x') as output:
    result = subprocess.run(command, cwd=root, env=environment, stdout=output, stderr=subprocess.STDOUT)
lines = log.read_text(errors='replace').split('\nFailing tests:', 1)[0].splitlines()
expected = {'UniswapV4Detf_Cp_Univ3Se_ResidualGas': 3, 'UniswapV4StandardExchangeOrbitalBufferHook_LiquidityTest': 4}
actual = {}
for line in lines:
    match = re.match(r'Ran (\d+) tests? for .*\.sol:(\S+)', line)
    if match:
        actual[match[2]] = int(match[1])
current = capture(root)
record = {'command': command, 'provenance': provenance, 'prior_full_build': 'implementation-full-build.json',
          'seconds': round(time.monotonic() - started, 3), 'exit_code': result.returncode,
          'passed': sum(line.startswith('[PASS]') for line in lines),
          'failed': sum(line.startswith('[FAIL') for line in lines),
          'skipped': sum(line.startswith('[SKIP') for line in lines),
          'expected_suites': expected, 'executed_suites': actual,
          'changed_fingerprints': [key for key in keys if current[key] != provenance[key]],
          'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest(),
          'explicitly_empty_rpc_environment_keys': empty_rpc_keys}
record['validation_passed'] = (result.returncode == 0 and record['passed'] == 7
    and record['failed'] == record['skipped'] == 0 and actual == expected and not record['changed_fingerprints'])
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({key: record[key] for key in ('exit_code', 'seconds', 'passed', 'failed', 'skipped', 'validation_passed')}), flush=True)
print('\n'.join(line for line in lines if line.startswith(('Compiling ', 'Solc ', '[PASS]', '[FAIL', 'Suite result:', 'Ran ')))[-6000:], flush=True)
raise SystemExit(0 if record['validation_passed'] else 1)
