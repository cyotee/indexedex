"""Measure the unchanged baseline with the five misplaced network tests excluded."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from build_provenance import capture

artifacts = Path(__file__).resolve().parent
baseline = Path('/private/tmp/indexedex-detf-funded-staking-20260906')
destination = baseline / 'implementation-artifacts/detf-funded-staking'
inventory = json.loads((artifacts / 'misplaced-fork-test-inventory.json').read_text())['rows']
excluded = []
for row in inventory:
    source = baseline / row['source']
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    assert digest == row['sha256']
    excluded.append({'source': row['source'], 'sha256': digest})
command = ['forge', 'test', '--offline', '--no-match-path', '{' + ','.join(row['source'] for row in excluded) + '}']
environment = os.environ.copy()
environment['FOUNDRY_PROFILE'] = 'default'
for key in ('FOUNDRY_TEST', 'FOUNDRY_SCRIPT', 'DETF_MATCH_TEST', 'DETF_MATCH_CONTRACT'):
    environment.pop(key, None)
record = {
    'command': command,
    'excluded_network_sources': excluded,
    'provenance': capture(baseline),
    'scope': 'Diagnostic full hermetic baseline; source unchanged. Not an unfiltered baseline result.',
    'previous_attempt': 'First hermetic attempt has no completion record and its unified session no longer exists after interruption. Its log is preserved without asserting an exit status.',
}
started = time.monotonic()
with (destination / 'baseline-hermetic-retry-test.log').open('w') as output:
    process = subprocess.Popen(command, cwd=baseline, env=environment, stdout=output, stderr=subprocess.STDOUT)
    record['pid'] = process.pid
    (destination / 'baseline-hermetic-retry-start.json').write_text(json.dumps(record, indent=2) + '\n')
    result = process.wait()
record.update(exit_code=result, seconds=round(time.monotonic() - started, 3))
(destination / 'baseline-hermetic-retry-test.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'exit_code': result, 'seconds': record['seconds']}), flush=True)
lines = (destination / 'baseline-hermetic-retry-test.log').read_text().splitlines()
print('\n'.join(line for line in lines if line.startswith('Ran ') and 'suite' in line)[-2000:], flush=True)
raise SystemExit(result)
