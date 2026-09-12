// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";

/// @notice Funded mature-claim authorization, inventory isolation and reserve custody.
contract UniswapV4Detf_Close is TestBase_UniswapV4Detf {
    /// @notice Funded claims cannot consume unrelated settlement inventory held by the DETF.
    function test_E6_fundedClaim_doesNotPayPriorSettlementInventory() public {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "FundedClaimInventory";
        IUniswapV4Detf info = IUniswapV4Detf(_deployHookThenDetf(args));
        vm.startPrank(detfUser);
        pairToken.approve(address(info), type(uint256).max);
        (uint256 id_,) = info.bond(
            IERC20(address(pairToken)), 100 ether, DEFAULT_MIN_LOCK, detfUser,
            false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        IDETFFundedRewards(address(info)).synchronizeRewards();
        IDetfBondNFT nft_ = IDetfBondNFT(info.bondNftVault());
        uint256 checkpoint_ = vm.snapshotState();
        vm.prank(detfUser);
        (uint256 cleanPrincipal_, uint256 cleanRewards_) = nft_.claimBond(id_, detfUser);
        assertTrue(vm.revertToState(checkpoint_));
        pairToken.mint(address(info), 10 ether);
        uint256 pairBefore_ = pairToken.balanceOf(detfUser);
        IStakedDETF stake_ = IStakedDETF(info.rebasingClaimToken());
        uint256 stakeBefore_ = stake_.balanceOf(detfUser);
        vm.prank(detfUser);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, detfUser);
        assertEq(principal_, cleanPrincipal_, "fixed principal ignores prior inventory");
        assertEq(rewards_, cleanRewards_, "unallocated inventory is not staking income");
        assertEq(stake_.balanceOf(detfUser) - stakeBefore_, principal_ + rewards_, "only funded sDETF paid");
        assertEq(pairToken.balanceOf(detfUser), pairBefore_, "no settlement token payout");
        assertGe(pairToken.balanceOf(address(info)), 10 ether, "gift retained by DETF");
    }

    /// @notice Ownership and transfer authorization govern every principal/reward payout.
    function test_fundedClaim_rejectsUnrelatedCaller() public {
        uint256 id_ = _prepareMatureClose();
        address attacker_ = makeAddr("unauthorizedBondCloser");
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        bytes32 before_ = keccak256(abi.encode(nft_.positionOf(id_)));
        vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.NotAuthorized.selector, attacker_));
        vm.prank(attacker_);
        nft_.claimBond(id_, attacker_);
        assertEq(nft_.ownerOf(id_), detfUser, "holder retains bond");
        assertEq(keccak256(abi.encode(nft_.positionOf(id_))), before_, "funded principal and gons unchanged");
        assertEq(pairToken.balanceOf(attacker_), 0, "no stolen reserve assets");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).balanceOf(attacker_), 0, "no stolen staking receipts");
    }

    function test_fundedClaim_rejectsFormerHolder() public {
        uint256 id_ = _prepareMatureClose();
        address newHolder_ = makeAddr("newBondHolder");
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        vm.prank(detfUser);
        nft_.transferFrom(detfUser, newHolder_, id_);
        vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.NotAuthorized.selector, detfUser));
        vm.prank(detfUser);
        nft_.claimBond(id_, detfUser);
        assertEq(nft_.ownerOf(id_), newHolder_, "new holder retains bond");
    }

    function test_fundedClaim_currentHolderCanChooseRecipient() public {
        uint256 id_ = _prepareMatureClose();
        address newHolder_ = makeAddr("newBondHolder");
        address recipient_ = makeAddr("chosenBondRecipient");
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        vm.prank(detfUser);
        nft_.transferFrom(detfUser, newHolder_, id_);
        uint256 lpBefore_ = IERC20(reserveHook).balanceOf(address(nft_));
        vm.prank(newHolder_);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, recipient_);
        assertGt(principal_, 0, "mature principal paid");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).balanceOf(recipient_), principal_ + rewards_, "chosen recipient paid sDETF");
        assertEq(pairToken.balanceOf(recipient_), 0, "no reserve basket payout");
        assertEq(IERC20(reserveHook).balanceOf(address(nft_)), lpBefore_, "protocol LP retained");
        assertEq(nft_.ownerOf(id_), address(0), "authorized claim retires bond");
    }

    function _prepareMatureClose() internal returns (uint256 id_) {
        (id_,) = _firstBond(100 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        IDETFFundedRewards(detf).synchronizeRewards();
    }

    function test_T7_12_matureClaimAndUnstakePreserveReserveLp() public {
        (uint256 id_, uint256 principal_) = _firstBond(100 ether);
        assertGt(principal_, 0, "funded native DETF principal");
        _assertFundedMatureClaim(detf, id_, detfUser);
        _assertNoJoinableDust();
    }
}
