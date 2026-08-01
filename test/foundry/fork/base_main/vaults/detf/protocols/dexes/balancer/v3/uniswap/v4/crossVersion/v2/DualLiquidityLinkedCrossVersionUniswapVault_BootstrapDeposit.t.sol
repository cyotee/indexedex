// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultRepo} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Proves the inert real deployment becomes functional through the manual bootstrap, end-to-end
///         over real Uniswap V4 + V2 legs and a real Balancer reserve pool. The deployed diamond exposes
///         no bespoke interface - the reserve pool and legs are read from the standard vault surface
///         (`IBasicVault.vaultTokens()`). Bootstrap: acquire the three leg shares from real leg deposits,
///         initialize the reserve pool for BPT, then make the first vault deposit (reserve BPT -> shares,
///         minted 1:1 against an empty vault).
contract DualLiquidityLinkedCrossVersionUniswapVault_BootstrapDeposit is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    /// @notice A non-bootstrap route reverts on the inert vault (reserve holds no BPT).
    function test_inertVault_nonBootstrapRouteReverts() public {
        assertEq(IERC20(_reservePool()).balanceOf(linkedVault), 0, "reserve BPT is zero at deploy");
        vm.expectRevert(DualLiquidityLinkedCrossVersionUniswapVaultRepo.ReservePoolNotInitialized.selector);
        IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(address(commonToken)), 1e18, IERC20(linkedVault), 0, address(this), false, block.timestamp
        );
    }

    /// @notice The manual bootstrap makes the vault live and mints the bootstrapper 1:1.
    function test_bootstrap_makesVaultLive_mints1to1() public {
        uint256 bpt = _bootstrapReserve();
        assertGt(bpt, 0, "reserve pool minted BPT");
        uint256 reserveBpt = IERC20(_reservePool()).balanceOf(linkedVault);
        assertGt(reserveBpt, 0, "reserve live after bootstrap");
        // First deposit mints 1:1: supply equals the BPT now backing it.
        assertEq(IERC20(linkedVault).totalSupply(), reserveBpt, "1:1 genesis ratio");
        assertGt(IERC20(linkedVault).balanceOf(address(this)), 0, "bootstrapper holds vault shares");
    }

    /// @notice After bootstrap, a real commonToken deposit routes through the legs and mints shares.
    function test_bootstrap_thenRealDeposit_mintsShares() public {
        _bootstrapReserve();
        commonToken.approve(linkedVault, LEG_SEED);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(address(commonToken)), LEG_SEED, IERC20(linkedVault), 0, address(this), false, block.timestamp
        );
        assertGt(minted, 0, "post-bootstrap depositor receives shares");
    }
}
