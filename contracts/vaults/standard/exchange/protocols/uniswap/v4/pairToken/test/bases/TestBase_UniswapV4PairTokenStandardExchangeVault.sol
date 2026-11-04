// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {TestBase_Weth9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/TestBase_Weth9.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "../../interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "../../interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService as Components} from "../../UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol";
import {IUniswapV4PairTokenStandardExchangeVaultComponentBindings as IBindings} from "../../UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol";
import {PoolActor} from "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/harness/PoolActor.sol";

// tag::TestBase_UniswapV4PairTokenStandardExchangeVault[]
/// @notice Registered, artifact-first real-family fixture. Default pool is empty 18/18 ERC20.
/// @dev Native fixtures have token0 == address(0); key always identifies actual currencies.
/// _deployPool changes the active token/key/actor handles, not an already deployed vault.
abstract contract TestBase_UniswapV4PairTokenStandardExchangeVault is IndexedexTest, TestBase_Weth9 {
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    IPoolManager internal pool;
    PoolKey internal key;
    ERC20PermitMintableStub internal token0;
    ERC20PermitMintableStub internal token1;
    IWETH internal wrappedNative;
    IPackage internal pairTokenPackage;
    IVault internal vault;
    PoolActor internal poolActor;
    IPackage.PkgInit internal pkgInit;
    uint256 internal componentDeploymentSnapshot;
    uint256 internal packageDeploymentSnapshot;

    /// @notice Accept public-route native refunds and redemption payouts.
    receive() external payable virtual {}

    /// @notice Initialize the Crane/IndexedEx stack before the canonical wrapper and family.
    function setUp() public virtual override(IndexedexTest, TestBase_Weth9) {
        IndexedexTest.setUp();
        TestBase_Weth9.setUp();
        if (address(pool) != address(0)) return;
        wrappedNative = IWETH(address(weth));
        pool = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256(abi.encode("PairToken.Test.PoolManager"))
        ));
        vm.label(address(pool), "PairToken.PoolManager");
        _deployPool(false, 18, 18);
        componentDeploymentSnapshot = vm.snapshotState();
        pkgInit = _packageInit();
        packageDeploymentSnapshot = vm.snapshotState();
        vm.prank(owner);
        pairTokenPackage = Components.deployUniswapV4PairTokenStandardExchangeVaultDFPkg(indexedexManager, pkgInit);
        vault = _deployVault(_defaultArgs(key, address(token0), "PairToken shares"));
    }

    /// @notice Deploy a fresh initialized pool with configurable raw token decimals.
    /// @dev For ERC20 pools decimals follow each token when addresses are sorted.
    function _deployPool(bool native_, uint8 decimals0_, uint8 decimals1_) internal returns (PoolKey memory) {
        token1 = new ERC20PermitMintableStub("PairToken currency B", "B", decimals1_, address(this), 0);
        if (native_) {
            token0 = ERC20PermitMintableStub(address(0));
        } else {
            token0 = new ERC20PermitMintableStub("PairToken currency A", "A", decimals0_, address(this), 0);
            if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        }
        key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(0)));
        pool.initialize(key, uint160(1) << 96);
        poolActor = new PoolActor(pool);
        vm.label(address(poolActor), "PairToken.externalPoolActor");
        return key;
    }

    /// @notice Explicit standard arguments; callers may change every identity field.
    function _defaultArgs(PoolKey memory key_, address rateAsset_, string memory name_)
        internal pure returns (IPackage.PkgArgs memory)
    {
        return IPackage.PkgArgs(key_, rateAsset_, name_, "PTSE", 1000, 600);
    }

    /// @notice Deploy only through the registered package's registry helper.
    function _deployVault(IPackage.PkgArgs memory args_) internal returns (IVault instance_) {
        instance_ = IVault(pairTokenPackage.deployVault(args_));
        vm.label(address(instance_), args_.name);
    }

    /// @notice Fund a non-SUT actor in active-key raw units; native funding never touches SUT storage.
    function _fund(address recipient_, uint256 amount0_, uint256 amount1_) internal {
        if (Currency.unwrap(key.currency0) == address(0)) {
            vm.deal(recipient_, recipient_.balance + amount0_);
        } else {
            token0.mint(recipient_, amount0_);
        }
        token1.mint(recipient_, amount1_);
    }

    /// @notice Approve active currencies from the test caller to a selected real vault.
    function _approveVault(address vault_) internal {
        if (address(token0) != address(0)) IERC20(address(token0)).approve(vault_, type(uint256).max);
        IERC20(address(token1)).approve(vault_, type(uint256).max);
    }

    /// @notice Fund the test caller and bootstrap via the public paired method only.
    function _bootstrap(uint256 amount0_, uint256 amount1_, address recipient_) internal returns (uint256 shares_) {
        _fund(address(this), amount0_, amount1_);
        _approveVault(address(vault));
        shares_ = vault.depositPair{value: address(token0) == address(0) ? amount0_ : 0}(
            amount0_, amount1_, 0, recipient_, block.timestamp
        );
    }

    function _packageInit() internal returns (IPackage.PkgInit memory init_) {
        init_.erc20Facet = create3Factory.deployERC20Facet();
        init_.erc2612Facet = create3Factory.deployERC2612Facet();
        init_.erc5267Facet = create3Factory.deployERC5267Facet();
        init_.basicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        init_.standardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        init_.moneyFacet = Components.deployMoneyFacet(create3Factory);
        init_.quoteFacet = Components.deployQuoteFacet(create3Factory);
        init_.outFacet = Components.deployOutFacet(create3Factory);
        init_.queryFacet = Components.deployQueryFacet(create3Factory);
        init_.syMoneyFacet = Components.deploySYMoneyFacet(create3Factory);
        init_.syQueryFacet = Components.deploySYQueryFacet(create3Factory);
        init_.callbackFacet = Components.deployCallbackFacet(create3Factory);
        init_.poolManager = pool;
        init_.registry = indexedexManager;
        init_.oracle = indexedexManager;
        init_.wrappedNative = wrappedNative;
        init_.diamondFactory = diamondPackageFactory;
        init_.linkedLibraries = IBindings(address(init_.moneyFacet)).linkedComponents();
    }
}
// end::TestBase_UniswapV4PairTokenStandardExchangeVault[]
