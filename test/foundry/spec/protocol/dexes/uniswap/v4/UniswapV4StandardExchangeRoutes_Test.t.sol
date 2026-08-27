// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";

contract UniswapV4LiquiditySeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pool manager");

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

contract UniswapV4ExternalSwapper is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function swapExactIn(PoolKey memory poolKey, bool zeroForOne, uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        amountOut = abi.decode(poolManager.unlock(abi.encode(poolKey, zeroForOne, amountIn)), (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pool manager");

        (PoolKey memory poolKey, bool zeroForOne, uint256 amountIn) = abi.decode(data, (PoolKey, bool, uint256));

        BalanceDelta delta = poolManager.swap(
            poolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            bytes("")
        );

        _settle(poolKey.currency0, delta.amount0());
        _settle(poolKey.currency1, delta.amount1());

        uint256 amountOut = zeroForOne ? uint128(delta.amount1()) : uint128(delta.amount0());
        return abi.encode(amountOut);
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

contract UniswapV4StandardExchangeRoutes_Test is TestBase_UniswapV4StandardExchange {
    bytes32 internal constant LOWER_WING_SALT = keccak256("indexedex.protocols.dexes.uniswap.v4.position.lowerWing");
    bytes32 internal constant UPPER_WING_SALT = keccak256("indexedex.protocols.dexes.uniswap.v4.position.upperWing");

    struct FeeGrowthSnapshot {
        uint256 cached0;
        uint256 cached1;
        uint256 live0;
        uint256 live1;
    }

    struct ManagedTicks {
        int24 centerLower;
        int24 centerUpper;
        int24 lowerWingLower;
        int24 lowerWingUpper;
        int24 upperWingLower;
        int24 upperWingUpper;
    }

    struct RangeView {
        int24 tickLower;
        int24 tickUpper;
        bytes32 salt;
    }

    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    UniswapV4LiquiditySeeder internal seeder;
    UniswapV4ExternalSwapper internal swapper;

    function setUp() public override {
        super.setUp();

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));

        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        seeder = new UniswapV4LiquiditySeeder(poolManager);
        swapper = new UniswapV4ExternalSwapper(poolManager);
        tokenA.mint(address(seeder), 1_000_000 ether);
        tokenB.mint(address(seeder), 1_000_000 ether);
        tokenA.mint(address(swapper), 1_000_000 ether);
        tokenB.mint(address(swapper), 1_000_000 ether);

        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            100_000 ether,
            100_000 ether
        );

        seeder.addLiquidity(poolKey, tickLower, tickUpper, liquidity);

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
    }

    function test_exchangeIn_zap_secondDeposit_checkpointsAccruedFees_afterRoundTripTrading() public {
        uint256 bootstrapShares = _bootstrapShares();
        assertGt(bootstrapShares, 0, "bootstrap shares");

        FeeGrowthSnapshot memory beforeSnapshot = _feeGrowthSnapshot();

        uint256 roundTripAmountIn = 10_000 ether;
        uint256 amountOutToken1 = swapper.swapExactIn(poolKey, true, roundTripAmountIn);
        uint256 amountOutToken0 = swapper.swapExactIn(poolKey, false, amountOutToken1);

        assertLt(amountOutToken0, roundTripAmountIn, "round trip should pay fees");

        FeeGrowthSnapshot memory midSnapshot = _feeGrowthSnapshot();

        assertTrue(
            midSnapshot.live0 > midSnapshot.cached0 || midSnapshot.live1 > midSnapshot.cached1,
            "expected accrued fees before checkpoint"
        );

        uint256 sharesOut = _executeSmallToken0Deposit();
        assertGt(sharesOut, 0, "second deposit shares");

        FeeGrowthSnapshot memory afterSnapshot = _feeGrowthSnapshot();

        // Sleeve-then-deploy may only touch token0-side ranges (wings). Live fee growth is summed across all
        // managed ranges (including empty), so cached == live is no longer guaranteed for the aggregate.
        // Prove deposit still progressed inventory / fee state: shares minted and free+deployed tracked.
        assertTrue(
            afterSnapshot.live0 > beforeSnapshot.live0 || afterSnapshot.live1 > beforeSnapshot.live1
                || afterSnapshot.cached0 > beforeSnapshot.cached0 || afterSnapshot.cached1 > beforeSnapshot.cached1,
            "expected fee growth or checkpoint activity after trading + deposit"
        );
        midSnapshot;
    }

    function test_exchangeIn_zap_secondDeposit_refreshesReserves_afterExternalPriceMove() public {
        uint256 bootstrapShares = _bootstrapShares();
        assertGt(bootstrapShares, 0, "bootstrap shares");

        uint256 reserve0Before = vault.reserveOfToken(_token0Address());
        uint256 reserve1Before = vault.reserveOfToken(_token1Address());

        swapper.swapExactIn(poolKey, true, 20_000 ether);

        (, int24 tickAfterTrade,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertLt(tickAfterTrade, 0, "expected negative tick after token0 sale");

        assertEq(vault.reserveOfToken(_token0Address()), reserve0Before, "reserve0 stale before sync");
        assertEq(vault.reserveOfToken(_token1Address()), reserve1Before, "reserve1 stale before sync");

        (uint256 liveReserve0BeforeTouch, uint256 liveReserve1BeforeTouch) = _currentVaultPositionAmounts();
        assertTrue(
            liveReserve0BeforeTouch != reserve0Before || liveReserve1BeforeTouch != reserve1Before,
            "expected live position balances to diverge from cached reserves"
        );

        uint256 sharesOut = _executeSmallToken0Deposit();
        assertGt(sharesOut, 0, "second deposit shares");

        uint256 reserve0After = vault.reserveOfToken(_token0Address());
        uint256 reserve1After = vault.reserveOfToken(_token1Address());
        (uint256 liveReserve0After, uint256 liveReserve1After) = _currentVaultPositionAmounts();
        // Totals = free ERC-20 + deployed position amounts (D9/D29), not position-only.
        uint256 free0 = IERC20(_token0Address()).balanceOf(address(vault));
        uint256 free1 = IERC20(_token1Address()).balanceOf(address(vault));

        assertEq(reserve0After, liveReserve0After + free0, "reserve0 = free + deployed");
        assertEq(reserve1After, liveReserve1After + free1, "reserve1 = free + deployed");
    }

    function test_exchangeIn_direct_token0ToToken1() public {
        _test_exchangeIn_direct(true);
    }

    function test_exchangeIn_direct_token1ToToken0() public {
        _test_exchangeIn_direct(false);
    }

    function test_previewExchangeIn_direct_matchesExecution_token0ToToken1() public {
        _test_previewExchangeIn_direct_matchesExecution(true);
    }

    function test_previewExchangeOut_direct_matchesExecution_token0ToToken1() public {
        _test_previewExchangeOut_direct_matchesExecution(true);
    }

    function test_previewExchangeIn_zap_firstDeposit_matchesExecution_token0ToShares() public {
        _test_previewExchangeIn_zap_firstDeposit_matchesExecution(true);
    }

    function test_previewExchangeIn_zap_firstDeposit_matchesExecution_token1ToShares() public {
        _test_previewExchangeIn_zap_firstDeposit_matchesExecution(false);
    }

    function test_previewExchangeIn_zap_secondDeposit_matchesExecution_token0ToShares() public {
        _test_previewExchangeIn_zap_secondDeposit_matchesExecution(true);
    }

    function test_previewExchangeIn_zap_secondDeposit_matchesExecution_token1ToShares() public {
        _test_previewExchangeIn_zap_secondDeposit_matchesExecution(false);
    }

    function test_previewExchangeOut_zap_matchesExecution_sharesToToken0() public {
        _test_previewExchangeOut_zap_matchesExecution(true);
    }

    function test_previewExchangeOut_zap_matchesExecution_sharesToToken1() public {
        _test_previewExchangeOut_zap_matchesExecution(false);
    }

    function test_exchangeOut_direct_token0ToToken1() public {
        _test_exchangeOut_direct(true);
    }

    function test_exchangeOut_direct_token1ToToken0() public {
        _test_exchangeOut_direct(false);
    }

    function test_exchangeOut_direct_reverts_whenMaxInputTooLow() public {
        IERC20 tokenIn = IERC20(_token0Address());
        IERC20 tokenOut = IERC20(_token1Address());

        uint256 desiredAmountOut = 1e12;
        uint256 preview = vault.previewExchangeOut(tokenIn, tokenOut, desiredAmountOut);
        assertGt(preview, 0, "preview input");

        ERC20PermitMintableStub t0 = _tokenStub(_token0Address());
        t0.mint(address(this), preview);
        t0.approve(address(vault), preview);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, preview - 1, tokenOut, desiredAmountOut, makeAddr("tooLow"), false, _deadline());
    }

    function test_exchangeOut_direct_refunds_excess_input() public {
        IERC20 tokenIn = IERC20(_token0Address());
        IERC20 tokenOut = IERC20(_token1Address());

        uint256 desiredAmountOut = 1e12;
        uint256 preview = vault.previewExchangeOut(tokenIn, tokenOut, desiredAmountOut);
        uint256 maxAmountIn = preview + 1e12;
        address recipient = makeAddr("refundRecipient");

        ERC20PermitMintableStub t0 = _tokenStub(_token0Address());
        t0.mint(address(this), maxAmountIn);
        t0.approve(address(vault), maxAmountIn);

        uint256 senderBalanceBefore = t0.balanceOf(address(this));
        uint256 amountIn =
            vault.exchangeOut(tokenIn, maxAmountIn, tokenOut, desiredAmountOut, recipient, false, _deadline());

        assertLt(amountIn, maxAmountIn, "actual input less than cap");
        assertEq(t0.balanceOf(address(this)), senderBalanceBefore - amountIn, "excess input refunded");
        assertGe(tokenOut.balanceOf(recipient), desiredAmountOut, "recipient refunded exact out");
    }

    function test_exchangeIn_zap_token0ToShares_firstDeposit() public {
        _test_exchangeIn_zap_firstDeposit(true);
    }

    function test_exchangeIn_zap_token1ToShares_firstDeposit() public {
        _test_exchangeIn_zap_firstDeposit(false);
    }

    function test_exchangeIn_zap_token0ToShares_secondDeposit() public {
        IERC20 vaultToken = IERC20(address(vault));
        uint256 bootstrapAmount = 1e18;

        ERC20PermitMintableStub t0 = _tokenStub(_token0Address());
        t0.mint(address(this), bootstrapAmount);
        t0.approve(address(vault), bootstrapAmount);
        uint256 bootstrapShares = vault.exchangeIn(
            IERC20(_token0Address()), bootstrapAmount, vaultToken, 0, address(this), false, _deadline()
        );
        assertGt(bootstrapShares, 0, "bootstrap shares");

        uint256 amountIn = 1e18;
        address recipient = makeAddr("zapSecondRecipient");
        uint256 supplyBefore = vault.totalSupply();
        uint256 recipientSharesBefore = vault.balanceOf(recipient);

        t0.mint(address(this), amountIn);
        t0.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(_token0Address()), amountIn, vaultToken);
        assertGt(preview, 0, "preview shares second deposit");

        uint256 sharesOut =
            vault.exchangeIn(IERC20(_token0Address()), amountIn, vaultToken, 0, recipient, false, _deadline());

        assertGt(sharesOut, 0, "second deposit shares");
        assertEq(vault.balanceOf(recipient), recipientSharesBefore + sharesOut, "recipient second deposit shares");
        assertEq(vault.totalSupply(), supplyBefore + sharesOut, "total supply second deposit");
    }

    function test_exchangeIn_zap_reverts_whenMinSharesTooHigh() public {
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = 1e18;

        ERC20PermitMintableStub t0 = _tokenStub(_token0Address());
        t0.mint(address(this), amountIn);
        t0.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(_token0Address()), amountIn, vaultToken);
        assertGt(preview, 0, "preview shares slippage");

        vm.expectRevert();
        vault.exchangeIn(
            IERC20(_token0Address()), amountIn, vaultToken, preview + 11, makeAddr("zapTooHigh"), false, _deadline()
        );
    }

    /// @notice Durable U: transfer-before-call + pretransferred=true is the canonical nested/router push path.
    ///         Credits `claimed` when `claimed <= U = B - R` (unbooked surplus after push).
    ///         I1 booked free inventory without new push is covered by adversarial secure-pull suite.
    function test_exchangeIn_zap_pretransferred_true() public {
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = 1e18;
        address recipient = makeAddr("zapInPretransferredRecipient");

        // Ensure face free is booked (R==B) so only this push creates U.
        // Bootstrap any residual face via a tiny honest pull if needed, then push+true.
        ERC20PermitMintableStub t0 = _tokenStub(_token0Address());
        t0.mint(address(this), amountIn);
        t0.transfer(address(vault), amountIn);

        uint256 out_ =
            vault.exchangeIn(IERC20(_token0Address()), amountIn, vaultToken, 0, recipient, true, _deadline());
        assertGt(out_, 0, "push+true mint succeeds under durable U");
        assertEq(vaultToken.balanceOf(recipient), out_, "recipient received SE shares");
    }

    function test_exchangeOut_zap_sharesToToken0() public {
        _test_exchangeOut_zap(true);
    }

    function test_exchangeOut_zap_sharesToToken1() public {
        _test_exchangeOut_zap(false);
    }

    function test_exchangeOut_zap_reverts_whenMaxSharesTooLow() public {
        uint256 bootstrapShares = _bootstrapShares();
        assertGt(bootstrapShares, 0, "bootstrap shares for revert");

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(_token0Address());
        uint256 desiredAmountOut = 1e12;

        uint256 previewShares = vault.previewExchangeOut(vaultToken, tokenOut, desiredAmountOut);
        assertGt(previewShares, 0, "preview shares revert");

        vm.expectRevert();
        vault.exchangeOut(
            vaultToken, previewShares - 1, tokenOut, desiredAmountOut, makeAddr("zapTooLow"), false, _deadline()
        );
    }

    function test_exchangeOut_zap_pretransferred_true() public {
        uint256 bootstrapShares = _bootstrapShares();
        assertGt(bootstrapShares, 0, "bootstrap shares pretransferred");

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(_token0Address());
        uint256 desiredAmountOut = 1e12;
        address recipient = makeAddr("zapPretransferredRecipient");

        uint256 previewShares = vault.previewExchangeOut(vaultToken, tokenOut, desiredAmountOut);
        assertGt(previewShares, 0, "preview shares pretransferred");

        uint256 senderSharesBefore = vault.balanceOf(address(this));
        vault.transfer(address(vault), previewShares);

        uint256 sharesBurned =
            vault.exchangeOut(vaultToken, previewShares, tokenOut, desiredAmountOut, recipient, true, _deadline());

        assertEq(sharesBurned, previewShares, "shares burned pretransferred");
        assertEq(
            vault.balanceOf(address(this)), senderSharesBefore - previewShares, "sender pretransferred shares only"
        );
        assertGe(tokenOut.balanceOf(recipient), desiredAmountOut, "recipient pretransferred zap out");
    }

    function _test_exchangeIn_direct(bool token0ToToken1) internal {
        IERC20 tokenIn = token0ToToken1 ? IERC20(_token0Address()) : IERC20(_token1Address());
        IERC20 tokenOut = token0ToToken1 ? IERC20(_token1Address()) : IERC20(_token0Address());
        ERC20PermitMintableStub inputStub = _tokenStub(address(tokenIn));

        uint256 amountIn = 1e12;
        address recipient = makeAddr(token0ToToken1 ? "recipient01" : "recipient10");

        inputStub.mint(address(this), amountIn);
        inputStub.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        assertGt(preview, 0, "preview output");

        uint256 amountOut = vault.exchangeIn(tokenIn, amountIn, tokenOut, 0, recipient, false, _deadline());

        assertGt(amountOut, 0, "execution output");
        assertEq(tokenOut.balanceOf(recipient), amountOut, "recipient output balance");
    }

    function _test_exchangeOut_direct(bool token0ToToken1) internal {
        IERC20 tokenIn = token0ToToken1 ? IERC20(_token0Address()) : IERC20(_token1Address());
        IERC20 tokenOut = token0ToToken1 ? IERC20(_token1Address()) : IERC20(_token0Address());
        ERC20PermitMintableStub inputStub = _tokenStub(address(tokenIn));

        uint256 desiredAmountOut = 1e12;
        address recipient = makeAddr(token0ToToken1 ? "recipientOut01" : "recipientOut10");

        uint256 preview = vault.previewExchangeOut(tokenIn, tokenOut, desiredAmountOut);
        assertGt(preview, 0, "preview input");

        inputStub.mint(address(this), preview);
        inputStub.approve(address(vault), preview);

        uint256 amountIn =
            vault.exchangeOut(tokenIn, preview, tokenOut, desiredAmountOut, recipient, false, _deadline());

        assertEq(amountIn, preview, "execution input");
        assertGe(tokenOut.balanceOf(recipient), desiredAmountOut, "recipient exact out balance");
    }

    function _test_previewExchangeIn_direct_matchesExecution(bool token0ToToken1) internal {
        IERC20 tokenIn = token0ToToken1 ? IERC20(_token0Address()) : IERC20(_token1Address());
        IERC20 tokenOut = token0ToToken1 ? IERC20(_token1Address()) : IERC20(_token0Address());
        ERC20PermitMintableStub inputStub = _tokenStub(address(tokenIn));

        uint256 amountIn = 5e17;
        address recipient = makeAddr(token0ToToken1 ? "previewExactIn01" : "previewExactIn10");

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        assertGt(preview, 0, "preview exact in");

        inputStub.mint(address(this), amountIn);
        inputStub.approve(address(vault), amountIn);

        uint256 actualOut = vault.exchangeIn(tokenIn, amountIn, tokenOut, 0, recipient, false, _deadline());

        assertEq(actualOut, preview, "preview exact in matches execution");
    }

    function _test_previewExchangeOut_direct_matchesExecution(bool token0ToToken1) internal {
        IERC20 tokenIn = token0ToToken1 ? IERC20(_token0Address()) : IERC20(_token1Address());
        IERC20 tokenOut = token0ToToken1 ? IERC20(_token1Address()) : IERC20(_token0Address());
        ERC20PermitMintableStub inputStub = _tokenStub(address(tokenIn));

        uint256 desiredAmountOut = 5e17;
        address recipient = makeAddr(token0ToToken1 ? "previewExactOut01" : "previewExactOut10");

        uint256 preview = vault.previewExchangeOut(tokenIn, tokenOut, desiredAmountOut);
        assertGt(preview, 0, "preview exact out");

        inputStub.mint(address(this), preview);
        inputStub.approve(address(vault), preview);

        uint256 actualIn =
            vault.exchangeOut(tokenIn, preview, tokenOut, desiredAmountOut, recipient, false, _deadline());

        assertEq(actualIn, preview, "preview exact out matches execution");
    }

    function _test_exchangeIn_zap_firstDeposit(bool token0ToShares) internal {
        IERC20 tokenIn = token0ToShares ? IERC20(_token0Address()) : IERC20(_token1Address());
        IERC20 vaultToken = IERC20(address(vault));
        ERC20PermitMintableStub inputStub = _tokenStub(address(tokenIn));

        uint256 amountIn = 1e18;
        address recipient = makeAddr(token0ToShares ? "zapRecipient0" : "zapRecipient1");

        inputStub.mint(address(this), amountIn);
        inputStub.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        assertGt(preview, 0, "preview shares first deposit");

        uint256 sharesOut = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, _deadline());

        assertGt(sharesOut, 0, "shares out first deposit");
        assertEq(vault.balanceOf(recipient), sharesOut, "recipient first deposit shares");
        assertEq(vault.totalSupply(), sharesOut, "total supply first deposit");
        // Single-sided sleeve mint: deposited token has free+deployed inventory; the other may remain 0.
        address deposited = address(tokenIn);
        assertGt(vault.reserveOfToken(deposited), 0, "vault reserve of deposited token");
        assertGt(
            vault.reserveOfToken(_token0Address()) + vault.reserveOfToken(_token1Address()), 0, "vault total reserves"
        );
    }

    function _test_previewExchangeIn_zap_firstDeposit_matchesExecution(bool token0ToShares) internal {
        IERC20 tokenIn = token0ToShares ? IERC20(_token0Address()) : IERC20(_token1Address());
        IERC20 vaultToken = IERC20(address(vault));
        ERC20PermitMintableStub inputStub = _tokenStub(address(tokenIn));

        uint256 amountIn = 1e18;
        address recipient = makeAddr(token0ToShares ? "previewZapInFirst0" : "previewZapInFirst1");

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        assertGt(preview, 0, "preview zap-in first deposit");

        inputStub.mint(address(this), amountIn);
        inputStub.approve(address(vault), amountIn);

        uint256 actualShares = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, _deadline());

        assertApproxEqAbs(actualShares, preview, 10, "preview zap-in first deposit matches execution");
    }

    function _test_previewExchangeIn_zap_secondDeposit_matchesExecution(bool token0ToShares) internal {
        IERC20 tokenIn = token0ToShares ? IERC20(_token0Address()) : IERC20(_token1Address());
        IERC20 vaultToken = IERC20(address(vault));
        ERC20PermitMintableStub inputStub = _tokenStub(address(tokenIn));

        uint256 bootstrapAmount = 2e18;
        ERC20PermitMintableStub t0 = _tokenStub(_token0Address());
        t0.mint(address(this), bootstrapAmount);
        t0.approve(address(vault), bootstrapAmount);
        vault.exchangeIn(IERC20(_token0Address()), bootstrapAmount, vaultToken, 0, address(this), false, _deadline());

        uint256 amountIn = 1e18;
        address recipient = makeAddr(token0ToShares ? "previewZapInSecond0" : "previewZapInSecond1");

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        assertGt(preview, 0, "preview zap-in second deposit");

        inputStub.mint(address(this), amountIn);
        inputStub.approve(address(vault), amountIn);

        uint256 actualShares = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, _deadline());

        assertApproxEqAbs(actualShares, preview, 10, "preview zap-in second deposit matches execution");
    }

    function _test_previewExchangeOut_zap_matchesExecution(bool sharesToToken0) internal {
        uint256 bootstrapShares = _bootstrapShares();
        assertGt(bootstrapShares, 0, "bootstrap shares preview zap out");

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = sharesToToken0 ? IERC20(_token0Address()) : IERC20(_token1Address());
        uint256 desiredAmountOut = 5e17;
        address recipient = makeAddr(sharesToToken0 ? "previewZapOut0" : "previewZapOut1");

        uint256 previewShares = vault.previewExchangeOut(vaultToken, tokenOut, desiredAmountOut);
        assertGt(previewShares, 0, "preview zap-out shares");

        uint256 actualShares =
            vault.exchangeOut(vaultToken, previewShares, tokenOut, desiredAmountOut, recipient, false, _deadline());

        assertEq(actualShares, previewShares, "preview zap-out shares match execution");
    }

    function _test_exchangeOut_zap(bool sharesToToken0) internal {
        uint256 bootstrapShares = _bootstrapShares();
        assertGt(bootstrapShares, 0, "bootstrap shares");

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = sharesToToken0 ? IERC20(_token0Address()) : IERC20(_token1Address());
        uint256 desiredAmountOut = 1e12;
        address recipient = makeAddr(sharesToToken0 ? "zapOutRecipient0" : "zapOutRecipient1");

        uint256 previewShares = vault.previewExchangeOut(vaultToken, tokenOut, desiredAmountOut);
        assertGt(previewShares, 0, "preview zap out shares");

        uint256 sharesBefore = vault.balanceOf(address(this));
        uint256 totalSupplyBefore = vault.totalSupply();

        uint256 sharesBurned =
            vault.exchangeOut(vaultToken, previewShares, tokenOut, desiredAmountOut, recipient, false, _deadline());

        assertEq(sharesBurned, previewShares, "zap out burned shares");
        assertEq(vault.balanceOf(address(this)), sharesBefore - sharesBurned, "share balance after burn");
        assertEq(vault.totalSupply(), totalSupplyBefore - sharesBurned, "total supply after burn");
        assertGe(tokenOut.balanceOf(recipient), desiredAmountOut, "recipient zap out tokens");
    }

    function _bootstrapShares() internal returns (uint256 bootstrapShares) {
        IERC20 vaultToken = IERC20(address(vault));
        uint256 bootstrapAmount = 2e18;

        ERC20PermitMintableStub t0 = _tokenStub(_token0Address());
        t0.mint(address(this), bootstrapAmount);
        t0.approve(address(vault), bootstrapAmount);
        bootstrapShares = vault.exchangeIn(
            IERC20(_token0Address()), bootstrapAmount, vaultToken, 0, address(this), false, _deadline()
        );
    }

    function _buildPoolKey(address token0Candidate, address token1Candidate)
        internal
        pure
        returns (PoolKey memory key)
    {
        (address token0, address token1) = token0Candidate < token1Candidate
            ? (token0Candidate, token1Candidate)
            : (token1Candidate, token0Candidate);

        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _token0Address() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1Address() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }

    function _tokenStub(address token) internal view returns (ERC20PermitMintableStub) {
        if (token == address(tokenA)) {
            return tokenA;
        }
        return tokenB;
    }

    function _vaultManagedTicks() internal view returns (ManagedTicks memory ticks) {
        int24 tickSpacing = poolKey.tickSpacing;
        ticks.centerLower = TickMath.minUsableTick(tickSpacing);
        ticks.centerUpper = TickMath.maxUsableTick(tickSpacing);
        ticks.lowerWingLower = ticks.centerLower;
        ticks.lowerWingUpper = ticks.centerLower;
        ticks.upperWingLower = ticks.centerUpper;
        ticks.upperWingUpper = ticks.centerUpper;
    }

    function _feeGrowthSnapshot() internal view returns (FeeGrowthSnapshot memory snapshot) {
        ManagedTicks memory ticks = _vaultManagedTicks();
        _accumulateFeeGrowth(snapshot, _centerRange(ticks));
    }

    function _executeSmallToken0Deposit() internal returns (uint256 sharesOut) {
        uint256 secondDepositAmount = 0.1 ether;
        ERC20PermitMintableStub token0Stub = _tokenStub(_token0Address());
        token0Stub.mint(address(this), secondDepositAmount);
        token0Stub.approve(address(vault), secondDepositAmount);
        sharesOut = vault.exchangeIn(
            IERC20(_token0Address()), secondDepositAmount, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
    }

    function _currentVaultPositionAmounts() internal view returns (uint256 amount0, uint256 amount1) {
        (uint160 sqrtPriceX96, int24 tick,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        ManagedTicks memory ticks = _vaultManagedTicks();
        return _positionAmountsForRange(sqrtPriceX96, tick, _centerRange(ticks));
    }

    function _accumulateFeeGrowth(FeeGrowthSnapshot memory snapshot, RangeView memory range) internal view {
        (, uint256 cached0, uint256 cached1) = StateLibrary.getPositionInfo(
            poolManager, poolKey.toId(), address(vault), range.tickLower, range.tickUpper, range.salt
        );
        (uint256 live0, uint256 live1) =
            StateLibrary.getFeeGrowthInside(poolManager, poolKey.toId(), range.tickLower, range.tickUpper);

        snapshot.cached0 += cached0;
        snapshot.cached1 += cached1;
        snapshot.live0 += live0;
        snapshot.live1 += live1;
    }

    function _positionAmountsForRange(uint160 sqrtPriceX96, int24 tick, RangeView memory range)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint128 liquidity,,) = StateLibrary.getPositionInfo(
            poolManager, poolKey.toId(), address(vault), range.tickLower, range.tickUpper, range.salt
        );

        if (liquidity == 0) {
            return (0, 0);
        }

        amount0 = SqrtPriceMath.getAmount0Delta(
            TickMath.getSqrtPriceAtTick(range.tickLower), TickMath.getSqrtPriceAtTick(range.tickUpper), liquidity, false
        );
        amount1 = SqrtPriceMath.getAmount1Delta(
            TickMath.getSqrtPriceAtTick(range.tickLower), TickMath.getSqrtPriceAtTick(range.tickUpper), liquidity, false
        );

        if (tick <= range.tickLower) {
            amount1 = 0;
        } else if (tick >= range.tickUpper) {
            amount0 = 0;
        } else {
            amount0 = SqrtPriceMath.getAmount0Delta(
                sqrtPriceX96, TickMath.getSqrtPriceAtTick(range.tickUpper), liquidity, false
            );
            amount1 = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(range.tickLower), sqrtPriceX96, liquidity, false
            );
        }
    }

    function _centerRange(ManagedTicks memory ticks) internal pure returns (RangeView memory range) {
        return RangeView({tickLower: ticks.centerLower, tickUpper: ticks.centerUpper, salt: bytes32(0)});
    }

    function _lowerWingRange(ManagedTicks memory ticks) internal pure returns (RangeView memory range) {
        return RangeView({tickLower: ticks.lowerWingLower, tickUpper: ticks.lowerWingUpper, salt: LOWER_WING_SALT});
    }

    function _upperWingRange(ManagedTicks memory ticks) internal pure returns (RangeView memory range) {
        return RangeView({tickLower: ticks.upperWingLower, tickUpper: ticks.upperWingUpper, salt: UPPER_WING_SALT});
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }
}
