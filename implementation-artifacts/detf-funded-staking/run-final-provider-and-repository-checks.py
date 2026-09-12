"""Run remaining pinned providers and complete repository checks sequentially."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, json, re, subprocess, time
from build_provenance import capture

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
record_path = art / ('final-provider-repository-' + args.label + '-sequence.json')
assert not record_path.exists(), 'Preserve previous execution evidence; choose another label.'
position = json.loads((art / 'position-cleanup-runtime-migrations-run.json').read_text())
assert position['test']['validation_passed'], 'Resolve actual position runtime failures first.'
cleanup = json.loads((art / 'v3-import-storage-followup-applied.json').read_text())
assert cleanup['status'] == 'APPLIED_RUNTIME_VALIDATION_PENDING'
provenance = capture(root)
assert cleanup['provenance']['source_and_config_sha256'] == provenance['source_and_config_sha256']
record = {'status': 'RUNNING', 'provenance': provenance, 'steps': [],
    'started_at_utc': datetime.now(timezone.utc).isoformat(),
    'scope': 'Pinned actual Rocket v3/v4 and sfrxETH; complete default build with maintained scripts; unfiltered hermetic suite; exact baseline attribution. One Forge at a time, no cache clearing or test settings changes.'}
record_path.write_text(json.dumps(record, indent=2) + '\n')
steps = [
    ('rocket-v3', ['run-etherfi-live-projection-fork.py', '--provider', 'rocket', '--label', args.label]),
    ('rocket-v4', ['run-etherfi-live-projection-fork.py', '--provider', 'rocket', '--rocket-block', '25934585', '--label', args.label]),
    ('sfrxeth', ['run-etherfi-live-projection-fork.py', '--provider', 'sfrxeth', '--label', args.label]),
    ('full-build', ['run-full-build.py', '--include-scripts']),
    ('full-hermetic', ['run-current-hermetic.py']),
    ('baseline-attribution', ['compare-current-hermetic.py']),
]
failed = False
for name, arguments in steps:
    print('Starting', name, flush=True)
    started = time.monotonic()
    command = ['python3', str(art / arguments[0])] + arguments[1:]
    result = subprocess.run(command, cwd=root)
    unchanged = capture(root)['source_and_config_sha256'] == provenance['source_and_config_sha256']
    record['steps'].append({'name': name, 'command': command, 'exit_code': result.returncode,
        'seconds': round(time.monotonic() - started, 3), 'sources_unchanged': unchanged})
    failed = failed or bool(result.returncode) or not unchanged
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    # Always attribute an actually completed failing hermetic run. Earlier build
    # or provider failures stop before dependent validation can be misreported.
    if not unchanged or (result.returncode and name != 'full-hermetic'):
        break
record['status'] = ('STOPPED_REQUIRED_FAILURE_REVIEW' if failed else
    'REPOSITORY_CHECKS_PASSED_LOCAL_REHEARSAL_AND_ACCEPTANCE_REMAIN')
record['finished_at_utc'] = datetime.now(timezone.utc).isoformat()
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(record['status'], flush=True)
raise SystemExit(1 if failed else 0)
