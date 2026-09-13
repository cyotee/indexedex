"""Preserve mature-claim security cases while replacing retired LP-basket settlement."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];ART=Path(__file__).resolve().parent
folder=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
p=folder/'UniswapV4Detf_Close.t.sol';before=p.read_text()
head=before[:before.index('/// @notice T7.12')]
head+='''import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";

/// @notice Funded mature-claim authorization, inventory isolation and reserve custody.
contract UniswapV4Detf_Close is TestBase_UniswapV4Detf {
'''
after=head+(ART/'pending-v4-close-tests.txt').read_text()+'}\n'
records=[(p,before,after)]
p=folder/'decimals/UniswapV4Detf_Close_Decimals.sol';before=p.read_text()
s=before[:before.index('/// @notice T7.12')]+'''/// @notice Native-unit funded claim and exact held-DETF redemption.
abstract contract UniswapV4Detf_Close_Decimals is TestBase_UniswapV4Detf_Decimals {
    function test_T7_12_matureClaimAndUnstakePreserveReserveLp() public {
        (uint256 id_, uint256 principal_) = _firstBond(_uPair(100));
        assertGt(principal_, 0, "funded native DETF principal");
        _assertFundedMatureClaim(detf, id_, detfUser);
        _assertNoJoinableDust();
    }
}
'''
records.append((p,before,s))
for p,b,s in records:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-funded-close-'+p.name+'.txt')).write_text(s)
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','coverage_mapping':{'E6':'Prior unrelated DETF-held inventory cannot increase funded principal/reward payout or pay reserve assets. Existing inert custom configuration retained while A30 approval is pending.','unauthorized/previous/current holder':'Existing three independent authority and recipient cases retained on funded NFT claimBond; fixed principal/gons and LP custody asserted.','T7.12':'Existing CP and all native-unit wrappers reuse exact funded mature claim and 1:1 unstake; no LP-basket close.'},'files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in records]}
(ART/('v4-close-funded-migration.json' if '--apply' in sys.argv else 'pending-v4-close-funded-migration.json')).write_text(json.dumps(r,indent=2)+'\n')
print(r['status'])
