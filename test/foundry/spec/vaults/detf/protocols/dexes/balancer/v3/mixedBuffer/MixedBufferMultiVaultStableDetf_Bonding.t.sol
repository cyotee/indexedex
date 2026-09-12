// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {FundedPrimaryRouteAssertions} from "contracts/test/bases/FundedPrimaryRouteAssertions.sol";

contract MixedBufferMultiVaultStableDetf_Bonding_Test is
    TestBase_MixedBufferMultiVaultStableDetf,
    FundedPrimaryRouteAssertions
{
    function setUp() public virtual override {
        super.setUp();
        _bootstrapDefault(detf, alice);
    }

    function test_bond_buffer_after_live() public {
        _fundBuffer(bob, _fixtureAmount(100e18));
        vm.startPrank(bob);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(100e18));
        (uint256 tokenId_, uint256 principal_) = detfBonding.bond(
            IERC20(address(_fixtureBufferToken())),
            _fixtureAmount(100e18),
            DEFAULT_MIN_LOCK,
            bob,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tokenId_ > 0 && principal_ > 0, "buffer bond");
    }

    function test_bond_vaultShare_after_live() public {
        uint256 shares_ = _fundVaultShares(0, bob, 100e18);
        vm.startPrank(bob);
        seShares[0].approve(detf, shares_);
        (uint256 tokenId_, uint256 principal_) =
            detfBonding.bond(seShares[0], shares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(tokenId_ > 0 && principal_ > 0, "share bond");
    }

    function test_bond_reserveBpt_isNotSupported() public {
        // D60 retires Balancer LP bond payments; only buffer and configured
        // vault shares are accepted by this family's funded purchase route.
        uint256 bpt_ = _fundReserveBpt(detf, bob, 80e18);
        assertGt(bpt_, 0, "user funded with real reserve BPT");
        IERC20 pool_ = IERC20(detfInfo.reservePool());
        uint256 protocolBefore_ = pool_.balanceOf(detfInfo.bondNftVault());
        vm.startPrank(bob);
        pool_.approve(detf, bpt_);
        vm.expectRevert(abi.encodeWithSignature("InvalidRoute(address,address)", address(pool_), detf));
        detfBonding.bond(pool_, bpt_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(pool_.balanceOf(bob), bpt_, "unsupported payment remains with buyer");
        assertEq(pool_.balanceOf(detfInfo.bondNftVault()), protocolBefore_, "protocol reserve unchanged");
    }

    function test_bond_lock_too_short_reverts() public {
        _fundBuffer(bob, _fixtureAmount(50e18));
        vm.startPrank(bob);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(50e18));
        vm.expectRevert();
        detfBonding.bond(
            IERC20(address(_fixtureBufferToken())), _fixtureAmount(50e18), 1 days, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_bond_lock_clamps_to_max() public {
        _fundBuffer(bob, _fixtureAmount(50e18));
        vm.startPrank(bob);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(50e18));
        (uint256 tokenId_,) = detfBonding.bond(
            IERC20(address(_fixtureBufferToken())),
            _fixtureAmount(50e18),
            DEFAULT_MAX_LOCK + 365 days,
            bob,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tokenId_ > 0, "clamped lock succeeds");
        assertEq(IDetfBondNFT(detfInfo.bondNftVault()).positionOf(tokenId_).vestingDuration, DEFAULT_MAX_LOCK);
    }

    function test_newBondPaysRewardsWithoutUnlockingUnvestedPrincipal() public {
        _fundBuffer(bob, _fixtureAmount(80e18));
        vm.startPrank(bob);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(80e18));
        (uint256 tokenId_,) = detfBonding.bond(
            IERC20(address(_fixtureBufferToken())),
            _fixtureAmount(80e18),
            DEFAULT_MIN_LOCK,
            bob,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        Math.BondPosition memory position_ = nft_.positionOf(tokenId_);
        IStakedDETF staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        uint256 balance_ = staking_.balanceOf(bob);
        vm.prank(bob);
        assertEq(nft_.claimPrincipal(tokenId_, bob), 0);
        uint256 expected_ = nft_.previewClaim(tokenId_).rewardsDue;
        assertGt(expected_, 0);
        vm.prank(bob);
        assertEq(nft_.claimRewards(tokenId_, bob), expected_);
        assertEq(staking_.balanceOf(bob), balance_ + expected_);
        assertEq(IERC20(detf).balanceOf(bob), 0);
        assertEq(nft_.positionOf(tokenId_).principal, position_.principal);
        assertEq(nft_.positionOf(tokenId_).claimedPrincipal, 0);
    }

    function test_matureBondPaysFundedStakingAndRetiresPosition() public {
        _fundBuffer(bob, _fixtureAmount(80e18));
        vm.startPrank(bob);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(80e18));
        (uint256 tokenId_,) = detfBonding.bond(
            IERC20(address(_fixtureBufferToken())),
            _fixtureAmount(80e18),
            DEFAULT_MIN_LOCK,
            bob,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        Math.BondPosition memory position_ = nft_.positionOf(tokenId_);
        vm.warp(position_.startTimestamp + position_.vestingDuration);
        // NFT previews intentionally exclude unminted expansion. Settle the
        // completed epochs before comparing its stored-index quote to payment.
        IDETFFundedRewards(detf).synchronizeRewards();
        Math.BondClaim memory quote_ = nft_.previewClaim(tokenId_);
        IStakedDETF staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        uint256 balance_ = staking_.balanceOf(bob);
        uint256 lp_ = nft_.lpToken().balanceOf(address(nft_));
        vm.prank(bob);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(tokenId_, bob);
        assertEq(principal_, position_.principal);
        assertEq(principal_, quote_.principalDue);
        assertEq(rewards_, quote_.rewardsDue);
        assertEq(staking_.balanceOf(bob), balance_ + principal_ + rewards_);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_);
        assertEq(nft_.ownerOf(tokenId_), address(0));
    }

    function _fundReserveBpt(address instance_, address buyer_, uint256 payment_) private returns (uint256) {
        IDetfBondNFT nft_ = IDetfBondNFT(IMixedBufferMultiVaultStableDetfInfo(instance_).bondNftVault());
        uint256 amount_ = _fundVaultShares(0, buyer_, payment_);
        uint256 before_ = nft_.lpToken().balanceOf(buyer_);
        _externalReserveJoin(
            PrimaryContext(
                instance_,
                IStakedDETF(detfInfo.rebasingClaimToken()),
                nft_,
                IVault(address(vault)),
                seShares[0],
                0,
                buyer_
            ),
            address(router),
            address(permit2),
            buyer_,
            amount_
        );
        return nft_.lpToken().balanceOf(buyer_) - before_;
    }
}
