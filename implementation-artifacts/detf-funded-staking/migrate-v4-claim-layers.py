"""Migrate the existing common claim helper hierarchies and their three lifecycle assertions."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];ART=Path(__file__).resolve().parent

def replace_function(source,name,body):
 a=source.index('    function '+name+'(');o=source.index('{',a);d=1;e=o+1
 while d:d+=(source[e]=='{')-(source[e]=='}');e+=1
 return source[:a]+body.rstrip()+source[e:]

imports='''import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
'''
records=[]
for suffix in ('','_Decimals'):
 folder=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
 if suffix:folder/='decimals'
 p=folder/f'UniswapV4Detf_ClaimBase{suffix}.sol';before=p.read_text();s=before
 at=s.index(';',s.index('pragma solidity'))+1;s=s[:at]+'\n'+imports+s[at:]
 s=replace_function(s,'_d10SellToClaimOn','''    function _d10SellToClaimOn(address d, uint256 tokenId, address seller)
        internal returns (uint256 principal, uint256 claimMinted)
    {
        IDETFFundedRewards(d).synchronizeRewards();
        IDetfBondNFT nft_ = IDetfBondNFT(IUniswapV4Detf(d).bondNftVault());
        IERC20 staking_ = IERC20(IUniswapV4Detf(d).rebasingClaimToken());
        uint256 before_ = staking_.balanceOf(seller);
        uint256 lp_ = _lpOf(d).balanceOf(address(nft_));
        vm.prank(seller);
        uint256 rewards_;
        (principal, rewards_) = nft_.claimBond(tokenId, seller);
        claimMinted = principal + rewards_;
        assertEq(staking_.balanceOf(seller) - before_, claimMinted, "funded sDETF claim");
        assertEq(_lpOf(d).balanceOf(address(nft_)), lp_, "claim retains protocol LP");
    }''')
 s=replace_function(s,'_warpMature','''    function _warpMature(uint256 tokenId) internal {
        _warpMatureOf(detf, tokenId);
    }''')
 s=replace_function(s,'_warpMatureOf','''    function _warpMatureOf(address d, uint256 tokenId) internal {
        DETFFundedStakingMath.BondPosition memory position_ = IDetfBondNFT(IUniswapV4Detf(d).bondNftVault()).positionOf(tokenId);
        uint256 unlock_ = position_.startTimestamp + position_.vestingDuration;
        if (block.timestamp < unlock_) vm.warp(unlock_);
    }''')
 s=s.replace(' * @notice Shared Bond NFT sell / claim-token helpers. No extra setUp deploy.\n * @dev Sell is NFT `sellPositionToDetfNft` (onlyOwner = DETF) then `mintFromNFTSale`.\n *      Redeem is `IRebasingClaimToken.redeem`. Rewards are NFT `claimRewards`.',' * @notice Shared owner-authorized funded bond-claim helpers. No extra setUp deployment.\n * @dev Remaining legacy interface consumers are migrated separately; these helpers use funded NFT methods.')
 s=s.replace('/// @notice D10: NFT sell (DETF owner) then claim `mintFromNFTSale` with pre-credit originalShares.','/// @notice D10 replacement: the actual bond owner claims funded principal and rewards as sDETF.')
 records.append((p,before,s,['Maturity comes from funded position terms; claim uses actual owner authorization, pays sDETF and preserves protocol LP. Remaining old caller economic assertions still require migration.']))
 p=folder/f'UniswapV4Detf_ClaimOpenBase{suffix}.sol';before=p.read_text()
 s='''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
'''+imports+f'''import {{UniswapV4Detf_ClaimBase{suffix}}} from "{str((folder/f'UniswapV4Detf_ClaimBase{suffix}.sol').relative_to(ROOT))}";

/// @notice Funded claim layer shared by existing family and provider fixtures.
abstract contract UniswapV4Detf_ClaimOpenBase{suffix} is UniswapV4Detf_ClaimBase{suffix} {{
'''+'''    function test_preMaturity_principalVestsLinearly() public {
        _firstBond(AMOUNT100);
        (uint256 id_,) = _firstBond(AMOUNT20);
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        vm.prank(detfUser);
        assertEq(nft_.claimPrincipal(id_, detfUser), 0, "no principal vested at purchase");
        vm.warp(position_.startTimestamp + position_.vestingDuration / 2);
        uint256 before_ = IERC20(detfInfo.rebasingClaimToken()).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 paid_ = nft_.claimPrincipal(id_, detfUser);
        assertEq(paid_, position_.principal / 2, "halfway principal floors once");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).balanceOf(detfUser) - before_, paid_, "principal is paid as sDETF");
        assertEq(nft_.positionOf(id_).principal, position_.principal, "fixed purchased principal retained");
        assertEq(nft_.positionOf(id_).claimedPrincipal, paid_, "principal debit recorded once");
    }

    function test_postMaturity_claimPaysFundedStaking() public {
        _firstBond(AMOUNT100);
        (uint256 id_,) = _firstBond(AMOUNT40);
        _assertFundedMatureClaim(detf, id_, detfUser);
    }

    function test_claimRewards_whileLocked() public {
        _setPfc(detf);
        (uint256 id_,) = _firstBond(AMOUNT100);
        _firstBond(AMOUNT20);
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        assertLt(block.timestamp, position_.startTimestamp + position_.vestingDuration, "principal remains locked");
        uint256 pending_ = nft_.previewClaim(id_).rewardsDue;
        assertGt(pending_, 0, "funded rewards accrue while vesting");
        IERC20 staking_ = IERC20(detfInfo.rebasingClaimToken());
        uint256 before_ = staking_.balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 paid_ = nft_.claimRewards(id_, detfUser);
        assertEq(paid_, pending_, "reward preview equals execution");
        assertEq(staking_.balanceOf(detfUser) - before_, paid_, "reward paid as sDETF");
        assertEq(nft_.positionOf(id_).claimedPrincipal, 0, "reward claim cannot unlock principal");
        assertEq(nft_.previewClaim(id_).rewardsDue, 0, "funded reward debit applied once");
    }
}
'''
 for amount in (100,40,20):s=s.replace('AMOUNT'+str(amount),f'_uPair({amount})' if suffix else f'{amount} ether')
 records.append((p,before,s,['preMaturity sell revert -> zero-at-start and linear halfway principal payout','mature sale -> funded sDETF payout, NFT retirement, exact unstake and retained LP','reward-while-locked keeps independent claimability and pays sDETF; raw-DETF payout retired under D32']))
for p,b,s,m in records:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-funded-'+p.name+'.txt')).write_text(s)
record={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest(),'mapping':m} for p,b,s,m in records]}
(ART/('v4-claim-layer-migration.json' if '--apply' in sys.argv else 'pending-v4-claim-layer-migration.json')).write_text(json.dumps(record,indent=2)+'\n')
print(record['status'])
