// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHook as CpHook} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as CpPackage} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpFactory} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib as CurveInverseClaim} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as BalancerInverseClaim} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {IUniswapV4SingleStandardExchangeBufferHookPackage as WrapperPackage} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {IUniswapV4SingleStandardExchangeBufferHook as Wrapper} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol";
import {UniswapV4SingleStandardExchangeBufferHook_FactoryService as WrapperFactory} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {FullSpreadSameManagerWeightedFixture as WeightedFixture} from "./FullSpreadSameManagerWeightedFixture.sol";
import {FullSpreadSameManagerAmmFixture as AmmFixture} from "./FullSpreadSameManagerAmmFixture.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as WeightedHook} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as WeightedPair} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as HAcceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as PAcceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";

/// @dev A real outer-unlock caller for mode-correct previews; never impersonates the manager.
contract FullSpreadConsumerUnlock is IUnlockCallback {
    IPoolManager private immutable manager;
    constructor(IPoolManager manager_) { manager = manager_; }
    function run(address target, bytes calldata data) external returns (bytes memory) {
        return manager.unlock(abi.encode(target, data));
    }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager), "manager only");
        (address target, bytes memory callData) = abi.decode(data, (address, bytes));
        (bool ok, bytes memory result) = target.call(callData);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return result;
    }
}

/// @dev Non-custodial capability probe forwarding real H/P snapshots, but not advertising quantities.
contract FullSpreadContextCapabilityProbe {
    address private immutable exchange;
    constructor(address exchange_) { exchange = exchange_; }
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStandardExchangeUnlockContextQuote).interfaceId;
    }
    function quoteState(address pair, address holder) external view returns (bytes memory state, uint256 assets) {
        return Transition(exchange).quoteState(pair, holder);
    }
    function quoteStateWithUnavailableUnlock(bytes calldata state, address manager) external view returns (bytes memory) {
        return IStandardExchangeUnlockContextQuote(exchange).quoteStateWithUnavailableUnlock(state, manager);
    }
}

/// @notice Same-manager production wrapper hooks around both underlying orientations of a real H/P SE.
abstract contract FullSpreadSameManagerAssertions is Test {
    IPoolManager private consumerManager;
    address private consumerVault;
    IERC20[2] private consumerTokens;
    address[2] private consumers;
    PoolKey[2] private consumerKeys;
    WrapperExactOutRouter private consumerRouter;
    FullSpreadConsumerUnlock private driver;
    HookFactory private consumerHookFactory;

    function _consumerContext() internal view virtual returns (SeMatrixFixture.Ctx memory);

    function _configureConsumers(IPoolManager manager_, address vault_, IERC20 a, IERC20 b) internal {
        consumerManager = manager_; consumerVault = vault_; consumerTokens = [a, b];
        consumerRouter = new WrapperExactOutRouter(manager_);
        driver = new FullSpreadConsumerUnlock(manager_);
        SeMatrixFixture.Ctx memory c = _consumerContext();
        IFacetRegistry registry = IFacetRegistry(address(c.create3Factory));
        HookFactory factory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(c.create3Factory,
            HookFactory.InitArgs(registry.canonicalFacet(type(IERC165).interfaceId), registry.canonicalFacet(type(IDiamondLoupe).interfaceId),
                registry.canonicalFacet(type(IERC8109Introspection).interfaceId), registry.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                HookFactoryService.deployUniswapV4HookFlagsFacet(c.create3Factory)));
        consumerHookFactory = factory;
        vm.prank(c.owner);
        IVaultRegistryDeployment(address(c.indexedexManager)).setHookDiamondPackageFactory(address(factory));
        WrapperPackage pkg = WrapperFactory.deployPackage(IVaultRegistryDeployment(address(c.indexedexManager)), c.owner,
            WrapperPackage.PkgInit(IVaultRegistryDeployment(address(c.indexedexManager)), WrapperFactory.deployProductFacet(c.create3Factory),
                c.multiAssetBasicVaultFacet, c.multiAssetStandardVaultFacet));
        for (uint256 i; i < 2; ++i) {
            WrapperPackage.PkgArgs memory args = WrapperPackage.PkgArgs(address(manager_), vault_, address(consumerTokens[i]));
            consumers[i] = WrapperFactory.deployHook(pkg, args, WrapperFactory.findMineNonce(factory, pkg, args));
            IUniswapV4HookStagedPairInit(consumers[i]).deployPair(address(consumerTokens[i]), vault_);
            require(IUniswapV4HookStagedPairInit(consumers[i]).finalizeInitialization(), "finalized");
            Wrapper wrapper = Wrapper(consumers[i]);
            consumerKeys[i] = PoolKey(Currency.wrap(wrapper.currency0()), Currency.wrap(wrapper.currency1()),
                wrapper.poolFee(), wrapper.tickSpacingHint(), IHooks(consumers[i]));
            consumerTokens[i].approve(address(consumerRouter), type(uint256).max);
        }
        IERC20(vault_).approve(address(consumerRouter), type(uint256).max);
    }

    function _params(uint256 i, bool wrap, int256 amount) private view returns (SwapParams memory) {
        bool zfo = (address(consumerTokens[i]) < consumerVault) == wrap;
        return SwapParams(zfo, amount, zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
    }
    function _wrapped(uint256 i, bytes memory reason) private view returns (bytes memory) {
        return abi.encodeWithSelector(CustomRevert.WrappedError.selector, consumers[i], IHooks.beforeSwap.selector,
            reason, abi.encodePacked(Hooks.HookCallFailed.selector));
    }
    function _book() private view returns (bytes32) {
        (uint256 a, uint256 b) = Reserve(consumerVault).deployedReserve();
        return keccak256(abi.encode(IERC20(consumerVault).totalSupply(), IERC20(consumerVault).balanceOf(address(this)),
            consumerTokens[0].balanceOf(consumerVault), consumerTokens[1].balanceOf(consumerVault), a, b));
    }
    function _assertBookedAndFlat(uint256 i) private view {
        for (uint256 j; j < 2; ++j) assertEq(IBasicVault(consumerVault).reserveOfToken(address(consumerTokens[j])), consumerTokens[j].balanceOf(consumerVault));
        assertEq(IERC20(consumerVault).balanceOf(consumers[i]), 0);
        assertEq(consumerTokens[i].balanceOf(consumers[i]), 0);
        assertTrue(Reserve(consumerVault).canOpenPoolManagerUnlock());
    }

    function test_sameManager_fundedEiBothOrientationsAndShareBurnParity() public {
        // Two blocked previews and two executed swaps per bound underlying, exactly eight outer unlocks.
        vm.expectCall(address(consumerManager), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(8));
        for (uint256 i; i < 2; ++i) {
            uint256 amount = 10 ** uint256(IERC20Metadata(address(consumerTokens[i])).decimals());
            uint256 quote = abi.decode(driver.run(consumers[i], abi.encodeCall(Wrapper.previewWrap, (amount))), (uint256));
            assertEq(Wrapper(consumers[i]).previewWrap(amount), quote, "idle PM preview projects blocked input");
            uint256 beforeInput = consumerTokens[i].balanceOf(address(this));
            uint256 beforeShares = IERC20(consumerVault).balanceOf(address(this));
            consumerRouter.swapExactIn(consumerKeys[i], _params(i, true, -int256(amount)), "");
            assertEq(consumerTokens[i].balanceOf(address(this)), beforeInput - amount);
            assertEq(IERC20(consumerVault).balanceOf(address(this)), beforeShares + quote);
            uint256 burn = quote / 2;
            uint256 payout = abi.decode(driver.run(consumers[i], abi.encodeCall(Wrapper.previewUnwrap, (burn))), (uint256));
            assertEq(Wrapper(consumers[i]).previewUnwrap(burn), payout, "idle PM preview projects blocked output");
            uint256 supply = IERC20(consumerVault).totalSupply();
            beforeInput = consumerTokens[i].balanceOf(address(this));
            beforeShares = IERC20(consumerVault).balanceOf(address(this));
            consumerRouter.swapExactIn(consumerKeys[i], _params(i, false, -int256(burn)), "");
            assertEq(consumerTokens[i].balanceOf(address(this)), beforeInput + payout);
            assertEq(IERC20(consumerVault).balanceOf(address(this)), beforeShares - burn);
            assertEq(IERC20(consumerVault).totalSupply(), supply - burn);
            _assertBookedAndFlat(i);
        }
    }

    function test_sameManager_twoLegEoRejectsPrefundedRouterBothOrientations() public {
        vm.expectCall(address(consumerManager), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(4));
        for (uint256 i; i < 2; ++i) {
            bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, consumerVault, address(consumerTokens[i]));
            bytes32 beforeBook = _book();
            vm.expectRevert(reason);
            Wrapper(consumers[i]).previewUnwrapExactOut(1e12);
            vm.expectRevert(reason);
            driver.run(consumers[i], abi.encodeCall(Wrapper.previewUnwrapExactOut, (1e12)));
            uint256 maximum = IERC20(consumerVault).balanceOf(address(this)) / 10;
            vm.expectRevert(_wrapped(i, reason));
            consumerRouter.swapExactOut(consumerKeys[i], _params(i, false, int256(1e12)), maximum, "");
            assertEq(_book(), beforeBook);
            _assertBookedAndFlat(i);
        }
    }

    function test_sameManager_shortageRollsBackWithoutNestedUnlockBothOrientations() public {
        vm.expectCall(address(consumerManager), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(2));
        for (uint256 i; i < 2; ++i) {
            uint256 burn = IERC20(consumerVault).balanceOf(address(this)) / 2;
            uint256 payout = _blockedPayout(i, burn);
            uint256 available = consumerTokens[i].balanceOf(consumerVault);
            assertGt(payout, available);
            bytes memory reason = abi.encodeWithSignature("UniswapV4Exchange_InsufficientLocalReserve(address,uint256,uint256)", address(consumerTokens[i]), payout, available);
            bytes32 beforeBook = _book();
            vm.expectRevert(_wrapped(i, reason));
            consumerRouter.swapExactIn(consumerKeys[i], _params(i, false, -int256(burn)), "");
            assertEq(_book(), beforeBook);
            _assertBookedAndFlat(i);
        }
    }
    function _blockedPayout(uint256 i, uint256 shares) private view returns (uint256) {
        (uint256 d0, uint256 d1) = Reserve(consumerVault).deployedReserve();
        uint256 outBook = consumerTokens[i].balanceOf(consumerVault) + (i == 0 ? d0 : d1);
        uint256 otherBook = consumerTokens[1-i].balanceOf(consumerVault) + (i == 0 ? d1 : d0);
        uint256 supply = IERC20(consumerVault).totalSupply();
        uint256 u = outBook * shares / supply;
        uint256 v = otherBook * shares / supply;
        return u + (outBook-u) * v / otherBook;
    }

    function test_consumer_contextHelperPreservesForeignManagerAndPropagatesDecoderFailure() public {
        (bytes memory state,) = Transition(consumerVault).quoteState(address(consumerTokens[0]), address(0));
        assertEq(ContextQuote.project(consumerVault, state, address(driver)), state, "other manager is unchanged");
        bytes memory malformed = hex"01";
        (bool ok, bytes memory reason) = consumerVault.staticcall(abi.encodeCall(
            IStandardExchangeUnlockContextQuote.quoteStateWithUnavailableUnlock, (malformed, address(consumerManager))));
        assertFalse(ok);
        vm.expectRevert(reason);
        ContextQuote.project(consumerVault, malformed, address(consumerManager));
    }

    /// @notice Empty projection is not evidence of legacy capability: H/P remain strict while idle.
    function test_consumer_contextCapabilityKeepsIdleInverseStrict() public {
        assertTrue(ContextQuote.supported(consumerVault));
        for (uint256 i; i < 2; ++i) {
            assertEq(ContextQuote.exactOutputState(consumerVault, address(consumerTokens[i]), address(driver)), bytes(""));
            bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(consumerTokens[i]), consumerVault);
            vm.expectRevert(reason);
            CurveInverseClaim.invertBufferExactSharesOut(consumerVault, address(consumerTokens[i]), 1);
            vm.expectRevert(reason);
            BalancerInverseClaim.invertBufferExactSharesOut(consumerVault, address(consumerTokens[i]), 1);
        }
    }

    /// @notice Projection and exact-output quantities are separate capabilities.
    function test_consumer_exactOutputContextRequiresQuantityCapability() public {
        FullSpreadContextCapabilityProbe probe = new FullSpreadContextCapabilityProbe(consumerVault);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        ContextQuote.exactOutputState(address(probe), address(consumerTokens[0]), address(consumerManager));
        assertEq(ContextQuote.exactOutputState(consumerVault, address(consumerTokens[0]), address(driver)), bytes(""));
        assertEq(ContextQuote.exactOutputState(consumerVault, address(consumerTokens[0]), address(0)), bytes(""));
        bytes memory projected = ContextQuote.exactOutputState(consumerVault, address(consumerTokens[0]), address(consumerManager));
        (bytes memory blocked,) = abi.decode(driver.run(consumerVault,
            abi.encodeCall(Transition.quoteState, (address(consumerTokens[0]), address(this)))), (bytes, uint256));
        assertEq(projected, blocked, "opaque projected state equals actual blocked state");
    }

    function test_sameManager_blockedExactShareMintRemainsSupported() public {
        for (uint256 i; i < 2; ++i) {
            uint256 desired = IERC20(consumerVault).totalSupply() / 10_000;
            uint256 quote = abi.decode(driver.run(consumers[i], abi.encodeCall(Wrapper.previewWrapExactOut, (desired))), (uint256));
            assertEq(Wrapper(consumers[i]).previewWrapExactOut(desired), quote, "idle wrapper EO projects blocked input");
            uint256 beforeInput = consumerTokens[i].balanceOf(address(this));
            uint256 beforeShares = IERC20(consumerVault).balanceOf(address(this));
            consumerRouter.swapExactOut(consumerKeys[i], _params(i, true, int256(desired)), quote, "");
            assertEq(consumerTokens[i].balanceOf(address(this)), beforeInput - quote);
            assertEq(IERC20(consumerVault).balanceOf(address(this)), beforeShares + desired);
            _assertBookedAndFlat(i);
        }
    }

    function _deployOwnerCp(uint256 i, IERC20 raw) private returns (address hook) {
        return _deployOwnerCpOnManager(i, raw, consumerManager);
    }

    function _deployOwnerCpOnManager(uint256 i, IERC20 raw, IPoolManager manager_) private returns (address hook) {
        SeMatrixFixture.Ctx memory c = _consumerContext();
        CpPackage.PkgInit memory init;
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.seFacet = CpFactory.deploySeFacet(c.create3Factory);
        init.depositFacet = CpFactory.deployDepositFacet(c.create3Factory);
        init.depositSingleFacet = CpFactory.deployDepositSingleFacet(c.create3Factory);
        init.depositPreviewFacet = CpFactory.deployDepositPreviewFacet(c.create3Factory);
        init.withdrawFacet = CpFactory.deployWithdrawFacet(c.create3Factory);
        init.erc20Facet = c.erc20Facet; init.erc5267Facet = c.erc5267Facet; init.erc2612Facet = c.erc2612Facet;
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet; init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        init.multiStepOwnableFacet = IFacetRegistry(address(c.create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        CpPackage pkg = CpFactory.deployPackage(init.vaultRegistryDeployment, c.owner, init);
        CpPackage.PkgArgs memory args;
        args.poolManager = address(manager_); args.feeOracle = address(c.indexedexManager);
        args.standardExchange = consumerVault; args.pairToken = address(consumerTokens[i]); args.rawToken = address(raw);
        args.pairTokenDecimals = IERC20Metadata(args.pairToken).decimals(); args.rawTokenDecimals = 18;
        args.ownerOnlyLiquidity = true; args.owner = address(driver);
        args.rateProvider = RateProviderFixtureLib.providerForCp(c.create3Factory, c.create3Factory.diamondPackageFactory(), consumerVault, args.pairToken);
        hook = CpFactory.deployHook(pkg, args, CpFactory.findMineNonce(consumerHookFactory, pkg, args));
        IUniswapV4HookStagedPairInit(hook).deployPair(args.pairToken, args.rawToken);
        require(IUniswapV4HookStagedPairInit(hook).finalizeInitialization(), "CP finalized");
    }

    function test_sameManager_realOwnerEiBothDirectionsBothUnderlyingFaces() public {
        for (uint256 i; i < 2; ++i) {
            SimpleMintableERC20 raw = new SimpleMintableERC20("Consumer Raw", "CRAW");
            address hook = _deployOwnerCp(i, IERC20(address(raw)));
            uint256 seedShares = IERC20(consumerVault).balanceOf(address(this)) / 20;
            raw.mint(address(driver), 1_000 ether);
            raw.mint(address(this), 100 ether);
            raw.approve(address(consumerRouter), type(uint256).max);
            IERC20(consumerVault).transfer(address(driver), seedShares);
            consumerTokens[i].transfer(address(driver), 10 ** (uint256(IERC20Metadata(address(consumerTokens[i])).decimals()) + 2));
            vm.startPrank(address(driver));
            raw.approve(hook, type(uint256).max);
            consumerTokens[i].approve(hook, type(uint256).max);
            IERC20(consumerVault).approve(hook, type(uint256).max);
            vm.stopPrank();
            driver.run(hook, abi.encodeCall(CpHook.depositWithSeShares, (100 ether, seedShares, address(driver), 0, block.timestamp)));
            for (uint256 mode; mode < 3; ++mode) {
                _consumerSwap(hook, IERC20(address(raw)), consumerTokens[i], 1e15, mode);
                _consumerSwap(hook, consumerTokens[i], IERC20(address(raw)), 10 ** uint256(IERC20Metadata(address(consumerTokens[i])).decimals()) / 1_000, mode);
            }
            _ownerExactOutput(hook, IERC20(address(raw)), consumerTokens[i]);
        }
    }

    struct SwapObservation {
        uint256 quote;
        uint256 input;
        uint256 output;
        uint256 shares;
        uint256 supply;
    }
    function _consumerSwap(address hook, IERC20 input, IERC20 output, uint256 amount, uint256 mode) private {
        SwapObservation memory beforeState;
        beforeState.quote = abi.decode(driver.run(hook, abi.encodeWithSignature("previewSwapExactIn(address,address,uint256)", address(input), address(output), amount)), (uint256));
        if (mode == 2) assertEq(IUniswapV4SeBufferHook(hook).previewSwapExactIn(address(input), address(output), amount), beforeState.quote,
            "idle CP PM preview equals in-session quote");
        address actor = mode == 2 ? address(this) : address(driver);
        beforeState.output = output.balanceOf(actor);
        beforeState.input = input.balanceOf(actor);
        beforeState.shares = IERC20(consumerVault).balanceOf(hook);
        beforeState.supply = IERC20(consumerVault).totalSupply();
        uint256 paid;
        if (mode == 0) paid = abi.decode(driver.run(hook, abi.encodeCall(IUniswapV4SeBufferHook.ownerSwapExactIn,
            (address(input), address(output), amount, beforeState.quote, block.timestamp))), (uint256));
        else if (mode == 1) paid = abi.decode(driver.run(hook, abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (input, amount, output, beforeState.quote, actor, false, block.timestamp))), (uint256));
        else {
            PoolKey memory key = PoolKey(Currency.wrap(CpHook(hook).currency0()), Currency.wrap(CpHook(hook).currency1()), 0, 60, IHooks(hook));
            bool zfo = address(input) == Currency.unwrap(key.currency0);
            consumerRouter.swapExactIn(key, SwapParams(zfo, -int256(amount), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
            paid = output.balanceOf(actor) - beforeState.output;
        }
        assertEq(paid, beforeState.quote);
        assertEq(output.balanceOf(actor), beforeState.output + paid);
        assertEq(input.balanceOf(actor), beforeState.input - amount);
        if (address(output) == address(consumerTokens[0]) || address(output) == address(consumerTokens[1])) {
            uint256 spent = beforeState.shares - IERC20(consumerVault).balanceOf(hook);
            assertGt(spent, 0);
            assertLt(spent, beforeState.shares);
            assertEq(beforeState.supply - IERC20(consumerVault).totalSupply(), spent);
        }
        assertEq(IERC20(consumerVault).allowance(hook, consumerVault), 0);
    }

    function _ownerExactOutput(address hook, IERC20 raw, IERC20 pair) private {
        _ownerTwoLegReject(hook, raw, pair);
        // The opposite route has raw output and a funded blocked F1 input inverse.
        uint256 wanted = 1e12;
        SwapObservation memory beforeState;
        beforeState.quote = abi.decode(driver.run(hook, abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactOut,
            (address(pair), address(raw), wanted))), (uint256));
        assertEq(IUniswapV4SeBufferHook(hook).previewSwapExactOut(address(pair), address(raw), wanted), beforeState.quote,
            "idle CP PM EO equals blocked quote");
        assertEq(CpHook(hook).previewSwapExactOut(address(pair) == CpHook(hook).currency0(), wanted), beforeState.quote,
            "both PM EO overloads agree");
        _idleOwnerInverseReject(hook, pair, raw, wanted, beforeState.quote);
        uint256 snapshot = vm.snapshotState();
        beforeState.input = pair.balanceOf(address(driver));
        beforeState.output = raw.balanceOf(address(driver));
        uint256 used = abi.decode(driver.run(hook, abi.encodeCall(IUniswapV4SeBufferHook.ownerSwapExactOut,
            (address(pair), address(raw), wanted, beforeState.quote, block.timestamp))), (uint256));
        assertEq(used, beforeState.quote);
        assertEq(pair.balanceOf(address(driver)), beforeState.input - used);
        assertEq(raw.balanceOf(address(driver)), beforeState.output + wanted);
        assertTrue(vm.revertToState(snapshot));
        _cpRouterExactOutput(hook, pair, raw, wanted, beforeState.quote);
    }

    function _ownerTwoLegReject(address hook, IERC20 raw, IERC20 pair) private {
        bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, consumerVault, address(pair));
        uint256 held = IERC20(consumerVault).balanceOf(hook);
        uint256 rawBefore = raw.balanceOf(address(driver));
        vm.expectRevert(reason);
        IUniswapV4SeBufferHook(hook).previewSwapExactOut(address(raw), address(pair), 1);
        vm.expectRevert(reason);
        driver.run(hook, abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactOut, (address(raw), address(pair), 1)));
        vm.expectRevert(reason);
        driver.run(hook, abi.encodeCall(IUniswapV4SeBufferHook.ownerSwapExactOut, (address(raw), address(pair), 1, 1 ether, block.timestamp)));
        assertEq(IERC20(consumerVault).balanceOf(hook), held);
        assertEq(raw.balanceOf(address(driver)), rawBefore);
    }

    function _idleOwnerInverseReject(address hook, IERC20 pair, IERC20 raw, uint256 wanted, uint256 quote) private {
        bytes memory idleReason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(pair), consumerVault);
        vm.expectRevert(idleReason);
        IStandardExchangeOut(hook).previewExchangeOut(pair, raw, wanted);
        vm.prank(address(driver));
        vm.expectRevert(idleReason);
        IUniswapV4SeBufferHook(hook).ownerSwapExactOut(address(pair), address(raw), wanted, quote, block.timestamp);
    }

    function _cpRouterExactOutput(address hook, IERC20 pair, IERC20 raw, uint256 wanted, uint256 quote) private {
        SwapObservation memory beforeState;
        beforeState.input = pair.balanceOf(address(this));
        beforeState.output = raw.balanceOf(address(this));
        beforeState.shares = IERC20(consumerVault).balanceOf(hook);
        beforeState.supply = IERC20(consumerVault).totalSupply();
        PoolKey memory key = PoolKey(Currency.wrap(CpHook(hook).currency0()), Currency.wrap(CpHook(hook).currency1()), 0, 60, IHooks(hook));
        bool zfo = address(pair) == Currency.unwrap(key.currency0);
        consumerRouter.swapExactOut(key, SwapParams(zfo, int256(wanted), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), quote, "");
        assertEq(pair.balanceOf(address(this)), beforeState.input - quote, "router spends idle quote exactly");
        assertEq(raw.balanceOf(address(this)), beforeState.output + wanted, "exact requested payout");
        uint256 minted = IERC20(consumerVault).balanceOf(hook) - beforeState.shares;
        assertGt(minted, 0);
        assertEq(IERC20(consumerVault).totalSupply(), beforeState.supply + minted);
        assertEq(pair.allowance(hook, consumerVault), 0);
        for (uint256 j; j < 2; ++j) assertEq(IBasicVault(consumerVault).reserveOfToken(address(consumerTokens[j])), consumerTokens[j].balanceOf(consumerVault));
        assertTrue(Reserve(consumerVault).canOpenPoolManagerUnlock());
        _cpRouterTwoLegReject(hook, raw, pair, key);
    }

    function _cpRouterTwoLegReject(address hook, IERC20 raw, IERC20 pair, PoolKey memory key) private {
        bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, consumerVault, address(pair));
        bytes32 beforeBook = _book();
        uint256 shares = IERC20(consumerVault).balanceOf(hook);
        uint256 beforeRaw = raw.balanceOf(address(this));
        bool zfo = address(raw) == Currency.unwrap(key.currency0);
        vm.expectRevert(abi.encodeWithSelector(CustomRevert.WrappedError.selector, hook, IHooks.beforeSwap.selector,
            reason, abi.encodePacked(Hooks.HookCallFailed.selector)));
        consumerRouter.swapExactOut(key, SwapParams(zfo, 1, zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), 1e12, "");
        assertEq(_book(), beforeBook);
        assertEq(IERC20(consumerVault).balanceOf(hook), shares);
        assertEq(raw.balanceOf(address(this)), beforeRaw);
    }

    /// @notice The linked weighted EO coordinator quotes both H/P orientations before the unlock.
    function test_sameManager_weightedIdleExactOutputMatchesRouter() public {
        for (uint256 i; i < 2; ++i) {
            SimpleMintableERC20 raw = new SimpleMintableERC20("Weighted Raw", "WRAW");
            IERC20 pair = consumerTokens[i];
            address hook = WeightedFixture.deploy(_consumerContext(), address(consumerManager), consumerVault,
                address(pair), address(raw), address(driver));
            raw.mint(address(driver), 100 ether);
            raw.mint(address(this), 1 ether);
            raw.approve(address(consumerRouter), type(uint256).max);
            uint256 pairSeed = 10 ** uint256(IERC20Metadata(address(pair)).decimals());
            pair.transfer(address(driver), pairSeed);
            vm.startPrank(address(driver));
            raw.approve(hook, type(uint256).max);
            pair.approve(hook, type(uint256).max);
            vm.stopPrank();
            uint256[] memory amounts = new uint256[](2);
            amounts[address(pair) < address(raw) ? 0 : 1] = pairSeed;
            amounts[address(pair) < address(raw) ? 1 : 0] = 100 ether;
            driver.run(hook, abi.encodeCall(WeightedHook.joinProportional, (amounts, address(driver), 0, block.timestamp)));
            _weightedExactOutput(hook, pair, IERC20(address(raw)));
        }
    }

    function _weightedExactOutput(address hook, IERC20 pair, IERC20 raw) private {
        uint256 wanted = 1e12;
        uint256 quote = IUniswapV4SeBufferHook(hook).previewSwapExactOut(address(pair), address(raw), wanted);
        assertGt(quote, 0);
        assertEq(quote, abi.decode(driver.run(hook, abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactOut,
            (address(pair), address(raw), wanted))), (uint256)), "weighted idle/blocked EO");
        bytes memory idleReason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(pair), consumerVault);
        vm.expectRevert(idleReason);
        IStandardExchangeOut(hook).previewExchangeOut(pair, raw, wanted);
        uint256 beforeInput = pair.balanceOf(address(this));
        uint256 beforeOutput = raw.balanceOf(address(this));
        PoolKey memory key = WeightedPair.pairKey(address(pair), address(raw), 1, IHooks(hook));
        bool zfo = address(pair) == Currency.unwrap(key.currency0);
        consumerRouter.swapExactOut(key, SwapParams(zfo, int256(wanted), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), quote, "");
        assertEq(pair.balanceOf(address(this)), beforeInput - quote);
        assertEq(raw.balanceOf(address(this)), beforeOutput + wanted);
        assertEq(pair.allowance(hook, consumerVault), 0);
        for (uint256 j; j < 2; ++j) assertEq(IBasicVault(consumerVault).reserveOfToken(address(consumerTokens[j])), consumerTokens[j].balanceOf(consumerVault));
        assertTrue(Reserve(consumerVault).canOpenPoolManagerUnlock());
        bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, consumerVault, address(pair));
        vm.expectRevert(reason);
        IUniswapV4SeBufferHook(hook).previewSwapExactOut(address(raw), address(pair), 1);
        _cpRouterTwoLegReject(hook, raw, pair, key);
    }

    /// @notice Dual EO buffers H/P input and pays an admitted, actually funded wrapper identity leg.
    function test_sameManager_dualIdleExactOutputMatchesRouter() public {
        _remainingAmmExactOutput(AmmFixture.Family.Dual);
    }

    /// @notice Orbital EO values all three legs in the actual unavailable-manager context.
    function test_sameManager_orbitalIdleExactOutputMatchesRouter() public {
        _remainingAmmExactOutput(AmmFixture.Family.Orbital);
    }

    /// @notice Curve Quad EO preserves its required-share inverse and actual exact payout.
    function test_sameManager_curveQuadIdleExactOutputMatchesRouter() public {
        _remainingAmmExactOutput(AmmFixture.Family.CurveQuad);
    }

    /// @notice Balancer Quad EO preserves its native-share scaling and actual exact payout.
    function test_sameManager_balancerQuadIdleExactOutputMatchesRouter() public {
        _remainingAmmExactOutput(AmmFixture.Family.BalancerQuad);
    }

    function _remainingAmmExactOutput(AmmFixture.Family family) private {
        for (uint256 i; i < 2; ++i) {
            AmmFixture.Request memory r;
            r.c = _consumerContext(); r.factory = consumerHookFactory;
            r.manager = address(consumerManager); r.vault = consumerVault;
            r.face = address(consumerTokens[i]); r.owner = address(driver);
            AmmFixture.Fixture memory f = AmmFixture.deploy(family, r);
            uint256 seed = 10 ** uint256(IERC20Metadata(r.face).decimals());
            consumerTokens[i].transfer(address(driver), seed);
            vm.startPrank(address(driver));
            for (uint256 j; j < f.tokens.length; ++j) IERC20(f.tokens[j]).approve(f.hook, type(uint256).max);
            vm.stopPrank();
            driver.run(f.hook, f.seedCall);
            assertGt(IERC20(f.hook).totalSupply(), 0, "real funded LP bootstrap");
            assertGt(IERC20(consumerVault).balanceOf(f.hook), 0, "real buffered input reserve");
            IERC20(f.output).approve(address(consumerRouter), type(uint256).max);
            _ammExactOutput(f, consumerTokens[i], family == AmmFixture.Family.Dual);
        }
    }

    function _ammExactOutput(AmmFixture.Fixture memory f, IERC20 pair, bool dual) private {
        _assertAmmContextRate(f.hook, address(pair));
        uint256 wanted = 10 ** uint256(IERC20Metadata(f.output).decimals()) / 10_000;
        SwapObservation memory beforeState;
        beforeState.quote = IUniswapV4SeBufferHook(f.hook).previewSwapExactOut(address(pair), f.output, wanted);
        assertGt(beforeState.quote, 0, "positive input inverse");
        assertEq(beforeState.quote, abi.decode(driver.run(f.hook, abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactOut,
            (address(pair), f.output, wanted))), (uint256)), "idle PM EO equals actual blocked EO");
        if (dual) {
            (bool ok, bytes memory result) = f.hook.staticcall(abi.encodeWithSignature("previewSwapExactOut(bool,uint256)", address(pair) < f.output, wanted));
            assertTrue(ok, "Dual bool EO preview");
            assertEq(abi.decode(result, (uint256)), beforeState.quote, "Dual EO overload parity");
        }
        bytes memory idleReason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(pair), consumerVault);
        vm.expectRevert(idleReason);
        IStandardExchangeOut(f.hook).previewExchangeOut(pair, IERC20(f.output), wanted);
        beforeState.input = pair.balanceOf(address(this));
        beforeState.output = IERC20(f.output).balanceOf(address(this));
        beforeState.shares = IERC20(consumerVault).balanceOf(f.hook);
        beforeState.supply = IERC20(consumerVault).totalSupply();
        uint256 heldOutput = IERC20(f.output).balanceOf(f.hook);
        PoolKey memory key = WeightedPair.pairKey(address(pair), f.output, f.spacing, IHooks(f.hook));
        if (dual) key.fee = 0;
        bool zfo = address(pair) == Currency.unwrap(key.currency0);
        consumerRouter.swapExactOut(key, SwapParams(zfo, int256(wanted), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), beforeState.quote, "");
        assertEq(pair.balanceOf(address(this)), beforeState.input - beforeState.quote, "exact quoted input debit");
        assertEq(IERC20(f.output).balanceOf(address(this)), beforeState.output + wanted, "exact requested output");
        assertEq(IERC20(f.output).balanceOf(f.hook), heldOutput - wanted, "output came from hook reserve");
        uint256 minted = IERC20(consumerVault).balanceOf(f.hook) - beforeState.shares;
        assertGt(minted, 0);
        assertEq(IERC20(consumerVault).totalSupply(), beforeState.supply + minted, "buffered input issued real shares");
        _assertAmmFlat(f);
        _ammTwoLegOutputReject(f, pair, key);
    }

    function _assertAmmContextRate(address hook, address pair) private {
        address provider = IUniswapV4SeBufferHook(hook).rateProvider(pair);
        assertTrue(provider != address(0), "real buffered-leg rate provider");
        (bytes memory state,) = Transition(consumerVault).quoteState(pair, hook);
        state = IStandardExchangeUnlockContextQuote(consumerVault).quoteStateWithUnavailableUnlock(state, address(consumerManager));
        uint256 projected = IStandardExchangeRateQuote(provider).quoteRate(consumerVault, pair, state);
        uint256 actual = abi.decode(driver.run(provider, abi.encodeCall(IRateProvider.getRate, ())), (uint256));
        assertGt(actual, 0);
        assertTrue(actual != 1e18, "fixture exercises a nonunit buffered rate");
        assertEq(projected, actual, "projected rate equals actual blocked rate");
    }

    function _assertAmmFlat(AmmFixture.Fixture memory f) private view {
        assertFalse(TransientStateLibrary.isUnlocked(consumerManager), "manager relocked");
        assertEq(TransientStateLibrary.getNonzeroDeltaCount(consumerManager), 0, "all manager deltas settled");
        for (uint256 j; j < f.tokens.length; ++j) {
            Currency currency = Currency.wrap(f.tokens[j]);
            assertEq(TransientStateLibrary.currencyDelta(consumerManager, f.hook, currency), 0);
            assertEq(TransientStateLibrary.currencyDelta(consumerManager, address(consumerRouter), currency), 0);
            assertEq(IERC20(f.tokens[j]).allowance(f.hook, consumerVault), 0, "no residual underlying approval");
        }
        assertEq(IERC20(consumerVault).allowance(f.hook, consumerVault), 0, "no residual share approval");
        for (uint256 j; j < 2; ++j) assertEq(IBasicVault(consumerVault).reserveOfToken(address(consumerTokens[j])), consumerTokens[j].balanceOf(consumerVault));
    }

    function _ammFingerprint(AmmFixture.Fixture memory f) private view returns (bytes32 digest) {
        digest = keccak256(abi.encode(_book(), IERC20(f.hook).totalSupply(), IERC20(consumerVault).balanceOf(f.hook)));
        for (uint256 j; j < f.tokens.length; ++j) {
            IERC20 token = IERC20(f.tokens[j]);
            bytes32 custody = keccak256(abi.encode(token.balanceOf(f.hook), token.balanceOf(address(this)),
                token.balanceOf(address(consumerManager)), token.balanceOf(address(consumerRouter))));
            digest = keccak256(abi.encode(digest, custody, IBasicVault(f.hook).reserveOfToken(f.tokens[j]),
                token.allowance(f.hook, consumerVault), token.allowance(address(this), address(consumerRouter))));
        }
    }

    function _ammTwoLegOutputReject(AmmFixture.Fixture memory f, IERC20 pair, PoolKey memory key) private {
        (uint256 deployed0, uint256 deployed1) = Reserve(consumerVault).deployedReserve();
        assertGt(deployed0 + consumerTokens[0].balanceOf(consumerVault), 0, "first backing leg positive");
        assertGt(deployed1 + consumerTokens[1].balanceOf(consumerVault), 0, "second backing leg positive");
        bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, consumerVault, address(pair));
        bytes32 beforeState = _ammFingerprint(f);
        vm.expectRevert(reason);
        IUniswapV4SeBufferHook(f.hook).previewSwapExactOut(f.output, address(pair), 1);
        vm.expectRevert(reason);
        driver.run(f.hook, abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactOut, (f.output, address(pair), 1)));
        bool zfo = f.output == Currency.unwrap(key.currency0);
        uint256 maximum = 10 ** uint256(IERC20Metadata(f.output).decimals()) / 100;
        vm.expectRevert(abi.encodeWithSelector(CustomRevert.WrappedError.selector, f.hook, IHooks.beforeSwap.selector,
            reason, abi.encodePacked(Hooks.HookCallFailed.selector)));
        consumerRouter.swapExactOut(key, SwapParams(zfo, 1, zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), maximum, "");
        assertEq(_ammFingerprint(f), beforeState, "failed EO fully rolls back custody, reserves and allowances");
        _assertAmmFlat(f);
    }

    /// @notice Opening a different real manager cannot make the underlying idle inverse available.
    function test_foreignManager_cpExactOutputPreservesActualIdleDomain() public {
        IPoolManager foreign = IPoolManager(address(new PoolManager(address(this))));
        FullSpreadConsumerUnlock foreignDriver = new FullSpreadConsumerUnlock(foreign);
        for (uint256 i; i < 2; ++i) {
            SimpleMintableERC20 raw = new SimpleMintableERC20("Foreign Raw", "FRAW");
            address hook = _deployOwnerCpOnManager(i, IERC20(address(raw)), foreign);
            uint256 seedShares = IERC20(consumerVault).balanceOf(address(this)) / 20;
            raw.mint(address(this), 100 ether);
            vm.prank(address(driver));
            // owner-only liquidity uses pre-owned shares; no underlying idle zap is needed.
            raw.approve(hook, type(uint256).max);
            raw.transfer(address(driver), 100 ether);
            IERC20(consumerVault).transfer(address(driver), seedShares);
            vm.prank(address(driver));
            IERC20(consumerVault).approve(hook, seedShares);
            vm.prank(address(driver));
            CpHook(hook).depositWithSeShares(100 ether, seedShares, address(driver), 0, block.timestamp);
            bytes memory data = abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactOut,
                (address(consumerTokens[i]), address(raw), 1e12));
            bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(consumerTokens[i]), consumerVault);
            vm.expectRevert(reason);
            IUniswapV4SeBufferHook(hook).previewSwapExactOut(address(consumerTokens[i]), address(raw), 1e12);
            vm.expectRevert(reason);
            foreignDriver.run(hook, data);
            vm.expectRevert(reason);
            IStandardExchangeOut(hook).previewExchangeOut(consumerTokens[i], IERC20(address(raw)), 1e12);
            assertTrue(Reserve(consumerVault).canOpenPoolManagerUnlock());
            _foreignManagerPositiveControl(hook, raw, consumerTokens[i], foreign, foreignDriver);
        }
    }

    function _foreignManagerPositiveControl(address hook, SimpleMintableERC20 raw, IERC20 pair,
        IPoolManager foreign, FullSpreadConsumerUnlock foreignDriver) private
    {
        uint256 amount = 1e15;
        SwapObservation memory beforeState;
        beforeState.quote = IUniswapV4SeBufferHook(hook).previewSwapExactIn(address(raw), address(pair), amount);
        assertGt(beforeState.quote, 0);
        assertEq(beforeState.quote, IStandardExchangeIn(hook).previewExchangeIn(IERC20(address(raw)), amount, pair));
        assertEq(beforeState.quote, abi.decode(foreignDriver.run(hook, abi.encodeCall(IUniswapV4SeBufferHook.previewSwapExactIn,
            (address(raw), address(pair), amount))), (uint256)), "foreign manager retains idle EI quote");
        WrapperExactOutRouter router = new WrapperExactOutRouter(foreign);
        raw.mint(address(this), amount);
        raw.approve(address(router), amount);
        beforeState.input = raw.balanceOf(address(this));
        beforeState.output = pair.balanceOf(address(this));
        PoolKey memory key = PoolKey(Currency.wrap(CpHook(hook).currency0()), Currency.wrap(CpHook(hook).currency1()), 0, 60, IHooks(hook));
        bool zfo = address(raw) == Currency.unwrap(key.currency0);
        router.swapExactIn(key, SwapParams(zfo, -int256(amount), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
        assertEq(raw.balanceOf(address(this)), beforeState.input - amount);
        assertEq(pair.balanceOf(address(this)), beforeState.output + beforeState.quote);
        assertTrue(Reserve(consumerVault).canOpenPoolManagerUnlock());
    }
}

contract HooklessSameManagerConsumersTest is HAcceptance, FullSpreadSameManagerAssertions {
    function setUp() public override { HAcceptance.setUp(); _bootstrap(); _configureConsumers(poolManager, address(vault), token0, token1); }
    function _consumerContext() internal view override returns (SeMatrixFixture.Ctx memory c) {
        c.create3Factory = create3Factory; c.indexedexManager = indexedexManager; c.owner = owner;
        c.erc20Facet = erc20Facet; c.erc5267Facet = erc5267Facet; c.erc2612Facet = erc2612Facet;
        c.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet; c.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
    }
}
contract PonsSameManagerConsumersTest is PAcceptance, FullSpreadSameManagerAssertions {
    function setUp() public override { PAcceptance.setUp(); _bootstrap(); _configureConsumers(poolManager, address(vault), token0, token1); }
    function _consumerContext() internal view override returns (SeMatrixFixture.Ctx memory c) {
        c.create3Factory = create3Factory; c.indexedexManager = indexedexManager; c.owner = owner;
        c.erc20Facet = erc20Facet; c.erc5267Facet = erc5267Facet; c.erc2612Facet = erc2612Facet;
        c.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet; c.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
    }
}

contract HooklessNativeSameManagerConsumersTest is HooklessSameManagerConsumersTest {
    function _native() internal pure override returns (bool) { return true; }
}
contract PonsNativeSameManagerConsumersTest is PonsSameManagerConsumersTest {
    function _native() internal pure override returns (bool) { return true; }
}
contract HooklessMixedDecimalsSameManagerConsumersTest is HooklessSameManagerConsumersTest {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
}
contract PonsMixedDecimalsSameManagerConsumersTest is PonsSameManagerConsumersTest {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
}
