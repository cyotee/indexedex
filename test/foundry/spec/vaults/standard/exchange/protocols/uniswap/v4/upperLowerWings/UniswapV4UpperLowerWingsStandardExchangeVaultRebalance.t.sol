// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from "./reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTest[]
abstract contract UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;
    Actor internal externalLp;
    function setUp() public virtual override {
        super.setUp();
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        externalLp = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256("Rebalance.externalLp")));
        token0.mint(address(this), 1e25); token1.mint(address(this), 1e25);
        token0.mint(address(externalLp), 1e25); token1.mint(address(externalLp), 1e25);
        token0.approve(address(wings0), type(uint256).max); token1.approve(address(wings1), type(uint256).max);
        externalLp.modify(key, -887220, 887220, 1e18, bytes32(0));
    }
}

contract UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTest is UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture {
    using StateLibrary for IPoolManager;
    function test_firstTargetOnlyDepositCanRebalanceIntoCoreBothTargets() public {
        for (uint256 i; i < 2; ++i) {
            uint256 snapshot = vm.snapshotState();
            IUniswapV4UpperLowerWingsStandardExchangeVault vault = i == 0 ? wings0 : wings1;
            _deposit(vault);
            (,, uint128 core,) = vault.position(0); assertEq(core, 0);
            uint256 valueBefore = vault.liquidationValue().value;
            address keeper = makeAddr("keeper");
            vm.prank(keeper);
            uint256 afterValue = IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance(address(vault)).rebalance(0, block.timestamp);
            (,, core,) = vault.position(0); assertGt(core, 0);
            assertGe(afterValue, valueBefore - valueBefore / 100);
            assertEq(IERC20(address(vault)).balanceOf(keeper), 0);
            assertEq(token0.balanceOf(keeper), 0); assertEq(token1.balanceOf(keeper), 0);
            assertEq(IERC20(address(vault)).totalSupply(), 1e12);
            (uint256 local0, uint256 local1) = vault.localReserves();
            assertGe(i == 0 ? local0 : local1, 1);
            assertEq(token0.balanceOf(address(vault)), local0); assertEq(token1.balanceOf(address(vault)), local1);
            assertTrue(vm.revertToState(snapshot));
        }
    }
    function test_repeatedRebalanceLossScalesWithActualCoreProgress() public {
        _deposit(wings0);
        for (uint256 i; i < 8; ++i) {
            (,, uint128 beforeCore,) = wings0.position(0);
            uint256 beforeValue = wings0.liquidationValue().value;
            try IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance(address(wings0)).rebalance(0, block.timestamp) returns (uint256 afterValue) {
                (,, uint128 afterCore,) = wings0.position(0);
                assertGt(afterCore, beforeCore);
                uint256 budget = FullMath.mulDiv(beforeValue, afterCore - beforeCore, afterCore) / 100;
                assertGe(afterValue, beforeValue - budget);
            } catch (bytes memory reason) {
                bytes4 selector = bytes4(reason);
                assertTrue(selector == IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.NoRebalanceProgress.selector || selector == IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.RebalanceLossExceeded.selector);
                assertEq(wings0.liquidationValue().value, beforeValue);
                break;
            }
        }
        assertEq(IERC20(address(wings0)).totalSupply(), 1e12);
    }
    function test_rebalanceBlockedByOuterUnlock() public {
        _deposit(wings0);
        vm.expectRevert(IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.RebalanceUnavailable.selector);
        externalLp.callWhileUnlocked(key, address(wings0), abi.encodeCall(IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.rebalance, (0, block.timestamp)));
    }
    function test_lateMinimumFailureRestoresWholePortfolioAndPool() public {
        _deposit(wings0);
        (uint160 price, int24 tick,,) = pool.getSlot0(key.toId());
        uint256 value = wings0.liquidationValue().value;
        (,, uint128 wing,) = wings0.position(1);
        vm.expectPartialRevert(IStandardExchangeErrors.MinAmountNotMet.selector);
        IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance(address(wings0)).rebalance(type(uint256).max, block.timestamp);
        (uint160 afterPrice, int24 afterTick,,) = pool.getSlot0(key.toId());
        assertEq(afterPrice, price); assertEq(afterTick, tick);
        assertEq(wings0.liquidationValue().value, value);
        (,, uint128 afterWing,) = wings0.position(1); assertEq(afterWing, wing);
    }
    function test_increasedOracleSleeveRestoresLocalCover() public {
        _deposit(wings0);
        IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance(address(wings0)).rebalance(0, block.timestamp);
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(1e18);
        IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance(address(wings0)).rebalance(0, block.timestamp);
        (uint256 local0,) = wings0.localReserves();
        assertGt(local0, 1e12 / 5, "raised oracle percentage replenishes target cover");
        assertEq(token0.balanceOf(address(wings0)), local0);
    }
    function _deposit(IUniswapV4UpperLowerWingsStandardExchangeVault vault_) private {
        IStandardExchangeIn(address(vault_)).exchangeIn(IERC20(vault_.targetToken()), 1e12, IERC20(address(vault_)), 1e12, address(this), false, block.timestamp);
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTest[]
