// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF,
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/**
 * @title Adversarial_UniV4CpSingleSE_A0Crops
 * @notice A0 first-bond residual + CROPS disable-on-exit (WP-SEC-DETF-SSE-A0-001).
 */
contract Adversarial_UniV4CpSingleSE_A0Crops is TestBase_UniswapV4SingleStandardExchangeDETF {
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    function _openArgsUnique(string memory tag_)
        internal
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args = _openArgs();
        args.name = string(abi.encodePacked("Open UniV4 DETF ", tag_));
        args.symbol = string(abi.encodePacked("oCP", tag_));
    }

    function _firstBondOn(address instance_, uint256 pairAmount_)
        internal
        returns (uint256 tokenId_, uint256 shares_)
    {
        pairToken.mint(detfUser, pairAmount_);
        vm.startPrank(detfUser);
        pairToken.approve(instance_, pairAmount_);
        (tokenId_, shares_) = IUniswapV4SingleStandardExchangeDETF(instance_).bond(
            IERC20(address(pairToken)),
            pairAmount_,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_A0_preLive_donatedPairToken_cannotBeFirstMinted() public {
        address instance_ = _deployDetfWired(_openArgsUnique("a0m"));
        IUniswapV4SingleStandardExchangeDETF info_ = IUniswapV4SingleStandardExchangeDETF(instance_);
        uint256 donate_ = 80 ether;
        pairToken.mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(address(pairToken)).transfer(instance_, donate_);
        assertEq(IERC20(address(pairToken)).balanceOf(instance_), donate_, "donation sitting");
        assertFalse(info_.isReserveLive(), "inert");

        pairToken.mint(attacker, 1 ether);
        vm.startPrank(attacker);
        IERC20(address(pairToken)).approve(instance_, 1 ether);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            1 ether,
            IERC20(instance_),
            0,
            attacker,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertFalse(info_.isReserveLive(), "still inert");
        assertEq(IERC20(address(pairToken)).balanceOf(instance_), donate_, "donation unmoved");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "no free detfToken");
    }

    function test_A0_donatedInventory_firstBondDoesNotStealOthersSeed() public {
        address instance_ = _deployDetfWired(_openArgsUnique("a0"));
        IUniswapV4SingleStandardExchangeDETF info_ = IUniswapV4SingleStandardExchangeDETF(instance_);
        uint256 donate_ = 80 ether;
        pairToken.mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(address(pairToken)).transfer(instance_, donate_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donate_, uint256(0))
        );
        info_.bond(
            IERC20(address(pairToken)),
            donate_,
            DEFAULT_MIN_LOCK,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertFalse(info_.isReserveLive(), "still inert");
        assertEq(IERC20(address(pairToken)).balanceOf(instance_), donate_, "donation unmoved");
    }

    function test_A0_preLive_pullFalse_doesNotCreditDonation() public {
        address instance_ = _deployDetfWired(_openArgsUnique("a0p"));
        IUniswapV4SingleStandardExchangeDETF info_ = IUniswapV4SingleStandardExchangeDETF(instance_);
        uint256 donate_ = 50 ether;
        pairToken.mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(address(pairToken)).transfer(instance_, donate_);

        _firstBondOn(instance_, 200 ether);
        assertTrue(info_.isReserveLive(), "honest pull first bond live");
        assertGe(IERC20(address(pairToken)).balanceOf(instance_), donate_, "donation leftover after pull-false go-live");
    }

    function test_A0_emptyUserSupply_donatedInventory_notDrainedByFirstMint() public {
        address instance_ = _deployDetfWired(_openArgsUnique("a0fm"));
        IUniswapV4SingleStandardExchangeDETF info_ = IUniswapV4SingleStandardExchangeDETF(instance_);
        uint256 donate_ = 60 ether;
        pairToken.mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(address(pairToken)).transfer(instance_, donate_);

        _firstBondOn(instance_, 400 ether);
        uint256 leftover_ = IERC20(address(pairToken)).balanceOf(instance_);
        assertGe(leftover_, donate_, "seed booked after first bond");

        uint256 mintIn_ = 40 ether;
        pairToken.mint(attacker, mintIn_);
        uint256 preview_ = IStandardExchangeIn(instance_).previewExchangeIn(
            IERC20(address(pairToken)), mintIn_, IERC20(instance_)
        );
        vm.startPrank(attacker);
        IERC20(address(pairToken)).approve(instance_, mintIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            mintIn_,
            IERC20(instance_),
            0,
            attacker,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(out_, preview_, "first mint not inflated by donation");
        // Unused inbound from this mint may sit on the diamond; donation must not shrink.
        assertGe(
            IERC20(address(pairToken)).balanceOf(instance_), leftover_, "donated pairToken not drained"
        );
        assertEq(IERC20(instance_).balanceOf(attacker), out_, "attacker enrichment == own mint");
    }

    function test_CROPS_disable_doesNotBlock_closeBondMature_or_redeemClaim() public {
        address instance_ = _deployDetfWired(_openArgsUnique("crops"));
        IUniswapV4SingleStandardExchangeDETF info_ = IUniswapV4SingleStandardExchangeDETF(instance_);
        _firstBondOn(instance_, 400 ether);
        (uint256 tokenId_,) = _firstBondOn(instance_, 80 ether);

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        uint256 principal_ = info_.sellPositionToDetfNft(tokenId_, detfUser);
        assertGt(principal_, 0, "sold to claim");

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(instance_, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(instance_));

        address claim_ = info_.rebasingClaimToken();
        uint256 claimBal_ = IRebasingClaimToken(claim_).balanceOf(detfUser);
        uint256 redeemAmt_ = claimBal_ / 2;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;
        vm.prank(detfUser);
        uint256 redeemOut_ = info_.redeemClaim(
            redeemAmt_, IERC20(address(pairToken)), 0, detfUser, block.timestamp + 1 hours
        );
        assertGt(redeemOut_, 0, "redeemClaim after disable");
    }

    function test_CROPS_disable_doesNotBlock_burnExit() public {
        address instance_ = _deployDetfWired(_openArgsUnique("cropsB"));
        _firstBondOn(instance_, 400 ether);

        uint256 mintIn_ = 40 ether;
        pairToken.mint(detfUser, mintIn_);
        vm.startPrank(detfUser);
        IERC20(address(pairToken)).approve(instance_, mintIn_);
        uint256 minted_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            mintIn_,
            IERC20(instance_),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(minted_, 0);

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(instance_, true);

        vm.startPrank(detfUser);
        IERC20(instance_).approve(instance_, minted_ / 2);
        uint256 burned_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_),
            minted_ / 2,
            IERC20(address(pairToken)),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(burned_, 0, "burn exit after disable");

        pairToken.mint(detfUser, 1 ether);
        vm.startPrank(detfUser);
        IERC20(address(pairToken)).approve(instance_, 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, instance_)
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            1 ether,
            IERC20(instance_),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
