"""Compile maintained callers in an independent warm cache before full acceptance.

This is an incremental engineering check, not a replacement for the complete
contracts/default-tests/maintained-scripts build or runtime validation.
"""
from pathlib import Path
import json, os, shutil, subprocess, time
from build_provenance import capture, hermetic_environment

art = Path(__file__).resolve().parent
root = art.parent.parent
inventory = json.loads((art / 'maintained-script-build-scope.json').read_text())
paths = inventory['included_sources']
all_sources = {str(p.relative_to(root)) for p in (root / 'scripts/foundry').rglob('*.sol')}
assert set(paths) | set(inventory['preserved_historical_sources']) == all_sources
cache = art / 'maintained-script-validation-cache'
cache.mkdir(exist_ok=True)
if not (cache / 'solidity-files-cache.json').exists():
    shutil.copy2(root / 'cache_forge/solidity-files-cache.json', cache / 'solidity-files-cache.json')
env, emptied = hermetic_environment(root)
minimal = 'contracts/vaults/detf/common/core'
env.update(FOUNDRY_TEST=minimal, FOUNDRY_SCRIPT=minimal, FOUNDRY_CACHE_PATH=str(cache))
command = ['forge', 'build', '--offline', '--contracts', minimal] + paths
record = {'status': 'RUNNING', 'provenance': capture(root), 'command': command,
          'scope': 'All 294 maintained/current script sources and their actual import closures. No release test gate is removed; complete default acceptance follows separately.',
          'cache': 'Independent warmed metadata, canonical out/. Primary full cache preserved.',
          'explicitly_empty_rpc_environment_keys': emptied}
record_path = art / 'maintained-script-compile.json'
record_path.write_text(json.dumps(record, indent=2) + '\n')
log = art / 'maintained-script-compile.log'
started = time.monotonic()
fd = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as output:
    result = subprocess.run(command, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT)
record.update(status='COMPLETED', exit_code=result.returncode, seconds=round(time.monotonic()-started, 3))
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({k: record[k] for k in ('status', 'exit_code', 'seconds')}), flush=True)
lines = log.read_text(errors='replace').splitlines()
for i, line in enumerate(lines):
    if line.startswith(('Compiling ', 'Solc ', 'No files changed')): print(line, flush=True)
    elif line.startswith('Error'): print('\n'.join(lines[i:i+9]), flush=True)
raise SystemExit(result.returncode)
