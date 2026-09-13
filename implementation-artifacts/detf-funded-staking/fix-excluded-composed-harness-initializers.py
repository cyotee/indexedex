"""Match excluded legacy harness initialization to surviving storage, like its existing TestBase."""
from pathlib import Path
import re,json,shutil,datetime
root=Path(__file__).resolve().parents[2];art=Path(__file__).resolve().parent
for ext in ('json','log'):shutil.copy2(art/('implementation-full-build.'+ext),art/('full-build-legacy-harness-initializer-failure.'+ext))
changes=[]
base=root/'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common'
for p in base.glob('*.t.sol'):
 s=p.read_text();before=s
 for method in ('_initializePricing','_initializeExchangeIn'):
  pattern='ComposedStableCommonDetfRepo.'+method+'('
  while pattern in s:
   start=s.index(pattern);cur=start+len(pattern);end=cur;depth=1
   while depth:
    if s[end]=='(':depth+=1
    elif s[end]==')':depth-=1
    end+=1
   text=s[cur:end-1];args=[];depth=0;last=0
   for i,c in enumerate(text):
    if c in '([':depth+=1
    elif c in ')]':depth-=1
    elif c==',' and depth==0:args.append(text[last:i].strip());last=i+1
   args.append(text[last:].strip());assert s[end]==';'
   lines=['// D60 compilation maintenance: populate the surviving fixture fields.','ComposedStableCommonDetfRepo.Storage storage legacyFixture_ = ComposedStableCommonDetfRepo._layoutStruct();'] if method=='_initializePricing' else []
   if method=='_initializePricing':
    assert len(args)==12,(p,args)
    fields={'reservePool':'CurrentWeightedPool(address('+args[0]+'))','bondNftVault':args[1],'rebasingDetfToken':'IStakedDETF(address('+args[2]+'))','stablePool':'IStablePool(address('+args[4]+'))','commonPool':'IStablePool(address('+args[5]+'))','rateAsset':args[6],'stablePoolExitPricer':args[7],'commonPoolExitPricer':args[8],'detfIndex':args[9],'stablePoolBptIndex':args[10],'commonPoolBptIndex':args[11]}
   else:
    assert len(args)==10,(p,args)
    fields={'balancerV3Router':args[1],'stablePool':args[2],'commonPool':args[3],'feeOracle':args[5],'mintThreshold':args[6],'burnThreshold':args[7]}
   lines.extend('legacyFixture_.'+key+' = '+value+';' for key,value in fields.items())
   if method=='_initializeExchangeIn':lines.extend(['delete legacyFixture_.routes;','for (uint256 i; i < '+args[9]+'.length; ++i) legacyFixture_.routes.push('+args[9]+'[i]);'])
   s=s[:start]+'\n        '.join(lines)+s[end+1:]
 if s!=before:
  anchor=re.search(r'pragma solidity [^;]+;',s).end()
  imports='\nimport {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";\nimport {IWeightedPool as CurrentWeightedPool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";\n'
  assert 'import {IStakedDETF}' not in s
  s=s[:anchor]+imports+s[anchor:];p.write_text(s);changes.append(str(p.relative_to(root)))
(art/'excluded-composed-harness-initialization-compatibility.json').write_text(json.dumps({'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'APPLIED_AWAITING_FULL_BUILD','scope':'D60 test fixture compilation maintenance only; existing fixture pattern; no production change or new economics','files':changes},indent=2)+'\n')
print('Updated',len(changes),'excluded harnesses')
