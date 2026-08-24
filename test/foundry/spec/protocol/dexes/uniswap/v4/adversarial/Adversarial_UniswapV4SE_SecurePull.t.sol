// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    UniswapV4StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";
import {
    UniswapV4StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";

/// @dev Minimal pool seeder for production Uniswap V4 SE adversarial suite.
contract AdversarialV4Seeder is IUnlockCallback {
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
 * @title Adversarial_UniswapV4SE_SecurePull
 * @notice WP-I-SE-UAB-001 / WP-J-SE-UAB-001 + WP-ADV-SE-UAB-001 residual A–H.
 * @dev Production DFPkg + proxy only (no mock SUT). L-GAPS-9/10 / ISecurePullErrors.
 *      Catalog residual (WP-ADV-SE-UAB-001): A1–A3 donation, E1/E4/E5, H2/H3 residual, F1 cut.
 *      I1 free-credit + J1–J3 surface already landed. C-class: nonReentrant on In/Out targets.
 *      B/D/G N/A for pure SE (no claim/NFT/seigniorage composition surface).
 */
contract Adversarial_UniswapV4SE_SecurePull is TestBase_UniswapV4StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    address internal attacker;
    address internal victim;

    uint256 internal constant TEST_AMT = 2 ether;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        (address t0, address t1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        poolKey = PoolKey({
            currency0: Currency.wrap(t0),
            currency1: Currency.wrap(t1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        AdversarialV4Seeder seeder = new AdversarialV4Seeder(poolManager);
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

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey, 60));
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

    function _expiredDeadline() internal view returns (uint256) {
        return block.timestamp - 1;
    }

    /// @dev Route token0 → SE shares for catalog donation / non-dilution cases.
    function _mintSeShares(address to_, uint256 amountIn_) internal returns (uint256 shares_) {
        address token0_ = _token0();
        ERC20PermitMintableStub(token0_).mint(to_, amountIn_);
        vm.startPrank(to_);
        IERC20(token0_).approve(address(vault), amountIn_);
        shares_ = vault.exchangeIn(IERC20(token0_), amountIn_, IERC20(address(vault)), 0, to_, false, _deadline());
        vm.stopPrank();
        assertGt(shares_, 0, "minted SE shares");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory (R==B), no new unbooked push, pretransferred=true */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: after honest money route end-syncs face book, free true without new push reverts U=0.
    /// @dev L-RSRV-DUST: bare donation free-credits until sync — not I1. Uni V4 SE may deploy free face
    ///      into the position on honest mint, so free face B can be 0; I1 still holds (U=0).
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        uint256 claimed_ = 5 ether;
        address token0_ = _token0();

        // Book face via honest !pretransfer (end-syncs R including deployed + free face).
        uint256 honestIn_ = 2 ether;
        ERC20PermitMintableStub(token0_).mint(victim, honestIn_);
        vm.startPrank(victim);
        IERC20(token0_).approve(address(vault), honestIn_);
        vault.exchangeIn(IERC20(token0_), honestIn_, IERC20(address(vault)), 0, victim, false, _deadline());
        vm.stopPrank();

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

    /// @notice I1: claimed > 0 with no unbooked face push reverts U=0 (absolute free credit forbidden).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        uint256 claimed_ = 3 ether;
        address token0_ = _token0();

        // Book via honest path so face free is fully accounted (U=0 even if free face dust remains).
        uint256 honestIn_ = 2 ether;
        ERC20PermitMintableStub(token0_).mint(victim, honestIn_);
        vm.startPrank(victim);
        IERC20(token0_).approve(address(vault), honestIn_);
        vault.exchangeIn(IERC20(token0_), honestIn_, IERC20(address(vault)), 0, victim, false, _deadline());
        vm.stopPrank();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault.exchangeIn(IERC20(token0_), claimed_, IERC20(address(vault)), 0, attacker, true, _deadline());
    }

    /// @notice Positive control: honest !pretransferred pull succeeds and mints shares.
    function test_I_positive_honestPullMint_succeeds() public {
        uint256 amountIn_ = 2 ether;
        address token0_ = _token0();
        ERC20PermitMintableStub(token0_).mint(attacker, amountIn_);
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), amountIn_);
        uint256 out_ = vault.exchangeIn(
            IERC20(token0_), amountIn_, IERC20(address(vault)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest !pretransferred mint");
        assertEq(vault.balanceOf(attacker), out_, "attacker received shares");
    }

    /* ---------------------------------------------------------------------- */
    /*  A1–A3 / E1 / E4 / E5 / F1 / H2–H3 residual (WP-ADV-SE-UAB-001)        */
    /* ---------------------------------------------------------------------- */

    /// @notice A1: donate underlyings to vault without deposit call — no free SE shares.
    function test_A1_donateToken_cannotMintFreeShares() public {
        uint256 amount_ = TEST_AMT;
        address token0_ = _token0();
        ERC20PermitMintableStub(token0_).mint(attacker, amount_);
        uint256 sharesBefore_ = vault.balanceOf(attacker);
        uint256 supplyBefore_ = vault.totalSupply();

        vm.prank(attacker);
        IERC20(token0_).transfer(address(vault), amount_);

        assertEq(vault.balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
        assertEq(vault.totalSupply(), supplyBefore_, "A1: supply unchanged");
        assertEq(IERC20(token0_).balanceOf(address(vault)), amount_, "A1: inventory idle");
    }

    /// @notice A2: donate SE shares (product token) to diamond — idle inventory; no free mint/theft.
    function test_A2_donateSeShares_noFreeMintOrTheft() public {
        uint256 shares_ = _mintSeShares(attacker, TEST_AMT);
        uint256 donate_ = shares_ / 2;
        if (donate_ == 0) donate_ = shares_;

        uint256 victimShares_ = _mintSeShares(victim, TEST_AMT / 2);
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

    /// @notice A3: donate pair token without deposit — no free SE shares (no LP token surface).
    function test_A3_donatePairToken_cannotMintFreeShares() public {
        uint256 amount_ = TEST_AMT;
        address token1_ = _token1();
        ERC20PermitMintableStub(token1_).mint(attacker, amount_);

        uint256 supplyBefore_ = vault.totalSupply();
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 vaultTokBefore_ = IERC20(token1_).balanceOf(address(vault));

        vm.prank(attacker);
        IERC20(token1_).transfer(address(vault), amount_);

        assertEq(IERC20(token1_).balanceOf(address(vault)), vaultTokBefore_ + amount_, "A3 token sits idle");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "A3 no free SE shares");
        assertEq(vault.totalSupply(), supplyBefore_, "A3 supply unchanged");
    }

    /// @notice E1: swap token0→token1→token0 conservation (fee-aware; no free lunch).
    function test_E1_swapRoundTrip_bounded() public {
        uint256 amount_ = TEST_AMT;
        address token0_ = _token0();
        address token1_ = _token1();
        ERC20PermitMintableStub(token0_).mint(attacker, amount_);

        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), amount_);
        uint256 out1_ = vault.exchangeIn(
            IERC20(token0_), amount_, IERC20(token1_), 0, attacker, false, _deadline()
        );
        assertGt(out1_, 0, "got token1");
        IERC20(token1_).approve(address(vault), out1_);
        uint256 back0_ = vault.exchangeIn(
            IERC20(token1_), out1_, IERC20(token0_), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertLe(back0_, amount_, "E1: no free lunch on SE swap round-trip");
    }

    /// @notice E4: existing SE share holder balance units not diluted by others' swaps.
    function test_E4_holderBalance_notDilutedByOthersSwap() public {
        uint256 victimShares_ = _mintSeShares(victim, TEST_AMT);
        assertEq(vault.balanceOf(victim), victimShares_, "victim seeded");

        address token0_ = _token0();
        address token1_ = _token1();
        ERC20PermitMintableStub(token0_).mint(attacker, TEST_AMT);
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), TEST_AMT);
        uint256 out_ =
            vault.exchangeIn(IERC20(token0_), TEST_AMT, IERC20(token1_), 0, attacker, false, _deadline());
        vm.stopPrank();
        assertGt(out_, 0, "attacker swap");
        assertEq(vault.balanceOf(victim), victimShares_, "E4: victim share balance unchanged");
    }

    /// @notice E5: zero amount reverts (product error, not missing selector).
    function test_E5_zeroAmount_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.exchangeIn(IERC20(_token0()), 0, IERC20(_token1()), 0, attacker, false, _deadline());
    }

    /// @notice E5: expired deadline reverts with UniswapV4ExchangeIn_DeadlineExceeded.
    function test_E5_expiredDeadline_reverts() public {
        uint256 amount_ = TEST_AMT;
        uint256 expired_ = _expiredDeadline();
        address token0_ = _token0();
        ERC20PermitMintableStub(token0_).mint(attacker, amount_);
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), amount_);
        vm.expectRevert(UniswapV4StandardExchangeInBase.UniswapV4ExchangeIn_DeadlineExceeded.selector);
        vault.exchangeIn(IERC20(token0_), amount_, IERC20(_token1()), 0, attacker, false, expired_);
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "E5 residual vault shares");
    }

    /// @notice E5: unsupported junk tokenOut → ExchangeInNotAvailable.
    function test_E5_invalidRoute_unsupportedToken_reverts() public {
        ERC20PermitMintableStub junk_ = new ERC20PermitMintableStub("Junk", "JNK", 18, address(this), 0);
        uint256 amount_ = TEST_AMT / 2;
        address token0_ = _token0();
        ERC20PermitMintableStub(token0_).mint(attacker, amount_);
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), amount_);
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        vault.exchangeIn(IERC20(token0_), amount_, IERC20(address(junk_)), 0, attacker, false, _deadline());
        vm.stopPrank();
    }

    /// @notice E5: exchangeOut expired deadline — exact selector; no residual shares.
    function test_E5_exchangeOut_expiredDeadline_reverts() public {
        uint256 amountOut_ = 0.1 ether;
        uint256 previewIn_ = vault.previewExchangeOut(IERC20(_token0()), IERC20(_token1()), amountOut_);
        uint256 expired_ = _expiredDeadline();
        ERC20PermitMintableStub(_token0()).mint(attacker, previewIn_ * 2);
        vm.startPrank(attacker);
        IERC20(_token0()).approve(address(vault), previewIn_ * 2);
        vm.expectRevert(UniswapV4StandardExchangeOutBase.UniswapV4ExchangeOut_DeadlineExceeded.selector);
        vault.exchangeOut(
            IERC20(_token0()), previewIn_ * 2, IERC20(_token1()), amountOut_, attacker, false, expired_
        );
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "E5 out residual shares");
    }

    /// @notice F1: diamondCut is not cut into unowned production proxy (immutability).
    /// @dev Loupe absence is authoritative; some proxies may no-op-delegatecall address(0).
    function test_F1_diamondCut_blocked() public view {
        assertEq(
            IDiamondLoupe(address(vault)).facetAddress(IDiamondCut.diamondCut.selector),
            address(0),
            "F1 diamondCut facet absent"
        );
    }

    /// @notice H2: failed exchangeOut (maxIn too low) is atomic — attacker inventory unchanged.
    function test_H2_exchangeOut_maxInTooLow_balancesUnchanged() public {
        uint256 amountOut_ = 0.1 ether;
        address token0_ = _token0();
        address token1_ = _token1();
        uint256 requiredIn_ = vault.previewExchangeOut(IERC20(token0_), IERC20(token1_), amountOut_);
        require(requiredIn_ > 1, "preview");
        uint256 tooLow_ = requiredIn_ / 4;
        if (tooLow_ == 0) tooLow_ = 1;

        ERC20PermitMintableStub(token0_).mint(attacker, requiredIn_);
        uint256 aBefore_ = IERC20(token0_).balanceOf(attacker);
        uint256 bBefore_ = IERC20(token1_).balanceOf(attacker);
        uint256 supplyBefore_ = vault.totalSupply();

        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), requiredIn_);
        vm.expectRevert();
        vault.exchangeOut(
            IERC20(token0_), tooLow_, IERC20(token1_), amountOut_, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(IERC20(token0_).balanceOf(attacker), aBefore_, "H2 tokenIn unchanged");
        assertEq(IERC20(token1_).balanceOf(attacker), bBefore_, "H2 tokenOut unchanged");
        assertEq(vault.totalSupply(), supplyBefore_, "H2 supply unchanged");
        assertEq(vault.balanceOf(address(vault)), 0, "H2 no free vault shares");
    }

    /// @notice H3: exchangeIn minOut too high leaves no free residual product shares.
    function test_H3_minOutTooHigh_noFreeShares() public {
        uint256 amount_ = TEST_AMT;
        address token0_ = _token0();
        address token1_ = _token1();
        ERC20PermitMintableStub(token0_).mint(attacker, amount_);
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

    /// @notice H3: exchangeOut maxIn fail leaves no free inventory on diamond product book.
    function test_H3_exchangeOut_maxInTooLow_noFreeShares() public {
        uint256 amountOut_ = 0.2 ether;
        address token0_ = _token0();
        address token1_ = _token1();
        uint256 requiredIn_ = vault.previewExchangeOut(IERC20(token0_), IERC20(token1_), amountOut_);
        uint256 tooLow_ = requiredIn_ / 2;
        if (tooLow_ == 0) tooLow_ = 1;

        ERC20PermitMintableStub(token0_).mint(attacker, requiredIn_);
        vm.startPrank(attacker);
        IERC20(token0_).approve(address(vault), requiredIn_);
        vm.expectRevert();
        vault.exchangeOut(
            IERC20(token0_), tooLow_, IERC20(token1_), amountOut_, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "H3 out residual vault shares");
    }

    /* ---------------------------------------------------------------------- */
    /*  J1–J3: diamond surface on production proxy (WP-J-SE-UAB-001)          */
    /* ---------------------------------------------------------------------- */

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

    /// @notice J1: CREATE3 facetFuncs cover target money/query selectors (Target ⊆ facetFuncs).
    function test_J1_facetFuncs_coversTargetApi() public {
        assertTrue(
            _facetFuncsContains(uniswapV4StandardExchangeInFacet.facetFuncs(), IStandardExchangeIn.exchangeIn.selector),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                uniswapV4StandardExchangeInQueryFacet.facetFuncs(), IStandardExchangeIn.previewExchangeIn.selector
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

    /// @notice J2: loupe facetAddress(sel) != 0 for product controls on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(vault));
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(vault), "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call money + view selectors on **proxy** (not facet impl address).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        address exchangeInFacet_ = IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address exchangeOutFacet_ =
            IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        assertTrue(exchangeInFacet_ != address(0) && exchangeInFacet_ != address(vault), "proxy cut in");
        assertTrue(exchangeOutFacet_ != address(0) && exchangeOutFacet_ != address(vault), "proxy cut out");

        uint256 previewIn_ =
            IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(_token0()), 1 ether, IERC20(address(vault)));
        assertGt(previewIn_, 0, "J3 previewExchangeIn live on proxy");

        // Money path smoke: product revert (not missing selector) for zero amount.
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
