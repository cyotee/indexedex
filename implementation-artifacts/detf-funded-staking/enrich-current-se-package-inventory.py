"""Record source-backed native SY models and package wiring without claiming execution."""
from pathlib import Path
import json,re,hashlib,datetime
root=Path(__file__).resolve().parents[2]; art=Path(__file__).resolve().parent
path=art/'current-se-package-inventory.json'; data=json.loads(path.read_text())
shared='contracts/vaults/standard/sy/NativeStandardYieldTarget.sol'
models={
 'UniswapV2StandardExchangeDFPkg':'contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol',
 'CamelotV2StandardExchangeDFPkg':'contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol',
 'AerodromeStandardExchangeDFPkg':'contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol',
 'UniswapV3StandardExchangeDFPkg':'contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutQueryTarget.sol',
 'UniswapV4StandardExchangeDFPkg':'contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol',
 'UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg':'contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol',
 'UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg':'contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol',
 'UniswapV4StandardExchangeOrbitalBufferHookDFPkg':'contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol',
 'UniswapV4StandardExchangeWeightedBufferHookDFPkg':'contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol',
 'UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg':'contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.sol',
 'UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg':'contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget.sol',
 'ERC4626StandardExchangeDFPkg':'contracts/vaults/standard/erc4626/ERC4626StandardYieldTarget.sol',
 'AaveV3StataStandardExchangeDFPkg':'contracts/protocols/lending/aave/v3.6/AaveV3StataStandardYieldTarget.sol',
 'AaveCrossVersionLoopDFPkg':'contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol',
 'MorphoBlueStandardExchangeDFPkg':'contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardYieldTarget.sol',
 'LidoWstETHStandardExchangeDFPkg':'contracts/protocols/staking/lido/LidoWstETHStandardYieldTarget.sol',
 'EtherFiWeETHStandardExchangeDFPkg':'contracts/protocols/staking/etherfi/EtherFiWeETHStandardYieldTarget.sol',
 'RocketPoolRETHStandardExchangeDFPkg':'contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardYieldTarget.sol',
}
def functions(source,names):
 s=(root/source).read_text();out=[]
 for name in names:
  for m in re.finditer(r'\bfunction\s+'+name+r'\s*\(',s):
   start=s.find('{',m.end()); semi=s.find(';',m.end())
   if start<0 or (semi>=0 and semi<start):continue
   depth=1;i=start+1
   while depth:
    if s[i]=='{':depth+=1
    elif s[i]=='}':depth-=1
    i+=1
   out.append(dict(function=name,path=source,line=s.count('\n',0,m.start())+1,source=s[m.start():i]))
 return out
for row in data['rows']:
 p=root/row['path']; row['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
 if row['disposition']!='in-scope SE share issuer':continue
 model=models.get(row['package'])
 if model is None:
  assert '/balancer/v3/pools/' in row['path'],row['package']
  model='contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol'
 row['model_source']=model
 row['model_source_sha256']=hashlib.sha256((root/model).read_bytes()).hexdigest()
 row['route_asset_yield_and_conversion_definitions']=functions(model,['getTokensIn','getTokensOut','assetInfo','yieldToken','exchangeRate'])
 assert len(row['route_asset_yield_and_conversion_definitions'])==5,row['package']
 row['reward_surface']={'source':shared,'methods':'Empty accrued/index/claim arrays; native SY does not introduce a second separately distributed reward.','existing_external_rewards':'Existing Aave reward forwarding to the fee recipient is retained.' if row['package']=='AaveV3StataStandardExchangeDFPkg' else 'Existing protocol fee realization, reserve interest and compounding remain on their pre-existing routes; native SY uses the stated accounting rate.'}
 row['package_wiring_anchors']=[{k:v for k,v in x.items() if k!='source'} for x in functions(row['path'],['facetAddresses','facetInterfaces','facetCuts','diamondConfig','initAccount'])]
 row['factory_dependencies']=[str(x.relative_to(root)) for x in sorted(p.parent.glob('*FactoryService.sol'))]
 row['units']='Existing SE share decimals retained. Amounts use native token units; exchangeRate scales proportional accounting-asset entitlement per raw share by 1e18. Exact implementation and empty-supply behavior are pinned above.'
data['source_model_reconciled_at_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
data['model_method']='Source extraction with explicit model mapping, hashes and line anchors; actual assembled proxy validation is recorded separately. Routes are instance-dependent definitions, not fabricated deployment addresses.'
path.write_text(json.dumps(data,indent=2)+'\n')
print('Reconciled source models for',sum(r['disposition']=='in-scope SE share issuer' for r in data['rows']),'issuers')
