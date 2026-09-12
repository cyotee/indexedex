"""Validate SE providers through their existing real registry/proxy fixtures."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,time
from build_provenance import capture,hermetic_environment
parser=argparse.ArgumentParser();parser.add_argument('--provider',choices=['camelot','aerodrome','uniswap-v2','erc4626'],default='camelot');parser.add_argument('--label',required=True);parser.add_argument('--checkpoints-only',action='store_true');parser.add_argument('--trace',action='store_true');args=parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+',args.label)
art=Path(__file__).resolve().parent;root=art.parent.parent
record_path=art/f'{args.provider}-{args.label}-run.json'
assert not record_path.exists(), 'Preserve the previous run; choose a new label.'
cache=art/(args.provider+'-provider-validation-cache');cache.mkdir(exist_ok=True)
if not (cache/'solidity-files-cache.json').exists():shutil.copy2(root/'cache_forge/solidity-files-cache.json',cache/'solidity-files-cache.json')
env,emptied=hermetic_environment(root);minimal='contracts/vaults/detf/common/core';source='test/foundry/spec/vaults/standard/sy/ConstantProductNativeSY.t.sol'
if args.provider == 'camelot':
 base='contracts/protocols/dexes/camelot/v2/'
 components=['CamelotV2StandardExchangeInFacet','CamelotV2StandardExchangeOutFacet','CamelotV2StandardExchangeDFPkg']
 if (root/(base+'CamelotV2StandardExchangeQueryFacet.sol')).exists():components.append('CamelotV2StandardExchangeQueryFacet')
 contract='CamelotV2NativeSYTest'
 pattern='^test_camelot(Checkpoint|LpPassThrough)' if args.checkpoints_only else '^test_(camelot|native|lpAccounting)'
 required=['test_camelotCheckpointTracksLiveBookAfterToken0Deposit','test_camelotCheckpointTracksLiveBookAfterToken1Deposit','test_camelotCheckpointTracksLiveBookAfterToken0Redemption','test_camelotCheckpointTracksLiveBookAfterToken1Redemption','test_camelotLpPassThroughPreviewMatchesExecution']
 minimum_cases=5 if args.checkpoints_only else 22
elif args.provider == 'aerodrome':
 assert not args.checkpoints_only, 'Checkpoint-only selection belongs to the Camelot baseline.'
 base='contracts/protocols/dexes/aerodrome/v1/'
 components=['AerodromeStandardExchangeInFacet','AerodromeStandardExchangeOutFacet','AerodromeStandardExchangeOutQueryFacet','AerodromeStandardExchangeDFPkg']
 contract='AerodromeNativeSYTest'
 pattern='^test_(aeroProjection|native|lpAccounting)'
 required=['test_aeroProjectionSelectorsAndComponentSizes','test_aeroProjectionSequentialBothAssetsAndCompoundedLpFees','test_aeroProjectionExternalDepositsAndLiveLpPayment','test_aeroProjectionExternalSwapsAndLpRedemptionPreserveOwnShares','test_aeroProjectionCompoundPaysActualLpWithoutIssuingSeFees','test_aeroProjectionDonationRemainsBackingBeforeLpPayment','test_aeroProjectionExternalLpBurnIncludesPoolHeldLpAndUnsyncedTokens']
 minimum_cases=37
elif args.provider == 'uniswap-v2':
 assert not args.checkpoints_only, 'Checkpoint-only selection belongs to the Camelot baseline.'
 base='contracts/protocols/dexes/uniswap/v2/'
 components=['UniswapV2StandardExchangeInFacet','UniswapV2StandardExchangeOutFacet','UniswapV2StandardExchangeQueryFacet','UniswapV2StandardExchangeDFPkg']
 contract='UniswapV2NativeSYTest'
 pattern='^test_(native|lpAccounting)'
 required=[]
 minimum_cases=8
else:
 assert not args.checkpoints_only, 'Checkpoint-only selection belongs to the Camelot baseline.'
 base='contracts/vaults/standard/erc4626/'
 source='test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol'
 components=['ERC4626StandardExchangeInFacet','ERC4626StandardExchangeOutFacet','ERC4626StandardExchangeMarkerFacet','ERC4626StandardExchangeDFPkg']
 contract='ERC4626StandardExchange_TransitionQuote'
 pattern='^test'
 required=['test_receiptAccounting_canonicalVirtualVaultSequence','test_receiptAccounting_sequentialDepositWithdrawalAndRedemption','test_receiptAccounting_externalUnderlyingAndReceiptDeposits','test_receiptAccounting_externalUnderlyingConversionPreservesReserve','testFuzz_receiptAccounting_sequenceWithYieldAndFeeRecipient','test_receiptAccounting_nestedErc4626DepositDoesNotChargeNestedSeUsageFee','test_receiptAccounting_exactOutputRetainsRoundingSurplus']
 minimum_cases=13
if args.provider != 'erc4626' and not args.checkpoints_only:
 required += ['test_lpAccountingSequentialCustodyWithAccruedFees','test_lpAccountingExternalDepositsPreserveBothLegsAndDonation','test_lpAccountingExternalConversionsRetainOwnLiquidity']
env.update(FOUNDRY_TEST=source,FOUNDRY_SCRIPT=minimal,FOUNDRY_CACHE_PATH=str(cache))
production=[base+name+'.sol' for name in components]
commands=[('build',['forge','build','--offline','--contracts',base.rstrip('/')]+production),('test',['forge','test','--offline','--contracts',base.rstrip('/'),'--match-contract','^'+contract+'$','--match-test',pattern,'-vvvv' if args.trace else '-vvv'])]
record={'provenance':capture(root),'provider':args.provider,'source':source,'scope':'Actual pool and SE registry/proxy; independent warmed cache, canonical out/. Full default validation remains separate.','explicitly_empty_rpc_environment_keys':emptied,'checkpoints_only':args.checkpoints_only}
for phase,command in commands:
 log=art/f'{args.provider}-{args.label}-{phase}.log';start=time.monotonic();fd=os.open(log,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
 with os.fdopen(fd,'w') as output:result=subprocess.run(command,cwd=root,env=env,stdout=output,stderr=subprocess.STDOUT)
 record[phase]={'command':command,'exit_code':result.returncode,'seconds':round(time.monotonic()-start,3)}
 lines=log.read_text(errors='replace').split('\nFailing tests:', 1)[0].splitlines()
 if phase=='test':
  results=[line for line in lines if line.startswith(('[PASS]','[FAIL'))]
  missing=[name for name in required if not any(re.search(r'\b'+name+r'\b',line) for line in results)]
  record[phase].update(executed_cases=len(results),missing_regressions=missing,validation_passed=result.returncode==0 and len(results)>=minimum_cases and not missing)
 if phase=='build' and result.returncode==0:
  sizes={}
  for name in components:
   artifact=json.loads((root/'out'/(name+'.sol')/(name+'.json')).read_text())
   sizes[name]=len(artifact['deployedBytecode']['object'].removeprefix('0x'))//2
  record[phase]['runtime_bytes']=sizes
  record[phase]['components_fit_eip170']=all(0<size<=24576 for size in sizes.values())
 record_path.write_text(json.dumps(record,indent=2)+'\n')
 print(phase,json.dumps({k:v for k,v in record[phase].items() if k!='command'}),flush=True)
 for i,line in enumerate(lines):
  if line.startswith(('Compiling ','Solc ','No files changed','[PASS]','[FAIL','Suite result:','Ran ')):print(line,flush=True)
  elif line.startswith('Error'):print('\n'.join(lines[i:i+8]),flush=True)
 if result.returncode:raise SystemExit(result.returncode)
 if phase=='build' and not record[phase]['components_fit_eip170']:raise SystemExit('Production components must fit EIP-170.')
 if phase=='test' and not record[phase]['validation_passed']:raise SystemExit('Required provider regressions did not all execute.')
