"""Move the old DETF ABI-double migration cases into the existing actual Pons/V4 fixture."""
from pathlib import Path
import re,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[2];ART=Path(__file__).resolve().parent
f=ROOT/'test/foundry/spec/protocols/staking/token'
def span(s,name):
 m=re.search(r'    function '+re.escape(name)+r'\(',s);assert m,name
 b=s.index('{',m.end());j=b+1;depth=1
 while depth:
  if s[j]=='{':depth+=1
  elif s[j]=='}':depth-=1
  j+=1
 return m.start(),j
p=f/'TokenStaking.t.sol';before=p.read_text();s=before
retired=['test_setTargetDetf_stores_address','test_migrate_wraps_claim_and_users_withdraw_rebasing_share',
 'test_migrate_amount_over_reserve_reverts','test_reassign_after_wrap','test_cannot_stake_after_migrate_starts',
 'test_completeWrap_after_partial_migrate','test_completeWrap_only_owner','_deployDetfStub']
for name in retired:
 i,j=span(s,name);s=s[:i]+s[j:]
i=s.index('/// @dev Non-SUT Uni V4 DETF ABI double');j=s.index('/// @dev Deferred:',i);s=s[:i]+s[j:]
records=[(p,before,s)]
p=f/'TokenStaking_PonsUv4Detf.t.sol';before=p.read_text();s=before
s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";\nimport {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";')
at=s.index('    function _assertRoutesHaveWethAndDtf(')
s=s[:at]+(ART/'pending-token-staking-migration-tests.txt').read_text()+'\n'+s[at:]
# Enhance the existing two-user chunked migration with actual funded rebase income.
i,j=span(s,'test_e2e_stake_dtf_migrate_chunks_withdraw_claim')
body=s[i:j]
needle='        address claim_ = detfInfo.rebasingClaimToken();'
assert needle in body
growth='''        _assertMigrationApprovalsCleared();
        address receiptBefore_ = detfInfo.rebasingClaimToken();
        uint256 vaultBacking_ = IERC20(receiptBefore_).balanceOf(address(staking.claimVault()));
        uint256 previewBefore_ = staking.previewClaim(detfUser, stakeAmt_);
        vm.prank(detfUser);
        detfInfo.bond(IERC20(launchToken), 10 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp);
        assertGt(IERC20(receiptBefore_).balanceOf(address(staking.claimVault())), vaultBacking_, "actual funded bond issuance rebases wrapping custody");
        assertGt(staking.previewClaim(detfUser, stakeAmt_), previewBefore_, "wrapped staker receives funded growth");
        uint256 previewA_ = staking.previewClaim(detfUser, stakeAmt_);
'''
body=body.replace(needle,growth+'\n'+needle)
body=body.replace('assertGt(outA_, 0, "A claim");','assertEq(outA_, previewA_, "A funded preview equals execution");')
body=body.replace('        vm.prank(stakerB);\n        uint256 outB_ = staking.withdrawClaim(stakeAmt_);','        uint256 previewB_ = staking.previewClaim(stakerB, stakeAmt_);\n        vm.prank(stakerB);\n        uint256 outB_ = staking.withdrawClaim(stakeAmt_);')
body=body.replace('assertGt(outB_, 0, "B claim");','assertEq(outB_, previewB_, "B funded preview equals execution");')
s=s[:i]+body+s[j:]
records.append((p,before,s))
for p,b,s in records:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-real-'+p.name+'.txt')).write_text(s)
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','mapping':{
 'test_setTargetDetf_stores_address/test_migrate_amount_over_reserve_reverts/test_cannot_stake_after_migrate_starts/test_completeWrap_after_partial_migrate/test_completeWrap_only_owner':'test_realMigrationBoundsSlippageAndOwnerChecks: actual DETF target, typed reserve/phase/owner failures, new minimum rollback and exact approval cleanup',
 'test_reassign_after_wrap':'test_reassignAfterRealFundedMigration: actual wrapped sDETF moves with stake assignment',
 'test_migrate_wraps_claim_and_users_withdraw_rebasing_share':'existing test_e2e_stake_dtf_migrate_chunks_withdraw_claim: actual funded bond rebase increases wrapping custody and both exact withdrawal previews'},
 'consolidation':'Remove seven old migration cases plus unused ABI-double contract/helper; two consolidated actual integration cases added and existing chunked lifecycle strengthened. Ordinary staking/reward/Permit2 and independent wrapping-vault cases retained.',
 'files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in records]}
(ART/('token-staking-real-migration-consolidation.json' if '--apply' in sys.argv else 'pending-token-staking-real-migration-consolidation.json')).write_text(json.dumps(r,indent=2)+'\n')
print(r['status'])
