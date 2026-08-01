// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Concrete deploy assertions over the inert base deployment: the vault is registered and is an
///         inert share token (zero supply until bootstrapped).
contract DualLiquidityLinkedCrossVersionUniswapVault_ProductionDeploy is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    function test_deployedVault_isRegisteredInRegistry() public view {
        assertTrue(
            IVaultRegistryVaultQuery(address(indexedexManager)).isVault(linkedVault),
            "vault is registered in the Vault Registry (source of truth)"
        );
    }

    function test_deployedVault_isInertShareToken() public view {
        assertEq(IERC20Metadata(linkedVault).name(), "Dual Liquidity Cross-Version Uniswap Vault", "share token name");
        assertEq(IERC20Metadata(linkedVault).symbol(), "dlCVUVault", "share token symbol");
        // Deploy is inert: no dust pre-mint, so supply is zero until the reserve is bootstrapped.
        assertEq(IERC20(linkedVault).totalSupply(), 0, "inert deploy has zero supply");
    }
}
