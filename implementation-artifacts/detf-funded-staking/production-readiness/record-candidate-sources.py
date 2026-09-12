"""Record the exact dirty Solidity dependency snapshot and supported callers.

File hashes identify a candidate; they are not a claim that every inventoried
file was compiled or executed. Secret dotenv and generated caches are excluded.
"""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import subprocess
import sys

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture

provenance = capture(root)
expected = json.loads((here / 'rehearsal-coverage-source.json').read_text())
for key in ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
            'crane_source_and_config_sha256', 'forge_version'):
    assert provenance[key] == expected[key], 'Candidate changed: ' + key

def tracked_or_new(directory):
    return subprocess.check_output(['git', 'ls-files', '-co', '--exclude-standard', '--', directory],
                                   cwd=root, text=True).splitlines()

paths = set()
for directory in ('contracts', 'test', 'scripts'):
    paths.update(p for p in tracked_or_new(directory) if p.endswith('.sol'))
paths.update(('foundry.toml', 'remappings.txt'))
crane = root / 'lib/crane'
for path in crane.rglob('*.sol'):
    if not any(part in ('out', 'cache_forge', 'node_modules', '.git') for part in path.relative_to(crane).parts):
        paths.add(str(path.relative_to(root)))
paths.update(str(p.relative_to(root)) for p in (crane / 'foundry.toml', crane / 'remappings.txt') if p.is_file())
callers = set(tracked_or_new('frontend'))
callers.update(tracked_or_new('scripts/shell'))
callers.update(p for p in tracked_or_new('scripts/foundry/anvil_robinhood_main') if p.endswith('.sh'))
callers = {p for p in callers if (not Path(p).name.startswith('.env') or Path(p).name == '.env.example')
           and Path(p).name not in ('.DS_Store',)}

def inventory(relative_paths):
    return [{'path': p, 'sha256': hashlib.sha256((root / p).read_bytes()).hexdigest(),
             'bytes': (root / p).stat().st_size}
            for p in sorted(relative_paths) if (root / p).is_file()]

source_rows = inventory(paths)
caller_rows = inventory(callers)
observed = json.loads((here / 'owner-passing-baseline.json').read_text())
app_at_start = {r['path']: r['sha256'] for r in observed['files'] if r['path'].startswith('frontend/apps/dtf/')}
current_callers = {r['path']: r['sha256'] for r in caller_rows}
app_changes = [p for p, digest in app_at_start.items() if current_callers.get(p) != digest]
new_app_sources = sorted(p for p in current_callers if p.startswith('frontend/apps/dtf/') and p not in app_at_start)
record = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(), 'provenance': provenance,
    'method': __doc__, 'solidity_and_config': source_rows, 'callers_and_orchestration': caller_rows,
    'working_tree_status': subprocess.check_output(['git', 'status', '--porcelain=v1', '--untracked-files=all'], cwd=root, text=True).splitlines(),
    'crane_working_tree_status': subprocess.check_output(['git', 'status', '--porcelain=v1', '--untracked-files=all'], cwd=crane, text=True).splitlines(),
    'frontend_evidence': {
        'run': 'frontend-check.json', 'log': 'frontend-check.log',
        'log_sha256': hashlib.sha256((here / 'frontend-check.log').read_bytes()).hexdigest(),
        'app_sources_observed_at_task_start': len(app_at_start),
        'changed_or_removed_app_sources': app_changes, 'new_app_sources': new_app_sources,
        'note': 'The 410-test check ran during this task. The recorded task-start app files remain unchanged; imported protocol/lock files are inventoried here. No public frontend bindings were edited by the readiness work.',
    },
    'limitations': 'Includes pre-existing unrelated changes without attributing them to this task. Public deployment requires preserving the recorded dirty Crane fixes, not only checking out the submodule HEAD. No secret environment values are included.',
}
(here / 'release-source-manifest.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'solidity_and_config_files': len(source_rows), 'caller_files': len(caller_rows),
                  'frontend_changed': app_changes, 'frontend_added': new_app_sources}))
