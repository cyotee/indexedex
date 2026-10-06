// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultGeometry as Geometry
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultGeometry.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor
} from "./reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValueTest[]
/// @notice Real PoolManager reference for the claimed target-only-funding => positive-current-V implication.
/// @dev This tests reachability of portfolio states, not an implemented Wings deposit or share issuance route.
contract UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValueTest is CraneTest {
    using StateLibrary for IPoolManager;
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal manager;
    PoolKey internal key;
    ERC20PermitMintableStub internal token0;
    ERC20PermitMintableStub internal token1;
    Actor internal portfolio;
    Actor internal trader;
    Actor internal externalLp;
    uint128 internal constant LIQUIDITY = 1_000_000;

    /// @notice Deploy real protocol through CREATE3 and separate funded actors; no protocol or vault mocks.
    function setUp() public override {
        super.setUp();
        manager = IPoolManager(
            create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
                abi.encode(address(this)),
                keccak256("WingsRecoveryValue.PoolManager")
            )
        );
        token0 = new ERC20PermitMintableStub("Reference A", "A", 18, address(this), 0);
        token1 = new ERC20PermitMintableStub("Reference B", "B", 18, address(this), 0);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(0)));
        manager.initialize(key, uint160(1) << 96);
        portfolio = _actor("portfolio");
        trader = _actor("trader");
        externalLp = _actor("externalLp");
        token0.mint(address(trader), 1e30);
        token1.mint(address(trader), 1e30);
        token0.mint(address(externalLp), 1e30);
        token1.mint(address(externalLp), 1e30);
    }

    /// @notice An upper wing funded only with target0 can convert fully and realize zero target after own removal.
    function test_realPool_target0OnlyFundingCanReachZeroRealizableValue() public {
        _witness(true);
    }

    /// @notice The same reachable state exists for target1, without fee-free-pool assumptions.
    function test_realPool_target1OnlyFundingCanReachZeroRealizableValue() public {
        _witness(false);
    }

    function _witness(bool target0_) internal {
        Types.Geometry memory geometry = Geometry.ranges(uint160(1) << 96, 60);
        Types.Range memory wing = target0_ ? geometry.upper : geometry.lower;
        Types.Principal memory funding = Inventory.principal(uint160(1) << 96, wing.lower, wing.upper, LIQUIDITY, true);
        ERC20PermitMintableStub target = target0_ ? token0 : token1;
        ERC20PermitMintableStub opposing = target0_ ? token1 : token0;
        uint256 deposit = target0_ ? funding.amount0 : funding.amount1;
        assertGt(deposit, 0);
        assertEq(target0_ ? funding.amount1 : funding.amount0, 0);
        target.mint(address(portfolio), deposit);
        portfolio.modify(key, wing.lower, wing.upper, int256(uint256(LIQUIDITY)), bytes32(0));
        assertEq(target.balanceOf(address(portfolio)), 0, "all target allocated, zero effective sleeve");
        assertEq(opposing.balanceOf(address(portfolio)), 0);

        // Ordinary market trading converts principal. It neither calls a vault nor burns vault shares.
        trader.swapTo(key, !target0_, 1e30, TickMath.getSqrtPriceAtTick(target0_ ? int24(887221) : int24(-887221)));
        (uint160 price,,,) = manager.getSlot0(key.toId());
        Types.Principal memory principal = Inventory.principal(price, wing.lower, wing.upper, LIQUIDITY, false);
        assertEq(target0_ ? principal.amount0 : principal.amount1, 0);
        assertGt(target0_ ? principal.amount1 : principal.amount0, 0);
        assertTrue(Inventory.harvestEligible(target0_ ? Types.Slot.Upper : Types.Slot.Lower, principal));

        // Perform the actual whole-book liquidation reference: remove every owned position first.
        (BalanceDelta removed, BalanceDelta fees) =
            portfolio.modify(key, wing.lower, wing.upper, -int256(uint256(LIQUIDITY)), bytes32(0));
        assertEq(target0_ ? removed.amount0() : removed.amount1(), 0);
        assertEq(target0_ ? fees.amount0() : fees.amount1(), 0, "swap fees accrue in opposing input");
        assertEq(manager.getLiquidity(key.toId()), 0);
        uint256 unsold = opposing.balanceOf(address(portfolio));
        assertGt(unsold, 0);
        BalanceDelta sale = portfolio.swap(key, !target0_, unsold);
        assertEq(sale.amount0(), 0);
        assertEq(sale.amount1(), 0);
        assertEq(target.balanceOf(address(portfolio)), 0, "V=0 despite strictly positive target-only funding");
        assertEq(opposing.balanceOf(address(portfolio)), unsold, "unsellable tokens remain physically held");
        emit log_named_uint("original target-only funding", deposit);
        emit log_named_uint("retained unsellable opposing", unsold);
        emit log_named_uint("realized target value", target.balanceOf(address(portfolio)));

        // Positive control: real external liquidity and a restoring market trade recover sellability.
        externalLp.modify(key, -887220, 887220, int256(uint256(LIQUIDITY)), bytes32(0));
        trader.swapTo(key, target0_, 1e30, uint160(1) << 96);
        portfolio.swap(key, !target0_, unsold);
        assertGt(target.balanceOf(address(portfolio)), 0, "external liquidity restores positive realizable proceeds");
        assertLt(opposing.balanceOf(address(portfolio)), unsold);
    }

    function _actor(string memory label_) internal returns (Actor actor_) {
        actor_ = Actor(
            create3Factory.create3WithArgs(
                type(Actor).creationCode, abi.encode(manager, address(this)), keccak256(bytes(label_))
            )
        );
        vm.label(address(actor_), label_);
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValueTest[]
