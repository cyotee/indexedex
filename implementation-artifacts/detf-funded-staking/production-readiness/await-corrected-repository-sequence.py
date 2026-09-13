"""Wait for the superseded compiler to finish, then validate the frozen candidate.

No compiler is interrupted and no second Forge is launched while it is active.
The previous coordinator is pinned to a different source fingerprint and must
fail its source guard before it can launch a successor.
"""
from datetime import datetime, timezone
from pathlib import Path
import json
import subprocess
import sys
import time

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture

candidate = json.loads((here / 'rehearsal-coverage-source.json').read_text())
previous = json.loads((here / 'corrected-sequence-coordinator.json').read_text())
assert previous['frozen_candidate']['source_and_config_sha256'] != candidate['source_and_config_sha256']
predecessor = art / 'current-repository-production-readiness-final-sequence.json'
successor = art / 'current-repository-production-readiness-core-final-sequence.json'
record_path = here / 'final-sequence-coordinator.json'
assert not record_path.exists() and not successor.exists(), 'Preserve completed/running evidence.'
record = {
    'status': 'WAITING_FOR_PREDECESSOR_EXIT',
    'started_at_utc': datetime.now(timezone.utc).isoformat(),
    'predecessor': predecessor.name, 'successor': successor.name,
    'frozen_candidate': candidate,
    'superseded_coordinator': 'corrected-sequence-coordinator.json',
}

def save():
    record_path.write_text(json.dumps(record, indent=2) + '\n')

save()
try:
    while True:
        prior = json.loads(predecessor.read_text())
        if prior.get('finished_at_utc'):
            break
        time.sleep(30)
    build = json.loads((art / 'implementation-full-build.json').read_text())
    assert build['exit_code'] == 0, 'Review predecessor compilation failure before proceeding.'
    assert prior['steps'][-1]['name'] == 'full-build'
    assert prior['steps'][-1]['sources_unchanged'] is False, 'Predecessor must record intentional supersession.'
    current = capture(root)
    keys = ('source_and_config_sha256', 'crane_head',
            'crane_tracked_contract_and_config_diff_sha256', 'crane_source_and_config_sha256', 'forge_version')
    assert all(current[key] == candidate[key] for key in keys), 'Frozen corrected candidate changed.'
    assert not successor.exists(), 'Do not race another validation sequence.'
    queue_path = art / 'current-implementation-queue.json'
    queue = json.loads(queue_path.read_text())
    queue.update(status='CORRECTED_FULL_BUILD_AND_TESTS_RUNNING', active_sequence_record=successor.name,
                 active_forge_session=None, updated_at_utc=datetime.now(timezone.utc).isoformat())
    queue_path.write_text(json.dumps(queue, indent=2) + '\n')
    record.update(status='CORRECTED_SEQUENCE_RUNNING', predecessor_result=prior['status'])
    save()
    command = [sys.executable, str(art / 'run-current-repository-checks.py'),
               '--label', 'production-readiness-core-final', '--readiness-regressions']
    print('Predecessor finished; starting corrected full build, 27 regressions and unfiltered suite.', flush=True)
    result = subprocess.run(command, cwd=root)
    record.update(status='COMPLETED' if result.returncode == 0 else 'FAILED_REQUIRES_REVIEW',
                  exit_code=result.returncode, finished_at_utc=datetime.now(timezone.utc).isoformat())
    save()
    raise SystemExit(result.returncode)
except Exception as error:
    record.update(status='BLOCKED_REQUIRES_REVIEW', error=str(error),
                  finished_at_utc=datetime.now(timezone.utc).isoformat())
    save()
    raise
