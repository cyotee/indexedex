"""Check or apply the reviewed provider/position drafts to the current main files.

Application is deliberately separate from preparation and requires the existing
release-validation parent to have exited. Unrelated files are never replaced.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, os, runpy
from build_provenance import capture

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
preparers = ['prepare-aerodrome-projection.py', 'prepare-rocket-projection.py',
             'prepare-erc4626-receipt-projection.py', 'prepare-position-storage-cleanup.py',
             'prepare-position-fixture-migrations.py']
changes = {}
for preparer in preparers:
    for path, contents in runpy.run_path(str(art / preparer))['changes'].items():
        assert path.startswith(('contracts/', 'test/')) and '..' not in Path(path).parts
        assert '/slipstream/' not in path and '/detf/protocols/dexes/balancer/' not in path
        assert path not in changes, ('Unresolved overlapping draft', path)
        changes[path] = contents
for path, (before, after) in changes.items():
    file = root / path
    assert (file.read_text() if file.exists() else '') == before, ('Source changed during preparation', path)
    assert before != after, path

# Match each diagnostic's exact draft inputs, rather than relying on the label.
diagnostics = {
    'aerodrome-draft-compile.json': 'aerodrome-draft-compiler-input.json',
    'aerodrome-draft-test-typecheck.json': 'aerodrome-draft-test-compiler-input.json',
    'rocket-draft-compile.json': 'rocket-draft-compiler-input.json',
    'rocket-draft-test-typecheck.json': 'rocket-draft-test-compiler-input.json',
    'erc4626-receipt-draft-compile.json': 'erc4626-receipt-draft-compiler-input.json',
    'erc4626-receipt-draft-test-typecheck.json': 'erc4626-receipt-draft-test-compiler-input.json',
    'position-cleanup-draft-production.json': 'position-cleanup-draft-production-compiler-input.json',
    'position-cleanup-draft-typecheck.json': 'position-cleanup-draft-typecheck-compiler-input.json',
    'position-cleanup-draft-test-codegen.json': 'position-cleanup-draft-test-codegen-compiler-input.json',
}
validated_changes = set()
for record_path, input_path in diagnostics.items():
    record = json.loads((art / record_path).read_text())
    compiler_input = json.loads((art / input_path).read_text())
    assert record['exit_code'] == 0 and not record['errors'], record_path
    assert record['compiler_input_sha256'] == hashlib.sha256((art / input_path).read_bytes()).hexdigest(), record_path
    for path, source in compiler_input['sources'].items():
        expected = changes[path][1] if path in changes else (root / path).read_text()
        assert source['content'] == expected, ('Diagnostic stale for a composed draft input', record_path, path)
        if path in changes: validated_changes.add(path)
assert validated_changes == set(changes), ('Prepared changes lack exact compiler-input coverage', sorted(set(changes) - validated_changes))

before_provenance = capture(root)
record = {'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
          'status': 'PREPARED_INPUTS_CHECKED_NOT_APPLIED', 'provenance_before': before_provenance,
          'diagnostics': list(diagnostics), 'changes': [
              {'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest() if before else None,
               'after_sha256': hashlib.sha256(after.encode()).hexdigest()}
              for path, (before, after) in changes.items()]}
if args.apply:
    # This is the existing compiler/test sequence, not an agent to interrupt.
    try:
        os.kill(49915, 0)
    except ProcessLookupError:
        pass
    else:
        raise SystemExit('Existing validation parent 49915 is still active; retain the canonical source freeze.')
    assert (art / 'current-release-validation-sequence.json').exists(), 'Preserve the previous sequence completion record first.'
    full_build = json.loads((art / 'implementation-full-build.json').read_text())
    assert full_build['exit_code'] == 0, 'Resolve the actual full-build failure before applying unrelated follow-ups.'
    assert full_build['provenance']['source_and_config_sha256'] == before_provenance['source_and_config_sha256'], 'Current sources differ from the completed build.'
    application_record = art / 'prepared-release-followups-applied.json'
    assert not application_record.exists(), 'Preserve prior application evidence; do not repeat the patch.'
    backups = art / 'provider-position-followups-before'
    backups.mkdir(exist_ok=True)
    for path, (before, after) in changes.items():
        backup = backups / (path.replace('/', '__') + '.txt')
        assert not backup.exists(), 'Preserve existing backup: ' + str(backup)
        backup.write_text(before)
    for path, (before, after) in changes.items():
        file = root / path
        assert (file.read_text() if file.exists() else '') == before, path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(after)
    record['status'] = 'APPLIED_RUNTIME_VALIDATION_PENDING'
    record['provenance_after'] = capture(root)
    application_record.write_text(json.dumps(record, indent=2) + '\n')
else:
    (art / 'prepared-release-followups-check.json').write_text(json.dumps(record, indent=2) + '\n')
print(record['status'], len(changes), 'sources')
