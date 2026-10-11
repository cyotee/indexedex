// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAToken} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAToken.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {DataTypes} from "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/types/DataTypes.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAaveOracle as IAaveOracleV4} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";
import {IAccessManager} from "@crane/contracts/external/openzeppelin-contracts/access/manager/IAccessManager.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {Roles} from "@crane/contracts/protocols/lending/aave/v4/deployments/utils/libraries/Roles.sol";
import {MockPriceFeed} from "@crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/MockPriceFeed.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {CrossVersionLoopExecutor} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol";
import {Errors} from "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/helpers/Errors.sol";
import {AaveCrossVersionLoop_APEX_D43_Test} from "./AaveCrossVersionLoop_APEX_D43.t.sol";

/// @notice R14.7 boundary verification with production pools, equal prices and 18-decimal tokens.
contract AaveCrossVersionLoop_APEX_Recurrence is AaveCrossVersionLoop_APEX_D43_Test {
    /// @notice Reuse the production market orchestration with the criterion's explicit token units.
    function setUp() public override {
        TestBase_VaultComponents.setUp();
        _deployTestTokenPkg();
        tokenA = IERC20(testTokenPkg.deployToken("Recurrence A", "RA", 18, address(this), keccak256("recurrence-A")));
        tokenB = IERC20(testTokenPkg.deployToken("Recurrence B", "RB", 18, address(this), keccak256("recurrence-B")));
        _setUpV4Market();
        _setUpV3Market();
        MockPriceFeed(IAaveOracle(v36Oracle).getSourceOfAsset(address(tokenA))).setPrice(1e8);
        MockPriceFeed(IAaveOracleV4(address(v4Oracle)).getReserveSource(v4ReserveIdA)).setPrice(1e8);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        _initVault();
        _mint(tokenB, v3lp, 2_000_000 ether);
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), type(uint256).max);
        v36Pool.supply(address(tokenB), 2_000_000 ether, v3lp, 0);
        vm.stopPrank();
        _mint(tokenA, v4lp, 1_000 ether);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), type(uint256).max);
        v4Spoke.supply(v4ReserveIdA, 1_000 ether, v4lp);
        vm.stopPrank();
    }

    function _assertNoLoopDebt() internal view {
        assertEq(AaveV36Service.debtOf(v36Pool, address(tokenB), vault), 0, "no V3 debt");
        assertEq(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), 0, "no V4 debt");
        assertEq(AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, vault), 0, "no V4 collateral");
    }

    /// @notice Capacity exactly equal to initial principal stops before either recursive borrow.
    function test_RECURRENCE_DX01_exactInitialCapacity_noRecursivePosition() public {
        _setSupplyCapA(100);
        uint256 quoted = IStandardExchangeIn(vault).previewExchangeIn(tokenA, 100 ether, IERC20(vault));
        assertEq(_deposit(100 ether), quoted, "shares for principal only");
        assertEq(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), 100 ether, "initial supply only");
        assertEq(tokenA.balanceOf(vault), 0, "no idle borrowed principal");
        _assertNoLoopDebt();
    }

    /// @notice Zero initial capacity on a fresh vault retains all input and starts no position.
    function test_RECURRENCE_DX01_zeroInitialCapacity_freshVault() public {
        _mint(tokenA, address(this), 1 ether);
        tokenA.approve(address(v36Pool), 1 ether);
        v36Pool.supply(address(tokenA), 1 ether, address(this), 0);
        _setSupplyCapA(1);
        uint256 quoted = IStandardExchangeIn(vault).previewExchangeIn(tokenA, 100 ether, IERC20(vault));
        assertEq(_deposit(100 ether), quoted, "shares for all retained principal");
        assertEq(tokenA.balanceOf(vault), 100 ether, "whole principal local");
        assertEq(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), 0, "no initial investment");
        _assertNoLoopDebt();
    }

    /// @notice The locked 100/150 case checks both collateral/debt legs and principal-only share issuance.
    function test_RECURRENCE_DX01_laterCapacity_exactNumericPosition() public {
        _setSupplyCapA(150);
        uint256 quoted = IStandardExchangeIn(vault).previewExchangeIn(tokenA, 100 ether, IERC20(vault));
        vm.expectCall(address(v36Pool), abi.encodeCall(IPool.supply, (address(tokenA), 100 ether, vault, 0)), 1);
        vm.expectCall(address(v36Pool), abi.encodeCall(IPool.supply, (address(tokenA), 39.69 ether, vault, 0)), 1);
        vm.expectCall(address(v36Pool), abi.encodeCall(IPool.supply, (address(tokenA), 10.31 ether, vault, 0)), 1);
        assertEq(_deposit(100 ether), quoted, "borrowed amounts mint no extra caller shares");
        assertEq(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), 150 ether, "100 plus 39.69 plus 10.31 supplied");
        assertEq(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), 50 ether, "recursive tokenA debt");
        assertEq(AaveV36Service.debtOf(v36Pool, address(tokenB), vault), 88.0047 ether, "63 plus 25.0047 tokenB borrowed");
        assertEq(AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, vault), 88.0047 ether, "all borrowed tokenB collateralized");
        assertEq(tokenA.balanceOf(vault), 0, "no idle borrowed tokenA");
        assertEq(tokenB.balanceOf(vault), 0, "no idle tokenB");
        assertEq(IERC20(vault).balanceOf(address(this)), quoted, "only quoted principal claim");
    }

    /// @notice A real frozen V4 collateral reserve fails after V3 progress and rolls that entire transaction back.
    function test_RECURRENCE_DX01_dependencyFailureAfterProgress_exactRollback() public {
        _setSupplyCapA(150);
        uint256 snapshot = vm.snapshotState();
        _deposit(100 ether);
        assertEq(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), 150 ether, "same-route positive cap stop");
        assertTrue(vm.revertToState(snapshot), "restore funded pools before failure");
        IAccessManager(v4AccessManager).grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(this), 0);
        ISpoke.ReserveConfig memory config = v4Spoke.getReserveConfig(v4ReserveIdB);
        config.frozen = true;
        v4Spoke.updateReserveConfig(v4ReserveIdB, config);
        _mint(tokenA, address(this), 100 ether);
        tokenA.approve(vault, 100 ether);
        uint256 poolBalance = tokenA.balanceOf(address(v36Pool.getReserveAToken(address(tokenA))));
        vm.expectRevert(ISpoke.ReserveFrozen.selector);
        IStandardExchangeIn(vault).exchangeIn(tokenA, 100 ether, IERC20(vault), 0, address(this), false, block.timestamp);
        assertEq(tokenA.balanceOf(address(this)), 100 ether, "caller transfer rolled back");
        assertEq(tokenA.allowance(address(this), vault), 100 ether, "caller allowance rolled back");
        assertEq(tokenA.balanceOf(vault), 0, "no local transfer survives");
        assertEq(tokenB.balanceOf(vault), 0, "no borrowed token survives");
        assertEq(tokenA.balanceOf(address(v36Pool.getReserveAToken(address(tokenA)))), poolBalance, "V3 token transfer rolled back");
        assertEq(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), 0, "initial V3 supply rolled back");
        assertEq(IERC20(vault).totalSupply(), 0, "caller and minimum shares rolled back");
        _assertNoLoopDebt();
    }

    /// @notice Reserve principal consumes finite reopened capacity before the new caller's independent loop.
    function test_RECURRENCE_DX01_reopenFiniteCapacity_sweepBeforeCaller() public {
        _mint(tokenA, address(this), 1 ether);
        tokenA.approve(address(v36Pool), 1 ether);
        v36Pool.supply(address(tokenA), 1 ether, address(this), 0);
        _setSupplyCapA(1);
        _deposit(80 ether);
        _setSupplyCapA(101);
        uint256 quote = IStandardExchangeIn(vault).previewExchangeIn(tokenA, 50 ether, IERC20(vault));
        assertEq(_deposit(50 ether), quote, "only caller's principal is credited");
        assertEq(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), 100 ether, "old principal loop consumes remaining capacity");
        assertEq(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), 20 ether, "old loop leverages only within headroom");
        assertEq(tokenA.balanceOf(vault), 50 ether, "new caller fully retained after old loop consumes capacity");
    }

    /// @notice Real elapsed lending interest creates a non-unit index before a capacity-bound deposit.
    function test_RECURRENCE_DX01_nonUnitLiquidityIndex_capBoundary() public {
        _mint(tokenA, address(this), 100 ether);
        tokenA.approve(address(v36Pool), 100 ether);
        v36Pool.supply(address(tokenA), 100 ether, address(this), 0);
        address borrower = makeAddr("index-growth-borrower");
        _mint(tokenB, borrower, 1_000 ether);
        vm.startPrank(borrower);
        tokenB.approve(address(v36Pool), 1_000 ether);
        v36Pool.supply(address(tokenB), 1_000 ether, borrower, 0);
        v36Pool.borrow(address(tokenA), 10 ether, 2, 0, borrower);
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days);
        uint256 index = v36Pool.getReserveNormalizedIncome(address(tokenA));
        assertGt(index, 1e27, "real interest generated a non-unit supply index");
        _setSupplyCapA(200);
        _assertSupplyCapacityBoundary();
        uint256 preview = IStandardExchangeIn(vault).previewExchangeIn(tokenA, 100 ether, IERC20(vault));
        uint256 minted = _deposit(100 ether);
        assertEq(minted, preview, "capacity does not change principal share quote");
        DataTypes.ReserveDataLegacy memory reserve = v36Pool.getReserveData(address(tokenA));
        uint256 used = (IAToken(reserve.aTokenAddress).scaledTotalSupply() + uint256(reserve.accruedToTreasury))
            * v36Pool.getReserveNormalizedIncome(address(tokenA)) / 1e27;
        assertLe(used, 200 ether, "aggregate scaled supply plus treasury respects cap");
        assertGt(tokenA.balanceOf(vault), 0, "principal that cannot fit remains local");
        _assertNoLoopDebt();
    }

    function _assertSupplyCapacityBoundary() internal {
        CrossVersionLoopExecutor.Market memory market;
        market.v36Pool = v36Pool;
        market.tokenA = tokenA;
        uint256 capacity = CrossVersionLoopExecutor.tokenASupplyCapacity(market);
        assertGt(capacity, 0, "interest leaves executable headroom");
        uint256 snapshot = vm.snapshotState();
        _mint(tokenA, address(this), capacity + 1);
        tokenA.approve(address(v36Pool), capacity + 1);
        vm.expectRevert(Errors.SupplyCapExceeded.selector);
        v36Pool.supply(address(tokenA), capacity + 1, address(this), 0);
        v36Pool.supply(address(tokenA), capacity, address(this), 0);
        assertEq(CrossVersionLoopExecutor.tokenASupplyCapacity(market), 0, "exact capacity exhausts executable supply");
        assertTrue(vm.revertToState(snapshot), "restore boundary state for vault deposit");
    }
}
