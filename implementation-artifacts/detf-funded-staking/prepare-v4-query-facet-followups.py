"""Prepare a snapshot selector move between existing facets if size validation needs it."""
from pathlib import Path
import datetime, hashlib, json, sys

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
base = root / 'contracts/protocols/dexes/uniswap/v4'
tests = root / 'test/foundry/spec/protocol/dexes/uniswap/v4'
changes = {}

def read(path):
    original = path.read_text()
    changes[path] = [original, original]
    return original

p = base / 'UniswapV4StandardExchangeInQueryTarget.sol'
s = read(p)
start = s.index('    function quoteState(')
end = s.index('    function quoteShareBalance(', start)
snapshot = s[start:end]
changes[p][1] = s[:start] + s[end:]
p = base / 'UniswapV4StandardExchangeOutMultiQueryTarget.sol'
s = read(p)
needle = '    function _standardRoute('
assert needle in s
changes[p][1] = s.replace(needle, snapshot + needle, 1)

p = base / 'UniswapV4StandardExchangeInQueryFacet.sol'
s = read(p)
s = s.replace('new bytes4[](4)', 'new bytes4[](3)')
s = s.replace('        funcs[0] = IStandardExchangeTransitionQuote.quoteState.selector;\n', '')
for index in range(1, 4):
    s = s.replace(f'funcs[{index}]', f'funcs[{index-1}]')
changes[p][1] = s

p = base / 'UniswapV4StandardExchangeOutMultiQueryFacet.sol'
s = read(p)
s = s.replace('import {NativeStandardYieldSelectors}', 'import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {NativeStandardYieldSelectors}')
s = s.replace('funcs = new bytes4[](1);', 'funcs = new bytes4[](2);')
needle = '        funcs[0] = IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector;'
s = s.replace(needle, needle + '\n        funcs[1] = IStandardExchangeTransitionQuote.quoteState.selector;')
changes[p][1] = s

p = tests / 'UniswapV4StandardExchangeInQueryFacet_IFacet_Test.t.sol'
s = read(p)
s = s.replace('new bytes4[](4)', 'new bytes4[](3)')
s = s.replace('        controlFuncs[0] = IStandardExchangeTransitionQuote.quoteState.selector;\n', '')
for index in range(1, 4):
    s = s.replace(f'controlFuncs[{index}]', f'controlFuncs[{index-1}]')
changes[p][1] = s

p = tests / 'UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol'
s = read(p)
s = s.replace('import {IStandardizedYield}', 'import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {IStandardizedYield}')
s = s.replace('new bytes4[](17)', 'new bytes4[](18)')
for index in range(16, 0, -1):
    s = s.replace(f'controlFuncs[{index}]', f'controlFuncs[{index+1}]')
needle = '        controlFuncs[0] = IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector;'
s = s.replace(needle, needle + '\n        controlFuncs[1] = IStandardExchangeTransitionQuote.quoteState.selector;')
changes[p][1] = s

for p, (before, after) in changes.items():
    assert before != after, p
    if '--apply' in sys.argv:
        p.write_text(after)
    else:
        (art / ('pending-query-move-' + p.name + '.txt')).write_text(after)
record = {
    'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED',
    'change': 'Move quoteState unchanged from existing InQuery to existing OutMultiQuery facet; retain the exact assembled proxy API and package deployment structure. Transition execution remains on InQuery. Independent selector controls migrate with the implementation.',
    'files': [{'path': str(p.relative_to(root)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest()} for p, (b, s) in changes.items()],
}
(art / 'v4-query-snapshot-facet-move.json').write_text(json.dumps(record, indent=2) + '\n')
print(record['status'])
