"""Build and validate actual Lido projections on a pinned read-only Ethereum fork."""
from pathlib import Path
import os,subprocess,time,json,shutil,re
from build_provenance import capture
art=Path(__file__).resolve().parent;root=art.parent.parent
cache=art/'lido-fork-validation-cache';cache.mkdir(exist_ok=True)
if not (cache/'solidity-files-cache.json').exists():shutil.copy2(art/'lido-validation-cache/solidity-files-cache.json',cache/'solidity-files-cache.json')
env=os.environ.copy();env.update(FOUNDRY_PROFILE='fork',FOUNDRY_TEST='test/foundry/fork/eth_main/staking/ethereum/LidoService_Fork.t.sol',FOUNDRY_SCRIPT='contracts/vaults/detf/common/core',FOUNDRY_CACHE_PATH=str(cache))
record={'provenance':capture(root),'profile':'fork','test_source':env['FOUNDRY_TEST'],'pinned_ethereum_block':24000000,'broadcast':False,'cache':'Independent warmed metadata; canonical out/'}
commands=[('build',['forge','build','--offline','--contracts','contracts/vaults/detf/common/core']),('test',['forge','test','--offline','--contracts','contracts/vaults/detf/common/core','--match-contract','^LidoStandardExchangeProjectionFork$','--etherscan-api-key','','--threads','1','-vvv'])]
for phase,command in commands:
 log=art/('lido-live-projection-fork-'+phase+'.log');start=time.monotonic()
 fd=os.open(str(log),os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
 with os.fdopen(fd,'w') as out:result=subprocess.run(command,cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT)
 record[phase]={'exit_code':result.returncode,'seconds':round(time.monotonic()-start,3),'command':command};(art/'lido-live-projection-fork-run.json').write_text(json.dumps(record,indent=2)+'\n')
 print(phase,json.dumps(record[phase]),flush=True)
 lines=log.read_text().splitlines();selected=[line for line in lines if line.startswith(('Compiling ','Solc ','Compiler run ','No files changed','[PASS]','[FAIL','Suite result:','Ran '))]
 print(re.sub(r'https?://[^\s\"\']+','<rpc endpoint>', '\n'.join(selected)[-2500:]),flush=True)
 if result.returncode:raise SystemExit(result.returncode)
