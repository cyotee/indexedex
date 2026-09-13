"""Keep hook-only composed quotes out of CurveQuad/Weighted SE execution facets."""
from pathlib import Path
import datetime, hashlib, json, sys

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
base = root / 'contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve'
name = 'UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget'
derived = 'UniswapV4StandardExchangeCurveQuadStableBufferHookQuoteTarget'
p = base / (name + '.sol')
before = p.read_text()
start = before.index('    function previewSwapAfterRedeem(')
end = before.index('    function _previewSwapExactIn(', start)
method = before[start:end]
after = before[:start] + before[end:]
needle = 'function _quoteRatedSwapExactIn(uint8 i, uint8 j, uint256[4] memory rated, uint256 ratedInflow)\n        private view'
assert needle in after
after = after.replace(needle, needle.replace('private view', 'internal view'))
after += ('\n/// @notice Hook-only composed quotes, separated from inherited SE execution code.\n'
          f'abstract contract {derived} is {name} {{\n' + method + '}\n')
changes = {p: (before, after)}
p = base / 'facets/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet.sol'
before = p.read_text()
after = before.replace('    '+name+'\n}', '    '+derived+'\n}').replace('    '+name+',', '    '+derived+',')
assert before != after
changes[p] = (before, after)

base = root / 'contracts/hooks/uniswap/v4/standardExchange/weighted'
name = 'UniswapV4StandardExchangeWeightedBufferHookHooksTarget'
derived = 'UniswapV4StandardExchangeWeightedBufferHookQuoteTarget'
p = base / (name + '.sol')
before = p.read_text()
start = before.index('    function previewSwapAfterRedeem(')
end = before.index('    function _previewSwapExactIn(', start)
method = before[start:end]
after = before[:start] + before[end:]
needle = 'function _quoteRatedSwapExactIn(uint8 i, uint8 j, uint256[] memory rated, uint256 ratedInflow)\n        private view'
assert needle in after
after = after.replace(needle, needle.replace('private view', 'internal view'))
after += ('\n/// @notice Hook-only composed quotes, separated from inherited SE execution code.\n'
          f'abstract contract {derived} is {name} {{\n' + method + '}\n')
changes[p] = (before, after)
p = base / 'facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol'
before = p.read_text()
after = before.replace('    '+name+'\n}', '    '+derived+'\n}').replace('    '+name+',', '    '+derived+',')
assert before != after
changes[p] = (before, after)

for p, (before, after) in changes.items():
    if '--apply' in sys.argv:
        p.write_text(after)
    else:
        (art / ('pending-curve-quote-isolation-' + p.name + '.txt')).write_text(after)
record = {
    'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED',
    'measured_failure': 'Current CurveQuad SeFacet 25,944 bytes exceeds EIP-170 by 1,368; Weighted SeFacet 25,422 exceeds by 846. Their exported selectors do not include previewSwapAfterRedeem, but Solidity inherited that public method from HooksTarget.',
    'change': 'Move each unchanged composed quote to an abstract target in its same existing source file, inherited only by the HooksFacet that already exports it. Preserve the exact proxy selector, quote math, ownership and execution paths; no new deployed facet/package.',
    'files': [{'path': str(p.relative_to(root)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest()} for p, (b, s) in changes.items()],
}
(art / 'curve-quote-target-isolation.json').write_text(json.dumps(record, indent=2)+'\n')
print(record['status'])
