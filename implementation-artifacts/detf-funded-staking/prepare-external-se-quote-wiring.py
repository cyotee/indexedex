"""Prepare provider facet/package exports and independent controls for external quotes."""
from pathlib import Path
import datetime, hashlib, json, re, sys

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
changes = {}
facets = [
    'contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInFacet.sol',
    'contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInQueryFacet.sol',
    'contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet.sol',
    'contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol',
]
packages = [f'contracts/protocols/dexes/uniswap/v{v}/UniswapV{v}StandardExchangeDFPkg.sol' for v in (2,3,4)]
packages += ['contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol']
controls = [f'test/foundry/spec/protocol/dexes/uniswap/v{v}/UniswapV{v}StandardExchangeInQueryFacet_IFacet_Test.t.sol' for v in (3,4)]

def append_array(s, variable, expression):
    allocation = re.search(r'\b'+variable+r' = new bytes4\[\]\((\d+)\);', s)
    assert allocation, variable
    n = int(allocation[1])
    s = s[:allocation.start(1)] + str(n+1) + s[allocation.end(1):]
    lines = list(re.finditer(r'^[ \t]*'+variable+r'\[\d+\][^\n]*;', s, re.M))
    assert len(lines) == n, (variable, n, len(lines))
    last = lines[-1]
    return s[:last.end()] + f'\n        {variable}[{n}] = {expression};' + s[last.end():]

for relative in facets + packages + controls:
    p = root / relative
    before = p.read_text()
    after = before.replace('import {IStandardExchangeTransitionQuote}',
        'import {IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {IStandardExchangeTransitionQuote}')
    assert before != after, p
    after = append_array(after, 'controlInterfaces' if relative in controls else 'interfaces',
                         'type(IStandardExchangeExternalQuote).interfaceId')
    if relative not in packages:
        after = append_array(after, 'controlFuncs' if relative in controls else 'funcs',
                             'IStandardExchangeExternalQuote.quoteExternalExchange.selector')
    changes[p] = (before, after)

for p, (before, after) in changes.items():
    if '--apply' in sys.argv:
        p.write_text(after)
    else:
        (art / ('pending-external-quote-wiring-' + p.name + '.txt')).write_text(after)
record = {
    'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED',
    'scope': 'Export the optional external-transition selector on four existing provider facets and declare it on all four actual packages; update independent V3/V4 facet controls. No new deployment package or facet.',
    'files': [{'path': str(p.relative_to(root)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest()} for p, (b, s) in changes.items()],
}
(art / 'external-se-quote-wiring.json').write_text(json.dumps(record, indent=2)+'\n')
print(record['status'])
