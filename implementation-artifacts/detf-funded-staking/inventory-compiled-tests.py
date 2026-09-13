"""Count current cache-indexed test artifacts, not stale files left in out/."""
from pathlib import Path
from datetime import datetime, timezone
from collections import Counter
import argparse
import hashlib
import json

parser = argparse.ArgumentParser()
parser.add_argument('--baseline', action='store_true')
args = parser.parse_args()
art = Path(__file__).resolve().parent
root = Path('/private/tmp/indexedex-detf-funded-staking-20260906') if args.baseline else art.parent.parent
cache_path = root / 'cache_forge/solidity-files-cache.json'
cache_bytes = cache_path.read_bytes()
cache = json.loads(cache_bytes)
assert cache['paths']['sources'] == 'contracts', 'A complete default build must replace narrow development cache metadata first.'
assert cache['paths']['tests'] == 'test/foundry/spec', 'A complete default test-root build is required.'
if not args.baseline:
    assert json.loads((art / 'implementation-full-build.json').read_text())['exit_code'] == 0

network_sources = {row['source'] for row in json.loads((art / 'misplaced-fork-test-inventory.json').read_text())['rows']}
excluded_funded = {'SingleSEFundedStaking.t.sol', 'MixedBufferFundedStaking.t.sol',
                    'MixedBufferFundedDecimalBooks.t.sol', 'MultiWeightedFundedStaking.t.sol',
                    'ComposedStableFundedStaking.t.sol'}
rows = []
for source, entry in sorted(cache['files'].items()):
    if not source.startswith('test/foundry/spec/') or not source.endswith('.t.sol'):
        continue
    for contract, versions in sorted(entry['artifacts'].items()):
        for compiler, profiles in sorted(versions.items()):
            info = profiles.get('default')
            if info is None:
                continue
            path = root / cache['paths']['artifacts'] / info['path']
            payload = path.read_bytes()
            artifact = json.loads(payload)
            runtime = len(artifact['deployedBytecode']['object'].removeprefix('0x')) // 2
            methods = [item for item in artifact['abi'] if item['type'] == 'function'
                       and item['name'].startswith(('test', 'invariant'))]
            if not runtime or not methods:
                continue
            scope = ('D66_DEFERRED_PRESERVE_EXISTING' if '/slipstream/' in source else
                     'D60_BALANCER_DETF_EXCLUDED' if '/vaults/detf/protocols/dexes/balancer/' in source
                     or Path(source).name in excluded_funded else 'IN_SCOPE_OR_SHARED_DEPENDENCY')
            rows.append({'source': source, 'contract': contract, 'compiler': compiler, 'scope': scope,
                         'artifact': info['path'], 'artifact_sha256': hashlib.sha256(payload).hexdigest(),
                         'artifact_file_bytes': len(payload), 'runtime_bytes': runtime,
                         'compiled_test_or_invariant_methods': len(methods),
                         'documented_baseline_network_exclusion': args.baseline and source in network_sources})

summary = {'compiled_test_contracts': len(rows),
           'compiled_test_or_invariant_methods': sum(row['compiled_test_or_invariant_methods'] for row in rows),
           'scope_contract_counts': dict(Counter(row['scope'] for row in rows)),
           'documented_network_exclusion_contracts': sum(row['documented_baseline_network_exclusion'] for row in rows),
           'largest_runtime_bytes': max(row['runtime_bytes'] for row in rows),
           'total_test_artifact_file_bytes': sum(row['artifact_file_bytes'] for row in rows)}
record = {'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
          'workspace': str(root), 'mode': 'baseline' if args.baseline else 'current',
          'method': 'Concrete nonempty-runtime contracts in cached default-profile local .t.sol sources whose ABI declares test/invariant methods, including inherited methods. The active cache supplies artifact paths; deleted-source artifacts left in out/ are never enumerated. Compiled method counts exceed executed cases when setup fails and do not prove passing behavior.',
          'cache_sha256': hashlib.sha256(cache_bytes).hexdigest(), 'cache_paths': cache['paths'],
          'summary': summary,
          'largest_twenty': sorted(rows, key=lambda row: row['runtime_bytes'], reverse=True)[:20],
          'rows': rows}
output = art / ('compiled-test-inventory-baseline.json' if args.baseline else 'compiled-test-inventory-current.json')
output.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(summary), flush=True)
