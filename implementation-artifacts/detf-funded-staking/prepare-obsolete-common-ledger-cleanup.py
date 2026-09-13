"""Prepare the owner's approved dead-ledger cleanup against current main files.

No canonical sources are changed. A later application must wait for the active
runtime parent to exit and verify every before hash again.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re, difflib
art=Path(__file__).resolve().parent
root=art.parent.parent
drafts=art/'obsolete-common-ledger-cleanup-drafts'
drafts.mkdir(exist_ok=False)
base='contracts/vaults/detf/common/'
retired=[base+'bondNft/DETFNFTVault'+name+'.sol' for name in ('Target','Common','Repo','Service')]
retired += [base+'core/'+name+'.sol' for name in ('DETFBondLifecycleLib','DETFProtocolCompoundLib')]
changes=[];patches=[]
def add(path,after,reason,action='update'):
 p=root/path;before=p.read_text();assert before!=after
 draft=drafts/(str(len(changes)).zfill(2)+'-'+p.name+'.txt');draft.write_text(after)
 changes.append({'path':path,'draft':str(draft.relative_to(root)),'reason':reason,'action':action,
  'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(after.encode()).hexdigest()})
 patches.extend(difflib.unified_diff(before.splitlines(True), ([] if action=='delete' else after.splitlines(True)),fromfile='a/'+path,tofile=('/dev/null' if action=='delete' else 'b/'+path)))
for path in retired:
 add(path,'// SPDX-License-Identifier: BSL-1.1\npragma solidity ^0.8.0;\n// Deleted obsolete LP-backed bond implementation.\n',
  'No installed facet, package, FactoryService, script or Balancer DETF uses this legacy implementation. The active NFT facet inherits DETFFundedBondTarget. Keep legacy public interfaces required by excluded families.', 'delete')
review=json.loads((art/'current-v4-unused-import-review.json').read_text())
for row in review['rows']:
 p=root/row['path'];s=p.read_text();assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256']
 unused={name for entry in row['unused_local_imports'] for name in entry['unused_names']}
 def keep(m):
  parts=[part.strip() for part in m[1].split(',') if part.strip().split(' as ')[-1] not in unused]
  return 'import {'+', '.join(parts)+'} from "'+m[2]+'";' if parts else ''
 after=re.sub(r'import\s*\{(.*?)\}\s*from\s*"([^"]+)";',keep,s,flags=re.S)
 after=re.sub(r'\n{3,}', '\n\n', after)
 if p.name=='UniswapV4DetfCommon.sol': after=after.replace('Shared gates, quotes, pull, sweep, expansion, compound.', 'Shared gates, quotes, pull, sweep and funded expansion.')
 add(row['path'],after,'Remove unused legacy imports; active funded route implementations and storage are preserved.')
pons=root/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons'
for p in sorted(pons.rglob('*.sol')):
 s=p.read_text();line='import {DETFNFTVaultCommon} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultCommon.sol";\n'
 if line not in s: continue
 assert len(re.findall(r'\bDETFNFTVaultCommon\b',s))==2
 add(str(p.relative_to(root)),s.replace(line,''),'Remove unused imported legacy common class; every Pons test and helper body is preserved.')
retirements=[]
for path in ('test/foundry/spec/saf/T10_DeadMembers.t.sol','test/foundry/spec/vaults/detf/common/core/DETFProtocolCompoundLib.t.sol'):
 s=(root/path).read_text();names=re.findall(r'\bfunction\s+(test\w*)\s*\(',s)
 anchors=[{'source':'test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVaultDFPkg_Deploy.t.sol','function':'test_positionPrincipalIsFundedOnceAndNotDerivedFromProtocolLp'},
 {'source':'test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVaultDFPkg_Deploy.t.sol','function':'test_rewardOnlyClaimIsImmediateAndDoesNotUnlockPrincipal'},
 {'source':'test/foundry/spec/vaults/detf/common/core/DETFFundedStakingMath.t.sol','function':'testFuzz_fundedRebaseConservation'},
 {'source':'test/foundry/spec/vaults/detf/common/core/DETFEpochNaturalExpansionLib.t.sol','function':'test_sevenDaysIncludesAll21EpochsWithoutCompounding'}]
 for entry in anchors: assert 'function '+entry['function']+'(' in (root/entry['source']).read_text()
 retirements.extend({'old_source':path,'old_function':name,'reason':'The old LP-harvest struct shape and compound dust gate have no production caller under funded staking. These checks preserve deleted functionality only; current funded custody, reward and epoch behavior is covered separately.', 'current_test_anchors':anchors} for name in names)
 add(path,'// SPDX-License-Identifier: BSL-1.1\npragma solidity ^0.8.0;\n\n// Obsolete LP-backed harvest/compound checks retired under funded staking.\n// See implementation-artifacts/detf-funded-staking/obsolete-common-ledger-test-consolidation.json.\n// Current funded NFT, staking-math and fixed-epoch suites retain behavior coverage.\n', 'Retire declarations that assert only deleted struct shapes or the obsolete LP compound dust gate. Explicit replacement/retirement mapping retained.')
p=root/'test/foundry/spec/oracles/fee/VaultFeeOracle_BondTermsFallback.t.sol';s=p.read_text();after=s.replace('Tests proving DETFNFTVaultTarget always delegates to the oracle.', 'Tests proving current bond terms delegate to the oracle.').replace('/// @notice DETFNFTVaultCommon._bondTerms() has different hardcoded values than the oracle.', '/// @notice The former NFT base used different hardcoded values than the oracle.').replace('// Verify these are NOT the DETFNFTVaultCommon base class values:', '// Verify these differ from the historical NFT base values:')
add(str(p.relative_to(root)),after,'Remove stale references to the retired common target; all fee-oracle assertions remain.')
# Validate the complete repository import boundary, including test-only imports.
changed={row['path'] for row in changes}
edges=[]
for directory in ('contracts','test','scripts','lib/crane/contracts','lib/crane/test'):
 for p in (root/directory).rglob('*.sol'):
  if not p.is_file(): continue
  for m in re.finditer(r'\bimport\s+(?:[^;]*?\s+from\s+)?["\']([^"\']+)["\']\s*;',p.read_text()):
   if any(m[1].endswith('/'+Path(path).name) or m[1]==Path(path).name for path in retired):
    path=str(p.relative_to(root));edges.append({'consumer':path,'import':m[1]});assert path in changed,(path,m[1])
fields=[];old=(root/(base+'bondNft/DETFNFTVaultRepo.sol')).read_text();block=re.search(r'struct Storage\s*\{(.*?)\n    \}',old,re.S)[1]
for line in block.splitlines():
 line=line.split('//',1)[0].strip()
 if line.endswith(';'): fields.append(line)
record={'status':'PREPARED_NOT_APPLIED','recorded_at_utc':datetime.now(timezone.utc).isoformat(),
 'approval':'v4-close-cleanup-owner-approval.json','authorization':'Owner-approved unused legacy close/storage cleanup and implementation plan A30; no additional approval is pending.',
 'gate':'Apply only after active gold runtime parent exits; preserve exact before copies and verify hashes.',
 'scope':'Unused common legacy ledger and lifecycle code only. No Balancer-hosted DETF or Slipstream functional changes; their remaining compatibility interfaces stay.',
 'correction_to_prior_inventory':'The claim that DETFNFTVaultRepo was an excluded-family compatibility dependency was incorrect. Current repository import edges show only this dead cluster, unused Pons imports and two obsolete test sources.',
 'removed_storage_members':fields,'import_edges':edges,'changes':changes}
(art/'obsolete-common-ledger-cleanup-prepared.json').write_text(json.dumps(record,indent=2)+'\n')
(art/'obsolete-common-ledger-cleanup.patch').write_text(''.join(patches))
(art/'obsolete-common-ledger-test-consolidation.json').write_text(json.dumps({'status':'PREPARED_NOT_APPLIED','approval':'v4-close-cleanup-owner-approval.json','retirements':retirements},indent=2)+'\n')
print(json.dumps({'sources':len(changes),'deleted_unused_sources':len(retired),'retired_storage_members':len(fields),'retired_test_declarations':len(retirements),'verified_import_edges':len(edges)}))
