// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {IBaseProtocolDETFDFPkg} from "contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol";
import {
    ProtocolDETFBaseCustomFixtureHelpers,
    ProtocolDETFEthereumCustomFixtureHelpers
} from "./ProtocolDETF_CustomFixtureHelpers.t.sol";

contract ProtocolDETFSyntheticThresholdsBaseTest is ProtocolDETFBaseCustomFixtureHelpers {
    function test_default_fixture_prefers_minting() public view {
        assertGt(detf.syntheticPrice(), detf.mintThreshold(), "default fixture should start above the upper deadband bound");
        assertTrue(detf.isMintingAllowed(), "minting should be enabled above the upper deadband bound");
        assertFalse(detf.isBurningAllowed(), "burning should be disabled above the upper deadband bound");
    }

    function test_low_price_fixture_prefers_burning_and_allows_chir_to_weth() public {
        IProtocolDETF lowPriceDetf = _deployBurnEnabledDetf();

        _assertBurnEnabled(lowPriceDetf);

        uint256 amountIn = 5_000e18;
        deal(address(lowPriceDetf), detfAlice, amountIn, true);
        vm.startPrank(detfAlice);
        IERC20(address(lowPriceDetf)).approve(address(lowPriceDetf), amountIn);
        uint256 wethOut = IStandardExchangeIn(address(lowPriceDetf)).exchangeIn(
            IERC20(address(lowPriceDetf)), amountIn, IERC20(address(weth9)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(wethOut, 0, "burn-enabled fixture should allow CHIR to WETH redemption");
    }

    function test_near_peg_fixture_enforces_deadband() public {
        IProtocolDETF nearPegDetf = _deployDeadbandDetf();

        _assertDeadband(nearPegDetf);
    }

    function test_near_peg_fixture_reverts_mint_and_burn_routes() public {
        IProtocolDETF nearPegDetf = _deployDeadbandDetf();
        uint256 wethAmountIn = 10_000e18;
        uint256 chirAmountIn = 5_000e18;
        uint256 syntheticPrice;

        _assertDeadband(nearPegDetf);
        syntheticPrice = nearPegDetf.syntheticPrice();
        deal(address(nearPegDetf), detfAlice, chirAmountIn, true);

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(nearPegDetf), wethAmountIn);
        vm.expectRevert(
            abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, nearPegDetf.mintThreshold())
        );
        IStandardExchangeIn(address(nearPegDetf)).exchangeIn(
            IERC20(address(weth9)), wethAmountIn, IERC20(address(nearPegDetf)), 0, detfAlice, false, block.timestamp + 1 hours
        );

        IERC20(address(nearPegDetf)).approve(address(nearPegDetf), chirAmountIn);
        vm.expectRevert(
            abi.encodeWithSelector(IProtocolDETFErrors.BurningNotAllowed.selector, syntheticPrice, nearPegDetf.burnThreshold())
        );
        IStandardExchangeIn(address(nearPegDetf)).exchangeIn(
            IERC20(address(nearPegDetf)), chirAmountIn, IERC20(address(weth9)), 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}

contract ProtocolDETFSyntheticThresholdsEthereumTest is ProtocolDETFEthereumCustomFixtureHelpers {
    function test_default_fixture_prefers_minting() public view {
        assertGt(detf.syntheticPrice(), detf.mintThreshold(), "default fixture should start above the upper deadband bound");
        assertTrue(detf.isMintingAllowed(), "minting should be enabled above the upper deadband bound");
        assertFalse(detf.isBurningAllowed(), "burning should be disabled above the upper deadband bound");
    }

    function test_low_price_fixture_prefers_burning() public {
        _driveEthereumToBurnEnabled(detf);
    }

    function test_near_peg_fixture_enforces_deadband() public {
        _driveEthereumToDeadband(detf);
    }

    function test_near_peg_fixture_reverts_mint_and_burn_routes() public {
        uint256 wethAmountIn = 10_000e18;
        uint256 chirAmountIn = 5_000e18;
        bool success;
        bytes memory revertData;
        bytes4 revertSelector;

        _driveEthereumToDeadband(detf);
        deal(address(detf), detfAlice, chirAmountIn, true);

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), wethAmountIn);
        (success, revertData) = address(detf).call(
            abi.encodeCall(
                IStandardExchangeIn.exchangeIn,
                (IERC20(address(weth9)), wethAmountIn, IERC20(address(detf)), 0, detfAlice, false, block.timestamp + 1 hours)
            )
        );
        assertFalse(success, "deadband mint route should revert");
        assembly {
            revertSelector := mload(add(revertData, 32))
        }
        assertEq(revertSelector, IProtocolDETFErrors.MintingNotAllowed.selector, "mint route should revert with MintingNotAllowed");

        IERC20(address(detf)).approve(address(detf), chirAmountIn);
        (success, revertData) = address(detf).call(
            abi.encodeCall(
                IStandardExchangeIn.exchangeIn,
                (IERC20(address(detf)), chirAmountIn, IERC20(address(weth9)), 0, detfAlice, false, block.timestamp + 1 hours)
            )
        );
        assertFalse(success, "deadband burn route should revert");
        assembly {
            revertSelector := mload(add(revertData, 32))
        }
        assertEq(revertSelector, IProtocolDETFErrors.BurningNotAllowed.selector, "burn route should revert with BurningNotAllowed");
        vm.stopPrank();
    }
}