// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultInvariantHandler as Handler} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInvariant.t.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from "./reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice Randomized custody invariants with separate mandatory funded lifecycle coverage.
contract WingsApexRecurrenceInvariantWitnessTest is Fixture {
    using StateLibrary for IPoolManager;
    Handler private handler;
    uint256 private initialDeposits;
    uint256 private initialWithdrawals;
    bool private witnessedTrade;
    bool private witnessedRebalance;

    function setUp() public override {
        super.setUp();
        handler = Handler(create3Factory.create3WithArgs(type(Handler).creationCode,
            abi.encode(wings0, address(this)), keccak256("Wings.ReviewHandler")));
        token0.mint(address(handler), 1e18);
        handler.deposit(1e9);
        Actor market = Actor(create3Factory.create3WithArgs(type(Actor).creationCode,
            abi.encode(pool, address(handler)), keccak256("Wings.ReviewMarket")));
        token0.mint(address(market), 1e25);
        token1.mint(address(market), 1e25);
        handler.configureMarket(market);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.redeem.selector;
        selectors[2] = handler.rebalance.selector;
        selectors[3] = handler.trade.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
        targetContract(address(handler));
        assertEq(handler.deposits(), 1, "setup deposit must have executed");
        assertGt(IERC20(address(wings0)).totalSupply(), 0, "no zero-supply escape");
        (,, uint128 coreBefore,) = wings0.position(0);
        handler.rebalance();
        (,, uint128 coreAfter,) = wings0.position(0);
        witnessedRebalance = coreAfter > coreBefore;
        assertTrue(witnessedRebalance, "rebalance must change actual core liquidity");
        (uint160 beforePrice,,,) = pool.getSlot0(key.toId());
        handler.trade(1e12, true);
        (uint160 afterPrice,,,) = pool.getSlot0(key.toId());
        witnessedTrade = afterPrice != beforePrice;
        assertTrue(witnessedTrade, "external trade must move actual pool price");
        handler.redeem(999);
        assertEq(handler.withdrawals(), 1, "funded exit must succeed");
        assertGt(handler.paid(), 0, "exit paid actual target");
        initialDeposits = handler.deposits();
        initialWithdrawals = handler.withdrawals();
    }

    function invariant_review_actionWitnessesAndCustody() public view {
        assertTrue(witnessedTrade);
        assertTrue(witnessedRebalance);
        assertGe(handler.deposits(), initialDeposits);
        assertGe(handler.withdrawals(), initialWithdrawals);
        (uint256 local0, uint256 local1) = wings0.localReserves();
        assertEq(token0.balanceOf(address(wings0)), local0);
        assertEq(token1.balanceOf(address(wings0)), local1);
        uint256 supply = IERC20(address(wings0)).totalSupply();
        assertEq(supply, IERC20(address(wings0)).balanceOf(address(handler)));
        if (supply != 0) { assertGe(local0, 1); assertGt(wings0.liquidationValue().value, 0); }
        assertEq(token0.balanceOf(address(handler)), 1e18 - handler.funded() + handler.paid());
        for (uint8 i; i < 3; ++i) {
            (int24 lower, int24 upper, uint128 liquidity, bytes32 salt) = wings0.position(i);
            if (liquidity == 0) continue;
            (uint128 actual,,) = pool.getPositionInfo(key.toId(), address(wings0), lower, upper, salt);
            assertEq(actual, liquidity);
        }
    }

    /// @notice Coverage is deliberate; a shrunk rebalance-only sequence is still valid.
    function test_deterministicMoneyPathCoverage() public {
        handler.deposit(1e9);
        assertGt(handler.deposits(), initialDeposits, "additional funded deposit required");
        invariant_review_actionWitnessesAndCustody();
        handler.redeem(999);
        assertGt(handler.withdrawals(), initialWithdrawals, "additional funded exit required");
        invariant_review_actionWitnessesAndCustody();
    }
}
