"""Run the remaining machine checks sequentially after the matching P3 pass.

Only the existing fixed-loopback runners may broadcast. Provider forks are
read-only. This coordinator never closes acceptance or authorizes a public
deployment, and stops at the first failed check for review.
"""
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture, readiness_provenance_matches

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--label', default='core-final')
parser.add_argument('--resume-record', type=Path)
parser.add_argument('--baseline-evidence', type=Path)
parser.add_argument('--resume-architecture', type=Path)
parser.add_argument('--lifecycle-fixes', action='store_true', help='Validate the renewed candidate on fresh local fork 18665; reuse only matching provider/V3 evidence.')
args = parser.parse_args()
assert args.label and all(c.isalnum() or c in '-_' for c in args.label)
directory = here / ('post-build-release-' + args.label)
assert not directory.exists(), 'Preserve the prior run; review before creating a successor.'
directory.mkdir()
record_path = directory / 'run.json'
predecessor = art / (json.loads((art / 'current-implementation-queue.json').read_text())['active_sequence_record'] if args.lifecycle_fixes else 'current-repository-production-readiness-core-final-sequence.json')
expected = json.loads((here / 'rehearsal-coverage-source.json').read_text())
keys = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')
provenance = capture(root)
assert all(provenance[key] == expected[key] for key in keys), 'Corrected candidate changed.'
record = {
    'status': 'WAITING_FOR_CURRENT_P3', 'provenance': provenance,
    'started_at_utc': datetime.now(timezone.utc).isoformat(),
    'predecessor': str(predecessor.relative_to(root)), 'steps': [],
    'public_broadcast': False, 'fund_migration': False,
    'local_nodes': ['http://127.0.0.1:18665', 'http://127.0.0.1:18664'],
    'scope': __doc__,
    'script_only_evidence_reuse': 'production-readiness/pr08-script-only-evidence-reuse.json' if args.resume_architecture else None,
}
reused_steps = {}
if args.resume_record:
    resume_bytes = args.resume_record.read_bytes()
    resume = json.loads(resume_bytes)
    assert resume['status'] == 'STOPPED_REQUIRES_REVIEW', 'Only a completed reviewed stop can be resumed.'
    assert readiness_provenance_matches(root, provenance, resume['provenance']), 'Resume candidate differs.'
    script_only_change = resume['provenance']['source_and_config_sha256'] != provenance['source_and_config_sha256']
    for step in resume.get('reused_steps', []) + resume['steps']:
        if step['exit_code'] or step['changed_fingerprints']:
            break
        assert hashlib.sha256((root / step['log']).read_bytes()).hexdigest() == step['log_sha256']
        if not script_only_change or step['name'] in ('provider-forks', 'v3-forks'):
            reused_steps[step['name']] = step
    record['resumed_from'] = {'path': str(args.resume_record), 'sha256': hashlib.sha256(resume_bytes).hexdigest()}
    record['reused_steps'] = []

def save():
    record_path.write_text(json.dumps(record, indent=2) + '\n')

def fingerprint_changes():
    current = capture(root)
    return [key for key in keys if current[key] != provenance[key]]

save()
print(record['status'], flush=True)
while True:
    previous = json.loads(predecessor.read_text())
    if previous['status'] != 'RUNNING':
        break
    time.sleep(55)
if previous['status'] != 'REPOSITORY_CHECKS_PASSED_REHEARSAL_AND_ACCEPTANCE_REMAIN':
    record.update(status='STOPPED_P3_REQUIRES_REVIEW', predecessor_status=previous['status'])
    save()
    raise SystemExit(1)
assert readiness_provenance_matches(root, provenance, previous['provenance'])
assert not fingerprint_changes(), 'Candidate changed while waiting.'

archive = directory / 'prior-reconciliation'
archive.mkdir()
for relative in (
    'current-funded-selector-manifest.json', 'current-se-package-inventory.json',
    'current-source-manifest.json', 'compiled-test-inventory-current.json',
    'current-test-consolidation.json', 'production-readiness/frontend-abi-reconciliation.json',
    'production-readiness/release-artifact-manifest.json', 'production-readiness/release-source-manifest.json',
    'production-readiness/renderer-evidence-reuse.json',
):
    path = art / relative
    if path.is_file():
        shutil.copy2(path, archive / path.name)

def py(relative, *arguments):
    return ['python3', str(art / relative), *arguments]

commands = [
    ('selectors', py('reconcile-funded-selector-manifest.py', '--require-current')),
    ('native-se-proxies', py('reconcile-se-proxy-evidence.py', '--require-current')),
    ('source-inventory', py('reconcile-current-source-manifest.py')),
    ('compiled-test-inventory', py('inventory-compiled-tests.py')),
    ('test-consolidation', py('reconcile-test-consolidation.py', *(['--baseline-evidence', str(args.baseline_evidence)] if args.baseline_evidence else []))),
    ('release-artifacts', py('production-readiness/record-release-artifacts.py')),
    ('frontend-abis', ['node', str(here / 'reconcile-frontend-abis.mjs')]),
    ('renderer', py('production-readiness/reconcile-renderer-evidence.py')),
    ('provider-forks', py('production-readiness/run-provider-renewal.py', '--label', 'core-final')),
    ('v3-forks', py('run-v3-retained-live-pool-forks.py', '--label', 'production-readiness')),
    ('local-architecture', py('production-readiness/run-local-release-rehearsal.py', 'architecture',
        *(['--resume-architecture', str(args.resume_architecture)] if args.resume_architecture else []))),
    ('local-core-and-packages', py('production-readiness/inspect-rehearsal-core.py',
        '--rpc', 'http://127.0.0.1:18665',
        '--deployments', str(art / 'current-robinhood-rehearsal-production-readiness-lifecycle-fixed/deployments'),
        '--output', 'corrected-local-core-and-packages.json', '--packages', '--require-current')),
    ('local-receipts', py('production-readiness/record-local-release-receipts.py')),
    ('local-lifecycle', py('production-readiness/run-local-release-rehearsal.py', 'lifecycle')),
    ('local-funding-quote', py('production-readiness/run-local-funding-quote.py')),
]
if args.lifecycle_fixes:
    commands = [(name, command) for name, command in commands if name not in ('provider-forks', 'v3-forks')]
    commands.insert(0, ('retained-fork-reuse', py('production-readiness/check-retained-fork-reuse.py')))
    commands.insert(4, ('release-source-inventory', py('production-readiness/record-candidate-sources.py')))
    if 'local-core-and-packages' not in reused_steps:
        prior_core = here / 'corrected-local-core-and-packages.json'
        if prior_core.exists():
            previous_core = json.loads(prior_core.read_text())
            assert previous_core['rpc_alias_or_loopback'] != 'http://127.0.0.1:18665', 'Review the previous current-node inspection before replacing it.'
            shutil.move(prior_core, archive / prior_core.name)
for name, command in commands:
    assert not fingerprint_changes(), 'Candidate changed before ' + name
    if name in reused_steps:
        assert reused_steps[name]['command'] == command, 'Changed command cannot reuse prior evidence: ' + name
        record['reused_steps'].append(reused_steps[name])
        save()
        print('Reusing matching ' + name, flush=True)
        continue
    record.update(status='RUNNING', active_step=name)
    save()
    print('Starting ' + name, flush=True)
    started = time.monotonic()
    log = directory / (name + '.log')
    with os.fdopen(os.open(log, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as stream:
        result = subprocess.run(command, cwd=root, stdout=stream, stderr=subprocess.STDOUT)
    changed = fingerprint_changes()
    step = {'name': name, 'command': command, 'exit_code': result.returncode,
            'seconds': round(time.monotonic() - started, 3), 'changed_fingerprints': changed,
            'log': str(log.relative_to(root)), 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
    record['steps'].append(step)
    save()
    print(json.dumps({key: step[key] for key in ('name', 'exit_code', 'seconds', 'changed_fingerprints')}), flush=True)
    if result.returncode or changed:
        record.update(status='STOPPED_REQUIRES_REVIEW', finished_at_utc=datetime.now(timezone.utc).isoformat())
        save()
        raise SystemExit(1)
record.pop('active_step', None)
record.update(status='REQUIRED_RUNS_COMPLETE_ACCEPTANCE_REVIEW_PENDING',
              finished_at_utc=datetime.now(timezone.utc).isoformat())
save()
print(record['status'], flush=True)
