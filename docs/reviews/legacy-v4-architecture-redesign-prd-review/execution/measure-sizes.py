from pathlib import Path
import json,sys
names=['ERC20Facet','ERC5267Facet','ERC2612Facet','MultiAssetBasicVaultFacet','MultiAssetStandardVaultFacet']+['UniswapV4StandardExchange'+s+'Facet' for s in ['Callback','In','InQuery','PositionImport','Out','OutQuery','LiquidReserve','InMulti','InMultiQuery','OutMulti','OutMultiQuery']]
rows=[]
for name in names:
 path=Path('out')/(name+'.sol')/(name+'.json');artifact=json.loads(path.read_text());obj=artifact['deployedBytecode']['object'];size=len(obj.removeprefix('0x'))//2
 rows.append({'facet':name,'runtime_bytes':size,'hard_limit':24576,'advisory_limit':23000,'artifact':str(path)})
 print(f'{name}: {size} bytes'+(' — HARD LIMIT EXCEEDED' if size>24576 else ' — advisory exceeded' if size>23000 else ''))
Path('.scratch/legacy-v4-redesign/sizes.json').write_text(json.dumps(rows,indent=2)+'\n')
raise SystemExit(1 if any(r['runtime_bytes']>24576 for r in rows) else 0)
