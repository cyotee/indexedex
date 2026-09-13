"""Hand off from the existing build to the exact checked source corrections.

Only starts another Forge after the entire previous validation parent exits.
Any unsuccessful prerequisite stops this handoff for review.
"""
from pathlib import Path
from datetime import datetime, timezone
import json, os, shutil, subprocess, time

art = Path(__file__).resolve().parent
root = art.parent.parent
record_path = art / 'checked-followup-handoff.json'
assert not record_path.exists(), 'Preserve an existing handoff result for review.'
record = {'status': 'WAITING_FOR_EXISTING_VALIDATION', 'pid': os.getpid(),
          'previous_parent_pid': 49915, 'started_at_utc': datetime.now(timezone.utc).isoformat()}
record_path.write_text(json.dumps(record, indent=2) + '\n')
while True:
    try:
        os.kill(record['previous_parent_pid'], 0)
    except ProcessLookupError:
        break
    time.sleep(30)

try:
    assert (art / 'current-release-validation-sequence.json').exists(), 'Missing previous completion record.'
    build = json.loads((art / 'implementation-full-build.json').read_text())
    followups = json.loads((art / 'post-build-followups.json').read_text())
    assert build['exit_code'] == 0, 'The full build needs review.'
    assert followups['validation_passed'], 'The actual post-build regressions need review.'
    assert followups['provenance']['source_and_config_sha256'] == build['provenance']['source_and_config_sha256']
    archive = art / 'pre-provider-build-checkpoint'
    archive.mkdir(exist_ok=False)
    for name in ['implementation-full-build.json', 'implementation-full-build.log',
                 'post-build-followups.json', 'post-build-followups.log',
                 'current-release-validation-sequence.json', 'hermetic-pre-provider-deferral.json']:
        shutil.copy2(art / name, archive / name)
    print('Previous full build and actual post-build regressions passed; applying checked corrections.', flush=True)
    subprocess.run(['python3', str(art / 'apply-prepared-release-followups.py'), '--apply'], cwd=root, check=True)
    deferral_path = art / 'hermetic-pre-provider-deferral.json'
    deferral = json.loads(deferral_path.read_text())
    deferral.update(active=False, retirement='Prepared follow-ups applied; the next matching full hermetic run remains required.')
    deferral_path.write_text(json.dumps(deferral, indent=2) + '\n')
    queue_path = art / 'current-implementation-queue.json'
    queue = json.loads(queue_path.read_text())
    queue['updated_at_utc'] = datetime.now(timezone.utc).isoformat()
    queue['active_forge_session'] = None
    queue['active_validation_parent_pid'] = os.getpid()
    queue['in_validation'] = ['Applied provider/position follow-ups: sequential actual builds, proxy tests and pinned read-only forks.']
    queue['prepared_application_gate']['status'] = 'APPLIED_RUNTIME_VALIDATION_IN_PROGRESS'
    queue['prepared_application_gate']['application_record'] = 'prepared-release-followups-applied.json'
    queue['applied_followups'] = queue.pop('prepared_not_applied')
    queue['focused_followup_sequence']['status'] = 'RUNNING'
    queue_path.write_text(json.dumps(queue, indent=2) + '\n')
    record['status'] = 'APPLIED_FOCUSED_RUNTIME_CHECKS_RUNNING'
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    subprocess.run(['python3', str(art / 'run-provider-position-followups.py'),
                    '--label', 'funded-followups'], cwd=root, check=True)
    record['status'] = 'FOCUSED_CHECKS_PASSED_FINAL_RELEASE_GATES_REMAIN'
except Exception as error:
    record['status'] = 'STOPPED_FOR_ACTUAL_RESULT_REVIEW'
    record['error'] = str(error)
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    raise
record['finished_at_utc'] = datetime.now(timezone.utc).isoformat()
record_path.write_text(json.dumps(record, indent=2) + '\n')
