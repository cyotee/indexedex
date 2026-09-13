// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";
import {AaveCrossVersionLoopExchangeBase} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol";
import {AaveCrossVersionLoopExchangeInTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol";
import {AaveCrossVersionLoopRebalanceTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";

/// @dev Combined In + Rebalance vault mirroring the diamond (shared storage). Gold Target-as-vault.
contract _RebalVaultDecimals is AaveCrossVersionLoopExchangeInTarget, AaveCrossVersionLoopRebalanceTarget {}

/// @notice Rebalance money paths on each two-token combo. pairToken = tokenA.
abstract contract AaveCrossVersionLoopRebalance_Decimals is TestBase_AaveCrossVersionLoopV3Market_Decimals {
    _RebalVaultDecimals internal vault;
    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);
    address internal v4borrower = address(0x4099);

    function _initVault() internal {
        vault = new _RebalVaultDecimals();
        vault.initCrossVersionLoop(
            AaveCrossVersionLoopExchangeBase.InitArgs({
                v36Pool: v36Pool,
                v36AddressesProvider: IPoolAddressesProvider(v36AddressesProvider),
                v36Oracle: IAaveOracle(v36Oracle),
                v4Spoke: v4Spoke,
                v4Hub: v4Hub,
                v4Oracle: IAaveOracleV4(address(v4Oracle)),
                tokenA: tokenA,
                tokenB: tokenB,
                v4AssetIdA: v4AssetIdA,
                v4ReserveIdA: v4ReserveIdA,
                v4AssetIdB: v4AssetIdB,
                v4ReserveIdB: v4ReserveIdB,
                shareName: "Cross Loop Vault",
                shareSymbol: "CLV"
            })
        );
    }

    function _seedAndDeposit() internal {
        _mint(tokenB, v3lp, _uB(4_000_000));
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), _uB(4_000_000));
        v36Pool.supply(address(tokenB), _uB(4_000_000), v3lp, 0);
        vm.stopPrank();

        _mint(tokenA, v4lp, _uA(2_000));
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), _uA(2_000));
        v4Spoke.supply(v4ReserveIdA, _uA(2_000), v4lp);
        vm.stopPrank();

        uint256 deposit = _uA(100);
        _mint(tokenA, address(this), deposit);
        tokenA.approve(address(vault), deposit);
        vault.exchangeIn(tokenA, deposit, IERC20(address(vault)), 0, address(this), false, block.timestamp);
    }

    function _spikeV4ABorrow() internal {
        _mint(tokenB, v4borrower, _uB(6_000_000));
        vm.startPrank(v4borrower);
        tokenB.approve(address(v4Spoke), _uB(6_000_000));
        v4Spoke.supply(v4ReserveIdB, _uB(6_000_000), v4borrower);
        v4Spoke.setUsingAsCollateral(v4ReserveIdB, true, v4borrower);
        v4Spoke.borrow(v4ReserveIdA, _uA(1_500), v4borrower);
        vm.stopPrank();
    }

    function test_rebalance_respects_min_interval() public {
        _initVault();
        _seedAndDeposit();

        vm.warp(block.timestamp + 2 hours);
        vault.rebalance();

        vm.expectRevert();
        vault.rebalance();
    }

    function test_rebalance_derisks_on_negative_carry() public {
        _initVault();
        _seedAndDeposit();
        _spikeV4ABorrow();

        uint256 suppliedBefore = AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(vault));
        assertLt(vault.previewNetCarry(), int256(0), "carry is negative after spike");

        vm.warp(block.timestamp + 2 hours);
        vault.rebalance();

        assertLt(
            AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(vault)),
            suppliedBefore,
            "de-risked (V3 supply down)"
        );
        assertGt(AaveV36Service.healthFactor(v36Pool, address(vault)), 1e18, "V3 HF > 1");
        assertGt(AaveV4Service.healthFactor(v4Spoke, address(vault)), 1e18, "V4 HF > 1");
    }

    function test_forceRepay_reverts_when_healthy() public {
        _initVault();
        _seedAndDeposit();

        vm.expectRevert(AaveCrossVersionLoopRebalanceTarget.NotAtRisk.selector);
        vault.forceRepay();
    }
}
