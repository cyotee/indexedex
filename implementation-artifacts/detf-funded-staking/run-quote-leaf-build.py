from pathlib import Path
import os,json,subprocess,time,shutil
from build_provenance import capture
art=Path(__file__).resolve().parent;root=art.parent.parent
env=os.environ.copy();env['FOUNDRY_PROFILE']='default';env['FOUNDRY_TEST']='contracts/interfaces';env['FOUNDRY_SCRIPT']='contracts/interfaces'
# A narrow source graph can prune Foundry cache entries for omitted units. Keep
# this development compile's metadata separate, seeded only when no Forge runs.
# Actual artifacts remain in the canonical out/ used by FactoryServices.
leaf_cache=art/'quote-leaf-cache'
if not leaf_cache.exists():
    shutil.copytree(root/'cache_forge', leaf_cache)
env['FOUNDRY_CACHE_PATH']=str(leaf_cache)

paths=['contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol','contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderFacet.sol','contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol']
paths += json.loads(os.environ.get('QUOTE_LEAF_EXTRA', '[]'))
cmd=['forge','build','--offline']+paths
record={'provenance':capture(root),'command':cmd,'scope':'Selected provider facets only; not full build or validation','environment':{k:env[k] for k in ('FOUNDRY_PROFILE','FOUNDRY_TEST','FOUNDRY_SCRIPT')}}
start=time.monotonic()
with (art/'quote-leaf-build.log').open('w') as log:r=subprocess.run(cmd,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
record.update(exit_code=r.returncode,seconds=round(time.monotonic()-start,3));(art/'quote-leaf-build.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'exit_code':r.returncode,'seconds':record['seconds']}),flush=True);print((art/'quote-leaf-build.log').read_text()[-4500:],flush=True);raise SystemExit(r.returncode)
