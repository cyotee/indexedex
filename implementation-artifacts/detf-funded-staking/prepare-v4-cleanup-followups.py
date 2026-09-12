"""Regenerate dead comments/errors and obsolete no-op/surface test migrations."""
from pathlib import Path
import datetime, hashlib, json, re, sys

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
changes = {}
base = root / 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf'
tests = root / 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'

def save(path, transform):
    before = path.read_text()
    after = transform(before)
    assert before != after, path
    changes[path] = (before, after)

save(base / 'UniswapV4DetfRepo.sol', lambda s: re.sub(
    r'    error (?:MintingNotAllowed|BurningNotAllowed|BondNotMature)\([^\n]+\);\n', '', s
))
save(base / 'UniswapV4DetfTarget.sol', lambda s: s.replace(
    '    /// @dev Live-only, ungated vs mint/burn thresholds (D22). Joins DETF self-leg,\n'
    '    ///      credits id 0, then prices claim issuance against its pre-credit principal.\n', ''
).replace(
    '    /* ---------------------------------------------------------------------- */\n'
    '    /*                                 Close                                  */\n'
    '    /* ---------------------------------------------------------------------- */\n\n', ''
))
for relative in ('UniswapV4Detf_IoTables.t.sol', 'decimals/UniswapV4Detf_IoTables_Decimals.sol'):
    def migrate_noop(s):
        s = s.replace('T7.11 execute and T7.15 FoT N/A are CP-only (Orbital/Weighted skip T7.11/T7.15; Quad T8.3 owns custom close execute).',
                      'T7.11 retains funded claim/LP conservation; Quad T8.3 covers its distinct multi-leg funded claim.')
        s, count = re.subn(
            r'    /// @notice T7\.15 N/A[^\n]*\n(?:    ///[^\n]*\n)*'
            r'(?:    function test_T7_15_L2_FoT_forbidden\(\) public pure \{\s*return;\s*\})?',
            '    // T7.15 is a token-policy declaration, not an executable regression.\n'
            '    // FoT remains forbidden by product law; no deployment allowlist is introduced.\n'
            '    // Actual short-payment rejection remains covered by the SecurePull suites.', s
        )
        assert count == 1
        return s
    save(tests / relative, migrate_noop)

se_tests = root / 'test/foundry/spec/protocol/dexes/uniswap/v4'
for relative in ('adversarial/Adversarial_UniswapV4SE_SecurePull.t.sol',
                 'decimals/adversarial/Adversarial_UniswapV4SE_SecurePull_Decimals.sol'):
    save(se_tests / relative, lambda s: s.replace(
        'uniswapV4StandardExchangeInQueryFacet.facetFuncs(), IStandardExchangeIn.previewExchangeIn.selector',
        'uniswapV4StandardExchangeInMultiQueryFacet.facetFuncs(), IStandardExchangeIn.previewExchangeIn.selector'
    ))

for path, (before, after) in changes.items():
    if '--apply' in sys.argv:
        path.write_text(after)
    else:
        (art / ('pending-cleanup-followup-' + path.name + '.txt')).write_text(after)
record = {
    'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED',
    'authority': 'Owner-approved obsolete close/dead code cleanup and required test consolidation/API migration.',
    'coverage_mapping': {
        'retired T7.15 return-only cases': 'No executable assertion existed. FoT remains forbidden in product law; real secure-pull/short-delivery money-path tests remain required and retained.',
        'J1 preview selector': 'Retain the same presence assertion on the existing InMultiQuery facet that now exports the standard preview. Final proxy route still covered.',
        'dead errors/comments': 'No current unified V4 production caller uses the three deleted errors; obsolete LP-priced stake/close comments contradicted the funded implementation.',
    },
    'files': [{'path': str(p.relative_to(root)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest()} for p, (b, s) in changes.items()],
}
(art / 'v4-cleanup-followups.json').write_text(json.dumps(record, indent=2) + '\n')
print(record['status'])
