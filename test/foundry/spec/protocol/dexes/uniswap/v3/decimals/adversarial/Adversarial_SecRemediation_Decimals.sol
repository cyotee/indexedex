// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {
    NonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial_Decimals
} from "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/adversarial/TestBase_UniswapV3StandardExchange_Adversarial_Decimals.sol";

contract MockTokenDescriptorSec_Dec {
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

/// @notice E6 / I1 / A0. pairToken = tokenA. Amounts are raw units via `_u0`/`_u1`.
abstract contract Adversarial_SecRemediation_Decimals is TestBase_UniswapV3StandardExchange_Adversarial_Decimals {
    NonfungiblePositionManager internal npm;

    function setUp() public virtual override {
        super.setUp();
        npm = new NonfungiblePositionManager(
            address(uniswapV3Factory), address(1), address(new MockTokenDescriptorSec_Dec())
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1;
    }

    function _zapIn(address actor, address pairToken, uint256 amountIn) internal returns (uint256 shares) {
        _mint(pairToken, actor, amountIn);
        vm.startPrank(actor);
        IERC20(pairToken).approve(address(vault), amountIn);
        if (IERC20(address(vault)).totalSupply() == 0) {
            assertEq(pairToken, pool.token0(), "activation fixture token0 funding");
            shares = _activateWithFundedToken0(actor, amountIn, amountIn * _u1(1) / _u0(1));
        } else {
            shares = vault.exchangeIn(
                IERC20(pairToken), amountIn, IERC20(address(vault)), 0, actor, false, _deadline()
            );
        }
        vm.stopPrank();
    }

    function _mintNft(address to, uint256 amount0, uint256 amount1) internal returns (uint256 tokenId) {
        address token0 = pool.token0();
        address token1 = pool.token1();
        (int24 tickLower, int24 tickUpper) = _ticksAroundSpot(pool, 8);
        _mint(token0, address(this), amount0);
        _mint(token1, address(this), amount1);
        IERC20(token0).approve(address(npm), amount0);
        IERC20(token1).approve(address(npm), amount1);
        (tokenId,,,) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: FEE_MEDIUM,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: to,
                deadline: _deadline()
            })
        );
    }

    function test_E6_zapIn_doesNotRefundPriorDonation() public {
        address pairToken = pool.token0();
        address rateAsset = pool.token1();
        _zapIn(victim, pairToken, _u0(100));

        uint256 donate_ = _u0(50);
        _mint(pairToken, address(this), donate_);
        IERC20(pairToken).transfer(address(vault), donate_);
        uint256 vaultPairAfterDonate_ = IERC20(pairToken).balanceOf(address(vault));
        assertGe(vaultPairAfterDonate_, donate_, "E6: donation sits on proxy");

        uint256 zapIn_ = _u0(1);
        _mint(pairToken, attacker, zapIn_);
        uint256 attackerPairBefore_ = IERC20(pairToken).balanceOf(attacker);
        uint256 attackerRateBefore_ = IERC20(rateAsset).balanceOf(attacker);

        vm.startPrank(attacker);
        IERC20(pairToken).approve(address(vault), zapIn_);
        vault.exchangeIn(
            IERC20(pairToken), zapIn_, IERC20(address(vault)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        uint256 attackerPairAfter_ = IERC20(pairToken).balanceOf(attacker);
        uint256 attackerRateAfter_ = IERC20(rateAsset).balanceOf(attacker);
        uint256 pairRefund_ =
            attackerPairAfter_ > attackerPairBefore_ ? attackerPairAfter_ - attackerPairBefore_ : 0;
        uint256 rateRefund_ =
            attackerRateAfter_ > attackerRateBefore_ ? attackerRateAfter_ - attackerRateBefore_ : 0;
        assertLt(attackerPairAfter_, donate_, "E6: zap-in refund must not pay donated pairToken");
        assertLt(rateRefund_, donate_, "E6: zap-in refund must not pay donated rateAsset");
        assertLe(pairRefund_ + rateRefund_, zapIn_, "E6: refund <= this-call unused inbound");
    }

    function test_E6_exchangeOut_swap_fatMax_transferOnlyUsed_doesNotPayBooked() public {
        address pairToken = pool.token0();
        address rateAsset = pool.token1();
        uint256 seed_ = _u0(20);
        _mint(pairToken, address(vault), seed_);
        uint256 vaultPairBefore_ = IERC20(pairToken).balanceOf(address(vault));
        assertEq(vaultPairBefore_, seed_, "E6: seeded pairToken on proxy");

        uint256 amountOut_ = _u1(1);
        uint256 used_ = vault.previewExchangeOut(IERC20(pairToken), IERC20(rateAsset), amountOut_);
        require(used_ > 0, "preview used");
        uint256 fatMax_ = used_ + seed_;

        _mint(pairToken, attacker, used_);
        vm.prank(attacker);
        IERC20(pairToken).transfer(address(vault), used_);

        uint256 attackerPairAfterPush_ = IERC20(pairToken).balanceOf(attacker);
        uint256 vaultPairAfterPush_ = IERC20(pairToken).balanceOf(address(vault));

        vm.prank(attacker);
        vault.exchangeOut(
            IERC20(pairToken), fatMax_, IERC20(rateAsset), amountOut_, attacker, true, _deadline()
        );

        uint256 attackerPairGain_ = IERC20(pairToken).balanceOf(attacker) - attackerPairAfterPush_;
        assertLt(attackerPairGain_, seed_, "E6: attacker must not receive seeded pairToken");
        assertGe(
            IERC20(pairToken).balanceOf(address(vault)) + 1,
            vaultPairAfterPush_ - used_,
            "E6: seeded pairToken not refund-skimmed"
        );
        assertLe(attackerPairGain_, used_, "E6: refund <= this-call unused inbound");
    }

    function test_E6_import_doesNotSweepDonatedPairTokens() public {
        address pairToken = pool.token0();
        address rateAsset = pool.token1();
        uint256 donate_ = _u0(50);
        _mint(pairToken, address(this), donate_);
        IERC20(pairToken).transfer(address(vault), donate_);

        uint256 tokenId = _mintNft(attacker, _u0(30), _u1(30));
        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));

        uint256 attackerPairBefore_ = IERC20(pairToken).balanceOf(attacker);
        uint256 attackerRateBefore_ = IERC20(rateAsset).balanceOf(attacker);

        vm.startPrank(attacker);
        IERC721(address(npm)).approve(address(vault), tokenId);
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, attacker, attacker, _deadline()
        );
        vm.stopPrank();

        uint256 attackerPairGain_ = IERC20(pairToken).balanceOf(attacker) - attackerPairBefore_;
        uint256 attackerRateGain_ = IERC20(rateAsset).balanceOf(attacker) - attackerRateBefore_;
        assertLt(attackerPairGain_, donate_, "E6 import: donated pairToken not swept to recipient");
        assertLt(attackerRateGain_, donate_, "E6 import: donated rateAsset not swept");
        assertGe(IERC20(pairToken).balanceOf(address(vault)), donate_ / 2, "E6 import: donation remains on vault");
    }

    function test_E6_zapOut_doesNotSweepOtherUsersShares() public {
        address pairToken = pool.token0();
        uint256 shares_ = _zapIn(victim, pairToken, _u0(80));
        vm.prank(victim);
        IERC20(address(vault)).transfer(address(vault), shares_);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), shares_, "E6: self-held vaultShare");

        uint256 amountOut_ = _u0(1);
        uint256 attackerSharesBefore_ = IERC20(address(vault)).balanceOf(attacker);
        uint256 attackerPairBefore_ = IERC20(pairToken).balanceOf(attacker);
        uint256 selfBefore_ = IERC20(address(vault)).balanceOf(address(vault));

        vm.prank(attacker);
        try vault.exchangeOut(
            IERC20(address(vault)), type(uint256).max, IERC20(pairToken), amountOut_, attacker, true, _deadline()
        ) {
            revert("E6 zap-out: expected no extract");
        } catch {}

        assertEq(IERC20(address(vault)).balanceOf(attacker), attackerSharesBefore_, "E6: no leftover vaultShare");
        assertEq(IERC20(pairToken).balanceOf(attacker), attackerPairBefore_, "E6: no pairToken extract");
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), selfBefore_, "E6: donated vaultShare stays");
    }

    function test_I1_zapOut_pretransferred_noShareDelivery_existingSelfShares_revertsOrNoExtract() public {
        address pairToken = pool.token0();
        uint256 shares_ = _zapIn(victim, pairToken, _u0(80));
        vm.prank(victim);
        IERC20(address(vault)).transfer(address(vault), shares_);

        uint256 amountOut_ = _u0(1);
        uint256 sharesNeeded_ = vault.previewExchangeOut(IERC20(address(vault)), IERC20(pairToken), amountOut_);
        require(sharesNeeded_ > 0, "preview shares");

        uint256 attackerPairBefore_ = IERC20(pairToken).balanceOf(attacker);
        uint256 selfBefore_ = IERC20(address(vault)).balanceOf(address(vault));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, sharesNeeded_, uint256(0))
        );
        vault.exchangeOut(
            IERC20(address(vault)), type(uint256).max, IERC20(pairToken), amountOut_, attacker, true, _deadline()
        );

        assertEq(IERC20(pairToken).balanceOf(attacker), attackerPairBefore_, "I1: no pairToken extract");
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), selfBefore_, "I1: self vaultShare unmoved");
        assertEq(IERC20(address(vault)).balanceOf(attacker), 0, "I1: attacker vaultShare unchanged");
    }

    function test_A0_donatePair_thenTwoTokenActivation_cannotRedeemDonation() public {
        address pairToken = pool.token0();
        assertEq(IERC20(address(vault)).totalSupply(), 0, "A0: empty supply");

        uint256 donate_ = _u0(50);
        _mint(pairToken, address(this), donate_);
        IERC20(pairToken).transfer(address(vault), donate_);

        uint256 zapIn_ = _u0(10);
        _mint(pairToken, attacker, zapIn_);

        vm.startPrank(attacker);
        IERC20(pairToken).approve(address(vault), zapIn_);
        uint256 shares_ = _activateWithFundedToken0(attacker, zapIn_, _u1(10));
        vm.stopPrank();

        assertGt(shares_, 0, "A0: first zap minted");
        uint256 wadIn = _toWad(pairToken, zapIn_);
        assertLe(shares_, wadIn + wadIn / 5, "A0: shares only this-call principal");
        assertGe(IERC20(pairToken).balanceOf(address(vault)), donate_ / 2, "A0: donation not absorbed into LP");

        uint256 wantOut_ = zapIn_ / 2;
        uint256 sharesNeeded_ = vault.previewExchangeOut(IERC20(address(vault)), IERC20(pairToken), wantOut_);
        require(sharesNeeded_ > 0 && sharesNeeded_ <= shares_, "A0 preview");

        vm.prank(attacker);
        vault.exchangeOut(
            IERC20(address(vault)), shares_, IERC20(pairToken), wantOut_, attacker, false, _deadline()
        );

        assertLe(IERC20(pairToken).balanceOf(attacker), zapIn_, "A0: redeem <= own principal");
        assertLt(IERC20(pairToken).balanceOf(attacker), donate_, "A0: first mover cannot drain donation");
        assertGe(IERC20(pairToken).balanceOf(address(vault)), donate_ / 2, "A0: donation remains after redeem");
    }

    function test_A0_donatePair_thenImport_cannotSweepDonation() public {
        address pairToken = pool.token0();
        address rateAsset = pool.token1();
        assertEq(IERC20(address(vault)).totalSupply(), 0, "A0 import: empty supply");

        uint256 donate_ = _u0(50);
        _mint(pairToken, address(this), donate_);
        IERC20(pairToken).transfer(address(vault), donate_);

        uint256 tokenId = _mintNft(attacker, _u0(30), _u1(30));
        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));

        uint256 attackerPairBefore_ = IERC20(pairToken).balanceOf(attacker);
        uint256 attackerRateBefore_ = IERC20(rateAsset).balanceOf(attacker);

        vm.startPrank(attacker);
        IERC721(address(npm)).approve(address(vault), tokenId);
        uint256 shares_ = importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, attacker, attacker, _deadline()
        );
        vm.stopPrank();

        uint256 importPairGain_ = IERC20(pairToken).balanceOf(attacker) - attackerPairBefore_;
        uint256 importRateGain_ = IERC20(rateAsset).balanceOf(attacker) - attackerRateBefore_;
        assertLt(importPairGain_, donate_, "A0 import: leftover refund is not the donation");
        assertLt(importRateGain_, donate_, "A0 import: leftover rateAsset is not the donation");
        assertGt(shares_, 0, "A0 import: minted");
        assertGe(IERC20(pairToken).balanceOf(address(vault)), donate_ / 2, "A0 import: donation not reminted away");

        uint256 wantOut_ = _u0(10);
        uint256 sharesNeeded_ = vault.previewExchangeOut(IERC20(address(vault)), IERC20(pairToken), wantOut_);
        require(sharesNeeded_ > 0 && sharesNeeded_ <= shares_, "A0 import preview");

        vm.prank(attacker);
        vault.exchangeOut(
            IERC20(address(vault)), shares_, IERC20(pairToken), wantOut_, attacker, false, _deadline()
        );

        uint256 recoveredPair_ = IERC20(pairToken).balanceOf(attacker) - attackerPairBefore_;
        assertLt(recoveredPair_, donate_ + _u0(30), "A0 import: redeem does not drain donation+NFT");
        assertGe(IERC20(pairToken).balanceOf(address(vault)), donate_ / 2, "A0 import: donation remains after redeem");
    }
}
