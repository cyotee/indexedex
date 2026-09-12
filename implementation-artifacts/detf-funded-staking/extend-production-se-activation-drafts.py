"""Prepare funded position activation in the distinct Weighted/Orbital fixtures.

Canonical Solidity remains frozen while parent validation session 4255 runs.
"""
from pathlib import Path
from datetime import datetime, timezone
import difflib
import hashlib
import json

art = Path(__file__).resolve().parent
root = art.parent.parent
record_path = art / 'production-se-fixture-followups-prepared.json'
record = json.loads(record_path.read_text())
assert record['status'] == 'PREPARED_NOT_APPLIED'
assert len(record['changes']) == 9
archive = art / 'production-se-fixture-followups-before-weighted-orbital.json'
assert not archive.exists()
archive.write_text(record_path.read_text())
base = Path('contracts/vaults/detf/protocols/dexes/uniswap/v4/detf')
draft_dir = art / 'production-se-fixture-followup-drafts'
for family in ('Weighted', 'Orbital'):
    pairs = ('pairA', 'pairB') if family == 'Weighted' else ('pairAddr0', 'pairAddr1')
    for provider in ('Univ3Se', 'Univ4Se', 'PonsV1Se', 'PonsV2Se', 'PonsMix', 'MorphoMix'):
        for suffix in ('', '_Decimals'):
            path = base / f'TestBase_UniswapV4Detf_{family}_{provider}{suffix}.sol'
            before = (root / path).read_text()
            opening = before.index('{', before.index('    function setUp()'))
            depth, end = 1, opening + 1
            while depth:
                depth += (before[end] == '{') - (before[end] == '}')
                end += 1
            # Activate after real user funding, including Pons purchases. The common
            # _finish* helpers run before that funding and are too early.
            assert before[end - 5:end] == '    }'
            weth = 'address(0)' if provider == 'Univ3Se' else 'address(weth)'
            assert provider == 'Univ3Se' or 'IWETH internal weth' in before
            insertion = ''.join(
                f'        SeLib.activatePositionVault(se{i}, {pair}, detfUser, {weth});\n'
                for i, pair in enumerate(pairs)
            )
            after = before[:end - 5] + insertion + before[end - 5:]
            draft = draft_dir / (path.name + '.txt')
            assert not draft.exists()
            draft.write_text(after)
            record['changes'].append({
                'path': str(path), 'draft': str(draft.relative_to(root)),
                'reason': 'Fund both position currencies after actual provider funding; preserve all existing test declarations and Morpho token-asset initialization.',
                'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
            })

patch = []
for row in record['changes']:
    before = (root / row['path']).read_text()
    after = (root / row['draft']).read_text()
    assert hashlib.sha256(before.encode()).hexdigest() == row['before_sha256']
    assert hashlib.sha256(after.encode()).hexdigest() == row['after_sha256']
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                     fromfile='a/' + row['path'], tofile='b/' + row['path']))
record['updated_at_utc'] = datetime.now(timezone.utc).isoformat()
record['scope'] = '33 existing fixture sources: shared exact V3 seeding and funded two-currency position activation across CP, Quad, Weighted and Orbital provider fixtures. All declarations retained.'
record['diagnostic_note'] = 'Earlier nine-source checks remain historical evidence; the 24 additional fixture sources require fresh typecheck and runtime validation.'
record_path.write_text(json.dumps(record, indent=2) + '\n')
(art / 'production-se-fixture-followups.patch').write_text(''.join(patch))
print(json.dumps({'status': record['status'], 'draft_sources': len(record['changes']), 'canonical_sources_changed': 0}))
