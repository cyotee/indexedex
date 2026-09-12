// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_ERC4626StandardExchange_Decimals} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange_Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {GiftingERC20} from "contracts/test/stubs/GiftingERC20.sol";
import {ShortRedeemERC4626} from "contracts/test/stubs/ShortRedeemERC4626.sol";
import {UnderConsumeERC4626} from "contracts/test/stubs/UnderConsumeERC4626.sol";

/**
 * @title ERC4626StandardExchange_Routes_Decimals
 * @notice Copied gold Routes money-paths on a non-18 protocol-vault asset. SE vaultShare stays 18-dec metadata.
 * @dev Amounts for the configured underlying are `_u(human)`. Gift/dust extra harnesses stay 18-dec stubs.
 */
abstract contract ERC4626StandardExchange_Routes_Decimals is TestBase_ERC4626StandardExchange_Decimals {
    function test_VT1_vaultTokens_containsProtocolVaultAndAsset() public view {
        address[] memory tokens = IBasicVault(se).vaultTokens();
        assertEq(tokens.length, 2);
        bool hasVault;
        bool hasAsset;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == address(protocolVault)) hasVault = true;
            if (tokens[i] == address(underlying)) hasAsset = true;
        }
        assertTrue(hasVault, "protocol vault");
        assertTrue(hasAsset, "underlying");
    }

    function test_VT2_standardVaultConfig_tokensMatch() public view {
        IStandardVault.VaultConfig memory cfg = IStandardVault(se).vaultConfig();
        assertEq(cfg.tokens.length, 2);
        bool hasVault;
        bool hasAsset;
        for (uint256 i; i < cfg.tokens.length; i++) {
            if (cfg.tokens[i] == address(protocolVault)) hasVault = true;
            if (cfg.tokens[i] == address(underlying)) hasAsset = true;
        }
        assertTrue(hasVault && hasAsset);
    }

    function test_SE1_wrapExactIn_previewEqualsExecution_zeroFee() public {
        uint256 amountIn = _u(100);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(underlying)), amountIn, IERC20(se));
        assertGt(preview, 0);
        vm.prank(user);
        uint256 out = seIn.exchangeIn(
            IERC20(address(underlying)), amountIn, IERC20(se), preview, user, false, block.timestamp
        );
        assertEq(out, preview, "preview == execution");
        assertEq(IERC20(se).balanceOf(user), out);
    }

    function test_F1_wrapExactIn_dilutionFee_userFull_feeToMints() public {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        require(feeTo != address(0), "feeTo configured by IndexedexTest");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0.01e18);

        uint256 amountIn = _u(100);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(underlying)), amountIn, IERC20(se));
        uint256 feeBalBefore = IERC20(se).balanceOf(feeTo);
        uint256 supplyBefore = IERC20(se).totalSupply();
        vm.prank(user);
        uint256 out = seIn.exchangeIn(
            IERC20(address(underlying)), amountIn, IERC20(se), preview, user, false, block.timestamp
        );
        assertEq(out, preview, "user receives full due");
        assertEq(IERC20(se).balanceOf(user), out);
        uint256 feeMinted = IERC20(se).balanceOf(feeTo) - feeBalBefore;
        assertEq(feeMinted, out / 100, "1% dilution fee");
        assertEq(IERC20(se).totalSupply() - supplyBefore, out + feeMinted);
    }

    function test_O1_wrapExactOut_previewEqualsSpend() public {
        _seedLiquidity(_u(50));
        uint256 seDesired = _u(10);
        uint256 previewIn = seOut.previewExchangeOut(IERC20(address(underlying)), IERC20(se), seDesired);
        assertGt(previewIn, 0);
        uint256 uBefore = underlying.balanceOf(user);
        uint256 seBefore = IERC20(se).balanceOf(user);
        vm.prank(user);
        uint256 spent = seOut.exchangeOut(
            IERC20(address(underlying)), previewIn, IERC20(se), seDesired, user, false, block.timestamp
        );
        assertEq(spent, previewIn, "spend == preview");
        assertEq(IERC20(se).balanceOf(user) - seBefore, seDesired, "exact SE out");
        assertEq(uBefore - underlying.balanceOf(user), spent, "underlying spent");
    }

    function test_O1b_wrapExactOut_withDilutionFee() public {
        _seedLiquidity(_u(50));
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0.01e18);
        uint256 seDesired = _u(10);
        uint256 previewIn = seOut.previewExchangeOut(IERC20(address(underlying)), IERC20(se), seDesired);
        uint256 feeBefore = IERC20(se).balanceOf(feeTo);
        vm.prank(user);
        seOut.exchangeOut(
            IERC20(address(underlying)), previewIn, IERC20(se), seDesired, user, false, block.timestamp
        );
        assertEq(IERC20(se).balanceOf(feeTo) - feeBefore, seDesired / 100);
    }

    function test_O2_protocolVaultToSeExactOut() public {
        _seedLiquidity(_u(50));
        uint256 vaultIn = _u(20);
        vm.startPrank(user);
        protocolVault.deposit(vaultIn, user);
        protocolVault.approve(se, type(uint256).max);
        vm.stopPrank();
        uint256 seDesired = _u(5);
        uint256 previewIn = seOut.previewExchangeOut(IERC20(address(protocolVault)), IERC20(se), seDesired);
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 reserveBefore = IERC20(address(protocolVault)).balanceOf(se);
        vm.prank(user);
        uint256 spent = seOut.exchangeOut(
            IERC20(address(protocolVault)), previewIn, IERC20(se), seDesired, user, false, block.timestamp
        );
        assertEq(spent, previewIn, "spend == preview");
        assertEq(IERC20(se).balanceOf(user) - seBefore, seDesired, "user SE delta == amountOut");
        assertEq(
            IERC20(address(protocolVault)).balanceOf(se),
            reserveBefore + spent,
            "SE retains protocolVault deposit as reserve"
        );
        assertEq(
            IERC20(address(protocolVault)).balanceOf(user),
            vaultIn - spent,
            "user only spends amountIn of vault tokens"
        );
    }

    function test_O3_unwrapExactOut_burnsOnlyAmountIn() public {
        _seedLiquidity(_u(100));
        uint256 seBal = IERC20(se).balanceOf(user);
        assertGt(seBal, 0);
        uint256 underlyingWanted = _u(10);
        uint256 previewSeIn =
            seOut.previewExchangeOut(IERC20(se), IERC20(address(underlying)), underlyingWanted);
        uint256 uBefore = underlying.balanceOf(user);
        vm.prank(user);
        uint256 spent = seOut.exchangeOut(
            IERC20(se), seBal, IERC20(address(underlying)), underlyingWanted, user, false, block.timestamp
        );
        assertEq(spent, previewSeIn, "burn only calculated amountIn");
        assertLt(spent, seBal, "did not burn full max");
        assertGe(underlying.balanceOf(user) - uBefore, underlyingWanted);
    }

    function test_SE2_unwrapExactIn_previewEqualsExecution() public {
        _seedLiquidity(_u(100));
        uint256 seInAmt = IERC20(se).balanceOf(user) / 2;
        assertGt(seInAmt, 0);
        uint256 preview = seIn.previewExchangeIn(IERC20(se), seInAmt, IERC20(address(underlying)));
        uint256 uBefore = underlying.balanceOf(user);
        vm.prank(user);
        uint256 out = seIn.exchangeIn(
            IERC20(se), seInAmt, IERC20(address(underlying)), preview, user, false, block.timestamp
        );
        assertEq(out, preview);
        assertEq(underlying.balanceOf(user) - uBefore, out);
    }

    function test_F3_unwrap_noExitFee_underNonZeroOracle() public {
        _seedLiquidity(_u(100));
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0.05e18);
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeBefore = IERC20(se).balanceOf(feeTo);
        uint256 seInAmt = IERC20(se).balanceOf(user) / 4;
        vm.prank(user);
        seIn.exchangeIn(IERC20(se), seInAmt, IERC20(address(underlying)), 0, user, false, block.timestamp);
        assertEq(IERC20(se).balanceOf(feeTo), feeBefore, "no exit fee mint");
    }

    function test_Z1_zeroAmountIn_reverts() public {
        vm.expectRevert();
        seIn.previewExchangeIn(IERC20(address(underlying)), 0, IERC20(se));
        vm.expectRevert();
        seOut.previewExchangeOut(IERC20(address(underlying)), IERC20(se), 0);
    }

    function test_I4_yieldIncreasesUnwrapClaim() public {
        _seedLiquidity(_u(100));
        uint256 seAmt = _u(20);
        if (IERC20(se).balanceOf(user) < seAmt) {
            uint256 uIn = seOut.previewExchangeOut(IERC20(address(underlying)), IERC20(se), seAmt);
            vm.prank(user);
            seOut.exchangeOut(
                IERC20(address(underlying)), uIn, IERC20(se), seAmt, user, false, block.timestamp
            );
        }
        uint256 beforeOut = seIn.previewExchangeIn(IERC20(se), seAmt, IERC20(address(underlying)));
        underlying.mint(address(this), _u(50));
        underlying.approve(address(protocolVault), _u(50));
        protocolVault.simulateYield(_u(50));
        uint256 afterOut = seIn.previewExchangeIn(IERC20(se), seAmt, IERC20(address(underlying)));
        assertGt(afterOut, beforeOut, "strict increase after real yield");
    }

    function test_FreeMint_pretransferred_noDelta_protocolVaultToSe_reverts() public {
        _seedLiquidity(_u(50));
        uint256 seBefore = IERC20(se).totalSupply();
        uint256 userSeBefore = IERC20(se).balanceOf(user);
        uint256 reserveBefore = IERC20(address(protocolVault)).balanceOf(se);
        vm.prank(user);
        vm.expectRevert();
        seIn.exchangeIn(
            IERC20(address(protocolVault)), _u(1), IERC20(se), 0, user, true, block.timestamp
        );
        assertEq(IERC20(se).totalSupply(), seBefore, "no free mint supply");
        assertEq(IERC20(se).balanceOf(user), userSeBefore, "no free mint to user");
        assertEq(IERC20(address(protocolVault)).balanceOf(se), reserveBefore, "reserve unchanged");
    }

    function test_FreeMint_pretransferred_noDelta_protocolVaultToSeExactOut_reverts() public {
        _seedLiquidity(_u(50));
        uint256 seBefore = IERC20(se).totalSupply();
        uint256 reserveBefore = IERC20(address(protocolVault)).balanceOf(se);
        vm.prank(user);
        vm.expectRevert();
        seOut.exchangeOut(
            IERC20(address(protocolVault)), _u(10), IERC20(se), _u(1), user, true, block.timestamp
        );
        assertEq(IERC20(se).totalSupply(), seBefore);
        assertEq(IERC20(address(protocolVault)).balanceOf(se), reserveBefore, "reserve unchanged");
    }

    function test_ReserveInvariant_protocolVaultToSeExactIn() public {
        _seedLiquidity(_u(50));
        uint256 vaultIn = _u(20);
        vm.startPrank(user);
        protocolVault.deposit(vaultIn, user);
        protocolVault.approve(se, type(uint256).max);
        uint256 amountIn = _u(7);
        uint256 reserveBefore = IERC20(address(protocolVault)).balanceOf(se);
        uint256 userVaultBefore = IERC20(address(protocolVault)).balanceOf(user);
        uint256 minted = seIn.exchangeIn(
            IERC20(address(protocolVault)), amountIn, IERC20(se), 0, user, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(minted, 0);
        assertEq(
            IERC20(address(protocolVault)).balanceOf(se),
            reserveBefore + amountIn,
            "SE reserve grows by amountIn"
        );
        assertEq(
            IERC20(address(protocolVault)).balanceOf(user),
            userVaultBefore - amountIn,
            "user only loses amountIn"
        );
    }

    function test_O5_wrapExactOut_pullSurplus_refunded() public {
        GiftingERC20 giftU = new GiftingERC20("GiftU", "GU");
        SimpleYieldERC4626 giftVault = new SimpleYieldERC4626(giftU);
        address giftSe = _deployERC4626SE(address(giftVault));
        giftU.mint(user, 1_000 ether);
        giftU.setGift(100);
        vm.startPrank(user);
        giftU.approve(giftSe, type(uint256).max);
        IStandardExchangeIn(giftSe).exchangeIn(
            IERC20(address(giftU)), 50 ether, IERC20(giftSe), 0, user, false, block.timestamp
        );
        uint256 seDesired = 5 ether;
        uint256 amountIn = IStandardExchangeOut(giftSe).previewExchangeOut(
            IERC20(address(giftU)), IERC20(giftSe), seDesired
        );
        uint256 uBefore = giftU.balanceOf(user);
        giftU.setGift(100);
        uint256 spent = IStandardExchangeOut(giftSe).exchangeOut(
            IERC20(address(giftU)), amountIn, IERC20(giftSe), seDesired, user, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(spent, amountIn);
        assertEq(uBefore - giftU.balanceOf(user), amountIn, "surplus gift refunded");
    }

    function test_O6_dustAbsorb_toFeeTo() public {
        SimpleMintableERC20 dustU = new SimpleMintableERC20("DustU", "DU");
        UnderConsumeERC4626 dustVault = new UnderConsumeERC4626(dustU);
        address dustSe = _deployERC4626SE(address(dustVault));
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        require(feeTo != address(0), "feeTo");
        dustU.mint(user, 1_000 ether);
        vm.startPrank(user);
        dustU.approve(dustSe, type(uint256).max);
        dustVault.setLeaveDust(0);
        IStandardExchangeIn(dustSe).exchangeIn(
            IERC20(address(dustU)), 50 ether, IERC20(dustSe), 0, user, false, block.timestamp
        );
        dustVault.setLeaveDust(5);
        uint256 feeBefore = dustU.balanceOf(feeTo);
        IStandardExchangeIn(dustSe).exchangeIn(
            IERC20(address(dustU)), 10 ether, IERC20(dustSe), 0, user, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(dustU.balanceOf(feeTo) - feeBefore, 5, "dust to feeTo");
    }

    function test_O6b_dustSkip_noRevert() public {
        SimpleMintableERC20 dustU = new SimpleMintableERC20("DustU2", "DU2");
        UnderConsumeERC4626 dustVault = new UnderConsumeERC4626(dustU);
        address dustSe = _deployERC4626SE(address(dustVault));
        dustU.mint(user, 1_000 ether);
        vm.startPrank(user);
        dustU.approve(dustSe, type(uint256).max);
        dustVault.setLeaveDust(0);
        IStandardExchangeIn(dustSe).exchangeIn(
            IERC20(address(dustU)), 20 ether, IERC20(dustSe), 0, user, false, block.timestamp
        );
        dustVault.setLeaveDust(3);
        IStandardExchangeIn(dustSe).exchangeIn(
            IERC20(address(dustU)), 5 ether, IERC20(dustSe), 0, user, false, block.timestamp
        );
        vm.stopPrank();
    }

    function test_O4_unwrapExactOut_underDelivery_revertsSlippage() public {
        ShortRedeemERC4626 shortVault = new ShortRedeemERC4626(underlying);
        address shortSe = _deployERC4626SE(address(shortVault));
        vm.startPrank(user);
        underlying.approve(shortSe, type(uint256).max);
        uint256 seAmt = IStandardExchangeIn(shortSe).exchangeIn(
            IERC20(address(underlying)), _u(100), IERC20(shortSe), 0, user, false, block.timestamp
        );
        shortVault.setShortByOne(true);
        uint256 want = _u(10);
        uint256 seInNeeded = IStandardExchangeOut(shortSe).previewExchangeOut(
            IERC20(shortSe), IERC20(address(underlying)), want
        );
        vm.expectRevert();
        IStandardExchangeOut(shortSe).exchangeOut(
            IERC20(shortSe), seInNeeded, IERC20(address(underlying)), want, user, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(IERC20(shortSe).balanceOf(user), seAmt);
    }
}
