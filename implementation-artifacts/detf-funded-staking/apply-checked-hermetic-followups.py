"""Apply the reviewed, hash-checked drafts after the complete frozen run exits.

Default behavior is read-only. Backups and application evidence stay visible in
the main repository; unrelated modifications and Forge artifacts are preserved.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, shutil
from build_provenance import capture

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
parser.add_argument('--label', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
queue = json.loads((art / 'current-implementation-queue.json').read_text())
records = []
changes = {}
for entry in queue['prepared_followups']:
    path = art / entry['record']
    record = json.loads(path.read_text())
    assert record['status'] == 'PREPARED_NOT_APPLIED', str(path)
    for row in record['changes']:
        relative = row['path']
        assert relative not in changes, 'Reconcile overlapping drafts explicitly: ' + relative
        assert '..' not in Path(relative).parts
        assert relative.startswith(('contracts/', 'test/')) and relative.endswith('.sol')
        assert '/slipstream/' not in relative.lower()
        assert '/vaults/detf/protocols/dexes/balancer/' not in relative
        before = (root / relative).read_bytes()
        after = (root / row['draft']).read_bytes()
        assert hashlib.sha256(before).hexdigest() == row['before_sha256'], relative
        assert hashlib.sha256(after).hexdigest() == row['after_sha256'], row['draft']
        assert before != after
        changes[relative] = (row, before, after)
    records.append((path, record))

print(json.dumps({'status': 'CHECKED', 'records': len(records), 'sources': len(changes),
                  'canonical_changes': False}), flush=True)
if not args.apply:
    raise SystemExit(0)

sequence_path = art / queue['active_sequence_record']
sequence = json.loads(sequence_path.read_text())
assert sequence.get('finished_at_utc') and sequence['status'] != 'RUNNING', 'Wait for the entire active validation parent.'
assert any(step['name'] == 'baseline-attribution' and step['exit_code'] == 0 for step in sequence['steps']), 'Preserve complete failure attribution before changing the snapshot.'
run = json.loads((art / 'implementation-hermetic-test.json').read_text())
assert run['executed_cases'] > 0
assert run['provenance']['source_and_config_sha256'] == sequence['provenance']['source_and_config_sha256']

archive = art / ('hermetic-followups-before-' + args.label)
assert not archive.exists(), 'Preserve prior backup; select a new label.'
archive.mkdir()
# Preserve every source and prepared record before the first canonical write.
for relative, (_, before, _) in changes.items():
    backup = archive / relative
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_bytes(before)
for path, _ in records:
    shutil.copy2(path, archive / path.name)
shutil.copy2(art / 'current-implementation-queue.json', archive / 'current-implementation-queue.json')
for name in ('implementation-full-build.json', 'implementation-full-build.log',
             'implementation-hermetic-start.json', 'implementation-hermetic-test.json',
             'implementation-hermetic-test.log', 'current-hermetic-baseline-attribution.json',
             'acceptance-current-run-anchors.json', sequence_path.name):
    source = art / name
    if source.is_file():
        shutil.copy2(source, archive / name)

now = datetime.now(timezone.utc).isoformat()
evidence_path = art / ('hermetic-followups-' + args.label + '-applied.json')
assert not evidence_path.exists()
evidence = {'status': 'APPLYING_CHECKED_DRAFTS', 'started_at_utc': now,
            'approval': 'Owner instruction to finish the existing implementation and test plan; mature-close deletion approval is separately preserved in v4-close-cleanup-owner-approval.json.',
            'previous_validated_snapshot': sequence['provenance'],
            'completed_full_test_record': 'implementation-hermetic-test.json',
            'completed_attribution_record': 'current-hermetic-baseline-attribution.json',
            'before_archive': str(archive.relative_to(root)),
            'records': [path.name for path, _ in records],
            'changes': [row for row, _, _ in changes.values()], 'applied_paths': [],
            'validation_passed': False}
evidence_path.write_text(json.dumps(evidence, indent=2) + '\n')
for relative, (row, before, after) in changes.items():
    path = root / relative
    assert path.read_bytes() == before, 'Concurrent edit detected; stop without overwriting: ' + relative
    path.write_bytes(after)
    assert hashlib.sha256(path.read_bytes()).hexdigest() == row['after_sha256']
    evidence['applied_paths'].append(relative)
    evidence_path.write_text(json.dumps(evidence, indent=2) + '\n')
for path, record in records:
    record.update(status='APPLIED_RUNTIME_VALIDATION_PENDING', applied_at_utc=now,
                  application_record=evidence_path.name)
    path.write_text(json.dumps(record, indent=2) + '\n')
evidence.update(status='APPLIED_RUNTIME_VALIDATION_PENDING', finished_at_utc=datetime.now(timezone.utc).isoformat())
evidence['applied_provenance'] = capture(root)
evidence_path.write_text(json.dumps(evidence, indent=2) + '\n')
queue.update(status='HERMETIC_REMEDIATION_APPLIED_VALIDATION_PENDING', updated_at_utc=now,
             solidity_frozen_until_session_exits=False, active_forge_session=None,
             active_validation_parent_pid=None, last_application_record=evidence_path.name,
             current_source_and_config_sha256=evidence['applied_provenance']['source_and_config_sha256'],
             in_validation=['Checked corrections applied; focused build/runtime validation is the next required gate.'])
for entry in queue['prepared_followups']:
    entry.update(status='APPLIED_RUNTIME_VALIDATION_PENDING', application_record=evidence_path.name)
(art / 'current-implementation-queue.json').write_text(json.dumps(queue, indent=2) + '\n')
print(json.dumps({'status': evidence['status'], 'applied_sources': len(changes),
                  'evidence': evidence_path.name, 'validation_passed': False}), flush=True)
