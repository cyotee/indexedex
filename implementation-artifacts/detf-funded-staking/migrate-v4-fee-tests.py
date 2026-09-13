"""Replace duplicated FC1-FC12 with shared funded tests and independent floor assertions."""
from pathlib import Path
import hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[2];ART=Path(__file__).resolve().parent
folder=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
def span(s,name):
 m=re.search(r'    function '+re.escape(name)+r'\(',s);assert m,name
 start=m.start();b=s.index('{',m.end());j=b+1;depth=1
 while depth:
  if s[j]=='{':depth+=1
  elif s[j]=='}':depth-=1
  j+=1
 return start,j
imports='''import {FundedRewardAssertions} from "contracts/test/bases/FundedRewardAssertions.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";
'''
hooks='''
    function _fundedFeeSubject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _fundedFeeOracle() internal view override returns (address) { return address(indexedexManager); }
    function _fundedFeeAdmin() internal view override returns (address) { return owner; }
    function _fundedFeeBoot() internal override returns (uint256 id_) {
        (id_,) = _bootAlice(_fundedFeeUnits(20));
    }
    function _fundedFeeBond(address d_, uint256 amount_) internal override returns (uint256, uint256) {
        return _bondOn(d_, bob, amount_);
    }
    function _fundedFeeLead(address d_) internal view override returns (IERC20) { return _leadPairOf(d_); }
    function _fundedFeeUnits(uint256 whole_) internal view override returns (uint256) { return UNIT_EXPR; }
    function _fundedFeeLock() internal view override returns (uint256) { return DEFAULT_MIN_LOCK; }
    function _fundedFeeDeploy(address creator_) internal override returns (address d_) {
        IUniswapV4Detf.PkgArgs memory args_ = _openArgsPolicy();
        args_.creator = creator_;
        d_ = _deployTagged(args_, string.concat("funded-fc", _nextTag()));
        _setPfc(d_); _setFeeOraclePfc(d_); _setBondTermsOn(d_);
    }
'''
records=[];primary=folder/'UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol'
bases=[primary,folder/'decimals/UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals.sol']
bases += [folder/f'UniswapV4Detf_{family}_Alignment_FeeCreatorClaim.t.sol' for family in ['Orbital','Weighted','Quad']]
for p in bases:
 b=p.read_text();s=b
 cut=s.index('    function _assertFC1(') if p in bases[:2] else s.index('    function test_FC1_')
 s=s[:cut]
 for name in ['_nftClaim','_potOf']:
  i,j=span(s,name);s=s[:i]+s[j:]
 suffix='_Decimals' if 'Decimals' in p.name else ''
 parent='UniswapV4Detf_ClaimBase'+suffix
 if p in bases[:2]:s=s.replace('is '+parent+' {','is '+parent+', V4FundedFeeBehavior {')
 else:
  m=re.search(r'(contract\s+\w+\s+is\s+.*?)(\{)',s,re.S);assert m
  head=m.group(1).rstrip()+',\n    V4FundedFeeBehavior\n'
  s=s[:m.start()]+head+s[m.start(2):]
 if p==primary:
  at=s.index('/**')
  s=s[:at]+imports+'\n'+(ART/'pending-v4-fee-behavior.txt').read_text()+'\n'+s[at:]
 else:
  s=s.replace('pragma solidity ^0.8.0;', 'pragma solidity ^0.8.0;\nimport {V4FundedFeeBehavior} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol";')
 s+=hooks.replace('UNIT_EXPR','_uPair(whole_)' if suffix else 'whole_ * 1 ether')+'}\n'
 s=re.sub(r'/// @notice (?:Weighted|Quad|Orbital) gold FC1[^\n]*', '/// @notice Shared funded fee/creator assertions on the actual reserve binding.',s)
 records.append((p,b,s))

# All other FC wrappers call the corresponding shared assertions through these bases.
# Remove only old one-line wrappers, so unrelated provider/policy test cases stay.
for p in sorted(folder.rglob('*.sol')):
 if p in bases:continue
 b=p.read_text();s=b
 names=re.findall(r'function (test_FC\d+_\w+)\(',s)
 if not names:continue
 for name in names:
  i,j=span(s,name);body=s[i:j]
  assert re.search(r'\{\s*_assertFC\d+\(\);\s*\}',body), (p,name,'independent body needs review')
  s=s[:i]+s[j:]
 records.append((p,b,s))
for p,b,s in records:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-funded-fee-'+p.name+'.txt')).write_text(s)
mapping={
 'FC1/FC2/FC3/FC4/FC5/FC12':'fundedTwoWavesMatchIndependentFloors: purchased gons + immediate ordered allocation, independent exact integer floors, old principal ownership and backing conservation across two waves',
 'FC6':'noNewFundingCannotRepeatStandingPayout: immediate receipts cannot be issued twice without new funding',
 'FC7/FC8/FC9':'reservedRolesCannotClaimEscrowAgain: both roles have zero purchased principal/gons and typed rejection; fullExit also rejects unauthorized transfer and duplicate unstake',
 'FC10':'fullExitAndFeeToRotationPreserveStandingIncome: exact redeemable sDETF exit, persistent standing rights, unchanged NFT recipients after live oracle change, later funded receipts again',
 'FC11':'creatorZeroFundsBothRightsToOriginalFeeOwner plus explicitCreatorReceivesSeparateFundedIncome'
}
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','coverage_mapping':mapping,'consolidation':'Twelve duplicated economic cases become six inherited current cases per existing provider/native-unit fixture. Reuses existing FundedRewardAssertions independent integer reference; no new SUT, alternate math package, or per-provider copy.','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest(),'migrated_tests':re.findall(r'function (test_FC\d+_\w+)\(',b)}for p,b,s in records]}
(ART/('v4-fee-funded-consolidation.json' if '--apply' in sys.argv else 'pending-v4-fee-funded-consolidation.json')).write_text(json.dumps(r,indent=2)+'\n')
print(r['status'],len(records),'files')
