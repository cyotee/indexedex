// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {Behavior_UniswapV4PairTokenStandardExchangeVaultPackage as PackageBehavior} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/behaviors/Behavior_UniswapV4PairTokenStandardExchangeVaultPackage.sol";
import {UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService as Components} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {Bytecode} from "@crane/contracts/utils/Bytecode.sol";
import {Creation} from "@crane/contracts/utils/Creation.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {Position} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

/// @notice Non-SUT negative metadata boundary; never used for vault accounting.
contract PairTokenInvalidMetadataFace {
    error MetadataUnavailable();
    function decimals() external pure returns (uint8) { revert MetadataUnavailable(); }
}

// tag::UniswapV4PairTokenStandardExchangeVaultDeploymentTest[]
/// @notice Real registered package lifecycle, identity, configuration and fixture evidence.
contract UniswapV4PairTokenStandardExchangeVaultDeploymentTest is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /// @notice S1-A01/A69: registry discovery and truthful zero fee IDs without fallback registration.
    function test_PairToken_DEP_RegistryDiscovery() public view {
        assertTrue(indexedexManager.isVault(address(vault)));
        assertTrue(indexedexManager.isPackage(address(pairTokenPackage)));
        assertEq(indexedexManager.packageFeeTypeIds(address(pairTokenPackage)), bytes32(0));
        _contains(indexedexManager.vaultsOfToken(address(token0)), address(vault));
        _contains(indexedexManager.vaultsOfToken(address(token1)), address(vault));
        _contains(indexedexManager.vaultsOfPackage(address(pairTokenPackage)), address(vault));
        address[] memory faces_ = IBasicVault(address(vault)).vaultTokens();
        _contains(indexedexManager.vaultsOfTokens(faces_), address(vault));
        bytes4[] memory ids_ = PackageBehavior.packageInterfaces();
        for (uint256 i_; i_ < ids_.length; ++i_) {
            _contains(indexedexManager.vaultsOfType(ids_[i_]), address(vault));
            _contains(indexedexManager.vaultsOfTypeOfTokens(ids_[i_], faces_), address(vault));
        }
        assertEq(IStandardVault(address(vault)).vaultFeeTypeIds(), bytes32(0));
        assertEq(indexedexManager.vaultUsageFeeTypeId(address(vault)), bytes4(0));
        assertEq(indexedexManager.vaultDexTermsTypeId(address(vault)), bytes4(0));
        assertEq(indexedexManager.vaultBondTermsTypeId(address(vault)), bytes4(0));
        assertEq(indexedexManager.vaultSeigniorageTermsTypeId(address(vault)), bytes4(0));
        assertEq(indexedexManager.vaultLendingTermsTypeId(address(vault)), bytes4(0));
    }

    /// @notice S1-A02: all argument fields affect identity; direct prediction equals factory-delegatecall deployment.
    function test_PairToken_DEP_ArgumentIdentitySensitivity() public {
        IPackage.PkgArgs memory args_ = _defaultArgs(key, address(token0), "identity");
        address predicted_ = diamondPackageFactory.calcAddress(pairTokenPackage, abi.encode(args_));
        assertEq(pairTokenPackage.calcSalt(abi.encode(args_)), keccak256(abi.encode(pairTokenPackage.bindingHash(), args_)));
        assertEq(address(_deployVault(args_)), predicted_);
        assertEq(address(_deployVault(args_)), predicted_);
        for (uint256 i_; i_ < 10; ++i_) {
            IPackage.PkgArgs memory changed_ = abi.decode(abi.encode(args_), (IPackage.PkgArgs));
            if (i_ == 0) changed_.rateAsset = address(token1);
            else if (i_ == 1) changed_.name = "identity changed";
            else if (i_ == 2) changed_.symbol = "OTHER";
            else if (i_ == 3) changed_.maxZapBps = 1001;
            else if (i_ == 4) changed_.maxZapTickMove = 601;
            else if (i_ == 5) changed_.poolKey.currency0 = Currency.wrap(address(1));
            else if (i_ == 6) changed_.poolKey.currency1 = Currency.wrap(address(2));
            else if (i_ == 7) changed_.poolKey.fee = 500;
            else if (i_ == 8) changed_.poolKey.tickSpacing = 10;
            else changed_.poolKey.hooks = IHooks(address(3));
            address next_ = diamondPackageFactory.calcAddress(pairTokenPackage, abi.encode(changed_));
            assertNotEq(next_, predicted_, "immutable argument omitted");
            // The first five variants are valid and must actually deploy at their prediction.
            if (i_ < 5) assertEq(address(_deployVault(changed_)), next_);
        }
    }

    /// @notice S1-A02/A68: each real component binding changes identity from an unoccupied snapshot.
    /// @dev Facet variants deploy identical genuine code at another CREATE3 name; no fake metadata.
    function test_PairToken_DEP_BindingIdentitySnapshots() public {
        bytes32 originalHash_ = pairTokenPackage.bindingHash();
        IPackage.PkgArgs memory args_ = _defaultArgs(key, address(token0), "binding identity");
        bytes32 originalSalt_ = pairTokenPackage.calcSalt(abi.encode(args_));
        address originalPrediction_ = diamondPackageFactory.calcAddress(pairTokenPackage, abi.encode(args_));
        assertTrue(vm.revertToState(packageDeploymentSnapshot));
        uint256 snapshot_ = vm.snapshotState();
        for (uint256 i_; i_ < 17; ++i_) {
            if (i_ != 0) {
                assertTrue(vm.revertToState(snapshot_));
                snapshot_ = vm.snapshotState();
            }
            IPackage.PkgInit memory changed_ = pkgInit;
            _changeBinding(changed_, i_);
            vm.prank(i_ == 13 ? address(this) : owner);
            IPackage next_ = Components.deployUniswapV4PairTokenStandardExchangeVaultDFPkg(changed_.registry, changed_);
            assertEq(next_.bindingHash(), keccak256(abi.encode(changed_)));
            assertNotEq(next_.bindingHash(), originalHash_);
            assertNotEq(next_.calcSalt(abi.encode(args_)), originalSalt_);
            assertNotEq(diamondPackageFactory.calcAddress(next_, abi.encode(args_)), originalPrediction_);
        }
    }

    /// @notice S1-A03: ordered currencies, code, hooks, static fee, spacing and initialized price.
    function test_PairToken_DEP_InvalidPoolConfiguration() public {
        for (uint256 i_; i_ < 12; ++i_) {
            IPackage.PkgArgs memory args_ = _defaultArgs(key, address(token0), "invalid key");
            if (i_ == 0) args_.poolKey.currency1 = args_.poolKey.currency0;
            else if (i_ == 1) (args_.poolKey.currency0, args_.poolKey.currency1) = (args_.poolKey.currency1, args_.poolKey.currency0);
            else if (i_ == 2) args_.poolKey.currency0 = Currency.wrap(address(1));
            else if (i_ == 3) args_.poolKey.currency1 = Currency.wrap(address(type(uint160).max));
            else if (i_ == 4) args_.poolKey.hooks = IHooks(address(token0));
            else if (i_ == 5) args_.poolKey.fee = 1_000_001;
            else if (i_ == 6) args_.poolKey.fee = 0x800000;
            else if (i_ == 7) args_.poolKey.tickSpacing = 0;
            else if (i_ == 8) args_.poolKey.tickSpacing = -1;
            else if (i_ == 9) args_.poolKey.tickSpacing = 32768;
            else if (i_ == 10) args_.poolKey.fee = 500; // structurally valid but uninitialized
            else args_.poolKey.currency1 = Currency.wrap(address(0));
            _expectInvalid(args_, IPackage.InvalidPoolKey.selector);
        }
    }

    /// @notice S1-A03/A69: explicit zap/rate bounds, zero pool fee and mixed decimals.
    function test_PairToken_DEP_RateZapAndZeroPoolFee() public {
        IPackage.PkgArgs memory args_ = _defaultArgs(key, address(123), "invalid rate");
        _expectInvalid(args_, IPackage.InvalidRateAsset.selector);
        for (uint256 i_; i_ < 3; ++i_) {
            args_ = _defaultArgs(key, address(token0), "invalid zap");
            if (i_ == 0) args_.maxZapBps = 0;
            else if (i_ == 1) args_.maxZapBps = 10001;
            else args_.maxZapTickMove = -1;
            _expectInvalid(args_, IPackage.InvalidZapLimits.selector);
        }
        _deployPool(false, 6, 8);
        key.fee = 0;
        pool.initialize(key, uint160(1) << 96);
        args_ = _defaultArgs(key, address(token0), "zero pool fee");
        args_.maxZapBps = 10000;
        args_.maxZapTickMove = 0;
        IVault next_ = _deployVault(args_);
        assertEq(next_.maxZapBps(), 10000);
        assertEq(next_.maxZapTickMove(), 0);
        (, address asset_, uint8 decimals_) = IStandardizedYield(address(next_)).assetInfo();
        assertEq(asset_, address(token0));
        assertEq(decimals_, IERC20Metadata(address(token0)).decimals());
        assertTrue(decimals_ == 6 || decimals_ == 8);
        assertEq(IERC20Metadata(address(next_)).decimals(), 18);
    }

    /// @notice A03: metadata failure propagates, factory self-faces reject, and
    /// native rate metadata must identify the wrapped display face rather than zero.
    function test_PairToken_DEP_MetadataFailureAndSelfFaceDomain() public {
        address invalid_ = address(new PairTokenInvalidMetadataFace());
        PoolKey memory invalidKey_ = key;
        invalidKey_.currency0 = Currency.wrap(invalid_ < address(token1) ? invalid_ : address(token1));
        invalidKey_.currency1 = Currency.wrap(invalid_ < address(token1) ? address(token1) : invalid_);
        pool.initialize(invalidKey_, uint160(1) << 96);
        _expectInvalid(_defaultArgs(invalidKey_, invalid_, "invalid metadata"),
            PairTokenInvalidMetadataFace.MetadataUnavailable.selector);
        address factory_ = address(diamondPackageFactory);
        invalidKey_.currency0 = Currency.wrap(factory_ < address(token1) ? factory_ : address(token1));
        invalidKey_.currency1 = Currency.wrap(factory_ < address(token1) ? address(token1) : factory_);
        _expectInvalid(_defaultArgs(invalidKey_, address(token1), "factory self face"), IPackage.InvalidPoolKey.selector);
        _deployPool(true, 18, 18);
        _expectInvalid(_defaultArgs(key, address(0), "raw native rate"), IPackage.InvalidRateAsset.selector);
    }

    /// @notice S1-A04: direct/foreign processing, initialization and lifecycle calls reject.
    function test_PairToken_DEP_LifecycleAuthentication() public {
        bytes memory args_ = abi.encode(_defaultArgs(key, address(token0), "authentication"));
        vm.expectRevert(IPackage.NotCalledByRegistry.selector);
        pairTokenPackage.processArgs(args_);
        vm.prank(address(indexedexManager));
        vm.expectRevert(IPackage.NotCalledByRegistry.selector);
        pairTokenPackage.processArgs(args_);
        vm.expectRevert(IPackage.NotCalledByRegistry.selector);
        diamondPackageFactory.deploy(pairTokenPackage, args_);
        vm.expectRevert(IPackage.InvalidInitializationContext.selector);
        pairTokenPackage.initAccount(args_);
        vm.expectRevert(IPackage.InvalidInitializationContext.selector);
        pairTokenPackage.postDeploy(address(vault));
        vm.expectRevert(IPackage.InvalidInitializationContext.selector);
        pairTokenPackage.updatePkg(address(vault), args_);
        vm.prank(address(diamondPackageFactory));
        assertTrue(pairTokenPackage.postDeploy(address(vault)));
        vm.prank(address(diamondPackageFactory));
        vm.expectRevert(IPackage.InvalidInitializationContext.selector);
        pairTokenPackage.updatePkg(address(vault), args_);
        // No initializer selector survives on the proxy; re-running the registry helper is idempotent.
        assertEq(IDiamondLoupe(address(vault)).facetAddress(IDiamondFactoryPackage.initAccount.selector), address(0));
        IPackage.PkgArgs memory original_ = _defaultArgs(key, address(token0), "PairToken shares");
        assertEq(address(_deployVault(original_)), address(vault));
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(address(diamondPackageFactory.pkgOfAccount(address(vault))), address(pairTokenPackage));
        assertEq(diamondPackageFactory.pkgArgsOfAccount(address(vault)), abi.encode(original_));
    }

    /// @notice S1-A04: absent/mis-slotted components and invalid wrapper bindings cannot partially register.
    function test_PairToken_DEP_InvalidComponents() public {
        assertTrue(vm.revertToState(packageDeploymentSnapshot));
        uint256 snapshot_ = vm.snapshotState();
        for (uint256 i_; i_ < 27; ++i_) {
            if (i_ != 0) {
                assertTrue(vm.revertToState(snapshot_));
                snapshot_ = vm.snapshotState();
            }
            IPackage.PkgInit memory invalid_ = pkgInit;
            if (i_ < 12) _setFacet(invalid_, i_, IFacet(address(0)));
            else if (i_ == 12) invalid_.poolManager = IPoolManager(address(0));
            else if (i_ == 13) invalid_.registry = IVaultRegistryDeployment(address(0));
            else if (i_ == 14) invalid_.oracle = IVaultFeeOracleQuery(address(0));
            else if (i_ == 15) invalid_.diamondFactory = IDiamondPackageCallBackFactory(address(0));
            else if (i_ == 16) invalid_.wrappedNative = IWETH(address(0));
            else if (i_ == 17) invalid_.wrappedNative = IWETH(address(new ERC20PermitMintableStub("bad wrapper", "BAD", 6, address(this), 0)));
            else if (i_ == 18) invalid_.moneyFacet = invalid_.outFacet;
            else if (i_ == 19) invalid_.erc2612Facet = invalid_.erc20Facet;
            else if (i_ == 20) invalid_.wrappedNative = IWETH(address(new ERC20PermitMintableStub("not a wrapper", "NOWRAP", 18, address(this), 0)));
            else invalid_.linkedLibraries[i_ - 21] = address(0);
            uint256 before_ = indexedexManager.vaults().length;
            uint256 packagesBefore_ = indexedexManager.vaultPackages().length;
            bytes32 salt_ = keccak256(abi.encode("PairToken.invalid.package"));
            address predicted_ = Creation._create3AddressFromOf(address(create3Factory), salt_);
            // Canonical CREATE3 does not propagate constructor returndata; this is its real outer error.
            vm.prank(owner);
            vm.expectRevert(Bytecode.ErrorCreatingContract.selector);
            indexedexManager.deployPkg(
                ArtifactCreationCode.creationCode("UniswapV4PairTokenStandardExchangeVaultDFPkg.sol:UniswapV4PairTokenStandardExchangeVaultDFPkg"),
                abi.encode(invalid_), salt_
            );
            assertEq(indexedexManager.vaults().length, before_);
            assertEq(indexedexManager.vaultPackages().length, packagesBefore_);
            assertEq(predicted_.code.length, 0);
            assertFalse(indexedexManager.isPackage(predicted_));
        }
    }

    /// @notice S1-A58: real native faces remain in pool order even when wrapper sorts last.
    function test_PairToken_DEP_NativeContentsOrdering() public {
        token1 = _tokenBelowWrapper();
        token0 = ERC20PermitMintableStub(address(0));
        key = PoolKey(Currency.wrap(address(0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(0)));
        pool.initialize(key, uint160(1) << 96);
        IVault native_ = _deployVault(_defaultArgs(key, address(wrappedNative), "native ordered"));
        assertGt(uint160(address(wrappedNative)), uint160(address(token1)));
        address[] memory faces_ = IBasicVault(address(native_)).vaultTokens();
        assertEq(faces_.length, 2);
        assertEq(faces_[0], address(wrappedNative));
        assertEq(faces_[1], address(token1));
        assertEq(IStandardVault(address(native_)).vaultConfig().tokens, faces_);
        address[] memory sorted_ = new address[](2);
        sorted_[0] = address(token1);
        sorted_[1] = address(wrappedNative);
        bytes32 contents_ = keccak256(abi.encode(sorted_));
        assertEq(IStandardVault(address(native_)).contentsId(), contents_);
        assertEq(indexedexManager.calcContentsId(faces_), contents_);
        _contains(indexedexManager.vaultsOfTokens(faces_), address(native_));
        _contains(indexedexManager.vaultsOfTokens(sorted_), address(native_));
        _contains(indexedexManager.vaultsOfToken(address(wrappedNative)), address(native_));
        assertEq(Currency.unwrap(native_.poolKey().currency0), address(0));
        assertEq(native_.wrappedNative(), address(wrappedNative));
        assertEq(IBasicVault(address(native_)).reserves(), new uint256[](2));
        key.currency1 = Currency.wrap(address(wrappedNative));
        _expectInvalid(_defaultArgs(key, address(wrappedNative), "face collision"), IPackage.InvalidWrappedNative.selector);
    }

    /// @notice S1-A47: public bootstrap changes only its own proxy/position/book.
    function test_PairToken_DEP_InstanceIsolation() public {
        IVault other_ = _deployVault(_defaultArgs(key, address(token1), "other instance"));
        _bootstrap(1e18, 1e18, address(this));
        IERC20(address(vault)).approve(address(123), 17);
        assertEq(IERC20(address(vault)).totalSupply(), 1e18);
        assertEq(IERC20(address(other_)).totalSupply(), 0);
        assertEq(IERC20(address(other_)).balanceOf(address(this)), 0);
        assertEq(IERC20(address(other_)).allowance(address(this), address(123)), 0);
        assertEq(other_.positionLiquidity(), 0);
        (uint256 b0_, uint256 b1_) = other_.localReserves();
        assertEq(b0_, 0);
        assertEq(b1_, 0);
        bytes32 position_ = Position.calculatePositionKey(address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
        assertEq(pool.getPositionLiquidity(key.toId(), position_), vault.positionLiquidity());
        assertGt(vault.positionLiquidity(), 0);
        assertEq(pool.getPositionLiquidity(key.toId(), Position.calculatePositionKey(
            address(other_), other_.tickLower(), other_.tickUpper(), bytes32(0)
        )), 0);
        assertEq(IERC20(address(pkgInit.erc20Facet)).totalSupply(), 0);
        assertEq(IERC20Metadata(address(pkgInit.erc20Facet)).name(), "");
    }

    /// @notice Native fixture bootstraps and closes via payable registered proxy routes and real callbacks.
    function test_PairToken_DEP_NativePublicBootstrapAndClose() public {
        _deployPool(true, 18, 8);
        vault = _deployVault(_defaultArgs(key, address(wrappedNative), "native public bootstrap"));
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        assertEq(supply_, 1e18);
        assertEq(IERC20(address(vault)).balanceOf(address(this)), supply_);
        assertGt(vault.positionLiquidity(), 0);
        (uint256 expected0_, uint256 expected1_) = vault.previewRedeemPair(supply_);
        uint256 before0_ = address(this).balance;
        uint256 before1_ = token1.balanceOf(address(this));
        (uint256 paid0_, uint256 paid1_) = vault.redeemPair(supply_, expected0_, expected1_, address(this), block.timestamp);
        assertEq(paid0_, expected0_);
        assertEq(paid1_, expected1_);
        assertEq(address(this).balance - before0_, paid0_);
        assertEq(token1.balanceOf(address(this)) - before1_, paid1_);
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        assertEq(book0_, 0);
        assertEq(book1_, 0);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(wrappedNative)), 0);
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency0), 0);
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency1), 0);
        assertFalse(TransientStateLibrary.isUnlocked(pool));
    }

    /// @notice The reusable actor genuinely adds/removes, crosses a tick, swaps and donates on ERC20/native pools.
    function test_PairToken_DEP_ExternalActorRoundTrip() public {
        _actorRoundTrip();
        _deployPool(true, 18, 8);
        _actorRoundTrip();
    }

    function _actorRoundTrip() private {
        _fund(address(poolActor), 1e22, 1e22);
        ModifyLiquidityParams memory params_ = ModifyLiquidityParams(-60, 60, 1e18, bytes32(0));
        poolActor.modifyLiquidity(key, params_);
        assertEq(pool.getLiquidity(key.toId()), 1e18);
        (uint256 g0_, uint256 g1_) = pool.getFeeGrowthGlobals(key.toId());
        poolActor.donate(key, 1e12, 2e12);
        (uint256 h0_, uint256 h1_) = pool.getFeeGrowthGlobals(key.toId());
        assertEq(h0_ - g0_, (uint256(1e12) << 128) / 1e18);
        assertEq(h1_ - g1_, (uint256(2e12) << 128) / 1e18);
        poolActor.swap(key, SwapParams(true, -int256(1e17), TickMath.getSqrtPriceAtTick(-120)));
        (, int24 tick_,,) = pool.getSlot0(key.toId());
        assertLt(tick_, -60);
        params_.liquidityDelta = -int256(1e18);
        poolActor.modifyLiquidity(key, params_);
        assertEq(pool.getPositionLiquidity(key.toId(), Position.calculatePositionKey(address(poolActor), -60, 60, bytes32(0))), 0);
        assertFalse(TransientStateLibrary.isUnlocked(pool));
        assertEq(TransientStateLibrary.currencyDelta(pool, address(poolActor), key.currency0), 0);
        assertEq(TransientStateLibrary.currencyDelta(pool, address(poolActor), key.currency1), 0);
    }

    function _expectInvalid(IPackage.PkgArgs memory args_, bytes4 error_) private {
        address predicted_ = diamondPackageFactory.calcAddress(pairTokenPackage, abi.encode(args_));
        uint256 count_ = indexedexManager.vaults().length;
        vm.expectRevert(error_);
        pairTokenPackage.deployVault(args_);
        assertEq(predicted_.code.length, 0);
        assertFalse(indexedexManager.isVault(predicted_));
        assertEq(indexedexManager.vaults().length, count_);
    }

    function _contains(address[] memory values_, address expected_) private pure {
        uint256 matches_;
        for (uint256 i_; i_ < values_.length; ++i_) if (values_[i_] == expected_) ++matches_;
        assertEq(matches_, 1, "registry membership");
    }

    function _tokenBelowWrapper() private returns (ERC20PermitMintableStub) {
        bytes32 initHash_ = keccak256(abi.encodePacked(
            type(ERC20PermitMintableStub).creationCode, abi.encode("native currency", "N", uint8(8), address(this), uint256(0))
        ));
        uint256 salt_;
        address predicted_;
        do {
            predicted_ = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(salt_), initHash_)))));
            if (predicted_ < address(wrappedNative)) break;
            ++salt_;
        } while (true);
        return new ERC20PermitMintableStub{salt: bytes32(salt_)}("native currency", "N", 8, address(this), 0);
    }

    function _setFacet(IPackage.PkgInit memory init_, uint256 index_, IFacet facet_) private pure {
        if (index_ == 0) init_.erc20Facet = facet_;
        else if (index_ == 1) init_.erc2612Facet = facet_;
        else if (index_ == 2) init_.erc5267Facet = facet_;
        else if (index_ == 3) init_.basicVaultFacet = facet_;
        else if (index_ == 4) init_.standardVaultFacet = facet_;
        else if (index_ == 5) init_.moneyFacet = facet_;
        else if (index_ == 6) init_.quoteFacet = facet_;
        else if (index_ == 7) init_.outFacet = facet_;
        else if (index_ == 8) init_.queryFacet = facet_;
        else if (index_ == 9) init_.syMoneyFacet = facet_;
        else if (index_ == 10) init_.syQueryFacet = facet_;
        else init_.callbackFacet = facet_;
    }

    function _changeBinding(IPackage.PkgInit memory init_, uint256 index_) private {
        if (index_ < 12) {
            string memory name_ = PackageBehavior.facetName(index_);
            _setFacet(init_, index_, create3Factory.deployFacet(
                ArtifactCreationCode.creationCode(create3Factory, string.concat(name_, ".sol:", name_)),
                keccak256(abi.encode("PairToken.alternate.facet", name_))
            ));
        } else if (index_ == 12) {
            init_.poolManager = IPoolManager(create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
                abi.encode(address(this)), keccak256(abi.encode("PairToken.alternate.manager"))
            ));
        } else if (index_ == 13) {
            // Real second registry; its own CREATE3 operator authorization mirrors IndexedexTest.
            IIndexedexManagerProxy alternate_ = IndexedexManagerFactoryService.deployIndexedexManager(
                diamondPackageFactory, create3Factory, indexedexManagerDFPkg, address(this), feeCollector
            );
            IOperable(address(create3Factory)).setOperator(address(alternate_), true);
            init_.registry = alternate_;
        } else if (index_ == 14) {
            init_.oracle = IndexedexManagerFactoryService.deployIndexedexManager(
                diamondPackageFactory, create3Factory, indexedexManagerDFPkg, address(this), feeCollector
            );
        } else if (index_ == 15) {
            init_.wrappedNative = IWETH(create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol:WETH9"), "",
                keccak256(abi.encode("PairToken.alternate.wrapper"))
            ));
        } else {
            init_.diamondFactory = IDiamondPackageCallBackFactory(create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(create3Factory, "DiamondPackageCallBackFactory.sol:DiamondPackageCallBackFactory"),
                abi.encode(
                    diamondPackageFactory.ERC165_FACET(), diamondPackageFactory.DIAMOND_LOUPE_FACET(),
                    IDiamondLoupe(address(indexedexManager)).facetAddress(IERC8109Introspection.functionFacetPairs.selector),
                    diamondPackageFactory.POST_DEPLOY_HOOK_FACET()
                ), keccak256(abi.encode("PairToken.alternate.callbackFactory"))
            ));
        }
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultDeploymentTest[]
