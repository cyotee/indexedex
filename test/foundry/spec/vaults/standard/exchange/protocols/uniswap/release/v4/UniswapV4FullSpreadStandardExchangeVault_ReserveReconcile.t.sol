// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {
    TestBase_UniswapV4FullSpreadStandardExchangeVault
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {
    IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol";

/// @dev Minimal PoolManager-unlock seeder for external liquidity (non-SUT harness).
contract ReserveReconcileSeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            abi.decode(data, (PoolKey, int24, int24, uint128));
        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: int256(uint256(liquidity)), salt: bytes32(0)
            }),
            bytes("")
        );
        _settle(poolKey.currency0, callerDelta.amount0());
        _settle(poolKey.currency1, callerDelta.amount1());
        return abi.encode(callerDelta);
    }

    function _settle(Currency currency, int128 delta) internal {
        if (delta < 0) {
            uint256 amount = uint128(-delta);
            poolManager.sync(currency);
            IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }
}

/**
 * @title APEX 2026-09-17 R3.3 (v4) — local reserve reconciles to custody.
 * @notice Assert the local book against actual token balances after deposits, rebalances,
 *         and funded trades. After a pool trade, an integrating contract cannot claim
 *         booked inventory without delivery; a fresh atomic delivery succeeds.
 */
contract UniswapV4FullSpreadStandardExchangeVault_ReserveReconcile_Test is
    TestBase_UniswapV4FullSpreadStandardExchangeVault
{
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve internal liquid;
    IStandardExchangeInMulti internal inMulti;
    PoolKey internal poolKey;
    ReserveReconcileSeeder internal seeder;

    uint256 internal constant DUST = 1e12;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        seeder = new ReserveReconcileSeeder(poolManager);
        tokenA.mint(address(seeder), 1_000_000 ether);
        tokenB.mint(address(seeder), 1_000_000 ether);
        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            100_000 ether,
            100_000 ether
        );
        seeder.addLiquidity(poolKey, tickLower, tickUpper, liq);

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        liquid = IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve(address(vault));
        inMulti = IStandardExchangeInMulti(address(vault));

        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(vault), 0);
        vm.stopPrank();
    }

    // R3.3 test 1: the persisted reserve is the actual locally held sleeve.
    function test_R3_3_deployedNotAboveTotal_afterDeposit() public {
        _dualJoin(500_000 ether, 500_000 ether);

        (uint256 d0, uint256 d1) = liquid.deployedReserve();
        uint256 f0 = liquid.localReserve(_token0());
        uint256 f1 = liquid.localReserve(_token1());
        uint256 total0 = f0 + d0;
        uint256 total1 = f1 + d1;

        assertGt(total0, 0, "token0 total booked");
        assertGt(total1, 0, "token1 total booked");
        _assertLocalReserveMatchesCustody();

        assertEq(IBasicVault(address(vault)).reserveOfToken(_token0()), f0, "reserveOfToken0 == localReserve0");
        assertEq(IBasicVault(address(vault)).reserveOfToken(_token1()), f1, "reserveOfToken1 == localReserve1");

        assertGt(f0, 0, "free sleeve0 present at 20% target");
        assertGt(d0, 0, "deployed0 present");

    }

    // R3.3 test 2: with a 0% target and a rebalance the free sleeve empties and deployed == total.
    function test_R3_3_deployedEqualsTotal_whenFreeSleeveEmpty() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve).interfaceId, 0
        );
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0);
        vm.stopPrank();
        assertEq(liquid.targetLiquidReservePercentage(), 0, "target 0%");

        _dualJoin(500_000 ether, 500_000 ether);
        liquid.rebalanceLiquidReserve();

        (uint256 d0, uint256 d1) = liquid.deployedReserve();
        uint256 f0 = liquid.localReserve(_token0());
        uint256 f1 = liquid.localReserve(_token1());

        assertLe(f0, DUST, "free sleeve0 empty at 0% target");
        assertLe(f1, DUST, "free sleeve1 empty at 0% target");
        assertGt(d0, 0, "everything deployed on token0");
        assertGt(d1, 0, "everything deployed on token1");
        _assertLocalReserveMatchesCustody();
    }

    // R3.3 test 3: rebalance re-books toward target and a following trade keeps booking consistent.
    function test_R3_3_rebalanceThenTrade_bookingStaysConsistent() public {
        _dualJoin(500_000 ether, 500_000 ether);

        (uint256 t0Before, uint256 t1Before) = _totals();
        uint256 sumBefore = t0Before + t1Before;

        liquid.rebalanceLiquidReserve();

        uint256 target = liquid.targetLiquidReservePercentage();
        assertApproxEqAbs(liquid.actualLiquidReservePercentage(_token0()), target, 0.05e18, "token0 near target after rebalance");
        assertApproxEqAbs(liquid.actualLiquidReservePercentage(_token1()), target, 0.05e18, "token1 near target after rebalance");
        assertEq(IBasicVault(address(vault)).reserveOfToken(_token0()), liquid.localReserve(_token0()), "reserve0 == free after rebalance");

        ERC20PermitMintableStub(_token0()).mint(address(this), 1_000 ether);
        IERC20(_token0()).approve(address(vault), 1_000 ether);
        vault.exchangeIn(IERC20(_token0()), 1_000 ether, IERC20(address(vault)), 0, address(this), false, _deadline());

        assertEq(IBasicVault(address(vault)).reserveOfToken(_token0()), liquid.localReserve(_token0()), "reserve0 == free after trade");
        assertEq(IBasicVault(address(vault)).reserveOfToken(_token1()), liquid.localReserve(_token1()), "reserve1 == free after trade");
        (uint256 t0After, uint256 t1After) = _totals();
        _assertLocalReserveMatchesCustody();

        uint256 sumAfter = t0After + t1After;
        assertGe(sumAfter, sumBefore, "no value lost across rebalance+trade");
        assertApproxEqRel(sumAfter, sumBefore + 1_000 ether, 0.02e18, "total value grew by the deposit");
        _assertCreditAfterFundedPoolTrade();
    }

    function _assertLocalReserveMatchesCustody() internal view {
        assertEq(IBasicVault(address(vault)).reserveOfToken(_token0()), IERC20(_token0()).balanceOf(address(vault)), "token0 book equals custody");
        assertEq(IBasicVault(address(vault)).reserveOfToken(_token1()), IERC20(_token1()).balanceOf(address(vault)), "token1 book equals custody");
    }

    function _assertCreditAfterFundedPoolTrade() internal {
        ERC20PermitMintableStub(_token0()).mint(address(this), 1_000 ether);
        IERC20(_token0()).approve(address(vault), 1_000 ether);
        uint256 output = vault.exchangeIn(IERC20(_token0()), 1_000 ether, IERC20(_token1()), 1, address(this), false, _deadline());
        assertGt(output, 0, "funded pool trade succeeds");
        _assertLocalReserveMatchesCustody();
        _assertNoDeliveryRejectedThenFunded(_token0());
        _assertNoDeliveryRejectedThenFunded(_token1());
    }

    function _assertNoDeliveryRejectedThenFunded(address token_) internal {
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 claimed = 1 ether;
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(token_), claimed, IERC20(address(vault)), 1, address(caller), true, _deadline()));
        bytes32 beforeState = _custodyState(address(caller));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0)));
        caller.execute(address(vault), data);
        assertEq(_custodyState(address(caller)), beforeState, "unfunded claim leaves custody, books, supply and recipient unchanged");

        ERC20PermitMintableStub(token_).mint(address(this), claimed);
        IERC20(token_).approve(address(caller), claimed);
        uint256 shares = abi.decode(caller.consumePretransfer(IERC20(token_), address(this), address(vault), claimed, data), (uint256));
        assertGt(shares, 0, "fresh atomic delivery succeeds after failed claim");
        assertEq(IERC20(address(vault)).balanceOf(address(caller)), shares, "only funded output delivered");
        assertEq(IERC20(token_).balanceOf(address(caller)), 0, "exact-in has no input refund");
        _assertLocalReserveMatchesCustody();
    }

    function _custodyState(address caller_) internal view returns (bytes32) {
        uint256[12] memory state;
        state[0] = IERC20(_token0()).balanceOf(address(vault));
        state[1] = IERC20(_token1()).balanceOf(address(vault));
        state[2] = IERC20(address(vault)).totalSupply();
        state[3] = IBasicVault(address(vault)).reserveOfToken(_token0());
        state[4] = IBasicVault(address(vault)).reserveOfToken(_token1());
        (state[5], state[6]) = liquid.deployedReserve();
        state[7] = IERC20(_token0()).balanceOf(caller_);
        state[8] = IERC20(_token1()).balanceOf(caller_);
        state[9] = IERC20(address(vault)).balanceOf(caller_);
        state[10] = IERC20(_token0()).balanceOf(address(poolManager));
        state[11] = IERC20(_token1()).balanceOf(address(poolManager));
        return keccak256(abi.encode(state));
    }

    function _totals() internal view returns (uint256, uint256) {
        (uint256 d0, uint256 d1) = liquid.deployedReserve();
        return (liquid.localReserve(_token0()) + d0, liquid.localReserve(_token1()) + d1);
    }

    function _dualJoin(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        ERC20PermitMintableStub(_token0()).mint(address(this), amount0);
        ERC20PermitMintableStub(_token1()).mint(address(this), amount1);
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        address[] memory tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        shares = inMulti.exchangeInManyToOne(tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline());
        assertGt(shares, 0, "dual join shares");
    }

    function _buildPoolKey(address token0Candidate, address token1Candidate) internal pure returns (PoolKey memory) {
        (address token0, address token1) =
            token0Candidate < token1Candidate ? (token0Candidate, token1Candidate) : (token1Candidate, token0Candidate);
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }
}
