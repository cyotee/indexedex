from pathlib import Path
import argparse,re,json,datetime
from build_provenance import capture, readiness_provenance_matches
parser=argparse.ArgumentParser()
parser.add_argument('--require-current',action='store_true')
args=parser.parse_args()
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking';p=a/'current-se-package-inventory.json';x=json.loads(p.read_text())
mapping={
'UniswapV2StandardExchangeDFPkg':['UniswapV2NativeSYTest'],
'UniswapV3StandardExchangeDFPkg':['V3FullRangeNativeSYTest','UniswapV3StandardExchange_Import_Test'],
'UniswapV4StandardExchangeDFPkg':['UniswapV4StandardExchange_FullRangeBook'],
'CamelotV2StandardExchangeDFPkg':['CamelotV2NativeSYTest'],
'AerodromeStandardExchangeDFPkg':['AerodromeNativeSYTest'],
'UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg':['SingleConstantProductHookNativeSYTest','SingleConstantProductHookRestrictedSYTest'],
'UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg':['DualBufferHookLiquidityRegressionTest'],
'UniswapV4StandardExchangeOrbitalBufferHookDFPkg':['UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi'],
'UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg':['BalancerStableBufferHookNativeSYTest'],
'UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg':['CurveQuadBufferHookNativeSYTest','CurveQuadBufferHookRestrictedSYTest'],
'UniswapV4StandardExchangeWeightedBufferHookDFPkg':['WeightedBufferHookNativeSYTest','WeightedBufferHookRestrictedSYTest'],
'BalancerV3ConstantProductPoolStandardVaultPkg':['BalancerConstantProductPoolNativeSYTest'],
'StandardExchangeBufferPoolStandardVaultPkg':['BalancerCpBufferPoolNativeSYTest'],
'CommonBufferMultiVaultStablePoolStandardVaultPkg':['BalancerCommonStablePoolNativeSYTest'],
'MixedBufferMultiVaultStablePoolStandardVaultPkg':['BalancerMixedStablePoolNativeSYTest'],
'CommonBufferMultiVaultWeightedPoolStandardVaultPkg':['BalancerCommonWeightedPoolNativeSYTest'],
'MixedLegWeightedBufferPoolStandardVaultPkg':['BalancerMixedLegPoolNativeSYTest'],
'MultiPairStandardExchangeBufferPoolStandardVaultPkg':['BalancerMultiPairPoolNativeSYTest'],
'ERC4626StandardExchangeDFPkg':['RebasingClaimTokenDFPkg_Deploy_Test'],
'AaveV3StataStandardExchangeDFPkg':['AaveStataNativeSYTest'],
'AaveCrossVersionLoopDFPkg':['AaveCrossVersionLoopE2E_Test'],
'MorphoBlueStandardExchangeDFPkg':['MorphoBlueNativeSYTest'],
'LidoWstETHStandardExchangeDFPkg':['LidoNativeSYTest'],
'EtherFiWeETHStandardExchangeDFPkg':['EtherFiNativeSYTest'],
'RocketPoolRETHStandardExchangeDFPkg':['RocketPoolNativeSYTest']}
wanted={name for v in mapping.values() for name in v};sources={}
for f in (r/'test/foundry/spec').rglob('*.sol'):
 if 'slipstream' in str(f).lower():continue
 s=f.read_text()
 for name in re.findall(r'^contract (\w+)\s',s,re.M):
  if name in wanted:sources[name]=str(f.relative_to(r))
evidence={name:[] for name in wanted};header=re.compile(r'Ran \d+ tests? for (.*):(\w+)');summary=re.compile(r'Suite result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) skipped;')
current=capture(r)
completed=json.loads((a/'implementation-hermetic-test.json').read_text())
build=json.loads((a/'implementation-full-build.json').read_text())
fingerprints=('source_and_config_sha256','crane_head',
 'crane_tracked_contract_and_config_diff_sha256','crane_source_and_config_sha256','forge_version')
matched_current=(readiness_provenance_matches(r,current,completed.get('provenance',{}))
 and all(build.get('provenance',{}).get(key)==current[key] for key in fingerprints)
 and build.get('exit_code')==0 and completed.get('exit_code')==0)
if args.require_current:
 assert matched_current,'Complete matching current full build and unfiltered tests before final reconciliation.'
# Scan recorded suite summaries only. Do not infer passing behavior from declarations.
logs=[a/'implementation-hermetic-test.log'] if args.require_current else sorted(a.glob('*test.log'))
for log in logs:
 if log.name=='funded-suite-test.log':continue
 name=None
 with log.open(errors='replace') as stream:
  for line in stream:
   if line.startswith('Failing tests:'):break
   if line.startswith('Ran '):
    match=header.match(line.strip());name=match[2] if match and match[2] in wanted else None
   elif name and line.startswith('Suite result:'):
    m=summary.match(line.strip())
    if m:evidence[name].append({'log':str(log.relative_to(r)),'passed':int(m[2]),'failed':int(m[3]),'skipped':int(m[4]),'current_full_run':matched_current and log.name=='implementation-hermetic-test.log'})
    name=None
for row in x['rows']:
 package=row['package']
 if package not in mapping:continue
 row['proxy_validation_suites']=[{'contract':name,'source':sources.get(name),'recorded_runs':evidence[name]} for name in mapping[package]]
 row['current_proxy_runtime_passed']=all(any(v.get('current_full_run') and v['passed']>0 and v['failed']==0 and v['skipped']==0 for v in evidence[name]) for name in mapping[package])
 row['runtime_evidence']='Matching current full-run actual proxy suites pass.' if row['current_proxy_runtime_passed'] else 'Concrete proxy suites mapped; historical selected results do not establish current full-run acceptance.'
missing_current=[name for name in sorted(wanted) if not any(v.get('current_full_run') and v['passed']>0 and v['failed']==0 and v['skipped']==0 for v in evidence[name])]
x['evidence_reconciled_at_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
x['status']='All 25 concrete SE issuers have matching current full-run proxy evidence.' if not missing_current else '25 concrete SE issuers mapped; current full-run proxy validation incomplete.'
x['proxy_evidence_provenance']=current
x['proxy_execution_provenance']=completed['provenance']
x['source_reuse_evidence']='production-readiness/pr08-script-only-evidence-reuse.json' if completed['provenance']['source_and_config_sha256'] != current['source_and_config_sha256'] else None
x['proxy_suites_missing_current_all_pass_result']=missing_current
p.write_text(json.dumps(x,indent=2)+'\n')
print('issuers',len(mapping),'concrete suites',len(wanted),'missing test sources',sorted(wanted-sources.keys()))
print('suites without historical all-pass summary',[name for name in sorted(wanted) if not any(v['failed']==0 for v in evidence[name])])
(a/'all-native-se-match-contract.txt').write_text('^('+'|'.join(sorted(wanted))+')$\n')
if args.require_current:
 assert not (wanted-sources.keys()),'Every mapped proxy suite must have current source.'
 assert not missing_current,missing_current
