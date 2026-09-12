"""Preserve previous evidence, then validate the current complete repository.

Run only after the selected remediation/fork sequence has exited and its
in-scope failures have been resolved. This does not repeat completed provider
forks, relax the default test settings, or award release acceptance.
"""
from datetime import datetime, timezone
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import time

from build_provenance import capture

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
parser.add_argument('--readiness-regressions', action='store_true', help='Run the 27 new security/boundary cases after the complete build, before the unfiltered suite.')
parser.add_argument('--lifecycle-regressions', action='store_true', help='Run seven residual gas and high-precision NAV regressions before the complete suite.')
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
record_path = art / ('current-repository-' + args.label + '-sequence.json')
archive = art / ('before-current-repository-' + args.label)
assert not record_path.exists() and not archive.exists(), 'Choose a new evidence label.'

provenance = capture(root)
archive.mkdir()
archived = []
for name in (
    'implementation-full-build.json', 'implementation-full-build.log',
    'implementation-hermetic-start.json', 'implementation-hermetic-test.json',
    'implementation-hermetic-test.log', 'current-hermetic-baseline-attribution.json',
    'acceptance-current-run-anchors.json', 'maintained-script-build-scope.json',
    'final-provider-repository-post-position-sequence.json',
):
    source = art / name
    if source.exists():
        destination = archive / name
        shutil.copy2(source, destination)
        digest = hashlib.sha256()
        with destination.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
        archived.append({'path': name, 'sha256': digest.hexdigest()})
record = {
    'status': 'RUNNING', 'provenance': provenance, 'steps': [],
    'started_at_utc': datetime.now(timezone.utc).isoformat(),
    'archive': archive.name, 'archived_evidence': archived,
    'scope': 'Full default contracts/tests plus maintained scripts; unfiltered '
             'default hermetic tests; exact baseline and owner-scope attribution.',
    'limitations': 'D60 failures remain reported. No result automatically closes '
                   'acceptance or substitutes for the strict local rehearsal.',
}

def save():
    record_path.write_text(json.dumps(record, indent=2) + '\n')

save()
failed = False
steps = [
    ('full-build', ['run-full-build.py', '--include-scripts']),
    ('full-hermetic', ['run-current-hermetic.py']),
    ('baseline-attribution', ['compare-current-hermetic.py']),
]
if args.readiness_regressions:
    steps.insert(1, ('readiness-regressions', ['run-production-readiness-regressions.py']))
if args.lifecycle_regressions:
    steps.insert(1, ('lifecycle-regressions', ['run-lifecycle-production-regressions.py']))
for name, arguments in steps:
    print('Starting', name, flush=True)
    record['active_step'] = name
    save()
    started = time.monotonic()
    command = ['python3', str(art / arguments[0])] + arguments[1:]
    result = subprocess.run(command, cwd=root)
    current = capture(root)
    fingerprint_keys = (
        'source_and_config_sha256', 'crane_head',
        'crane_tracked_contract_and_config_diff_sha256', 'crane_source_and_config_sha256',
        'forge_version',
    )
    changed_fingerprints = [key for key in fingerprint_keys if current[key] != provenance[key]]
    unchanged = not changed_fingerprints
    record['steps'].append({
        'name': name, 'command': command, 'exit_code': result.returncode,
        'seconds': round(time.monotonic() - started, 3),
        'sources_unchanged': unchanged,
        'changed_fingerprints': changed_fingerprints,
    })
    failed = failed or bool(result.returncode) or not unchanged
    save()
    # A completed failing test run still needs exact scope attribution.
    if not unchanged or (result.returncode and name != 'full-hermetic'):
        break
record.pop('active_step', None)
record['status'] = ('COMPLETED_REQUIRES_FAILURE_REVIEW' if failed else
                    'REPOSITORY_CHECKS_PASSED_REHEARSAL_AND_ACCEPTANCE_REMAIN')
record['finished_at_utc'] = datetime.now(timezone.utc).isoformat()
save()
print(record['status'], flush=True)
raise SystemExit(1 if failed else 0)
