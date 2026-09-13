"""Remove three audited internal helpers after the active Forge process exits."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
output = artifacts / 'unused-funded-helper-removal.json'
assert not output.exists(), 'Already applied; preserve original source provenance.'
sources = [
    (Path('contracts/vaults/detf/common/core/DETFMintSplitLib.sol'), [
        '_splitHalfSeigniorage(uint256 grossAmount_, uint256 seignioragePercentage_)',
        '_splitBond(uint256 joinDetf_, uint256 p_)',
    ]),
    (Path('contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol'), [
        '_executeUnderlyingExitExactOutShared(',
    ]),
]
rows = []
staged = {}
for path, signatures in sources:
    old = (root / path).read_text()
    updated = old
    for signature in signatures:
        start = updated.index('    function ' + signature)
        # Retire the old overload's superseded NatSpec along with its implementation.
        if signature.startswith('_splitBond('):
            start = updated.rfind('    /// @notice Bond L1', 0, start)
            assert start >= 0
        brace = updated.index('{', start)
        depth = 1
        end = brace + 1
        while depth:
            if updated[end] == '{': depth += 1
            elif updated[end] == '}': depth -= 1
            end += 1
        while end < len(updated) and updated[end] == '\n': end += 1
        updated = updated[:start] + updated[end:]
    staged[path] = updated
    rows.append({'source': str(path), 'removed_signatures': signatures,
                 'before_sha256': hashlib.sha256(old.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(updated.encode()).hexdigest()})
for path, source in staged.items():
    (root / path).write_text(source)
output.write_text(json.dumps({'status': 'applied; build validation pending', 'rows': rows,
    'reader_audit': 'All local contracts/test/scripts Solidity references: half-seigniorage and underlying exact-output helper had definitions only; every bond-split call passes independent U, G and p.'}, indent=2) + '\n')
print('Removed three unused internal helpers; public selectors unchanged.')
