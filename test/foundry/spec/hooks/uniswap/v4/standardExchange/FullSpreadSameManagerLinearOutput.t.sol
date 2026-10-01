// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote as Quantity} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {FullSpreadQuantityReference as Reference} from "contracts/test/bases/TestBase_UniswapV4FullSpreadExactOutputQuantity.sol";
import {TestBase_UniswapV4FullSpreadUnlockContextQuote as Shapes} from "contracts/test/bases/TestBase_UniswapV4FullSpreadUnlockContextQuote.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPool} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as HAcceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as PAcceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "./SeMatrixFixture.sol";
import {FullSpreadSameManagerAmmFixture as Amm} from "./FullSpreadSameManagerAmmFixture.sol";

/// @dev Genuine outer manager session; the caller never impersonates the manager or hook.
contract FullSpreadLinearOutputUnlock is IUnlockCallback {
    IPoolManager private immutable manager;
    constructor(IPoolManager manager_) { manager = manager_; }
    function run(address target, bytes calldata data) external returns (bytes memory) {
        return manager.unlock(abi.encode(target, data));
    }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager), "manager only");
        (address target, bytes memory input) = abi.decode(data, (address, bytes));
        (bool ok, bytes memory result) = target.call(input);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return result;
    }
}

/// @notice Real one-backed H/P output through every reserve-holding AMM family.
abstract contract FullSpreadLinearOutputAssertions is Test {
    IPoolManager private linearManager;
    address private linearVault;
    IERC20 private linearAsset;
    IERC20 private opposingAsset;
    HookFactory private linearFactory;
    FullSpreadLinearOutputUnlock private linearDriver;
    WrapperExactOutRouter private linearRouter;

    function _linearContext() internal view virtual returns (SeMatrixFixture.Ctx memory);
    function _prepareOrbitalBook() internal virtual;

    function _configureLinear(IPoolManager manager_, address vault_, IERC20 asset_, IERC20 opposing_) internal {
        linearManager = manager_; linearVault = vault_; linearAsset = asset_; opposingAsset = opposing_;
        linearDriver = new FullSpreadLinearOutputUnlock(manager_);
        linearRouter = new WrapperExactOutRouter(manager_);
        SeMatrixFixture.Ctx memory c = _linearContext();
        IFacetRegistry registry = IFacetRegistry(address(c.create3Factory));
        linearFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(c.create3Factory,
            HookFactory.InitArgs(registry.canonicalFacet(type(IERC165).interfaceId), registry.canonicalFacet(type(IDiamondLoupe).interfaceId),
                registry.canonicalFacet(type(IERC8109Introspection).interfaceId), registry.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                HookFactoryService.deployUniswapV4HookFlagsFacet(c.create3Factory)));
        vm.prank(c.owner);
        IVaultRegistryDeployment(address(c.indexedexManager)).setHookDiamondPackageFactory(address(linearFactory));
        (, , uint256 other) = _backing(address(this));
        assertEq(other, 0, "genuine zero opposing backing");
        assertGt(asset_.balanceOf(vault_), 0, "positive actual local cover");
    }

    /// @notice Single CP: positive linear output, short cover, and share-budget drain rejection.
    function test_linearOutput_singleCp() public { _exercise(Amm.Family.SingleCp); }
    /// @notice Dual: the input is an admitted funded identity wrapper, output is one-backed H/P.
    function test_linearOutput_dualCp() public { _exercise(Amm.Family.Dual); }
    /// @notice Weighted: retain rounded-up rated output debit and native share budget.
    function test_linearOutput_weighted() public { _exercise(Amm.Family.Weighted); }
    /// @notice Orbital: retain its one-share spendable reserve floor.
    function test_linearOutput_orbital() public { _prepareOrbitalBook(); _exercise(Amm.Family.Orbital); }
    /// @notice Curve Quad: executable output quantities do not waive local cover.
    function test_linearOutput_curveQuad() public { _exercise(Amm.Family.CurveQuad); }
    /// @notice Balancer Quad: executable output quantities do not waive holder cash.
    function test_linearOutput_balancerQuad() public { _exercise(Amm.Family.BalancerQuad); }

    function _backing(address holder) private view returns (Shapes.Snapshot memory q, uint256 backing, uint256 other) {
        (bytes memory state,) = Transition(linearVault).quoteState(address(linearAsset), holder);
        state = IStandardExchangeUnlockContextQuote(linearVault).quoteStateWithUnavailableUnlock(state, address(linearManager));
        return Reference.backing(state);
    }

    function _quantity(address holder, uint256 assets) private view returns (uint256) {
        (bytes memory state,) = Transition(linearVault).quoteState(address(linearAsset), holder);
        state = IStandardExchangeUnlockContextQuote(linearVault).quoteStateWithUnavailableUnlock(state, address(linearManager));
        return Quantity(linearVault).quoteSharesForExactAssets(state, assets);
    }

    function _deployLinear(Amm.Family family) private returns (Amm.Fixture memory f) {
        Amm.Request memory r;
        r.c = _linearContext(); r.factory = linearFactory; r.manager = address(linearManager);
        r.vault = linearVault; r.face = address(linearAsset); r.owner = address(linearDriver);
        // 9 + the real wrapper's 10-decimal offset is an admitted 19-decimal identity.
        // It keeps this extreme-price fixture's actual router input within int128.
        r.identityAssetDecimals = 9;
        f = Amm.deploy(family, r);
        (Shapes.Snapshot memory q, uint256 backing, uint256 other) = _backing(address(this));
        assertEq(other, 0);
        uint256 forCover = Math.mulDiv(linearAsset.balanceOf(linearVault) + 1, q.supply, backing, Math.Rounding.Ceil);
        uint256 shares = (forCover + 1) * 100 + 100;
        assertLt(shares, IERC20(linearVault).balanceOf(address(this)), "actually owned seed shares");
        // Price every raw seed in the same whole-token units as the one-backed inventory.
        uint256 faceValue = Math.mulDiv(shares, backing, q.supply, Math.Rounding.Ceil);
        uint256 faceUnit = 10 ** uint256(IERC20Metadata(address(linearAsset)).decimals());
        if (family == Amm.Family.Orbital) {
            // Three balanced WAD reserves at this bound have product <= 1e75.
            // Preserve Orbital's fee-on kLast path instead of disabling its arithmetic.
            assertLe(Math.mulDiv(faceValue, 1e18, faceUnit, Math.Rounding.Ceil), 1e25, "Orbital balanced cubic range");
        }
        for (uint256 i; i < f.tokens.length; ++i) {
            if (f.tokens[i] == address(linearAsset)) continue;
            uint256 amount = Math.mulDiv(faceValue, 10 ** uint256(IERC20Metadata(f.tokens[i]).decimals()), faceUnit, Math.Rounding.Ceil);
            f.amounts[i] = amount;
            Amm.fundInventory(f, f.tokens[i], address(linearDriver), amount);
            Amm.fundInventory(f, f.tokens[i], address(this), amount);
        }
        IERC20(linearVault).transfer(address(linearDriver), shares);
        vm.startPrank(address(linearDriver));
        IERC20(linearVault).approve(f.hook, shares);
        for (uint256 i; i < f.tokens.length; ++i) if (f.tokens[i] != address(linearAsset)) IERC20(f.tokens[i]).approve(f.hook, type(uint256).max);
        vm.stopPrank();
        bytes memory seedCall = Amm.shareSeedCall(family, f, address(linearAsset), shares, address(linearDriver));
        if (family == Amm.Family.BalancerQuad) {
            // First-mint denomination uses an executable SE redemption preview.
            // No SE is redeemed by this share-funded join, so initialize while idle;
            // only the later money-path tests deliberately make unlock unavailable.
            vm.prank(address(linearDriver));
            (bool ok, bytes memory result) = f.hook.call(seedCall);
            if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        } else linearDriver.run(f.hook, seedCall);
        assertEq(IERC20(linearVault).balanceOf(f.hook), shares, "hook holds delivered seed shares");
        assertGt(IERC20(f.hook).totalSupply(), 0);
        IERC20(f.output).approve(address(linearRouter), type(uint256).max);
    }

    function _key(Amm.Fixture memory f, Amm.Family family) private view returns (PoolKey memory key) {
        key = PairPool.pairKey(f.output, address(linearAsset), f.spacing, IHooks(f.hook));
        if (family == Amm.Family.SingleCp || family == Amm.Family.Dual) key.fee = 0;
    }

    function _exercise(Amm.Family family) private {
        Amm.Fixture memory f = _deployLinear(family);
        PoolKey memory key = _key(f, family);
        uint256 baseline = vm.snapshotState();
        _positive(f, key);
        assertTrue(vm.revertToState(baseline));
        _shortCover(f, key);
        _shortHeldShares(f, key, family);
    }

    struct Observation { uint256 input; uint256 output; uint256 held; uint256 supply; uint256 cover; }

    function _positive(Amm.Fixture memory f, PoolKey memory key) private {
        uint256 wanted = 1;
        (Shapes.Snapshot memory q, uint256 backing, uint256 other) = _backing(f.hook);
        assertEq(other, 0);
        uint256 expectedShares = Math.mulDiv(wanted, q.supply, backing, Math.Rounding.Ceil);
        assertGt(expectedShares, 0); assertLt(expectedShares, IERC20(linearVault).balanceOf(f.hook));
        assertEq(_quantity(f.hook, wanted), expectedShares);
        uint256 quote = IUniswapV4SeBufferHook(f.hook).previewSwapExactOut(f.output, address(linearAsset), wanted);
        assertGt(quote, 0);
        uint256 blocked = abi.decode(linearDriver.run(f.hook, abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactOut,
            (f.output, address(linearAsset), wanted))), (uint256));
        assertEq(quote, blocked, "idle projected EO equals actual blocked EO");
        Observation memory beforeState = _observe(f);
        bool zfo = f.output == Currency.unwrap(key.currency0);
        linearRouter.swapExactOut(key, SwapParams(zfo, int256(wanted), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), quote, "");
        assertEq(IERC20(f.output).balanceOf(address(this)), beforeState.input - quote);
        assertEq(linearAsset.balanceOf(address(this)), beforeState.output + wanted);
        assertEq(IERC20(linearVault).balanceOf(f.hook), beforeState.held - expectedShares, "independent linear share debit");
        assertEq(IERC20(linearVault).totalSupply(), beforeState.supply - expectedShares);
        assertEq(linearAsset.balanceOf(linearVault), beforeState.cover - wanted);
        assertEq(IBasicVault(linearVault).reserveOfToken(address(linearAsset)), linearAsset.balanceOf(linearVault));
        _flat(f);
    }

    function _observe(Amm.Fixture memory f) private view returns (Observation memory o) {
        o.input = IERC20(f.output).balanceOf(address(this)); o.output = linearAsset.balanceOf(address(this));
        o.held = IERC20(linearVault).balanceOf(f.hook); o.supply = IERC20(linearVault).totalSupply();
        o.cover = linearAsset.balanceOf(linearVault);
    }

    function _shortCover(Amm.Fixture memory f, PoolKey memory key) private {
        uint256 available = linearAsset.balanceOf(linearVault);
        uint256 wanted = available + 1;
        (Shapes.Snapshot memory q, uint256 backing, uint256 other) = _backing(f.hook);
        assertEq(other, 0); assertGe(backing, wanted);
        uint256 needed = Math.mulDiv(wanted, q.supply, backing, Math.Rounding.Ceil);
        assertEq(_quantity(f.hook, wanted), needed, "formula remains eligible despite short cover");
        assertLt(needed, IERC20(linearVault).balanceOf(f.hook), "cover failure is not a held-share failure");
        bytes memory reason = abi.encodeWithSignature("UniswapV4Exchange_InsufficientLocalReserve(address,uint256,uint256)", address(linearAsset), wanted, available);
        _reject(f, key, wanted, reason);
    }

    function _shortHeldShares(Amm.Fixture memory f, PoolKey memory key, Amm.Family family) private {
        (, uint256 oldBacking,) = _backing(f.hook);
        // Real selected-token donation supplies ample local cover without adding an opposing leg.
        uint256 donation = oldBacking / 100;
        assertGt(donation, 0); assertGe(linearAsset.balanceOf(address(this)), donation);
        linearAsset.transfer(linearVault, donation);
        (Shapes.Snapshot memory q, uint256 backing, uint256 other) = _backing(f.hook);
        assertEq(other, 0);
        uint256 held = IERC20(linearVault).balanceOf(f.hook);
        uint256 wanted = Math.mulDiv(held - 1, backing, q.supply) + 1;
        assertEq(Math.mulDiv(wanted, q.supply, backing, Math.Rounding.Ceil), held, "would spend the entire held share budget");
        assertLe(wanted, linearAsset.balanceOf(linearVault), "local cover independently sufficient");
        bytes memory reason = family == Amm.Family.Orbital ? abi.encodeWithSignature("Drain()")
            : family == Amm.Family.SingleCp || family == Amm.Family.Dual
                ? abi.encodeWithSignature("InsufficientTokenOut()") : abi.encodeWithSignature("WouldZeroReserve()");
        _reject(f, key, wanted, reason);
        wanted = Math.mulDiv(held, backing, q.supply) + 1;
        uint256 required = Math.mulDiv(wanted, q.supply, backing, Math.Rounding.Ceil);
        assertEq(required, held + 1, "requires one more share than the hook owns");
        assertEq(_quantity(f.hook, wanted), required, "quantity does not invent holder shares");
        assertLe(wanted, linearAsset.balanceOf(linearVault), "held shortage has enough asset cover");
        // The projected holder transition reports its precise share shortage. In a
        // live blocked quote the ordinary quantity preview reaches the hook's own cap.
        _rejectWithReasons(f, key, wanted,
            abi.encodeWithSelector(Transition.InsufficientQuoteShares.selector, required, held), reason);
    }

    function _reject(Amm.Fixture memory f, PoolKey memory key, uint256 wanted, bytes memory reason) private {
        _rejectWithReasons(f, key, wanted, reason, reason);
    }

    function _rejectWithReasons(Amm.Fixture memory f, PoolKey memory key, uint256 wanted, bytes memory idleReason, bytes memory reason) private {
        bytes32 beforeState = _fingerprint(f);
        vm.expectRevert(idleReason);
        IUniswapV4SeBufferHook(f.hook).previewSwapExactOut(f.output, address(linearAsset), wanted);
        vm.expectRevert(reason);
        linearDriver.run(f.hook, abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactOut, (f.output, address(linearAsset), wanted)));
        bool zfo = f.output == Currency.unwrap(key.currency0);
        vm.expectRevert(abi.encodeWithSelector(CustomRevert.WrappedError.selector, f.hook, IHooks.beforeSwap.selector,
            reason, abi.encodePacked(Hooks.HookCallFailed.selector)));
        // Fund the router before the hook rejects; the domain/cover failure must precede take.
        linearRouter.swapExactOut(key, SwapParams(zfo, int256(wanted), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), 1, "");
        assertEq(_fingerprint(f), beforeState, "failed EO preserves custody, book and approvals");
        _flat(f);
    }

    function _fingerprint(Amm.Fixture memory f) private view returns (bytes32 digest) {
        (uint256 d0, uint256 d1) = Reserve(linearVault).deployedReserve();
        digest = keccak256(abi.encode(_observe(f), d0, d1, opposingAsset.balanceOf(linearVault),
            IBasicVault(linearVault).reserveOfToken(address(linearAsset)), IBasicVault(linearVault).reserveOfToken(address(opposingAsset))));
        for (uint256 i; i < f.tokens.length; ++i) {
            IERC20 token = IERC20(f.tokens[i]);
            bytes32 custody = keccak256(abi.encode(token.balanceOf(f.hook), token.balanceOf(address(linearManager)), token.balanceOf(address(linearRouter))));
            digest = keccak256(abi.encode(digest, custody, IBasicVault(f.hook).reserveOfToken(f.tokens[i]), token.allowance(f.hook, linearVault), token.allowance(address(this), address(linearRouter))));
        }
    }

    function _flat(Amm.Fixture memory f) private view {
        assertFalse(TransientStateLibrary.isUnlocked(linearManager));
        assertEq(TransientStateLibrary.getNonzeroDeltaCount(linearManager), 0);
        assertEq(IERC20(linearVault).allowance(f.hook, linearVault), 0);
        for (uint256 i; i < f.tokens.length; ++i) {
            Currency currency = Currency.wrap(f.tokens[i]);
            assertEq(TransientStateLibrary.currencyDelta(linearManager, f.hook, currency), 0);
            assertEq(TransientStateLibrary.currencyDelta(linearManager, address(linearRouter), currency), 0);
            assertEq(IERC20(f.tokens[i]).allowance(f.hook, linearVault), 0);
        }
    }

    /// @notice A foreign unavailable manager retains the ordinary idle EO result or exact domain error.
    function test_linearOutput_foreignContextIsOrdinary() public {
        assertEq(ContextQuote.exactOutputState(linearVault, address(linearAsset), address(linearDriver)), bytes(""));
        (bool expectedOk, bytes memory expected) = linearVault.staticcall(abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
            (IERC20(linearVault), linearAsset, 1)));
        if (expectedOk) assertEq(ContextQuote.withdrawFromState(linearVault, address(linearAsset), 1, bytes("")), abi.decode(expected, (uint256)));
        else {
            vm.expectRevert(expected);
            ContextQuote.withdrawFromState(linearVault, address(linearAsset), 1, bytes(""));
        }
    }

    /// @dev Real 18-decimal assets make one raw SE share affordable in WAD units at
    /// the boundary. Small raw genesis liquidity keeps the boundary swap in int128.
    function _orbitalAssets() internal returns (IERC20 a, IERC20 b) {
        a = IERC20(address(new ERC20PermitMintableStub("Orbital linear A", "OLA", 18, address(this), 1e39)));
        b = IERC20(address(new ERC20PermitMintableStub("Orbital linear B", "OLB", 18, address(this), 1e39)));
        if (address(b) < address(a)) (a, b) = (b, a);
    }

    function _activateOrbitalBook(address exchange, IERC20 aToken, IERC20 bToken) internal {
        (uint256 amount0, uint256 amount1) = _orbitalBasket();
        address[] memory tokens = new address[](2); tokens[0] = address(aToken); tokens[1] = address(bToken);
        uint256[] memory amounts = new uint256[](2); amounts[0] = amount0; amounts[1] = amount1;
        aToken.approve(exchange, type(uint256).max); bToken.approve(exchange, type(uint256).max);
        uint256 issued = IStandardExchangeInMulti(exchange).exchangeInManyToOne(tokens, amounts, IERC20(exchange), 0, address(this), false, block.timestamp);
        assertGt(issued, 0);
        assertEq(bToken.balanceOf(exchange), 0, "funded placement consumes opposing sleeve");
    }

    function _orbitalBasket() private pure returns (uint256 amount0, uint256 amount1) {
        uint160 q = TickMath.getSqrtPriceAtTick(-60);
        uint160 a = TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(10));
        uint160 b = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(10));
        // The same funded-basket stencil as the accepted P one-backed reference,
        // now starting at one whole 18-decimal token (above its 1e15 minimum shares).
        for (uint256 i; i < 10_000; ++i) {
            amount1 = 1e18 + i;
            uint128 liquidity = uint128(amount1 * (uint256(1) << 96) / (q - a));
            amount0 = SqrtPriceMath.getAmount0Delta(q, b, liquidity, true);
            uint128 target = LiquidityAmounts.getLiquidityForAmounts(q, a, b, amount0, amount1);
            if (target > 0 && SqrtPriceMath.getAmount1Delta(a, q, target - 1, true) == amount1) break;
            if (i == 9_999) revert("no exact orbital basket");
        }
    }
}

/// @notice H one-backed book reached only through funded activation, a real swap and placement.
contract HooklessSameManagerLinearOutputTest is HAcceptance, FullSpreadLinearOutputAssertions {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }
    function _tickSpacing() internal pure override returns (int24) { return 10; }
    function setUp() public override {
        HAcceptance.setUp();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(Reserve).interfaceId, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0);
        vm.stopPrank();
        _bootstrap(); _externalSwap(true, 5e31); Reserve(address(vault)).rebalanceLiquidReserve();
        _configureLinear(poolManager, address(vault), token0, token1);
    }
    function _linearContext() internal view override returns (SeMatrixFixture.Ctx memory c) {
        c.create3Factory = create3Factory; c.indexedexManager = indexedexManager; c.owner = owner;
        c.erc20Facet = erc20Facet; c.erc5267Facet = erc5267Facet; c.erc2612Facet = erc2612Facet;
        c.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet; c.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
    }

    function _prepareOrbitalBook() internal override {
        (token0, token1) = _orbitalAssets();
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3_000, 10, IHooks(address(0)));
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(-60));
        _seedPool(1e18);
        address exchange = address(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        _activateOrbitalBook(exchange, token0, token1);
        _externalSwap(true, 5e37);
        Reserve(exchange).rebalanceLiquidReserve();
        _configureLinear(poolManager, exchange, token0, token1);
    }
}

/// @notice Genuine Pons launch with the same integer-funded basket as its accepted one-backed reference.
contract PonsSameManagerLinearOutputTest is PAcceptance, FullSpreadLinearOutputAssertions {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }
    function _tickSpacing() internal pure override returns (int24) { return 10; }
    function _initialPrice() internal pure override returns (uint160) { return TickMath.getSqrtPriceAtTick(-60); }
    function setUp() public override {
        PAcceptance.setUp();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(Reserve).interfaceId, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0);
        vm.stopPrank();
        _activateOneBackedReference(); _externalSwap(true, 5e31); Reserve(address(vault)).rebalanceLiquidReserve();
        _configureLinear(poolManager, address(vault), token0, token1);
    }
    function _activateOneBackedReference() private {
        uint160 q = _initialPrice();
        uint160 a = TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(_tickSpacing()));
        uint160 b = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(_tickSpacing()));
        uint256 amount0; uint256 amount1;
        for (uint256 i; i < 10_000; ++i) {
            amount1 = 1_000 * unit1 + i;
            uint128 liquidity = uint128(amount1 * (uint256(1) << 96) / (q - a));
            amount0 = SqrtPriceMath.getAmount0Delta(q, b, liquidity, true);
            uint128 target = LiquidityAmounts.getLiquidityForAmounts(q, a, b, amount0, amount1);
            if (target > 0 && SqrtPriceMath.getAmount1Delta(a, q, target - 1, true) == amount1) break;
            if (i == 9_999) revert("no exact fixture basket");
        }
        uint256 issued = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            _tokens(), _amounts(amount0, amount1), IERC20(address(vault)), 0, address(this), false, block.timestamp);
        assertGt(issued, 0); assertEq(token1.balanceOf(address(vault)), 0); _assertBooked();
    }
    function _linearContext() internal view override returns (SeMatrixFixture.Ctx memory c) {
        c.create3Factory = create3Factory; c.indexedexManager = indexedexManager; c.owner = owner;
        c.erc20Facet = erc20Facet; c.erc5267Facet = erc5267Facet; c.erc2612Facet = erc2612Facet;
        c.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet; c.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
    }

    function _prepareOrbitalBook() internal override {
        (token0, token1) = _orbitalAssets();
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 0, 10, IHooks(address(ponsHook)));
        ponsHook.registerPool(poolKey, address(token1), address(this), address(this),
            _creatorTaxBps(), false, ponsHook.currentFeePolicy());
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(-60));
        _seedPool(1e18);
        address exchange = address(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        _activateOrbitalBook(exchange, token0, token1);
        _externalSwap(true, 5e37);
        Reserve(exchange).rebalanceLiquidReserve();
        _configureLinear(poolManager, exchange, token0, token1);
    }
}
