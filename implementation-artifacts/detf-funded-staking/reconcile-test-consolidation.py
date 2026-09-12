"""Compare actual test sources and link existing consolidation decisions.

Source declarations are not executable inherited-case counts or timing evidence.
The immutable baseline remains untouched; current implementation stays in main.
"""
from pathlib import Path
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import re
import subprocess

artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
baseline = Path('/private/tmp/indexedex-detf-funded-staking-20260906')
baseline_commit = 'e08b415733e729471779dcb8102529631330ea16'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline-evidence', type=Path, help='Reuse a preserved comparison for this exact baseline commit when its Git object source is unavailable.')
args = parser.parse_args()
assert args.baseline_evidence or baseline.is_dir(), 'Recorded independent baseline or its preserved evidence is required.'
initial = json.loads((artifacts / 'test-consolidation-manifest.json').read_text())
paths = {row['path'] for row in initial}
paths.update(row['old_source'] for row in json.loads(
    (artifacts / 'obsolete-common-ledger-test-consolidation.json').read_text())['retirements'])
for directory in ('test/foundry/spec/vaults/detf/common', 'test/foundry/spec/vaults/standard/sy'):
    paths.update(str(p.relative_to(root)) for p in (root / directory).rglob('*.sol'))

records = {}
for path in sorted(artifacts.glob('*consolidation*.json')):
    if path.name.startswith(('pending-', 'current-')) or path.name == 'test-consolidation-manifest.json':
        continue
    payload = path.read_text()
    records[path.name] = set(re.findall(r'test/[^\s"\\]+\.sol', payload))


def describe_source(raw):
    if raw is None:
        return None
    source = raw.decode()
    code = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/', '', source)
    return {
        'sha256': hashlib.sha256(raw).hexdigest(),
        'bytes': len(raw),
        'declared_tests': sorted(set(re.findall(r'\bfunction\s+((?:test|invariant)\w*)\s*\(', code))),
        'concrete_contract_declarations': re.findall(r'(?<!abstract )\bcontract\s+(\w+)', code),
    }


# Read immutable Git blobs in one batch. The separate baseline checkout is only
# an object source; later working-tree changes must never rewrite the baseline.
ordered_paths = sorted(paths)
requests = ''.join(baseline_commit + ':' + path + '\n' for path in ordered_paths)
baseline_evidence = None
if args.baseline_evidence:
    raw = args.baseline_evidence.read_bytes()
    previous = json.loads(raw)
    assert previous['baseline_commit'] == baseline_commit, 'Different baseline commit'
    descriptions = {row['path']: row['before'] for row in previous['rows']}
    assert len(descriptions) == len(previous['rows']), 'Duplicate baseline paths'
    assert set(ordered_paths) <= descriptions.keys(), 'Missing baseline source descriptions'
    baseline_evidence = {'path': str(args.baseline_evidence), 'sha256': hashlib.sha256(raw).hexdigest(),
                         'method': 'Reuse the archived immutable-baseline descriptions, including recorded source hashes and absent files. The unavailable Git blobs were not reread. Current source descriptions are recomputed.'}
else:
    result = subprocess.run(['git', '-C', str(baseline), 'cat-file', '--batch'],
                            input=requests.encode(), capture_output=True, check=True)
    offset = 0
    descriptions = {}
    for relative in ordered_paths:
        end = result.stdout.index(b'\n', offset)
        header = result.stdout[offset:end]
        offset = end + 1
        if header.endswith(b' missing'):
            descriptions[relative] = None
            continue
        _, kind, size = header.split()
        assert kind == b'blob', relative
        size = int(size)
        descriptions[relative] = describe_source(result.stdout[offset:offset + size])
        offset += size + 1
    assert offset == len(result.stdout)

rows = []
excluded_funded_fixtures = {
    'SingleSEFundedStaking.t.sol', 'MultiWeightedFundedStaking.t.sol',
    'MixedBufferFundedStaking.t.sol', 'MixedBufferFundedDecimalBooks.t.sol',
    'ComposedStableFundedStaking.t.sol',
}
for relative in ordered_paths:
    before = descriptions[relative]
    current_path = root / relative
    after = describe_source(current_path.read_bytes() if current_path.is_file() else None)
    scope = ('D66_DEFERRED_PRESERVE_EXISTING' if '/slipstream/' in relative else
             'D60_BALANCER_DETF_EXCLUDED' if '/vaults/detf/protocols/dexes/balancer/' in relative
             or Path(relative).name in excluded_funded_fixtures else
             'IN_SCOPE_OR_SHARED_DEPENDENCY')
    status = ('ADDED' if before is None else 'REMOVED_OR_MOVED' if after is None else
              'UNCHANGED' if before['sha256'] == after['sha256'] else 'UPDATED')
    retired = sorted(set((before or {}).get('declared_tests', [])) -
                     set((after or {}).get('declared_tests', [])))
    evidence = [name for name, mapped in records.items() if relative in mapped]
    rows.append({'path': relative, 'scope': scope, 'source_disposition': status,
                 'before': before, 'current': after,
                 'no_longer_declared_here': retired, 'consolidation_records': evidence})

unmapped = [row['path'] for row in rows if row['scope'] == 'IN_SCOPE_OR_SHARED_DEPENDENCY'
            and row['no_longer_declared_here'] and not row['consolidation_records']]
summary = {'source_files': len(rows),
           'dispositions': dict(Counter(row['source_disposition'] for row in rows)),
           'scopes': dict(Counter(row['scope'] for row in rows)),
           'declared_tests_before': sum(len((r['before'] or {}).get('declared_tests', [])) for r in rows),
           'declared_tests_current': sum(len((r['current'] or {}).get('declared_tests', [])) for r in rows),
           'files_with_retired_declarations_without_direct_record': len(unmapped)}
report = {'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
          'status': 'SOURCE_RECONCILIATION_RUNTIME_AND_RETIREMENT_REVIEW_SEPARATE',
          'baseline': str(baseline), 'current': str(root),
          'baseline_commit': baseline_commit,
          'baseline_evidence_reuse': baseline_evidence,
          'method': 'Immutable baseline Git blobs compared with actual current source hashes and directly declared test/invariant names. Inherited tests remain in their concrete fixtures. A declaration removed here can have moved into a shared behavior; it is not automatically a removed executable case. Unrelated dirty changes are retained and are not attributed to this task by this inventory.',
          'timing_evidence': 'policy-fixture-performance-comparison.json; final full build/hermetic comparison remains required.',
          'summary': summary, 'retirement_mapping_review': unmapped, 'rows': rows}
(artifacts / 'current-test-consolidation.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(summary))
