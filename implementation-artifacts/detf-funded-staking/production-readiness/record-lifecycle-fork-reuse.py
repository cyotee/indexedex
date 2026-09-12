from pathlib import Path
from datetime import datetime,timezone
import json,hashlib,sys
from Crypto.Hash import keccak
root=Path.cwd();art=root/'implementation-artifacts/detf-funded-staking';d=art/'production-readiness';before=d/'before-lifecycle-production-fixes';sys.path.insert(0,str(art))
from build_provenance import capture,readiness_provenance_matches
prior=json.loads((before/'release-source-manifest.json').read_text());current=capture(root)
changes=[]
for row in prior['solidity_and_config']:
 p=root/row['path'];sha=hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
 if sha!=row['sha256']:changes.append(dict(path=row['path'],prior_sha256=row['sha256'],current_sha256=sha))
expected={'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol','contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol','test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Liquidity.t.sol','test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol'}
assert {r['path'] for r in changes}==expected,changes
closure_rows=[];closure={}
for row in json.loads((before/'fork-closures/index.json').read_text()):
 p=before/'fork-closures'/row['metadata_file'];m=json.loads(p.read_text())
 for name,entry in m['sources'].items():
  actual='0x'+keccak.new(digest_bits=256,data=(root/name).read_bytes()).hexdigest()
  assert actual==entry['keccak256'],name
  closure[name]=dict(keccak256=actual,sha256=hashlib.sha256((root/name).read_bytes()).hexdigest())
 closure_rows.append(dict(**row,metadata_path=str(p.relative_to(root)),metadata_sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
assert set(closure).isdisjoint(expected)
evidence=[]
for relative in ['production-readiness/provider-renewal-core-final/run.json','v3-retained-live-pool-production-readiness-run.json']:
 p=art/relative;r=json.loads(p.read_text())
 launch=json.loads((d/'pr08-script-only-evidence-reuse.json').read_text())
 harness=json.loads((d/'rehearsal-import-evidence-reuse.json').read_text())
 assert launch['status']=='PASS_UNCHANGED_EXECUTION_SOURCE_CLOSURES'
 assert harness['status']=='PASS_UNCHANGED_NON_REHEARSAL_SOURCE_CLOSURES'
 keys=('source_and_config_sha256','crane_head','crane_tracked_contract_and_config_diff_sha256','crane_source_and_config_sha256','forge_version')
 assert all(r['provenance'][k]==launch['prior_provenance'][k] for k in keys)
 assert all(launch['provenance'][k]==harness['prior_provenance'][k] for k in keys)
 assert all(harness['provenance'][k]==prior['provenance'][k] for k in keys)
 assert all(current[k]==prior['provenance'][k] for k in keys if k!='source_and_config_sha256')
 assert hashlib.sha256((before/'RobinhoodReleaseRehearsal.t.sol.txt').read_bytes()).hexdigest()==harness['changed_sources'][0]['current_sha256']
 assert hashlib.sha256((root/launch['changed_sources'][0]['path']).read_bytes()).hexdigest()==launch['changed_sources'][0]['current_sha256']
 if 'provider-' in relative:
  assert r['status']=='PASS_ALL_27_PROVIDER_CASES';passed=27
  for step in r['steps']:
   assert step['exit_code']==0 and step['validation_passed'] and not step['changed_fingerprints']
   assert hashlib.sha256((root/step['log']).read_bytes()).hexdigest()==step['log_sha256']
 else:
  assert r['status']=='PASS_ALL_EIGHT_RETAINED_CASES' and r['sources_unchanged'];passed=8
  assert r['test']['passed']==8 and r['test']['failed']==0
 evidence.append(dict(path=str(p.relative_to(root)),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),provenance=r['provenance'],passed=passed))
record=dict(status='PASS_UNCHANGED_PROVIDER_AND_V3_FORK_DEPENDENCIES',recorded_at_utc=datetime.now(timezone.utc).isoformat(),provenance=current,prior_inventory_provenance=prior['provenance'],changed_existing_sources=changes,added_regression='test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol',verified_prior_source_files=len(prior['solidity_and_config']),fork_suites=closure_rows,source_closure=closure,evidence=evidence,dynamic_creation_code_disposition='The only changed production sources are the V4 DETF common and Orbital hook math. Retained forks deploy provider SEs or Uniswap V3 SEs and shared core, which do not use these two sources. Their test/FactoryService source closures and the complete earlier source inventory are verified unchanged; the updated full production build remains independently required.',limitations='Reuse is restricted to these exact two passing fork records. This is not a full-suite, changed production-path or current local package deployment pass.')
p=d/'lifecycle-fork-evidence-reuse.json';assert not p.exists();p.write_text(json.dumps(record,indent=2)+'\n');print(len(closure), 'unchanged fork dependency files; 35 prior passing cases reusable.')
