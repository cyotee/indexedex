"""Record compiled funded surfaces and explicit standard-route replacements.

Runtime artifacts and source hashes are independent evidence. Run after final
build for final acceptance; this file never treats ABI presence as proxy wiring.
"""
from pathlib import Path
import hashlib,json,datetime,re,sys
from Crypto.Hash import keccak
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking'
roots=[r/'contracts/vaults/detf/common',r/'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf',r/'contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft']
rows=[]
source_hashes={}
def compiler_source_check(artifact):
 metadata=artifact.get('metadata') or json.loads(artifact['rawMetadata'])
 if isinstance(metadata,str):metadata=json.loads(metadata)
 mismatches=[]
 for source,entry in metadata['sources'].items():
  path=r/source
  if source not in source_hashes:
   in_workspace=not Path(source).is_absolute() or path.is_relative_to(r)
   source_hashes[source]='0x'+keccak.new(digest_bits=256,data=path.read_bytes()).hexdigest() if in_workspace and path.is_file() else None
  actual=source_hashes[source]
  if actual!=entry['keccak256']:
   mismatches.append({'source':source,'compiled_keccak256':entry['keccak256'],'current_keccak256':actual})
 return {'checked_sources':len(metadata['sources']),'matches_current_source':not mismatches,'mismatches':mismatches}
for root in roots:
 for p in sorted(root.rglob('*.sol')):
  if not p.stem.endswith(('Facet','DFPkg')) or p.stem.startswith('I'):continue
  art=r/'out'/p.name/(p.stem+'.json')
  if not art.exists():continue
  d=json.loads(art.read_text());src=p.read_text()
  methods=d.get('methodIdentifiers',{})
  rows.append({'contract':p.stem,'source':str(p.relative_to(r)),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'artifact':str(art.relative_to(r)),'artifact_sha256':hashlib.sha256(art.read_bytes()).hexdigest(),'runtime_bytes':len(d['deployedBytecode']['object'].removeprefix('0x'))//2,'direct_inheritance':re.findall(r'\bcontract\s+\w+\s+is\s+([^\{]+)\{',src),'compiled_signatures':[{'signature':k,'selector':'0x'+v} for k,v in sorted(methods.items())],'abi_entrypoints':[{'name':x['name'],'stateMutability':x.get('stateMutability'),'inputs':x['inputs'],'outputs':x.get('outputs',[])} for x in d['abi'] if x['type']=='function']})
  rows[-1]['source_kind']='abstract metadata base; inherited by active facets' if re.search(r'\babstract\s+contract\s+'+re.escape(p.stem)+r'\b',src) else 'deployable facet or package'
  rows[-1]['compiler_source_check']=compiler_source_check(d)
replacements=[
 {'old':'Standalone fungible mint/burn','new':'exchangeIn(tokenIn,amountIn,tokenOut,minAmountOut,recipient,pretransferred,deadline); token pair selects direction','owner':'DETF diamond','preserved':'Mandatory primary gate selects issuance/redemption or actual reserve swap; standard previews use same route.'},
 {'old':'mintClaim/buyClaim/redeemClaim and standalone stake/unstake','new':'IStandardExchangeIn and IStandardExchangeOut with DETF/sDETF or configured composed route','owner':'DETF and sDETF diamonds','preserved':'Actually held DETF funds 1:1 direct stake/unstake; output limits apply to final output.'},
 {'old':'LP-valued NFT mintFromNFTSale, sale and close variants','new':'claimPrincipal(tokenId,to), claimRewards(tokenId,to), claimBond(tokenId,to)','owner':'Funded bond NFT diamond','preserved':'Transfer attributable escrow sDETF; principal vests linearly; rewards remain separately claimable. No LP unwind.'},
 {'old':'LP-dependent rebasing rate/cache refresh','new':'stakingState/gonsOf and funded reward synchronization','owner':'sDETF diamond / authorized DETF reward entry','preserved':'Funded index and backing only; no spot NAV rebase.'},
 {'old':'No Pendle surface','new':'Pendle deposit/redeem, previews, directional discovery, exchangeRate, assetInfo/yieldToken and reward methods','owner':'Separate raw-DETF and static staking SY diamonds; native SE adapters at existing SE share addresses','preserved':'Nine decimals for DETF wrappers; actual existing decimals for other SE shares.'},
 {'old':'closeRouteMode/closeRoutes PkgArgs, getters and storage','new':None,'owner':'Removed from V4 new deployment schemas, callers, selectors and storage','preserved':'Ordinary output route tables and funded NFT claims remain.'}
]
record={'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'CURRENT_ARTIFACT_INVENTORY_FINAL_BUILD_AND_PROXY_RECONCILIATION_PENDING','scope':'Shared funded staking/bond/SY and unified V4 facets/packages; Balancer DETF exclusion and Slipstream deferral preserved. ABI lists include inherited methods beyond each installed cut; actual proxy exports must be checked against facetFuncs and DFPkg cuts in production-path tests.','replacements':replacements,'rows':rows,'runtime_wiring_tests':['test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol','test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_Surface.t.sol','test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault_Surface.t.sol','test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_FacetPackaging.t.sol','test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_BondNftPackaging.t.sol'],'cleanup_evidence':'approved-close-cleanup-surface.json'}
(a/'current-funded-selector-manifest.json').write_text(json.dumps(record,indent=2)+'\n')
stale=[row['contract'] for row in rows if not row['compiler_source_check']['matches_current_source']]
print(len(rows),'compiled funded facet/package records;',len(stale),'await current-source compilation')
if '--require-current' in sys.argv:
 assert not stale, 'Stale compiled source closures: '+', '.join(stale)
 assert all(0<row['runtime_bytes']<=24576 for row in rows if row['source_kind']=='deployable facet or package'), 'Invalid deployable runtime size'
