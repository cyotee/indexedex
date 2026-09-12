from pathlib import Path
import json,datetime
rows=[]
current={p.stem for p in Path('contracts/protocols/dexes/uniswap/v4').glob('*.sol')}
for p in sorted(Path('out').glob('UniswapV4StandardExchange*.sol/*.json')):
 name=p.stem
 if name not in current:continue # out/ deliberately retains retired artifacts.
 if not (name.endswith('Facet') or name.endswith('Delegate') or name.endswith('DFPkg')):continue
 artifact=json.loads(p.read_text());code=artifact.get('deployedBytecode',{}).get('object','').removeprefix('0x')
 if not code:continue
 size=len(code)//2
 rows.append({'contract':name,'artifact':str(p),'runtime_bytes':size,'eip170_limit':24576,'within_limit':size<=24576})
record={'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Current compiled V4 SE facets, execution delegates and package; run only after successful current-source build.','rows':rows}
Path('implementation-artifacts/detf-funded-staking/current-v4-se-runtime-sizes.json').write_text(json.dumps(record,indent=2)+'\n')
for row in rows:print(row['contract'],row['runtime_bytes'],'PASS' if row['within_limit'] else 'FAIL')
raise SystemExit(0 if all(row['within_limit'] for row in rows) else 1)
