// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IBaseProtocolDETFRichirRedeem} from "contracts/interfaces/IBaseProtocolDETFRichirRedeem.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {
    PREVIEW_BUFFER_DENOMINATOR,
    PREVIEW_RICHIR_BUFFER_BPS,
    PREVIEW_WETH_CHIR_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {ProtocolDETFBaseCustomFixtureHelpers} from "./ProtocolDETF_CustomFixtureHelpers.t.sol";

contract ProtocolDETFRoutesIntegrationTest is ProtocolDETFBaseCustomFixtureHelpers {
    function test_exchangeIn_weth_to_chir_preview_reverts_when_minting_not_allowed() public {
        IProtocolDETF burnEnabledDetf = _deployBurnEnabledDetf();
        uint256 amountIn = 10_000e18;
        uint256 syntheticPrice = burnEnabledDetf.syntheticPrice();
        uint256 mintThreshold = burnEnabledDetf.mintThreshold();

        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeIn(address(burnEnabledDetf)).previewExchangeIn(IERC20(address(weth9)), amountIn, IERC20(address(burnEnabledDetf)));
    }

    function test_route_weth_to_chir_reverts_when_minting_not_allowed() public {
        IProtocolDETF burnEnabledDetf = _deployBurnEnabledDetf();
        uint256 amountIn = 10_000e18;
        uint256 syntheticPrice = burnEnabledDetf.syntheticPrice();
        uint256 mintThreshold = burnEnabledDetf.mintThreshold();

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(burnEnabledDetf), amountIn);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeIn(address(burnEnabledDetf)).exchangeIn(
            IERC20(address(weth9)), amountIn, IERC20(address(burnEnabledDetf)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_route_weth_to_chir_when_minting_allowed() public {
        IProtocolDETF mintEnabledDetf = _deployMintEnabledDetf();
        uint256 amountIn = 10_000e18;

        _assertMintEnabled(mintEnabledDetf);

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(mintEnabledDetf), amountIn);
        uint256 chirOut = IStandardExchangeIn(address(mintEnabledDetf)).exchangeIn(
            IERC20(address(weth9)), amountIn, IERC20(address(mintEnabledDetf)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(chirOut, 0, "mint route should return CHIR");
        assertEq(IERC20(address(mintEnabledDetf)).balanceOf(detfAlice), chirOut, "CHIR should be minted to user");
    }

    function test_exchangeIn_weth_to_chir_preview_matches_execution_when_minting_allowed() public {
        IProtocolDETF mintEnabledDetf = _deployMintEnabledDetf();
        uint256 amountIn = 10_000e18;

        _assertMintEnabled(mintEnabledDetf);

        uint256 expectedChir = IStandardExchangeIn(address(mintEnabledDetf)).previewExchangeIn(
            IERC20(address(weth9)), amountIn, IERC20(address(mintEnabledDetf))
        );

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(mintEnabledDetf), amountIn);
        uint256 chirOut = IStandardExchangeIn(address(mintEnabledDetf)).exchangeIn(
            IERC20(address(weth9)), amountIn, IERC20(address(mintEnabledDetf)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertLe(expectedChir, chirOut, "exact-in preview must not exceed actual output");
        assertApproxEqRel(chirOut, expectedChir, 0.01e18, "preview should stay within 1% of actual output");
    }

    function test_route_chir_to_weth_when_burning_allowed() public {
        IProtocolDETF burnEnabledDetf = _deployBurnEnabledDetf();
        uint256 amountIn = 5_000e18;
        deal(address(burnEnabledDetf), detfAlice, amountIn, true);

        _assertBurnEnabled(burnEnabledDetf);

        vm.startPrank(detfAlice);
        IERC20(address(burnEnabledDetf)).approve(address(burnEnabledDetf), amountIn);
        uint256 wethOut = IStandardExchangeIn(address(burnEnabledDetf)).exchangeIn(
            IERC20(address(burnEnabledDetf)), amountIn, IERC20(address(weth9)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(wethOut, 0, "burn route should return WETH");
    }

    function test_exchangeIn_chir_to_weth_preview_matches_execution_when_burning_allowed() public {
        IProtocolDETF burnEnabledDetf = _deployBurnEnabledDetf();
        uint256 amountIn = 4e18;
        deal(address(burnEnabledDetf), detfAlice, amountIn, true);

        uint256 expectedWeth = IStandardExchangeIn(address(burnEnabledDetf)).previewExchangeIn(
            IERC20(address(burnEnabledDetf)), amountIn, IERC20(address(weth9))
        );
        assertGt(expectedWeth, 0, "preview should return non-zero");

        vm.startPrank(detfAlice);
        IERC20(address(burnEnabledDetf)).approve(address(burnEnabledDetf), amountIn);
        uint256 wethOut = IStandardExchangeIn(address(burnEnabledDetf)).exchangeIn(
            IERC20(address(burnEnabledDetf)), amountIn, IERC20(address(weth9)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(wethOut, expectedWeth, "CHIR->WETH execution output must match preview exactly");
    }

    function test_route_chir_to_weth_reverts_when_burning_not_allowed_in_mint_enabled_fixture() public {
        IProtocolDETF mintEnabledDetf = _deployMintEnabledDetf();
        uint256 amountIn = 5_000e18;
        uint256 syntheticPrice;

        _assertMintEnabled(mintEnabledDetf);
        deal(address(mintEnabledDetf), detfAlice, amountIn, true);
        syntheticPrice = mintEnabledDetf.syntheticPrice();

        vm.startPrank(detfAlice);
        IERC20(address(mintEnabledDetf)).approve(address(mintEnabledDetf), amountIn);
        vm.expectRevert(
            abi.encodeWithSelector(IProtocolDETFErrors.BurningNotAllowed.selector, syntheticPrice, mintEnabledDetf.burnThreshold())
        );
        IStandardExchangeIn(address(mintEnabledDetf)).exchangeIn(
            IERC20(address(mintEnabledDetf)), amountIn, IERC20(address(weth9)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_exchangeOut_weth_to_chir_preview_reverts_when_minting_not_allowed() public {
        IProtocolDETF burnEnabledDetf = _deployBurnEnabledDetf();
        uint256 exactChirOut = 1_000e18;
        uint256 syntheticPrice = burnEnabledDetf.syntheticPrice();
        uint256 mintThreshold = burnEnabledDetf.mintThreshold();

        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(burnEnabledDetf)).previewExchangeOut(IERC20(address(weth9)), IERC20(address(burnEnabledDetf)), exactChirOut);
    }

    function test_exchangeIn_weth_to_rich_preview() public {
        uint256 amountIn = 5_000e18;

        uint256 expectedRich = IStandardExchangeIn(address(detf)).previewExchangeIn(
            IERC20(address(weth9)),
            amountIn,
            rich
        );
        assertGt(expectedRich, 0, "preview should return non-zero");

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), amountIn);
        uint256 richOut = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(weth9)),
            amountIn,
            rich,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertLe(expectedRich, richOut, "exact-in preview must not exceed actual output");
        assertApproxEqRel(
            richOut,
            expectedRich,
            (PREVIEW_RICHIR_BUFFER_BPS + 10) * 1e14,
            "preview should stay close to actual output"
        );
    }

    function test_exchangeIn_weth_to_rich_pretransferred() public {
        uint256 amountIn = 5_000e18;
        uint256 wethBefore = IERC20(address(weth9)).balanceOf(detfAlice);
        uint256 richBefore = rich.balanceOf(detfAlice);

        vm.prank(detfAlice);
        IERC20(address(weth9)).transfer(address(detf), amountIn);

        vm.prank(detfAlice);
        uint256 richOut = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(weth9)),
            amountIn,
            rich,
            0,
            detfAlice,
            true,
            block.timestamp + 1 hours
        );

        assertGt(richOut, 0, "should receive RICH");
        assertEq(rich.balanceOf(detfAlice), richBefore + richOut, "RICH should be credited to user");
        assertEq(IERC20(address(weth9)).balanceOf(detfAlice), wethBefore - amountIn, "WETH should be deducted from user");
    }

    function test_exchangeIn_weth_to_rich_slippage() public {
        uint256 amountIn = 5_000e18;
        uint256 expectedRich = IStandardExchangeIn(address(detf)).previewExchangeIn(
            IERC20(address(weth9)),
            amountIn,
            rich
        );

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), amountIn);
        vm.expectRevert();
        IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(weth9)),
            amountIn,
            rich,
            expectedRich * 2,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }


    function test_exchangeIn_rich_to_weth_preview() public {
        uint256 amountIn = 5_000e18;

        uint256 expectedWeth = IStandardExchangeIn(address(detf)).previewExchangeIn(
            rich,
            amountIn,
            IERC20(address(weth9))
        );
        assertGt(expectedWeth, 0, "preview should return non-zero");

        vm.startPrank(detfAlice);
        rich.approve(address(detf), amountIn);
        uint256 wethOut = IStandardExchangeIn(address(detf)).exchangeIn(
            rich,
            amountIn,
            IERC20(address(weth9)),
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertLe(expectedWeth, wethOut, "exact-in preview must not exceed actual output");
        assertApproxEqRel(wethOut, expectedWeth, 0.01e18, "preview should stay within 1% of actual output");
    }

    function test_exchangeIn_rich_to_weth_recipient() public {
        uint256 amountIn = 5_000e18;
        uint256 wethBefore = IERC20(address(weth9)).balanceOf(detfBob);

        vm.startPrank(detfAlice);
        rich.approve(address(detf), amountIn);
        uint256 wethOut = IStandardExchangeIn(address(detf)).exchangeIn(
            rich,
            amountIn,
            IERC20(address(weth9)),
            0,
            detfBob,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(IERC20(address(weth9)).balanceOf(detfBob), wethBefore + wethOut, "WETH should be sent to the requested recipient");
    }

    function test_exchangeIn_rich_to_chir_preview_reverts_when_minting_not_allowed() public {
        IProtocolDETF burnEnabledDetf = _deployBurnEnabledDetf();
        uint256 amountIn = 5_000e18;
        uint256 syntheticPrice = burnEnabledDetf.syntheticPrice();
        uint256 mintThreshold = burnEnabledDetf.mintThreshold();

        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeIn(address(burnEnabledDetf)).previewExchangeIn(rich, amountIn, IERC20(address(burnEnabledDetf)));
    }

    function test_route_rich_to_chir_when_minting_allowed() public {
        IProtocolDETF mintEnabledDetf = _deployMintEnabledDetf();
        uint256 amountIn = 5_000e18;

        _assertMintEnabled(mintEnabledDetf);

        vm.startPrank(detfAlice);
        rich.approve(address(mintEnabledDetf), amountIn);
        uint256 chirOut = IStandardExchangeIn(address(mintEnabledDetf)).exchangeIn(
            rich, amountIn, IERC20(address(mintEnabledDetf)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(chirOut, 0, "mint wrapper route should return CHIR");
        assertEq(IERC20(address(mintEnabledDetf)).balanceOf(detfAlice), chirOut, "CHIR should be minted to user");
    }

    function test_exchangeIn_rich_to_chir_preview_matches_execution_when_minting_allowed() public {
        IProtocolDETF mintEnabledDetf = _deployMintEnabledDetf();
        uint256 amountIn = 5_000e18;

        _assertMintEnabled(mintEnabledDetf);

        uint256 expectedChir = IStandardExchangeIn(address(mintEnabledDetf)).previewExchangeIn(
            rich, amountIn, IERC20(address(mintEnabledDetf))
        );

        vm.startPrank(detfAlice);
        rich.approve(address(mintEnabledDetf), amountIn);
        uint256 chirOut = IStandardExchangeIn(address(mintEnabledDetf)).exchangeIn(
            rich, amountIn, IERC20(address(mintEnabledDetf)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertLe(expectedChir, chirOut, "exact-in preview must not exceed actual output");
        assertApproxEqRel(chirOut, expectedChir, 0.10e18, "preview should stay within 10% of actual output");
    }

    function test_preview_vs_actual_rich_to_richir_blackbox() public {
        uint256 amountIn = 5_000e18;
        uint256 protocolId = detf.protocolNFTId();
        uint256 posBefore = protocolNFTVault.getPosition(protocolId).originalShares;

        uint256 previewRichir = IStandardExchangeIn(address(detf)).previewExchangeIn(rich, amountIn, IERC20(address(richir)));

        vm.recordLogs();
        vm.startPrank(detfAlice);
        rich.approve(address(detf), amountIn);
        uint256 actualRichir = IStandardExchangeIn(address(detf)).exchangeIn(
            rich,
            amountIn,
            IERC20(address(richir)),
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 actualVaultSharesMinted = _sumTransferMints(logs, address(richChirVault), address(detf));
        uint256 actualRichirMinted = _sumTransferMints(logs, address(richir), detfAlice);
        uint256 posAfter = protocolNFTVault.getPosition(protocolId).originalShares;
        uint256 actualBptAddedToProtocolNft = posAfter - posBefore;

        assertEq(actualRichir, actualRichirMinted, "route return should match the minted RICHIR amount");
        assertGt(actualVaultSharesMinted, 0, "execution should mint intermediate vault shares");
        assertGt(actualBptAddedToProtocolNft, 0, "execution should add reserve shares to the protocol NFT");
        assertLt(previewRichir, actualRichir, "preview should remain conservative because of the output buffer");

        uint256 richirDiff = actualRichir - previewRichir;
        uint256 richirDiffBps = (richirDiff * PREVIEW_BUFFER_DENOMINATOR) / actualRichir;
        assertGt(richirDiffBps, 0, "preview buffer should be positive");
        assertLe(
            richirDiffBps,
            PREVIEW_RICHIR_BUFFER_BPS + 1000,
            "preview drift should stay within the configured buffer plus execution noise"
        );
    }

    function test_preview_vs_actual_weth_to_richir_blackbox() public {
        uint256 amountIn = 5_000e18;
        uint256 protocolId = detf.protocolNFTId();
        uint256 posBefore = protocolNFTVault.getPosition(protocolId).originalShares;
        uint256 chirSupplyBefore = IERC20(address(detf)).totalSupply();

        uint256 previewRichir = IStandardExchangeIn(address(detf)).previewExchangeIn(
            IERC20(address(weth9)),
            amountIn,
            IERC20(address(richir))
        );

        vm.recordLogs();
        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), amountIn);
        uint256 actualRichir = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(weth9)),
            amountIn,
            IERC20(address(richir)),
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 actualVaultSharesMinted = _sumTransferMints(logs, address(chirWethVault), address(detf));
        uint256 actualRichirMinted = _sumTransferMints(logs, address(richir), detfAlice);
        uint256 posAfter = protocolNFTVault.getPosition(protocolId).originalShares;
        uint256 actualBptAddedToProtocolNft = posAfter - posBefore;
        uint256 chirSupplyAfter = IERC20(address(detf)).totalSupply();

        assertEq(actualRichir, actualRichirMinted, "route return should match the minted RICHIR amount");
        assertGt(actualVaultSharesMinted, 0, "execution should mint intermediate vault shares");
        assertGt(actualBptAddedToProtocolNft, 0, "execution should add reserve shares to the protocol NFT");
        // Unchanged CHIR total supply proves this direct route did not mint CHIR.
        assertEq(chirSupplyAfter, chirSupplyBefore, "direct WETH to RICHIR should not mint CHIR");
        assertLt(previewRichir, actualRichir, "preview should remain conservative because of the output buffer");

        uint256 richirDiff = actualRichir - previewRichir;
        uint256 richirDiffBps = (richirDiff * PREVIEW_BUFFER_DENOMINATOR) / actualRichir;
        assertGt(richirDiffBps, 0, "preview buffer should be positive");
        assertLe(richirDiffBps, PREVIEW_RICHIR_BUFFER_BPS + 4000, "WETH to RICHIR preview drift should stay bounded");
    }

    function test_preview_vs_actual_richir_to_weth_blackbox() public {
        uint256 richBondAmount = 1_000_000e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), richBondAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf)).bond(
            rich, richBondAmount, lockDuration, detfAlice, false, block.timestamp + 1 hours
        );
        IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();

        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);

        uint256 richirAmount = richir.balanceOf(detfAlice);
        uint256 expectedWeth = IStandardExchangeIn(address(detf)).previewExchangeIn(
            IERC20(address(richir)),
            richirAmount,
            IERC20(address(weth9))
        );
        assertGt(expectedWeth, 0, "preview should return non-zero");

        vm.startPrank(detfAlice);
        richir.approve(address(detf), richirAmount);
        uint256 wethOut = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(richir)),
            richirAmount,
            IERC20(address(weth9)),
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertLe(expectedWeth, wethOut, "exact-in preview must not exceed actual output");
        assertApproxEqRel(wethOut, expectedWeth, 0.01e18, "preview should stay within 1% of actual output");
    }

    function test_preview_vs_actual_richir_to_rich_blackbox() public {
        uint256 richBondAmount = 1_000_000e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), richBondAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf)).bond(
            rich, richBondAmount, lockDuration, detfAlice, false, block.timestamp + 1 hours
        );
        IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();

        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);

        uint256 richirAmount = richir.balanceOf(detfAlice);
        uint256 expectedRich = IStandardExchangeIn(address(detf)).previewExchangeIn(
            IERC20(address(richir)),
            richirAmount,
            rich
        );
        assertGt(expectedRich, 0, "preview should return non-zero");

        vm.startPrank(detfAlice);
        richir.approve(address(detf), richirAmount);
        uint256 richOut = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(richir)),
            richirAmount,
            rich,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertLe(expectedRich, richOut, "exact-in preview must not exceed actual output");
        assertApproxEqRel(richOut, expectedRich, 0.02e18, "preview should stay within 2% of actual output");
    }

    function test_roundtrip_weth_rich_weth() public {
        uint256 wethIn = 5_000e18;

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), wethIn);
        uint256 richOut = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(weth9)),
            wethIn,
            rich,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        rich.approve(address(detf), richOut);
        uint256 wethOut = IStandardExchangeIn(address(detf)).exchangeIn(
            rich,
            richOut,
            IERC20(address(weth9)),
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(richOut, 0, "first leg should produce RICH");
        assertGt(wethOut, 0, "second leg should produce WETH");
        assertLt(wethOut, wethIn, "round-trip should incur some slippage");
        assertGt(wethOut, (wethIn * 90) / 100, "round-trip loss should stay bounded");
    }

    function _sumTransferMints(Vm.Log[] memory logs_, address token_, address to_) internal pure returns (uint256 sum_) {
        bytes32 transferSig = keccak256("Transfer(address,address,uint256)");

        for (uint256 i = 0; i < logs_.length; ++i) {
            Vm.Log memory logEntry = logs_[i];
            if (logEntry.emitter != token_ || logEntry.topics.length < 3 || logEntry.topics[0] != transferSig) {
                continue;
            }

            address from = address(uint160(uint256(logEntry.topics[1])));
            address to = address(uint160(uint256(logEntry.topics[2])));
            if (from != address(0) || to != to_) {
                continue;
            }

            sum_ += abi.decode(logEntry.data, (uint256));
        }
    }

}
