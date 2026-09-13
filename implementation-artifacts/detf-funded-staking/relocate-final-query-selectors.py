from pathlib import Path
import re,json,hashlib,datetime
root=Path.cwd(); changes=[]
def write(p,b,s):
 assert b!=s,p
 p.write_text(s);changes.append({'path':str(p.relative_to(root)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
b=root/'contracts/protocols/dexes/uniswap/v4'
p=b/'UniswapV4StandardExchangeOutMultiQueryTarget.sol';s=p.read_text();a=s.index('    function quoteState(');z=s.index('    function _standardRoute(',a);method=s[a:z];write(p,s,s[:a]+s[z:])
p=b/'UniswapV4StandardExchangeOutQueryTarget.sol';s=p.read_text();needle='    function previewExchangeOut(';write(p,s,s.replace(needle,method+needle,1))
p=b/'UniswapV4StandardExchangeOutMultiQueryFacet.sol';s=p.read_text();n=s.replace('import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\n','').replace('funcs = new bytes4[](2);','funcs = new bytes4[](1);').replace('        funcs[1] = IStandardExchangeTransitionQuote.quoteState.selector;\n','');write(p,s,n)
p=b/'UniswapV4StandardExchangeOutQueryFacet.sol';s=p.read_text();n=s.replace('import {IFacet}', 'import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {IFacet}',1).replace('new bytes4[](1)','new bytes4[](2)').replace('        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;','        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;\n        funcs[1] = IStandardExchangeTransitionQuote.quoteState.selector;');write(p,s,n)
p=root/'test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol';s=p.read_text();n=s.replace('import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\n','').replace('new bytes4[](18)','new bytes4[](17)').replace('        controlFuncs[1] = IStandardExchangeTransitionQuote.quoteState.selector;\n','')
for i in range(2,18):n=n.replace(f'controlFuncs[{i}]',f'controlFuncs[{i-1}]')
write(p,s,n)
# Move the unchanged geometry getter to an existing smaller query facet.
b=root/'contracts/hooks/uniswap/v4/standardExchange/orbital'
p=b/'UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol';s=p.read_text();a=s.index('    function radius(');z=s.index('\n    }',a)+6;method=s[a:z];write(p,s,s[:a]+s[z:])
p=b/'UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget.sol';s=p.read_text();n=s.replace('import {UniswapV4StandardExchangeOrbitalBufferHookDepositCore}', 'import {UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";\nimport {UniswapV4StandardExchangeOrbitalBufferHookDepositCore}',1).replace('    function previewAddLiquidity(',method+'\n\n    function previewAddLiquidity(',1);write(p,s,n)
p=b/'facets/UniswapV4StandardExchangeOrbitalBufferHookHooksFacet.sol';s=p.read_text();m=re.search(r'^\s*funcs\[(\d+)\] = [^\n]*\.radius.selector;\n',s,re.M);assert m;idx=int(m[1]);n=s[:m.start()]+s[m.end():];a=re.search(r'funcs = new bytes4\[\]\((\d+)\);',n);count=int(a[1]);n=n[:a.start(1)]+str(count-1)+n[a.end(1):]
for i in range(idx+1,count):n=n.replace(f'funcs[{i}]',f'funcs[{i-1}]')
write(p,s,n)
p=b/'facets/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet.sol';s=p.read_text();n=s.replace('funcs = new bytes4[](8);','funcs = new bytes4[](9);').replace('        funcs[7] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;', '        funcs[7] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;\n        funcs[8] = IUniswapV4StandardExchangeOrbitalBufferHook.radius.selector;');write(p,s,n)
a=root/'implementation-artifacts/detf-funded-staking';(a/'final-query-selector-relocations.json').write_text(json.dumps({'status':'APPLIED_VALIDATION_PENDING','recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'reason':'Actual leaf build measured V4 OutMultiQuery 26,794 bytes and Orbital Hooks 24,608. Put snapshot on existing OutQuery which already uses inventory snapshots for exact withdrawals; move unchanged radius view to an existing smaller query facet. Assembled proxy selectors and behavior remain unchanged.','files':changes},indent=2)+'\n');print(len(changes),'files updated')
