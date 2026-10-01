// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookMaintenanceProgressTest[]
contract UniswapV4FullSpreadPonsFamilyHookMaintenanceProgressTest is Acceptance {
    using PoolIdLibrary for *;

    function test_balancedRepeatedCallsDoNotTradeOrRewardCaller() public {
        _bootstrap();
        uint256 supply = vault.totalSupply();
        uint256 caller0 = token0.balanceOf(address(this));
        uint256 caller1 = token1.balanceOf(address(this));
        (uint160 price,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        for (uint256 i; i < 3; ++i) Reserve(address(vault)).rebalanceLiquidReserve();
        (uint160 afterPrice,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertEq(price, afterPrice);
        assertEq(vault.totalSupply(), supply);
        assertEq(token0.balanceOf(address(this)), caller0);
        assertEq(token1.balanceOf(address(this)), caller1);
        _assertBooked();
    }

    function test_liveSleeveOneMeansHalfTheBookNotAllLocal() public {
        _bootstrap();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 1e18);
        Reserve(address(vault)).rebalanceLiquidReserve();
        (uint256 d0, uint256 d1) = Reserve(address(vault)).deployedReserve();
        assertGt(d0, 0); assertGt(d1, 0);
        uint256 f0 = token0.balanceOf(address(vault));
        uint256 f1 = token1.balanceOf(address(vault));
        assertLe(f0 > d0 ? f0 - d0 : d0 - f0, 2);
        assertLe(f1 > d1 ? f1 - d1 : d1 - f1, 2);
        _assertBooked();
    }

    function test_holderRepairSwapsAndAllowsSameTransactionRepeats() public {
        _bootstrap();
        token0.transfer(address(vault), 10e18);
        (uint160 beforePrice,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        uint256 gasBefore = gasleft();
        Reserve(address(vault)).rebalanceLiquidReserve();
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("holder repair gas", gasUsed);
        assertLt(gasUsed, 28_000_000, "repair must retain 4M headroom below the 32M mainnet cap");
        (uint160 afterPrice,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertLt(afterPrice, beforePrice);
        Reserve(address(vault)).rebalanceLiquidReserve();
        _assertBooked();
    }

    function test_storedZeroInheritsAndEffectiveZeroTargetsNoSleeve() public {
        _bootstrap();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 0);
        vm.stopPrank();
        assertEq(Reserve(address(vault)).targetLiquidReservePercentage(), 0.2e18);
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(Reserve).interfaceId, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0);
        vm.stopPrank();
        assertEq(Reserve(address(vault)).targetLiquidReservePercentage(), 0);
        Reserve(address(vault)).rebalanceLiquidReserve();
        assertLe(token0.balanceOf(address(vault)), 1e12);
        assertLe(token1.balanceOf(address(vault)), 1e12);
        _assertBooked();
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookMaintenanceProgressTest[]
