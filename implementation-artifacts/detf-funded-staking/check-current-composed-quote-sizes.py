from pathlib import Path
import json,datetime
names=['UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet','UniswapV4StandardExchangeWeightedBufferHookHooksFacet','UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet','UniswapV4StandardExchangeOrbitalBufferHookHooksFacet']
rows=[]
for name in names:
 p=Path('out')/(name+'.sol')/(name+'.json');x=json.loads(p.read_text());bytecode=x['deployedBytecode']['object'];n=(len(bytecode)-2)//2 if bytecode.startswith('0x') else len(bytecode)//2
 rows.append({'contract':name,'artifact':str(p),'runtime_bytes':n,'eip170_limit':24576,'within_limit':n<=24576})
r={'checked_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'note':'Run only after successful build for current production sources; not a substitute for actual proxy/delegate validation.','rows':rows}
Path('implementation-artifacts/detf-funded-staking/current-composed-quote-runtime-sizes.json').write_text(json.dumps(r,indent=2)+'\n')
for row in rows:print(row['contract'],row['runtime_bytes'],row['within_limit'])
