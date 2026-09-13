"""Move an existing selector to an existing facet, preserving its code and proxy ABI. Not applied yet."""
from pathlib import Path
import hashlib,json
base=Path('contracts/protocols/dexes/uniswap/v4')
changed=[]
def save(p,s):
 old=p.read_text();p.write_text(s);changed.append({'path':str(p),'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
p=base/'UniswapV4StandardExchangeInQueryTarget.sol';s=p.read_text()
a=s.index('    function previewExchangeIn(');b=s.index('    struct InventoryQuote',a)
preview=s[a:b];s=s[:a]+s[b:]
s=s.replace('View-only exchange-in previews (size split from mutate facet). D24: no rebalance simulation.', 'Sequential inventory-transition quotes; standard previews reside on InMultiQueryFacet.')
save(p,s)
p=base/'UniswapV4StandardExchangeInMultiQueryTarget.sol';s=p.read_text();mark='    function previewExchangeInManyToOne(';assert mark in s;save(p,s.replace(mark,preview+'\n'+mark,1))
p=base/'UniswapV4StandardExchangeInQueryFacet.sol';s=p.read_text().replace('Preview-only facet to keep mutate InFacet under EIP-170.','Inventory-transition queries; split from standard previews to remain under EIP-170.')
s=s.replace('new bytes4[](2)','new bytes4[](1)').replace('        interfaces[0] = type(IStandardExchangeIn).interfaceId;\n        interfaces[1]', '        interfaces[0]')
s=s.replace('new bytes4[](5)','new bytes4[](4)').replace('        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;\n','')
for i in range(1,5): s=s.replace(f'funcs[{i}] = IStandardExchangeTransitionQuote',f'funcs[{i-1}] = IStandardExchangeTransitionQuote')
save(p,s)
p=base/'UniswapV4StandardExchangeInMultiQueryFacet.sol';s=p.read_text().replace('import {IFacet}', 'import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";\n\nimport {IFacet}',1)
s=s.replace('new bytes4[](1)','new bytes4[](2)').replace('        interfaces[0] = type(IStandardExchangeInMulti).interfaceId;', '        interfaces[0] = type(IStandardExchangeInMulti).interfaceId;\n        interfaces[1] = type(IStandardExchangeIn).interfaceId;')
s=s.replace('        funcs[0] = IStandardExchangeInMulti.previewExchangeInManyToOne.selector;', '        funcs[0] = IStandardExchangeInMulti.previewExchangeInManyToOne.selector;\n        funcs[1] = IStandardExchangeIn.previewExchangeIn.selector;')
save(p,s)
Path('implementation-artifacts/detf-funded-staking/v4-query-size-sources.json').write_text(json.dumps(changed,indent=2)+'\n')
