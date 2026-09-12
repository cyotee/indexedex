// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {AaveCrossVersionLoopExchangeBase} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol";
import {AaveCrossVersionLoopExchangeInTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";

/// @notice exchangeIn money path on each two-token combo. pairToken = tokenA.
abstract contract AaveCrossVersionLoopExchangeIn_Decimals is TestBase_AaveCrossVersionLoopV3Market_Decimals {
    AaveCrossVersionLoopExchangeInTarget internal vault;
    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);

    function _initVault() internal {
        vault = new AaveCrossVersionLoopExchangeInTarget();
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

    function _seedBorrowLiquidity() internal {
        _mint(tokenB, v3lp, _uB(2_000_000));
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), _uB(2_000_000));
        v36Pool.supply(address(tokenB), _uB(2_000_000), v3lp, 0);
        vm.stopPrank();
        _mint(tokenA, v4lp, _uA(1_000));
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), _uA(1_000));
        v4Spoke.supply(v4ReserveIdA, _uA(1_000), v4lp);
        vm.stopPrank();
    }

    function test_exchangeIn_builds_position_and_mints_shares() public {
        _initVault();
        _seedBorrowLiquidity();
        uint256 deposit = _uA(100);
        _mint(tokenA, address(this), deposit);
        tokenA.approve(address(vault), deposit);
        uint256 previewed = vault.previewExchangeIn(tokenA, deposit, IERC20(address(vault)));
        uint256 shares =
            vault.exchangeIn(tokenA, deposit, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        assertEq(shares, previewed, "preview == execution (shares)");
        assertApproxEqRel(shares, 200_000e8, 0.01e18, "shares ~= deposited value");
        assertGt(
            AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(vault)), deposit, "vault leveraged on V3"
        );
        assertGt(AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, address(vault)), 0, "vault supplied B on V4");
        assertGt(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, address(vault)), 0, "vault borrowed A on V4");
        assertGt(AaveV36Service.healthFactor(v36Pool, address(vault)), 1e18, "vault V3 HF > 1");
        assertGt(AaveV4Service.healthFactor(v4Spoke, address(vault)), 1e18, "vault V4 HF > 1");
        assertEq(tokenA.balanceOf(address(this)), 0, "deposit consumed");
    }
}
