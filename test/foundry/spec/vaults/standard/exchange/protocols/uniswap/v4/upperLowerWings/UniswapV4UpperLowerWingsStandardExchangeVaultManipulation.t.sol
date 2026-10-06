// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";

/// @notice SEC-08. O1 prices recovery when it becomes realizable and does not reserve it for incumbents.
///         Depositing at a depressed V must not mint more than floor(S * credit / V), and redemption
///         must not pay more than that position's pre-exit share of current V.
contract UniswapV4UpperLowerWingsStandardExchangeVaultManipulationTest is Fixture {
    using StateLibrary for IPoolManager;
    uint256 internal constant DEPOSIT = 1e12;

    function test_externalDepthRemovalDepositRestorationCannotOvermint() public {
        _seed();
        uint256 original = wings0.liquidationValue().value;
        _removeExternalDepth();
        uint256 depressed = wings0.liquidationValue().value;
        assertLt(depressed, original, "removed depth must reduce realizable V");
        _attack(depressed, true);
    }

    function test_unrestoredDepthCannotPayMoreThanTheDeposit() public {
        _seed();
        _removeExternalDepth();
        (, uint256 payout) = _attack(wings0.liquidationValue().value, false);
        assertLe(payout, DEPOSIT + 1, "SEC-08: unrestored depth must not create target proceeds");
    }

    function test_priceRoundTripUsesManipulatedValueThenRestoredShare() public {
        _seed();
        (uint160 price,,,) = pool.getSlot0(key.toId());
        externalLp.swapTo(key, false, 1e24, TickMath.getSqrtPriceAtTick(6000));
        uint256 depressed = wings0.liquidationValue().value;
        uint256 supply = IERC20(address(wings0)).totalSupply();
        address attacker = makeAddr("price attacker");
        token0.mint(attacker, DEPOSIT);
        vm.startPrank(attacker);
        token0.approve(address(wings0), type(uint256).max);
        uint256 minted = IStandardExchangeIn(address(wings0)).exchangeIn(
            token0, DEPOSIT, IERC20(address(wings0)), 0, attacker, false, block.timestamp);
        vm.stopPrank();
        assertEq(minted, FullMath.mulDiv(supply, DEPOSIT, depressed), "SEC-08: price move must not overmint");
        externalLp.swapTo(key, true, 1e24, price);
        uint256 cap = FullMath.mulDiv(minted, wings0.liquidationValue().value, supply + minted);
        vm.prank(attacker);
        uint256 payout = IStandardExchangeIn(address(wings0)).exchangeIn(
            IERC20(address(wings0)), minted, token0, 0, attacker, false, block.timestamp);
        assertLe(payout, cap, "SEC-08: restored redemption exceeds pre-exit share");
        assertEq(token1.balanceOf(attacker), 0);
    }

    function test_jitLiquidityAroundRebalancePaysTheKeeperNothing() public {
        IStandardExchangeIn(address(wings0)).exchangeIn(
            token0, DEPOSIT, IERC20(address(wings0)), DEPOSIT, address(this), false, block.timestamp);
        uint256 before = wings0.liquidationValue().value;
        externalLp.modify(key, -60, 60, int256(1e16), bytes32(uint256(1)));
        address keeper = makeAddr("jit keeper");
        vm.prank(keeper);
        uint256 afterValue = Rebalance(address(wings0)).rebalance(0, block.timestamp);
        externalLp.modify(key, -60, 60, -int256(1e16), bytes32(uint256(1)));
        assertEq(IERC20(address(wings0)).balanceOf(keeper), 0);
        assertEq(token0.balanceOf(keeper), 0);
        assertEq(token1.balanceOf(keeper), 0);
        assertGe(afterValue, before - before / 100, "SEC-15: JIT must not exceed the rebalance loss budget");
        assertEq(IERC20(address(wings0)).totalSupply(), DEPOSIT);
    }

    function test_blockedDepositUsesActualValue() public {
        _seed();
        uint256 supply = IERC20(address(wings0)).totalSupply();
        uint256 actual = wings0.liquidationValue().value;
        externalLp.approveToken(token0, address(wings0));
        bytes memory returned = externalLp.callWhileUnlocked(key, address(wings0), abi.encodeCall(
            IStandardExchangeIn.exchangeIn, (token0, DEPOSIT, IERC20(address(wings0)), 0, address(externalLp), false, block.timestamp)));
        uint256 minted = abi.decode(returned, (uint256));
        assertEq(minted, FullMath.mulDiv(supply, DEPOSIT, actual), "SEC-08: blocked entry must use actual V");
        assertEq(IERC20(address(wings0)).balanceOf(address(externalLp)), minted);
    }

    function _seed() private {
        IStandardExchangeIn(address(wings0)).exchangeIn(
            token0, DEPOSIT, IERC20(address(wings0)), DEPOSIT, address(this), false, block.timestamp);
        Rebalance(address(wings0)).rebalance(0, block.timestamp);
        assertEq(IERC20(address(wings0)).totalSupply(), DEPOSIT);
    }

    function _removeExternalDepth() private {
        externalLp.modify(key, -887220, 887220, 0, bytes32(0));
        externalLp.modify(key, -887220, 887220, -int256(1e18), bytes32(0));
    }

    function _attack(uint256 depressed_, bool restore_) private returns (uint256 minted_, uint256 payout_) {
        uint256 supply = IERC20(address(wings0)).totalSupply();
        address attacker = makeAddr("depth attacker");
        token0.mint(attacker, DEPOSIT);
        vm.startPrank(attacker);
        token0.approve(address(wings0), type(uint256).max);
        minted_ = IStandardExchangeIn(address(wings0)).exchangeIn(
            token0, DEPOSIT, IERC20(address(wings0)), 0, attacker, false, block.timestamp);
        vm.stopPrank();
        assertEq(minted_, FullMath.mulDiv(supply, DEPOSIT, depressed_), "SEC-08: depressed V must not overmint");
        if (restore_) externalLp.modify(key, -887220, 887220, 1e18, bytes32(0));
        uint256 cap = FullMath.mulDiv(minted_, wings0.liquidationValue().value, supply + minted_);
        vm.prank(attacker);
        payout_ = IStandardExchangeIn(address(wings0)).exchangeIn(
            IERC20(address(wings0)), minted_, token0, 0, attacker, false, block.timestamp);
        assertLe(payout_, cap, "SEC-08: redemption exceeds pre-exit share of current V");
        assertEq(token1.balanceOf(attacker), 0);
    }
}
