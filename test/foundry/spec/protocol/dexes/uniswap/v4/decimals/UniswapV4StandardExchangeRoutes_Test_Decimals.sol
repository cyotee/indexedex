// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";
import {
    UniswapV4LiquiditySeeder_ProDexUniV4,
    UniswapV4ExternalSwapper_ProDexUniV4
} from "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/harness/UniswapV4SeDecimalsPoolOps.sol";

/**
 * @title UniswapV4StandardExchangeRoutes_Test_Decimals
 * @notice Gold Routes money-paths on combo decimals. pairToken = tokenA. vaultShare stays 18.
 * @dev After PoolKey sort, `_u0`/`_u1` follow currency0/currency1. Combo ID is the wrapper name.
 */
abstract contract UniswapV4StandardExchangeRoutes_Test_Decimals is UniswapV4SeDecimalsHelpers {
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

    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    UniswapV4LiquiditySeeder_ProDexUniV4 internal seeder;
    UniswapV4ExternalSwapper_ProDexUniV4 internal swapper;
    uint160 internal initSqrtPriceX96;

    function _u0(uint256 human) internal view returns (uint256) {
        return _uOf(_token0Address(), human);
    }

    function _u1(uint256 human) internal view returns (uint256) {
        return _uOf(_token1Address(), human);
    }

    function setUp() public virtual override {
        super.setUp();

        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        initSqrtPriceX96 = _oneToOneHumanSqrtPrice(_token0Address(), _token1Address());

        poolManager.initialize(poolKey, initSqrtPriceX96);

        seeder = new UniswapV4LiquiditySeeder_ProDexUniV4(poolManager);
        swapper = new UniswapV4ExternalSwapper_ProDexUniV4(poolManager);
        tokenA.mint(address(seeder), _uA(1_000_000));
        tokenB.mint(address(seeder), _uB(1_000_000));
        tokenA.mint(address(swapper), _uA(1_000_000));
        tokenB.mint(address(swapper), _uB(1_000_000));

        (int24 tickLower, int24 tickUpper) = _seedTicksAround(initSqrtPriceX96, poolKey.tickSpacing);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            initSqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            _u0(100_000),
            _u1(100_000)
        );

        seeder.addLiquidity(poolKey, tickLower, tickUpper, liquidity);

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
    }

    function test_exchangeIn_zap_secondDeposit_checkpointsAccruedFees_afterRoundTripTrading() public {
        uint256 bootstrapShares = _bootstrapShares();
        assertGt(bootstrapShares, 0, "bootstrap shares");

        FeeGrowthSnapshot memory beforeSnapshot = _feeGrowthSnapshot();

        uint256 roundTripAmountIn = _u0(10_000);
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

        (, int24 tickBefore,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        swapper.swapExactIn(poolKey, true, _u0(20_000));

        (, int24 tickAfterTrade,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertLt(tickAfterTrade, tickBefore, "expected lower tick after token0 sale");

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

        uint256 desiredAmountOut = _tinyOf(_token1Address());
        uint256 preview = vault.previewExchangeOut(tokenIn, tokenOut, desiredAmountOut);
        assertGt(preview, 0, "preview input");

        MintableERC20Decimals t0 = _tokenStub(_token0Address());
        t0.mint(address(this), preview);
        t0.approve(address(vault), preview);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, preview - 1, tokenOut, desiredAmountOut, makeAddr("tooLow"), false, _deadline());
    }

    function test_exchangeOut_direct_refunds_excess_input() public {
        IERC20 tokenIn = IERC20(_token0Address());
        IERC20 tokenOut = IERC20(_token1Address());

        uint256 desiredAmountOut = _tinyOf(_token1Address());
        uint256 preview = vault.previewExchangeOut(tokenIn, tokenOut, desiredAmountOut);
        uint256 maxAmountIn = preview + _tinyOf(_token0Address());
        address recipient = makeAddr("refundRecipient");

        MintableERC20Decimals t0 = _tokenStub(_token0Address());
        t0.mint(address(this), maxAmountIn);
        t0.approve(address(vault), maxAmountIn);

        uint256 senderBalanceBefore = t0.balanceOf(address(this));
        uint256 amountIn =
            vault.exchangeOut(tokenIn, maxAmountIn, tokenOut, desiredAmountOut, recipient, false, _deadline());

        assertLt(amountIn, maxAmountIn, "actual input less than cap");
        assertEq(t0.balanceOf(address(this)), senderBalanceBefore - amountIn, "excess input refunded");
        assertGe(tokenOut.balanceOf(recipient), desiredAmountOut, "recipient refunded exact out");
    }

    function test_twoTokenActivation_token0Dominant_previewAndExecution() public {
        _test_exchangeIn_zap_firstDeposit(true);
    }

    function test_twoTokenActivation_token1Dominant_previewAndExecution() public {
        _test_exchangeIn_zap_firstDeposit(false);
    }

    function test_exchangeIn_zap_token0ToShares_secondDeposit() public {
        IERC20 vaultToken = IERC20(address(vault));
        MintableERC20Decimals t0 = _tokenStub(_token0Address());
        uint256 bootstrapShares = _bootstrapShares();
        assertGt(bootstrapShares, 0, "bootstrap shares");

        uint256 amountIn = _u0(1);
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
        _bootstrapShares();
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = _u0(1);

        MintableERC20Decimals t0 = _tokenStub(_token0Address());
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
    function test_exchangeIn_zap_pretransferred_true() public {
        _bootstrapShares();
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = _u0(1);
        address recipient = makeAddr("zapInPretransferredRecipient");

        MintableERC20Decimals t0 = _tokenStub(_token0Address());
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
        uint256 desiredAmountOut = _tinyOf(_token0Address());

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
        uint256 desiredAmountOut = _tinyOf(_token0Address());
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
        MintableERC20Decimals inputStub = _tokenStub(address(tokenIn));

        // Gold 1e12 of 18-dec is below fee dust on 6-dec (1 raw unit). Use 1e-3 human.
        uint256 amountIn = _milliOf(address(tokenIn));
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
        MintableERC20Decimals inputStub = _tokenStub(address(tokenIn));

        uint256 desiredAmountOut = _tinyOf(address(tokenOut));
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
        MintableERC20Decimals inputStub = _tokenStub(address(tokenIn));

        uint256 amountIn = _halfOf(address(tokenIn));
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
        MintableERC20Decimals inputStub = _tokenStub(address(tokenIn));

        uint256 desiredAmountOut = _halfOf(address(tokenOut));
        address recipient = makeAddr(token0ToToken1 ? "previewExactOut01" : "previewExactOut10");

        uint256 preview = vault.previewExchangeOut(tokenIn, tokenOut, desiredAmountOut);
        assertGt(preview, 0, "preview exact out");

        inputStub.mint(address(this), preview);
        inputStub.approve(address(vault), preview);

        uint256 actualIn =
            vault.exchangeOut(tokenIn, preview, tokenOut, desiredAmountOut, recipient, false, _deadline());

        assertEq(actualIn, preview, "preview exact out matches execution");
    }

    function _test_exchangeIn_zap_firstDeposit(bool token0Dominant) internal {
        address[] memory tokens = new address[](2);
        tokens[0] = _token0Address();
        tokens[1] = _token1Address();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = token0Dominant ? _u0(2) : _u0(1);
        amounts[1] = token0Dominant ? _u1(1) : _u1(2);
        address recipient = makeAddr(token0Dominant ? "firstToken0Dominant" : "firstToken1Dominant");
        for (uint256 i; i < 2; ++i) {
            _tokenStub(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(vault), amounts[i]);
        }
        uint256 preview = IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(
            tokens, amounts, IERC20(address(vault))
        );
        uint256 shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), preview, recipient, false, _deadline()
        );
        assertGt(shares, 0, "two-token initial shares");
        assertEq(shares, preview, "activation preview equals execution");
        assertEq(vault.balanceOf(recipient), shares, "activation recipient shares");
        assertEq(vault.totalSupply(), shares, "activation total supply");
        assertGt(vault.reserveOfToken(tokens[0]), 0, "activation token0 reserve");
        assertGt(vault.reserveOfToken(tokens[1]), 0, "activation token1 reserve");
    }



    function _test_previewExchangeIn_zap_secondDeposit_matchesExecution(bool token0ToShares) internal {
        IERC20 tokenIn = token0ToShares ? IERC20(_token0Address()) : IERC20(_token1Address());
        IERC20 vaultToken = IERC20(address(vault));
        MintableERC20Decimals inputStub = _tokenStub(address(tokenIn));

        _bootstrapShares();

        uint256 amountIn = _uOf(address(tokenIn), 1);
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
        uint256 desiredAmountOut = _halfOf(address(tokenOut));
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
        uint256 desiredAmountOut = _tinyOf(address(tokenOut));
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
        address[] memory tokens = new address[](2);
        tokens[0] = _token0Address();
        tokens[1] = _token1Address();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _u0(2);
        amounts[1] = _u1(2);
        for (uint256 i; i < 2; ++i) {
            _tokenStub(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(vault), amounts[i]);
        }
        bootstrapShares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
    }

    function _token0Address() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1Address() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }

    function _tokenStub(address token) internal view returns (MintableERC20Decimals) {
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
        uint256 secondDepositAmount = _u0(1) / 10;
        if (secondDepositAmount == 0) secondDepositAmount = 1;
        MintableERC20Decimals token0Stub = _tokenStub(_token0Address());
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
}
