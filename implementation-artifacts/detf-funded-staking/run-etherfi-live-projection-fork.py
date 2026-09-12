"""Build and validate staking-provider projections on a pinned read-only fork."""
from pathlib import Path
import os,subprocess,time,json,shutil,re,argparse
from build_provenance import capture
art=Path(__file__).resolve().parent;root=art.parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--provider',choices=['etherfi','rocket','sfrxeth'],default='etherfi')
parser.add_argument('--rocket-block',type=int,choices=[24000000,25934585],default=24000000)
parser.add_argument('--label', help='Unique retry label; preserve the original run evidence.')
args=parser.parse_args()
provider=args.provider
is_etherfi=provider=='etherfi'
fork_block=args.rocket_block if provider=='rocket' else 24000000
label=provider+('-v4' if provider=='rocket' and fork_block==25934585 else '')
if args.label:
 assert re.fullmatch(r'[a-z0-9-]+', args.label)
 label += '-' + args.label
assert not (art/(label+'-live-projection-fork-run.json')).exists(), 'Preserve the completed attempt; choose a unique --label.'
source='contracts/protocols/staking/'+('etherfi' if is_etherfi else 'rocket-pool')
test_source='test/foundry/fork/eth_main/vaults/staking/'+('etherfi/EtherFiWeETHStandardExchange_Fork.t.sol' if is_etherfi else 'rocket-pool/RocketPoolRETHStandardExchange_Fork.t.sol')
contract='EtherFiStandardExchangeProjectionFork' if is_etherfi else 'RocketPoolStandardExchangeProjectionFork'
method_prefix='test_etherFiLive' if is_etherfi else 'test_rocketLive'
required_cases=5 if is_etherfi else 7
prefix='EtherFiWeETH' if is_etherfi else 'RocketPoolRETH'
components=[prefix+suffix for suffix in ['StandardExchangeInFacet','StandardExchangeOutFacet','MarkerFacet','RebalanceFacet','StandardExchangeDFPkg']]
if provider=='sfrxeth':
 source='contracts/vaults/standard/erc4626'
 test_source='test/foundry/fork/eth_main/vaults/standard/erc4626/ERC4626StandardExchange_SfrxETH_Fork.t.sol'
 contract='ERC4626StandardExchange_SfrxETH_ProjectionFork'
 method_prefix='test_sfrxProjection'
 required_cases=4
 components=['ERC4626StandardExchange'+suffix for suffix in ['InFacet','OutFacet','MarkerFacet','DFPkg']]
cache=art/(provider+'-fork-validation-cache');cache.mkdir(exist_ok=True)
if not (cache/'solidity-files-cache.json').exists():shutil.copy2(root/'cache_forge/solidity-files-cache.json',cache/'solidity-files-cache.json')
env=os.environ.copy();env.update(FOUNDRY_PROFILE='fork',FOUNDRY_TEST=test_source,FOUNDRY_SCRIPT='contracts/vaults/detf/common/core',FOUNDRY_CACHE_PATH=str(cache))
if provider=='rocket':env['ROCKET_QUOTE_FORK_BLOCK']=str(fork_block)
record={'provenance':capture(root),'provider':provider,'profile':'fork','test_source':env['FOUNDRY_TEST'],'pinned_ethereum_block':fork_block,'broadcast':False,'cache':'Independent warmed metadata; canonical out/'}
production=[source+'/'+name+'.sol' for name in components]
record_path=art/(label+'-live-projection-fork-run.json')
commands=[('build',['forge','build','--offline','--contracts',source]+production),('test',['forge','test','--offline','--contracts',source,'--match-contract','^'+contract+'$','--match-test','^'+method_prefix,'--etherscan-api-key','','--threads','1','-vvv'])]
for phase,command in commands:
 log=art/(label+'-live-projection-fork-'+phase+'.log');start=time.monotonic()
 fd=os.open(str(log),os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
 with os.fdopen(fd,'w') as out:result=subprocess.run(command,cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT)
 record[phase]={'exit_code':result.returncode,'seconds':round(time.monotonic()-start,3),'command':command};record_path.write_text(json.dumps(record,indent=2)+'\n')
 print(phase,json.dumps(record[phase]),flush=True)
 lines=log.read_text().split('Failing tests:',1)[0].splitlines();selected=[line for line in lines if line.startswith(('Compiling ','Solc ','Compiler run ','No files changed','[PASS]','[FAIL','Suite result:','Ran '))]
 print(re.sub(r'https?://[^\s\"\']+','<rpc endpoint>', '\n'.join(selected)[-2500:]),flush=True)
 if result.returncode:raise SystemExit(result.returncode)
 if phase == 'build':
  sizes={}
  for name in components:
   artifact=json.loads((root/'out'/(name+'.sol')/(name+'.json')).read_text())
   bytecode=artifact['deployedBytecode']['object'].removeprefix('0x')
   sizes[name]=len(bytecode)//2
  record[phase]['deployed_bytecode_bytes']=sizes
  record_path.write_text(json.dumps(record,indent=2)+'\n')
  if any(size == 0 or size > 24576 for size in sizes.values()):raise SystemExit('Staking provider components must have nonempty EIP-170-compliant runtime bytecode.')
 if phase == 'test':
  passed = sum(line.startswith('[PASS] '+method_prefix) for line in lines)
  record[phase]['executed_projection_cases'] = passed
  record[phase]['validation_passed'] = passed == required_cases
  record_path.write_text(json.dumps(record,indent=2)+'\n')
  if passed != required_cases:raise SystemExit('All '+str(required_cases)+' actual-protocol projection cases must execute and pass.')
