// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {ThresholdMode, DETFThresholdPolicy} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    DETFEpochNaturalExpansionLib
} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice Phase 1: inert deploy via manager registry path.
contract UniswapV4SingleStandardExchangeDETF_DeployTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    function test_deploy_inert() public view {
        _assertInert();
        assertEq(detfInfo.pairToken(), address(pairToken));
        assertEq(detfInfo.standardExchangeVault(), se);
        assertTrue(detfInfo.reserveHook() != address(0));
        assertTrue(detfInfo.bondNftVault() != address(0));
        assertEq(detfInfo.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF);
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy));
        assertEq(detfInfo.mintThreshold(), DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD);
        assertEq(detfInfo.burnThreshold(), DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD);
        assertEq(detfInfo.expansionEpochLength(), DETFEpochNaturalExpansionLib.DEFAULT_EPOCH_LENGTH);
        assertEq(
            detfInfo.expansionClosureRatePerYearWad(),
            DETFEpochNaturalExpansionLib.DEFAULT_CLOSURE_RATE_PER_YEAR_WAD
        );
        assertEq(detfInfo.lastExpansionTimestamp(), 0);
        assertFalse(detfInfo.isMintingAllowed());
        assertFalse(detfInfo.isBurningAllowed());
        // Fee-recipient NFT must be wired when bond terms resolve (setDefaultBondTerms in TestBase).
        assertTrue(detfInfo.feeRecipientNftId() != 0, "feeRecipientNftId must be non-zero after deploy");
        assertTrue(detfInfo.rebasingClaimToken() != address(0), "rebasing claim wired");
    }

    function test_deploy_physicalLpHolders_startEmpty() public view {
        // Pre-live: no user bond LP on NFT, no protocol LP on claim.
        address hook = detfInfo.reserveHook();
        address bond = detfInfo.bondNftVault();
        address claim = detfInfo.rebasingClaimToken();
        assertEq(IERC20(hook).balanceOf(bond), 0, "bond NFT empty pre-live");
        assertEq(IERC20(hook).balanceOf(claim), 0, "claim empty pre-live");
        assertEq(detfInfo.protocolLp(), 0);
        assertEq(detfInfo.userBondedLp(), 0);
    }

    function test_deploy_launchRich_resolvesR() public {
        address d = _deployDetfInstance(_launchRichArgs());
        assertEq(
            IUniswapV4SingleStandardExchangeDETF(d).expansionClosureRatePerYearWad(), 4.4e18
        );
        assertFalse(IUniswapV4SingleStandardExchangeDETF(d).isReserveLive());
    }

    function test_deploy_open_mode() public {
        address d = _deployDetfInstance(_openArgs());
        assertEq(uint8(IUniswapV4SingleStandardExchangeDETF(d).thresholdMode()), uint8(ThresholdMode.Open));
    }
}
