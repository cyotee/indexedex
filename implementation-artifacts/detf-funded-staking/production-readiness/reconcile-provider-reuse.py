"""Check retained fork compilation closures without rerunning unchanged providers."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
from Crypto.Hash import keccak

here = Path(__file__).resolve().parent
root = here.parents[2]
art = here.parent
providers = [
    ('lido', 'LidoStandardExchangeProjectionFork', 'lido-live-projection-fork', 4),
    ('etherfi', 'EtherFiStandardExchangeProjectionFork', 'etherfi-live-projection-fork', 5),
    ('rocket', 'RocketPoolStandardExchangeProjectionFork', 'rocket-post-position-live-projection-fork', 7),
    ('rocket', 'RocketPoolStandardExchangeProjectionFork', 'rocket-v4-post-position-live-projection-fork', 7),
    ('sfrxeth', 'ERC4626StandardExchange_SfrxETH_ProjectionFork', 'sfrxeth-post-position-live-projection-fork', 4),
]
rows = []
for provider, contract, stem, expected in providers:
    record_path = art / (stem + '-run.json')
    record = json.loads(record_path.read_text())
    cache_path = art / f'{provider}-fork-validation-cache/solidity-files-cache.json'
    cache = json.loads(cache_path.read_text())
    candidates = [(s, v) for s, v in cache['files'].items() if contract in v.get('artifacts', {})]
    assert len(candidates) == 1, (provider, contract)
    source, entry = candidates[0]
    artifact_info = next(iter(next(iter(entry['artifacts'][contract].values())).values()))
    artifact_path = root / 'out' / artifact_info['path']
    compiled = json.loads(artifact_path.read_text())
    metadata = compiled.get('metadata') or json.loads(compiled['rawMetadata'])
    if isinstance(metadata, str):
        metadata = json.loads(metadata)
    closure = []
    for name, prior in sorted(metadata['sources'].items()):
        path = root / name
        current = '0x' + keccak.new(digest_bits=256, data=path.read_bytes()).hexdigest() if path.is_file() else None
        closure.append({'source': name, 'compiled_keccak256': prior['keccak256'],
                        'current_keccak256': current, 'matches': current == prior['keccak256']})
    logs = [art / (stem + '-test.log')]
    logs = [p for p in logs if p.exists()]
    assert logs, f'Missing test log for {stem}'
    text = logs[0].read_text(errors='replace')
    counts_match = f'{expected} passed; 0 failed; 0 skipped' in text
    passed = record['build']['exit_code'] == 0 and record['test']['exit_code'] == 0
    matched = all(row['matches'] for row in closure)
    rows.append({
        'provider': provider, 'contract': contract, 'record': str(record_path.relative_to(root)),
        'record_sha256': hashlib.sha256(record_path.read_bytes()).hexdigest(),
        'test_log': str(logs[0].relative_to(root)), 'test_log_sha256': hashlib.sha256(logs[0].read_bytes()).hexdigest(),
        'expected_cases': expected, 'recorded_pass': passed, 'counts_match': counts_match,
        'pinned_block': record['pinned_ethereum_block'],
        'cache': str(cache_path.relative_to(root)), 'cache_build_id': artifact_info['build_id'],
        'artifact': str(artifact_path.relative_to(root)),
        'artifact_sha256': hashlib.sha256(artifact_path.read_bytes()).hexdigest(),
        'compiler': metadata['compiler'], 'compiler_settings': metadata['settings'],
        'closure': closure, 'closure_matches_current': matched,
        'disposition': 'REUSE_PASS_UNCHANGED_COMPILED_DEPENDENCIES' if passed and counts_match and matched else 'RENEW_REQUIRED',
    })
result = {
    'checked_at_utc': datetime.now(timezone.utc).isoformat(),
    'method': 'Retained fork-cache build IDs identify existing test artifacts. Compare every compiler metadata source hash (including imported production, factory and Crane dependencies) with current files and verify successful recorded commands/counts. Global source changes outside these closures do not invalidate these provider checks.',
    'limits': 'This is local evidence reconciliation, not an independent execution attestation. Current full-build provenance and production artifact closure checks remain separately required. Historical records and logs are preserved.',
    'rows': rows,
    'all_reusable': all(row['disposition'].startswith('REUSE_') for row in rows),
}
(here / 'provider-evidence-reuse.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'all_reusable': result['all_reusable'], 'rows': [{k: row[k] for k in ('provider', 'expected_cases', 'pinned_block', 'disposition')} for row in rows]}))
assert result['all_reusable'], 'One or more provider evidence closures require renewal'
