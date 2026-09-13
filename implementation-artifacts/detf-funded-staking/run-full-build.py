"""Record the default full build separately from focused development checks."""
import json, os, subprocess, time, sys
from pathlib import Path
from build_provenance import capture
artifacts = Path(__file__).resolve().parent
checkout = artifacts.parent.parent
provenance = capture(checkout)
environment = os.environ.copy()
environment['FOUNDRY_PROFILE'] = 'default'
for key in ('FOUNDRY_TEST', 'FOUNDRY_SCRIPT', 'DETF_MATCH_TEST', 'DETF_MATCH_CONTRACT'):
    environment.pop(key, None)
started = time.monotonic()
command = ['forge', 'build', '--offline']
include_scripts = '--include-scripts' in sys.argv
if include_scripts:
    # Keep the complete default contract/test roots in this invocation. A
    # script-only/narrow project must not prune the expensive full-build cache.
    script_root = checkout / 'scripts/foundry'
    retired = script_root / 'research/dualLiquidityLinkedCrossVersion'
    script_roots = []
    for child in sorted(script_root.iterdir()):
        candidates = sorted(child.iterdir()) if child.name == 'research' else [child]
        script_roots.extend(path for path in candidates
                            if path != retired and (path.is_dir() or path.suffix == '.sol'))
    included = sorted({str(path.relative_to(checkout)) for folder in script_roots
                       for path in (folder.rglob('*.sol') if folder.is_dir() else [folder])})
    excluded = sorted(str(path.relative_to(checkout)) for path in retired.rglob('*.sol'))
    assert set(included) | set(excluded) == {str(path.relative_to(checkout)) for path in script_root.rglob('*.sol')}
    (artifacts / 'maintained-script-build-scope.json').write_text(json.dumps({
        'included_sources': included, 'included_count': len(included),
        'preserved_historical_sources': excluded,
        'exclusion_basis': 'DualLiquidity was deleted in commit c0631349 before this task; DETF_ALIGNMENT_PRD.md states it is removed and will not be repaired. Its research harness imports the deleted test base. Preserve these historical files without restoring the retired product.',
        'complete_default_contract_and_test_roots_preserved': True,
    }, indent=2) + '\n')
    command += ['contracts', 'test/foundry/spec'] + [str(path.relative_to(checkout)) for path in script_roots]
with (artifacts / 'implementation-full-build.log').open('w') as log:
    result = subprocess.run(command, cwd=checkout, env=environment, stdout=log, stderr=subprocess.STDOUT)
record = {'command': command, 'exit_code': result.returncode, 'seconds': round(time.monotonic() - started, 3), 'scope': 'Complete default contracts/tests plus explicit maintained scripts/foundry callers' if include_scripts else 'Default configured roots; scripts/ callers require the explicit additional build', 'cache': 'seeded, with earlier focused incremental builds; no clean', 'provenance': provenance}
(artifacts / 'implementation-full-build.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
print((artifacts / 'implementation-full-build.log').read_text()[-4000:], flush=True)
raise SystemExit(result.returncode)
