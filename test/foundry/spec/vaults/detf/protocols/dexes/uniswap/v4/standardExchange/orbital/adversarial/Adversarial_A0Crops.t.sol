// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @notice A0 first-bond residual + CROPS disable-on-exit + orbital depositClaim.
contract Adversarial_Orbital_A0Crops is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    function test_A0_preLive_donatePair_pretransferredBond_cannotMintFromResidual() public {
        address instance_ = _deployDetfWired(_openArgsUnique("a0"));
        IUniswapV4StandardExchangeOrbitalDETF info_ = IUniswapV4StandardExchangeOrbitalDETF(instance_);
        address p0_ = info_.pairToken0();
        address p1_ = info_.pairToken1();
        uint256 donate_ = 80 ether;
        SimpleMintableERC20(p0_).mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(p0_).transfer(instance_, donate_);

        SimpleMintableERC20(p1_).mint(attacker, donate_);
        vm.startPrank(attacker);
        IERC20(p1_).approve(instance_, donate_);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donate_ + donate_, uint256(0))
        );
        info_.bond(IERC20(p0_), donate_, IERC20(p1_), donate_, DEFAULT_MIN_LOCK, attacker, true, _dl());
        vm.stopPrank();

        assertFalse(info_.isReserveLive(), "still inert");
        assertEq(IERC20(p0_).balanceOf(instance_), donate_, "donation unmoved");
    }

    function test_A0_preLive_pullFalse_doesNotCreditDonation() public {
        address instance_ = _deployDetfWired(_openArgsUnique("a0p"));
        IUniswapV4StandardExchangeOrbitalDETF info_ = IUniswapV4StandardExchangeOrbitalDETF(instance_);
        address p0_ = info_.pairToken0();
        uint256 donate_ = 50 ether;
        SimpleMintableERC20(p0_).mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(p0_).transfer(instance_, donate_);

        _firstBondOn(instance_, 200 ether, 200 ether);
        assertTrue(info_.isReserveLive(), "honest pull first bond live");
        assertGe(IERC20(p0_).balanceOf(instance_), donate_, "donation leftover");
    }

    function test_depositClaim_pair_mintsClaim() public {
        address instance_ = _deployDetfWired(_openArgsUnique("dc"));
        IUniswapV4StandardExchangeOrbitalDETF info_ = IUniswapV4StandardExchangeOrbitalDETF(instance_);
        address p0_ = info_.pairToken0();
        _firstBondOn(instance_, 300 ether, 300 ether);

        SimpleMintableERC20(p0_).mint(detfUser, 40 ether);
        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, 40 ether);
        uint256 claimOut_ = info_.depositClaim(IERC20(p0_), 40 ether, 0, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(claimOut_, 0, "depositClaim mints");
        assertGt(IRebasingClaimToken(info_.rebasingClaimToken()).balanceOf(detfUser), 0);
    }

    function test_CROPS_disable_doesNotBlock_closeBondMature_or_redeemClaim() public {
        address instance_ = _deployDetfWired(_openArgsUnique("crops"));
        IUniswapV4StandardExchangeOrbitalDETF info_ = IUniswapV4StandardExchangeOrbitalDETF(instance_);
        address p0_ = info_.pairToken0();
        _firstBondOn(instance_, 300 ether, 300 ether);

        SimpleMintableERC20(p0_).mint(detfUser, 80 ether);
        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, type(uint256).max);
        (uint256 tokenId_,) = info_.bond(IERC20(p0_), 50 ether, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        uint256 claimOut_ = info_.depositClaim(IERC20(p0_), 20 ether, 0, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(claimOut_, 0);

        uint256 unlock_ = IDETFNFTVault(info_.bondNftVault()).unlockTimeOf(tokenId_);
        vm.warp(unlock_ + 1);

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(instance_, true);

        vm.startPrank(detfUser);
        uint256[] memory closeOut_ = info_.closeBondMature(tokenId_, _minOut3(), detfUser, _dl());
        assertTrue(closeOut_[1] + closeOut_[2] > 0, "closeBondMature after disable");

        uint256 claimBal_ = IRebasingClaimToken(info_.rebasingClaimToken()).balanceOf(detfUser);
        uint256 redeemAmt_ = claimBal_ / 2;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;
        uint256 redeemOut_ = info_.redeemClaim(redeemAmt_, IERC20(instance_), 0, detfUser, _dl());
        assertGt(redeemOut_, 0, "redeemClaim DETF after disable");
        vm.stopPrank();
    }

    function test_CROPS_disable_doesNotBlock_burnExit() public {
        address instance_ = _deployDetfWired(_openArgsUnique("cropsB"));
        IUniswapV4StandardExchangeOrbitalDETF info_ = IUniswapV4StandardExchangeOrbitalDETF(instance_);
        address p0_ = info_.pairToken0();
        _firstBondOn(instance_, 300 ether, 300 ether);

        SimpleMintableERC20(p0_).mint(detfUser, 40 ether);
        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, 40 ether);
        uint256 minted_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), 40 ether, IERC20(instance_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(instance_, true);

        vm.startPrank(detfUser);
        IERC20(instance_).approve(instance_, minted_ / 2);
        uint256 burned_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), minted_ / 2, IERC20(p0_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
        assertGt(burned_, 0, "burn after disable");

        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, instance_));
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), 1 ether, IERC20(instance_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
    }
}
