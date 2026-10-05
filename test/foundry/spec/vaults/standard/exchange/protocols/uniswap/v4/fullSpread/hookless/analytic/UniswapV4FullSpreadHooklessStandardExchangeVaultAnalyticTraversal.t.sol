// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition as Composition} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol";

contract RevertingPoolManager {
    fallback() external payable {
        revert("live read");
    }
}

contract UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticTraversalTest is CraneTest, IUnlockCallback {
    using PoolIdLibrary for PoolKey;

    IPoolManager internal manager;
    PoolKey internal key;
    int24 internal lower = -887_220;
    int24 internal upper = 887_220;
    uint128 internal ownLiquidity = 1_000e18;
    bool internal callbackActive;

    function setUp() public override {
        super.setUp();
        manager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)), keccak256(abi.encode("AnalyticTraversal.PoolManager"))
        ));
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("A", "A", 18, address(this), 1e32);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", 18, address(this), 1e32);
        key = PoolKey({
            currency0: Currency.wrap(address(a) < address(b) ? address(a) : address(b)),
            currency1: Currency.wrap(address(a) < address(b) ? address(b) : address(a)),
            fee: 0, tickSpacing: 60, hooks: IHooks(address(0))
        });
        manager.initialize(key, uint160(1) << 96);
        _modify(1_000_000e18);
        _modify(int256(uint256(ownLiquidity)));
    }

    function test_emptyBookDoesNotWalk() public view {
        Types.Snapshot memory empty = _state();
        empty.book.supply = 0;
        (,, Composition.Failure failure) = Composition._plan(empty, _params(true), 1, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.EmptyBook));
    }

    function test_overlayPrecedesLiveReads() public {
        Types.Snapshot memory state = _state();
        Composition.ProjectedPoolOverlay memory overlay;
        overlay.useOverlay = true;
        overlay.activeLiquidity = state.position.activeLiquidity;
        overlay.sqrtPriceX96 = state.position.sqrtPriceX96;
        overlay.tick = state.position.tick;
        overlay.ticks = new Composition.TickOverlay[](2);
        overlay.ticks[0] = Composition.TickOverlay(lower, int128(uint128(ownLiquidity)), ownLiquidity);
        overlay.ticks[1] = Composition.TickOverlay(upper, -int128(uint128(ownLiquidity)), ownLiquidity);
        Quotes.Params memory params = _params(true);
        params.manager = IPoolManager(address(new RevertingPoolManager()));
        Composition._plan(state, params, 1e15, overlay);
    }

    function test_liveWalkStaysInsideCeilings() public view {
        (Types.Plan memory plan, Composition.Work memory work, Composition.Failure failure) =
            Composition._plan(_state(), _params(true), 1e15, _none());
        assertTrue(failure == Composition.Failure.None || failure == Composition.Failure.Rejected);
        assertLe(work.bitmapWordReads, 64);
        assertLe(work.discoveryCoreSteps, 64);
        assertLe(work.certificationCoreSteps, 64);
        assertLe(work.placementEvaluations, 3);
        if (failure == Composition.Failure.None) {
            assertTrue(plan.valid);
            assertEq(plan.refinements, 0);
            assertEq(uint256(plan.workflow), uint256(Types.Workflow.Composition));
        }
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(manager) && callbackActive, "unexpected callback");
        (int256 liquidity, bytes32 salt) = abi.decode(data_, (int256, bytes32));
        (BalanceDelta delta,) = manager.modifyLiquidity(key, ModifyLiquidityParams(lower, upper, liquidity, salt), "");
        _settle(key.currency0, delta.amount0());
        _settle(key.currency1, delta.amount1());
        return abi.encode(delta);
    }

    function _modify(int256 liquidity_) internal {
        callbackActive = true;
        manager.unlock(abi.encode(liquidity_, bytes32(0)));
        callbackActive = false;
    }

    function _settle(Currency currency_, int128 delta_) internal {
        if (delta_ < 0) {
            manager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).transfer(address(manager), uint128(-delta_));
            manager.settle();
        } else if (delta_ > 0) manager.take(currency_, address(this), uint128(delta_));
    }

    function _none() internal pure returns (Composition.ProjectedPoolOverlay memory overlay_) {}

    function _params(bool zeroForOne_) internal view returns (Quotes.Params memory params_) {
        params_.manager = manager;
        params_.key = key;
        params_.zeroForOne = zeroForOne_;
    }

    function _state() internal view returns (Types.Snapshot memory state_) {
        state_.idle = true;
        state_.sleeveWad = 0.2e18;
        state_.book.supply = 1_000e18;
        state_.absoluteFloor = [uint256(1e12), uint256(1e12)];
        (state_.position.sqrtPriceX96, state_.position.tick,,) = StateLibrary.getSlot0(manager, key.toId());
        state_.position.lower = lower;
        state_.position.upper = upper;
        state_.position.lowerX96 = TickMath.getSqrtPriceAtTick(lower);
        state_.position.upperX96 = TickMath.getSqrtPriceAtTick(upper);
        state_.position.liquidity = ownLiquidity;
        state_.position.activeLiquidity = StateLibrary.getLiquidity(manager, key.toId());
        (state_.position.lowerLiquidityGross,) = StateLibrary.getTickLiquidity(manager, key.toId(), lower);
        (state_.position.upperLiquidityGross,) = StateLibrary.getTickLiquidity(manager, key.toId(), upper);
        state_.position.maxLiquidityPerTick = Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing);
        state_.book.deployed = Inventory._amounts(state_.position, ownLiquidity, false);
        state_.book.free[0] = state_.book.deployed[0] / 5;
        state_.book.free[1] = state_.book.deployed[1] / 5;
    }
}
