// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
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
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
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
 * @notice WP-I-SE-UAB-001 / WP-J-SE-UAB-001: I1 free-credit impossible + J facet/proxy surface.
 * @dev Production DFPkg + proxy only (no mock SUT). L-GAPS-9/10 / ISecurePullErrors.
 */
contract Adversarial_UniswapV4SE_SecurePull is TestBase_UniswapV4StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");

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

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: inventory present, no in-call transfer, pretransferred=true       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 free credit: donate inventory; claim pretransferred without transfer → delta 0.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        uint256 claimed_ = 5 ether;
        address token0_ = _token0();

        // Seed inventory so absolute balance theater would have passed.
        ERC20PermitMintableStub(token0_).mint(attacker, claimed_);
        vm.prank(attacker);
        IERC20(token0_).transfer(address(vault), claimed_);
        assertEq(IERC20(token0_).balanceOf(address(vault)), claimed_, "inventory present");
        assertEq(IERC20(token0_).balanceOf(attacker), 0, "attacker drained");
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

    /// @notice I1 claimed ≤ inventory still reverts when observedDelta is 0 (absolute credit forbidden).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        uint256 inventory_ = 10 ether;
        uint256 claimed_ = 3 ether;
        address token0_ = _token0();

        ERC20PermitMintableStub(token0_).mint(address(vault), inventory_);
        assertGe(IERC20(token0_).balanceOf(address(vault)), claimed_, "claimed <= inventory");

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
    /*  J1–J3: diamond surface on production proxy (WP-J-SE-UAB-001)          */
    /* ---------------------------------------------------------------------- */

    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](4);
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = IStandardExchangeOut.exchangeOut.selector;
        sels_[3] = IStandardExchangeOut.previewExchangeOut.selector;
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
                uniswapV4StandardExchangeOutFacet.facetFuncs(), IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
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
    }
}
