"""Seed only absent cache entries whose complete baseline dependency closure is unchanged.

Run without --apply to review. Never run --apply during a Forge process. Current
entries and their artifacts win; all copied records retain Foundry's own hashes.
Foundry still validates the resulting cache normally on the next build.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from datetime import datetime, timezone

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
baseline = Path('/private/tmp/indexedex-detf-funded-staking-20260906')
cache_path = Path('cache_forge/solidity-files-cache.json')
current = json.loads((root / cache_path).read_text())
seed = json.loads((baseline / cache_path).read_text())
assert current['profiles'] == seed['profiles'], 'Compiler profiles differ'

def artifact_records(entry):
    for versions in entry.get('artifacts', {}).values():
        for profiles in versions.values():
            yield from profiles.values()

current_paths = {
    record['path'] for entry in current['files'].values()
    for record in artifact_records(entry)
}
valid = set()
for name, entry in seed['files'].items():
    local, original = root / name, baseline / name
    if not local.is_file() or not original.is_file():
        continue
    if local.read_bytes() != original.read_bytes():
        continue
    existing = current['files'].get(name)
    if existing and existing['contentHash'] != entry['contentHash']:
        continue
    records = list(artifact_records(entry))
    if not all((baseline / 'out' / record['path']).is_file() for record in records):
        continue
    if not existing and any(record['path'] in current_paths for record in records):
        continue
    valid.add(name)

# Reject a source when even one transitive import differs. This also handles
# import cycles without assuming a topological order.
while True:
    rejected = {
        name for name in valid
        if any(dependency not in valid for dependency in seed['files'][name]['imports'])
    }
    if not rejected:
        break
    valid -= rejected
added = sorted(valid - current['files'].keys())
report = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
    'applied': False,
    'baseline': str(baseline),
    'baseline_cache_sha256': hashlib.sha256((baseline / cache_path).read_bytes()).hexdigest(),
    'current_cache_sha256_before': hashlib.sha256((root / cache_path).read_bytes()).hexdigest(),
    'current_entries': len(current['files']),
    'baseline_entries': len(seed['files']),
    'unchanged_dependency_closure': len(valid),
    'added_entries': len(added),
    'added_sources': added,
    'policy': 'Preserve all current cache entries/artifacts; seed only absent entries with unchanged source/import closure. No source edits, cache deletion, changed compiler settings or manufactured hashes.',
}
if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge session still active'
    assert not queue.get('active_forge_session'), 'Forge session still active'
    backup = artifacts / 'cache-before-baseline-seed.json'
    assert not backup.exists(), 'Seed already applied or backup exists; inspect before proceeding'
    shutil.copy2(root / cache_path, backup)
    builds = set(current['builds'])
    copied = 0
    for name in added:
        entry = seed['files'][name]
        for record in artifact_records(entry):
            destination = root / 'out' / record['path']
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(baseline / 'out' / record['path'], destination)
            builds.add(record['build_id'])
            copied += 1
        current['files'][name] = entry
    for build_id in builds - set(current['builds']):
        source = baseline / 'out/build-info' / f'{build_id}.json'
        assert source.is_file(), f'Missing baseline build info: {build_id}'
        shutil.copy2(source, root / 'out/build-info' / source.name)
    current['builds'] = sorted(builds)
    temporary = root / 'cache_forge/seeded-solidity-files-cache.json'
    temporary.write_text(json.dumps(current, separators=(',', ':')))
    temporary.replace(root / cache_path)
    report.update(applied=True, artifacts_copied=copied,
                  current_cache_sha256_after=hashlib.sha256((root / cache_path).read_bytes()).hexdigest())
    (artifacts / 'unchanged-baseline-cache-seed.json').write_text(json.dumps(report, indent=2) + '\n')
else:
    (artifacts / 'unchanged-baseline-cache-seed-preview.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({key: value for key, value in report.items() if key != 'added_sources'}, indent=2))
