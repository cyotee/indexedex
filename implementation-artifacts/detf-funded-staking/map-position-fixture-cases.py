"""Map every prepared fixture test rename/merge, preserving decimal inheritance."""
from pathlib import Path
import hashlib, json, re, runpy

art = Path(__file__).resolve().parent
changes = runpy.run_path(str(art / 'prepare-position-fixture-migrations.py'))['changes']
aliases = {
    'test_T1b_idleDeposit_token0Only_doesNotRequireSleeveAndL': 'test_T1b_subsequentSingleTokenDeposit_keepsFullRangeLiquidity',
    'test_zapIn_firstDeposit_createsPositionsAndShares': 'test_twoTokenActivation_createsPositionsAndShares',
    'test_P_IN_03_zapIn_token0_firstDeposit': 'test_P_IN_03_singleToken0ActivationRejected',
    'test_P_IN_04_zapIn_token1_firstDeposit': 'test_P_IN_04_singleToken1ActivationRejected',
    'test_A0_donatePair_thenFirstZapIn_cannotRedeemDonation': 'test_A0_donatePair_thenTwoTokenActivation_cannotRedeemDonation',
}
for side in ['token0', 'token1']:
    target = 'test_twoTokenActivation_' + side + 'Dominant_previewAndExecution'
    aliases['test_exchangeIn_zap_' + side + 'ToShares_firstDeposit'] = target
    aliases['test_previewExchangeIn_zap_firstDeposit_matchesExecution_' + side + 'ToShares'] = target
rows = []
for path, (before, after) in changes.items():
    names = lambda source: set(re.findall(r'function\s+((?:test|invariant)\w*)\s*\(', source))
    old, new = names(before), names(after)
    for name in old - new:
        assert name in aliases and aliases[name] in new, (path, name)
    rows.append({'source': path,
        'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
        'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
        'unchanged_declared_cases': sorted(old & new),
        'removed_or_renamed_cases': {name: aliases[name] for name in sorted(old - new)},
        'new_or_renamed_cases': sorted(new - old),
        'declared_count_before': len(old), 'declared_count_after': len(new)})
record = {'status': 'PREPARED_CASE_MAPPING_NOT_RUNTIME_ACCEPTANCE', 'source_count': len(rows),
    'declared_cases_before': sum(row['declared_count_before'] for row in rows),
    'declared_cases_after': sum(row['declared_count_after'] for row in rows),
    'unmapped_removed_cases': [],
    'inheritance_note': 'All retained concrete decimal leaves inherit their migrated abstract cases. Leaf files remain. Execution counts and performance require actual current-source validation.',
    'coverage_rationale': 'Two-token activation replaces invalid single-token initialization, with subsequent single-token routes retained. V4 first-activation execution/preview duplicates are combined in both amount-ratio directions. V3 first-single-token preview cases assert exact rejection and no loss; its positive two-token activation remains in Routes. Existing donation, reentrancy, slippage, lock, native ETH, TWAP, import and nested-holder cases receive funded setups. Native ETH fixtures force WETH to sort after its pair and reject reversed PoolKey arrays.',
    'rows': rows}
(art / 'position-fixture-case-migration-map.json').write_text(json.dumps(record, indent=2) + '\n')
print({key: value for key, value in record.items() if key not in ['rows', 'inheritance_note', 'coverage_rationale']})
