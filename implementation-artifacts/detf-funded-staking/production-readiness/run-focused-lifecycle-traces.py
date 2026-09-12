"""Trace selected existing lifecycle cases against the owned strict loopback node."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
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
parser.add_argument('--cases', nargs='+', default=['test_cp_v3', 'test_orbital_v2', 'test_quad_morpho'])
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
assert args.cases and all(re.fullmatch(r'test_[A-Za-z0-9_]+', value) for value in args.cases)
runtime = art / 'current-robinhood-rehearsal-production-readiness-lifecycle-fixed'
output = here / args.label
output.mkdir(exist_ok=False)
env = os.environ.copy()
for key in ('FOUNDRY_SCRIPT', 'ETH_RPC_URL', 'FOUNDRY_ETH_RPC_URL', 'FOUNDRY_FORK_URL', 'DAPP_TEST_RPC_URL'):
    env.pop(key, None)
env.update(FOUNDRY_PROFILE='fork', FOUNDRY_TEST='test/foundry/fork',
           FOUNDRY_CACHE_PATH=str(runtime / 'cache_forge'),
           REHEARSAL_RPC_URL='http://127.0.0.1:18665',
           REHEARSAL_DEPLOYMENTS_DIR=str(runtime / 'deployments'))
pattern = '^(' + '|'.join(args.cases) + r')\(\)$'
command = ['forge', 'test', '--match-contract', '^RobinhoodReleaseRehearsalTest$',
           '--match-test', pattern, '--threads', '1', '--offline', '--etherscan-api-key', '', '-vvvv']
provenance = capture(root)
record = dict(status='RUNNING', provenance=provenance, command=command, expected_cases=len(args.cases),
              started_at_utc=datetime.now(timezone.utc).isoformat(), public_broadcast=False)
path = output / 'run.json'
path.write_text(json.dumps(record, indent=2) + '\n')
start = time.monotonic()
log = output / 'traces.log'
with log.open('x') as stream:
    result = subprocess.run(command, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT)
lines = log.read_text(errors='replace').split('\nFailing tests:', 1)[0].splitlines()
counts = {name: sum(line.startswith(prefix) for line in lines)
          for name, prefix in [('passed', '[PASS]'), ('failed', '[FAIL'), ('skipped', '[SKIP')]}
current = capture(root)
keys = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')
unchanged = all(current[key] == provenance[key] for key in keys)
passed = result.returncode == 0 and counts['passed'] == len(args.cases) and not counts['failed'] and not counts['skipped'] and unchanged
record.update(status='PASS_SELECTED_DIAGNOSTIC_CASES' if passed else 'DIAGNOSIS_REQUIRES_REVIEW',
              exit_code=result.returncode, seconds=round(time.monotonic() - start, 3),
              log_sha256=hashlib.sha256(log.read_bytes()).hexdigest(), sources_unchanged=unchanged,
              finished_at_utc=datetime.now(timezone.utc).isoformat(), **counts)
path.write_text(json.dumps(record, indent=2) + '\n')
print({key: record[key] for key in ('status', 'exit_code', 'passed', 'failed', 'skipped', 'seconds')})
raise SystemExit(0 if passed else 1)
