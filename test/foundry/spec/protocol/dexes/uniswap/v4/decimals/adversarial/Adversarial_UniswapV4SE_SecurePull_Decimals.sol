// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {UniswapV4StandardExchangeInBase} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";
import {UniswapV4StandardExchangeOutBase} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";
import {UniswapV4LiquiditySeeder_ProDexUniV4} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/harness/UniswapV4SeDecimalsPoolOps.sol";

/**
 * @title Adversarial_UniswapV4SE_SecurePull_Decimals
 * @notice Gold SecurePull tests on combo decimals. pairToken = tokenA. vaultShare stays 18.
 */
abstract contract Adversarial_UniswapV4SE_SecurePull_Decimals is UniswapV4SeDecimalsHelpers {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    address internal attacker;
    address internal victim;

    function _u0(uint256 human) internal view returns (uint256) {
        return _uOf(_token0(), human);
    }

    function _u1(uint256 human) internal view returns (uint256) {
        return _uOf(_token1(), human);
    }

    function _testAmt0() internal view returns (uint256) {
        return _u0(2);
    }

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");

        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        uint160 sqrtP = _oneToOneHumanSqrtPrice(_token0(), _token1());
        poolManager.initialize(poolKey, sqrtP);

        UniswapV4LiquiditySeeder_ProDexUniV4 seeder = new UniswapV4LiquiditySeeder_ProDexUniV4(poolManager);
        tokenA.mint(address(seeder), _uA(1_000_000));
        tokenB.mint(address(seeder), _uB(1_000_000));
        (int24 tickLower, int24 tickUpper) = _seedTicksAround(sqrtP, poolKey.tickSpacing);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            _u0(100_000),
            _u1(100_000)
        );
        seeder.addLiquidity(poolKey, tickLower, tickUpper, liq);

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }

    function _expiredDeadline() internal view returns (uint256) {
        return block.timestamp - 1;
    }

    function _mintSeShares(address to_, uint256 amountIn_) internal returns (uint256 shares_) {
        address token0_ = _token0();
        MintableERC20Decimals(token0_).mint(to_, amountIn_);
        vm.startPrank(to_);
        IERC20(token0_).approve(address(vault), amountIn_);
        if (vault.totalSupply() == 0) {
            uint256 amount1_ = amountIn_ * _u1(1) / _u0(1);
            MintableERC20Decimals(_token1()).mint(to_, amount1_);
            IERC20(_token1()).approve(address(vault), amount1_);
            address[] memory tokens = new address[](2);
            tokens[0] = token0_;
            tokens[1] = _token1();
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = amountIn_;
            amounts[1] = amount1_;
            shares_ = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
                tokens, amounts, IERC20(address(vault)), 0, to_, false, _deadline()
            );
        } else {
            shares_ = vault.exchangeIn(IERC20(token0_), amountIn_, IERC20(address(vault)), 0, to_, false, _deadline());
        }
        vm.stopPrank();
        assertGt(shares_, 0, "minted SE shares");
    }

    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        uint256 claimed_ = _u0(5);
        address token0_ = _token0();

        uint256 honestIn_ = _u0(2);
        _mintSeShares(victim, honestIn_);

        assertEq(IERC20(token0_).balanceOf(attacker), 0, "attacker empty");
        assertEq(IERC20(token0_).allowance(attacker, address(vault)), 0, "no allowance");

        uint256 supplyBefore_ = vault.totalSupply();
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 invBefore_ = IERC20(token0_).balanceOf(address(vault));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault.exchangeIn(IERC20(token0_), claimed_, IERC20(address(vault)), 0, attacker, true, _deadline());

        assertEq(vault.totalSupply(), supplyBefore_, "I1: no free share mint");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "I1: attacker shares unchanged");
        assertEq(IERC20(token0_).balanceOf(address(vault)), invBefore_, "I1: inventory unmoved");
    }

    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        uint256 claimed_ = _u0(3);
        address token0_ = _token0();

        uint256 honestIn_ = _u0(2);
        _mintSeShares(victim, honestIn_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault.exchangeIn(IERC20(token0_), claimed_, IERC20(address(vault)), 0, attacker, true, _deadline());
    }

    function test_I_positive_honestPullMint_succeeds() public {
        uint256 amountIn_ = _u0(2);
        uint256 out_ = _mintSeShares(attacker, amountIn_);
        assertGt(out_, 0, "honest !pretransferred mint");
        assertEq(vault.balanceOf(attacker), out_, "attacker received shares");
    }

    function test_A1_donateToken_cannotMintFreeShares() public {
        uint256 amount_ = _testAmt0();
        address token0_ = _token0();
        MintableERC20Decimals(token0_).mint(attacker, amount_);
        uint256 sharesBefore_ = vault.balanceOf(attacker);
        uint256 supplyBefore_ = vault.totalSupply();

        vm.prank(attacker);
        IERC20(token0_).transfer(address(vault), amount_);

        assertEq(vault.balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
        assertEq(vault.totalSupply(), supplyBefore_, "A1: supply unchanged");
        assertEq(IERC20(token0_).balanceOf(address(vault)), amount_, "A1: inventory idle");
    }

    function test_A2_donateSeShares_noFreeMintOrTheft() public {
        uint256 shares_ = _mintSeShares(attacker, _testAmt0());
        uint256 donate_ = shares_ / 2;
        if (donate_ == 0) donate_ = shares_;

        uint256 victimShares_ = _mintSeShares(victim, _u0(1));
        uint256 supplyBefore_ = vault.totalSupply();
        uint256 victimBefore_ = vault.balanceOf(victim);

        vm.prank(attacker);
        vault.transfer(address(vault), donate_);

        assertEq(vault.balanceOf(attacker), shares_ - donate_, "A2 attacker spent donation");
        assertEq(vault.balanceOf(address(vault)), donate_, "A2 idle product on diamond");
        assertEq(vault.balanceOf(victim), victimBefore_, "A2 victim shares untouched");
        assertEq(victimBefore_, victimShares_, "A2 victim mint stable");
        assertEq(vault.totalSupply(), supplyBefore_, "A2 transfer does not mint/burn");
    }

    function test_A3_donatePairToken_cannotMintFreeShares() public {
        uint256 amount_ = _u1(2);
        address token1_ = _token1();
        MintableERC20Decimals(token1_).mint(attacker, amount_);

        uint256 supplyBefore_ = vault.totalSupply();
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 vaultTokBefore_ = IERC20(token1_).balanceOf(address(vault));

        vm.prank(attacker);
        IERC20(token1_).transfer(address(vault), amount_);

        assertEq(IERC20(token1_).balanceOf(address(vault)), vaultTokBefore_ + amount_, "A3 token sits idle");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "A3 no free SE shares");
        assertEq(vault.totalSupply(), supplyBefore_, "A3 supply unchanged");
    }

    function test_E1_swapRoundTrip_bounded() public {
        uint256 amount_ = _testAmt0();
        address token0_ = _token0();
        address token1_ = _token1();
        MintableERC20Decimals(token0_).mint(attacker, amount_);

        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), amount_);
        uint256 out1_ = vault.exchangeIn(IERC20(token0_), amount_, IERC20(token1_), 0, attacker, false, _deadline());
        assertGt(out1_, 0, "got token1");
        IERC20(token1_).approve(address(vault), out1_);
        uint256 back0_ = vault.exchangeIn(IERC20(token1_), out1_, IERC20(token0_), 0, attacker, false, _deadline());
        vm.stopPrank();
        assertLe(back0_, amount_, "E1: no free lunch on SE swap round-trip");
    }

    function test_E4_holderBalance_notDilutedByOthersSwap() public {
        uint256 victimShares_ = _mintSeShares(victim, _testAmt0());
        assertEq(vault.balanceOf(victim), victimShares_, "victim seeded");

        address token0_ = _token0();
        address token1_ = _token1();
        MintableERC20Decimals(token0_).mint(attacker, _testAmt0());
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), _testAmt0());
        uint256 out_ =
            vault.exchangeIn(IERC20(token0_), _testAmt0(), IERC20(token1_), 0, attacker, false, _deadline());
        vm.stopPrank();
        assertGt(out_, 0, "attacker swap");
        assertEq(vault.balanceOf(victim), victimShares_, "E4: victim share balance unchanged");
    }

    function test_E5_zeroAmount_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.exchangeIn(IERC20(_token0()), 0, IERC20(_token1()), 0, attacker, false, _deadline());
    }

    function test_E5_expiredDeadline_reverts() public {
        uint256 amount_ = _testAmt0();
        uint256 expired_ = _expiredDeadline();
        address token0_ = _token0();
        MintableERC20Decimals(token0_).mint(attacker, amount_);
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), amount_);
        vm.expectRevert(UniswapV4StandardExchangeInBase.UniswapV4ExchangeIn_DeadlineExceeded.selector);
        vault.exchangeIn(IERC20(token0_), amount_, IERC20(_token1()), 0, attacker, false, expired_);
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "E5 residual vault shares");
    }

    function test_E5_invalidRoute_unsupportedToken_reverts() public {
        MintableERC20Decimals junk_ = new MintableERC20Decimals("Junk", "JNK", 18);
        uint256 amount_ = _u0(1);
        address token0_ = _token0();
        MintableERC20Decimals(token0_).mint(attacker, amount_);
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), amount_);
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        vault.exchangeIn(IERC20(token0_), amount_, IERC20(address(junk_)), 0, attacker, false, _deadline());
        vm.stopPrank();
    }

    function test_E5_exchangeOut_expiredDeadline_reverts() public {
        uint256 amountOut_ = _u1(1) / 10;
        if (amountOut_ == 0) amountOut_ = 1;
        uint256 previewIn_ = vault.previewExchangeOut(IERC20(_token0()), IERC20(_token1()), amountOut_);
        uint256 expired_ = _expiredDeadline();
        MintableERC20Decimals(_token0()).mint(attacker, previewIn_ * 2);
        vm.startPrank(attacker);
        IERC20(_token0()).approve(address(vault), previewIn_ * 2);
        vm.expectRevert(UniswapV4StandardExchangeOutBase.UniswapV4ExchangeOut_DeadlineExceeded.selector);
        vault.exchangeOut(
            IERC20(_token0()), previewIn_ * 2, IERC20(_token1()), amountOut_, attacker, false, expired_
        );
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "E5 out residual shares");
    }

    function test_F1_diamondCut_blocked() public view {
        assertEq(
            IDiamondLoupe(address(vault)).facetAddress(IDiamondCut.diamondCut.selector),
            address(0),
            "F1 diamondCut facet absent"
        );
    }

    function test_H2_exchangeOut_maxInTooLow_balancesUnchanged() public {
        uint256 amountOut_ = _u1(1) / 10;
        if (amountOut_ == 0) amountOut_ = 1;
        address token0_ = _token0();
        address token1_ = _token1();
        uint256 requiredIn_ = vault.previewExchangeOut(IERC20(token0_), IERC20(token1_), amountOut_);
        require(requiredIn_ > 1, "preview");
        uint256 tooLow_ = requiredIn_ / 4;
        if (tooLow_ == 0) tooLow_ = 1;

        MintableERC20Decimals(token0_).mint(attacker, requiredIn_);
        uint256 aBefore_ = IERC20(token0_).balanceOf(attacker);
        uint256 bBefore_ = IERC20(token1_).balanceOf(attacker);
        uint256 supplyBefore_ = vault.totalSupply();

        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), requiredIn_);
        vm.expectRevert();
        vault.exchangeOut(IERC20(token0_), tooLow_, IERC20(token1_), amountOut_, attacker, false, _deadline());
        vm.stopPrank();

        assertEq(IERC20(token0_).balanceOf(attacker), aBefore_, "H2 tokenIn unchanged");
        assertEq(IERC20(token1_).balanceOf(attacker), bBefore_, "H2 tokenOut unchanged");
        assertEq(vault.totalSupply(), supplyBefore_, "H2 supply unchanged");
        assertEq(vault.balanceOf(address(vault)), 0, "H2 no free vault shares");
    }

    function test_H3_minOutTooHigh_noFreeShares() public {
        uint256 amount_ = _testAmt0();
        address token0_ = _token0();
        address token1_ = _token1();
        MintableERC20Decimals(token0_).mint(attacker, amount_);
        uint256 preview_ = vault.previewExchangeIn(IERC20(token0_), amount_, IERC20(token1_));

        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), amount_);
        vm.expectRevert();
        vault.exchangeIn(
            IERC20(token0_), amount_, IERC20(token1_), preview_ + type(uint128).max, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "H3 residual vault shares");
        assertEq(IERC20(token0_).balanceOf(attacker), amount_, "H3 atomic tokenIn");
    }

    function test_H3_exchangeOut_maxInTooLow_noFreeShares() public {
        uint256 amountOut_ = _u1(1) / 5;
        if (amountOut_ == 0) amountOut_ = 1;
        address token0_ = _token0();
        address token1_ = _token1();
        uint256 requiredIn_ = vault.previewExchangeOut(IERC20(token0_), IERC20(token1_), amountOut_);
        uint256 tooLow_ = requiredIn_ / 2;
        if (tooLow_ == 0) tooLow_ = 1;

        MintableERC20Decimals(token0_).mint(attacker, requiredIn_);
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), requiredIn_);
        vm.expectRevert();
        vault.exchangeOut(IERC20(token0_), tooLow_, IERC20(token1_), amountOut_, attacker, false, _deadline());
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "H3 out residual vault shares");
    }

    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](8);
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = IStandardExchangeOut.exchangeOut.selector;
        sels_[3] = IStandardExchangeOut.previewExchangeOut.selector;
        sels_[4] = IStandardExchangeInMulti.exchangeInManyToOne.selector;
        sels_[5] = IStandardExchangeInMulti.previewExchangeInManyToOne.selector;
        sels_[6] = IStandardExchangeOutMulti.exchangeOutOneToMany.selector;
        sels_[7] = IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector;
    }

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    function test_J1_facetFuncs_coversTargetApi() public {
        assertTrue(
            _facetFuncsContains(uniswapV4StandardExchangeInFacet.facetFuncs(), IStandardExchangeIn.exchangeIn.selector),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                uniswapV4StandardExchangeInMultiQueryFacet.facetFuncs(), IStandardExchangeIn.previewExchangeIn.selector
            ),
            "J1 previewExchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                uniswapV4StandardExchangeOutFacet.facetFuncs(), IStandardExchangeOut.exchangeOut.selector
            ),
            "J1 exchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                uniswapV4StandardExchangeOutQueryFacet.facetFuncs(), IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                uniswapV4StandardExchangeInMultiFacet.facetFuncs(), IStandardExchangeInMulti.exchangeInManyToOne.selector
            ),
            "J1 exchangeInManyToOne"
        );
        assertTrue(
            _facetFuncsContains(
                uniswapV4StandardExchangeInMultiQueryFacet.facetFuncs(),
                IStandardExchangeInMulti.previewExchangeInManyToOne.selector
            ),
            "J1 previewExchangeInManyToOne"
        );
        assertTrue(
            _facetFuncsContains(
                uniswapV4StandardExchangeOutMultiFacet.facetFuncs(),
                IStandardExchangeOutMulti.exchangeOutOneToMany.selector
            ),
            "J1 exchangeOutOneToMany"
        );
        assertTrue(
            _facetFuncsContains(
                uniswapV4StandardExchangeOutMultiQueryFacet.facetFuncs(),
                IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector
            ),
            "J1 previewExchangeOutOneToMany"
        );
    }

    function test_J2_proxyLoupe_allProductSelectors() public {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(vault));
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(vault), "J2 facet != proxy");
        }
    }

    function test_J3_proxyCallable_smoke_eachSelector() public {
        _mintSeShares(victim, _u0(2));
        address exchangeInFacet_ = IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address exchangeOutFacet_ =
            IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        assertTrue(exchangeInFacet_ != address(0) && exchangeInFacet_ != address(vault), "proxy cut in");
        assertTrue(exchangeOutFacet_ != address(0) && exchangeOutFacet_ != address(vault), "proxy cut out");

        uint256 previewIn_ =
            IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(_token0()), _u0(1), IERC20(address(vault)));
        assertGt(previewIn_, 0, "J3 previewExchangeIn live on proxy");

        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(_token0()), 0, IERC20(address(vault)), 0, attacker, false, _deadline()
        );

        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            new address[](1), new uint256[](1), IERC20(address(vault)), 0, attacker, false, _deadline()
        );
    }
}
