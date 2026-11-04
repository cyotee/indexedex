// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProvider_FactoryService} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService as Components} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultComponentBindings as IBindings} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

interface IFullSpreadBundleIn {
    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);
}

/// @notice Hook-matrix adapter for `UniswapV4FullSpreadStandardExchangeVault`.
/// @dev One hookless PoolKey on the bound PoolManager. Bootstrap is one public bundle deposit.
///      This vault has no sleeve, no `getRate`, and no `asset`.
contract SeMatrix_FullSpreadV4Fixture is SeMatrixFixture {
    using Components for ICreate3FactoryProxy;
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;

    uint24 internal constant FEE = 3000;
    int24 internal constant SPACING = 60;
    uint256 internal constant BOOTSTRAP = 100_000 ether;
    uint256 internal constant EXTERNAL = 1_000_000 ether;
    bytes32 internal constant MANAGER_SALT = keccak256("SeMatrix_FullSpreadV4_PoolManager");

    IPackage internal pkg_;
    IPoolManager public poolManager;
    SimpleMintableERC20 public token0;
    SimpleMintableERC20 public token1;
    IWETH public weth;
    address internal seVault;
    address public currency0Provider;
    address public currency1Provider;

    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        weth = IWETH(address(new WETH9()));
        _deployManager(c);
        pkg_ = existingPkg == address(0) ? _deployPkg(c) : IPackage(existingPkg);
        _createMarket();
        vm.prank(c.owner);
        seVault = pkg_.deployVault(IPackage.PkgArgs(key(), "Full spread shares", "FS"));
        _seedExternal();
        _bootstrap();
        _deployProviders(c);
    }

    function key() public view returns (PoolKey memory) {
        return PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), FEE, SPACING, IHooks(address(0)));
    }

    function pkg() external view returns (address) {
        return address(pkg_);
    }

    function familyName() external pure override returns (string memory) {
        return "UniswapV4FullSpreadStandardExchangeVault";
    }

    function faceToken() public view override returns (address) {
        return address(token0);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    function fund(address to, uint256 amount) external override {
        token0.mint(to, amount);
    }

    function hasPartialCase() external pure override returns (bool) {
        return false;
    }

    function limitCapacity(uint256) external override {}

    function openCapacity() external override {}

    function seBooked() external view override returns (uint256) {
        return token0.balanceOf(seVault);
    }

    function operativeRevertReachable() external pure override returns (bool) {
        return false;
    }

    function armOperativeRevert() external override {}

    function disarmOperativeRevert() external override {}

    function isAmm() external pure override returns (bool) {
        return true;
    }

    function otherToken() external view override returns (address) {
        return address(token1);
    }

    function fundOther(address to, uint256 amount) external override {
        token1.mint(to, amount);
    }

    function _deployManager(Ctx memory c) internal {
        bytes memory code_ = ArtifactCreationCode.creationCode(c.create3Factory, "PoolManager.sol:PoolManager");
        address factoryOwner_ = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.prank(factoryOwner_);
        poolManager = IPoolManager(c.create3Factory.create3WithArgs(code_, abi.encode(factoryOwner_), MANAGER_SALT));
    }

    function _deployPkg(Ctx memory c) internal returns (IPackage pkgOut_) {
        address factoryOwner_ = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.startPrank(factoryOwner_);
        IFacet money_ = c.create3Factory.deployMoneyFacet();
        IPackage.PkgInit memory init_;
        init_.erc20Facet = c.erc20Facet;
        init_.erc2612Facet = c.erc2612Facet;
        init_.erc5267Facet = c.erc5267Facet;
        init_.basicVaultFacet = c.multiAssetBasicVaultFacet;
        init_.standardVaultFacet = c.multiAssetStandardVaultFacet;
        init_.moneyFacet = money_;
        init_.quoteFacet = c.create3Factory.deployQuoteFacet();
        init_.outFacet = c.create3Factory.deployOutFacet();
        init_.queryFacet = c.create3Factory.deployQueryFacet();
        init_.callbackFacet = c.create3Factory.deployCallbackFacet();
        init_.uniswapV4ProtocolAwareFacet = c.create3Factory.deployProtocolAwareFacet();
        init_.uniswapV4SinglePositionAwareFacet = c.create3Factory.deploySinglePositionAwareFacet();
        init_.linkedLibraries = IBindings(address(money_)).linkedComponents();
        vm.stopPrank();
        init_.poolManager = poolManager;
        init_.positionDescriptor = address(0xD1);
        init_.positionManager = address(0xD2);
        init_.quoter = address(0xD3);
        init_.stateView = address(0xD4);
        init_.reservesLens = address(0xD5);
        init_.universalRouter = address(0xD6);
        init_.registry = IVaultRegistryDeployment(address(c.indexedexManager));
        init_.oracle = IVaultFeeOracleQuery(address(c.indexedexManager));
        init_.weth = weth;
        init_.diamondFactory = c.create3Factory.diamondPackageFactory();
        vm.prank(c.owner);
        pkgOut_ = Components.deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(
            IVaultRegistryDeployment(address(c.indexedexManager)), init_
        );
    }

    function _createMarket() internal {
        SimpleMintableERC20 a_ = new SimpleMintableERC20("FullSpread V4 Face", "FS4A");
        SimpleMintableERC20 b_ = new SimpleMintableERC20("FullSpread V4 Pair", "FS4B");
        (token0, token1) = address(a_) < address(b_) ? (a_, b_) : (b_, a_);
        poolManager.initialize(key(), uint160(uint256(1) << 96));
    }

    /// @dev Independent full-range liquidity, the V3 fixture's external LP. A full-book one-token
    ///      exit removes this vault's position and must still swap the unwanted face through the pool.
    function _seedExternal() internal {
        int24 lower_ = TickMath.minUsableTick(SPACING);
        int24 upper_ = TickMath.maxUsableTick(SPACING);
        uint128 liquidity_ = LiquidityAmounts.getLiquidityForAmounts(
            uint160(uint256(1) << 96),
            TickMath.getSqrtPriceAtTick(lower_),
            TickMath.getSqrtPriceAtTick(upper_),
            EXTERNAL,
            EXTERNAL
        );
        FullSpreadV4ExternalLp lp_ = new FullSpreadV4ExternalLp(poolManager);
        token0.mint(address(lp_), EXTERNAL * 2);
        token1.mint(address(lp_), EXTERNAL * 2);
        lp_.add(key(), lower_, upper_, liquidity_);
    }

    function _bootstrap() internal {
        token0.mint(address(this), BOOTSTRAP);
        token1.mint(address(this), BOOTSTRAP);
        token0.approve(seVault, BOOTSTRAP);
        token1.approve(seVault, BOOTSTRAP);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = BOOTSTRAP;
        amounts_[1] = BOOTSTRAP;
        IFullSpreadBundleIn(seVault).exchangeBundleInForSingleOut(
            amounts_, seVault, 0, address(this), false, block.timestamp
        );
    }

    function _deployProviders(Ctx memory c) internal {
        address factoryOwner_ = IMultiStepOwnable(address(c.create3Factory)).owner();
        IDiamondPackageCallBackFactory diamond_ = c.create3Factory.diamondPackageFactory();
        vm.startPrank(factoryOwner_);
        IFacet facet_ = c.create3Factory.deployStandardExchangeRateProviderFacet();
        IStandardExchangeRateProviderDFPkg providerPkg_ =
            c.create3Factory.deployStandardExchangeRateProviderDFPkg(facet_, diamond_);
        vm.stopPrank();
        currency0Provider = address(providerPkg_.deployRateProvider(IStandardExchange(seVault), IERC20(address(token0))));
        currency1Provider = address(providerPkg_.deployRateProvider(IStandardExchange(seVault), IERC20(address(token1))));
    }
}

/// @dev Real PoolManager liquidity. Not a mock of the vault or the manager.
contract FullSpreadV4ExternalLp is IUnlockCallback {
    IPoolManager public immutable manager;

    constructor(IPoolManager manager_) {
        manager = manager_;
    }

    function add(PoolKey calldata key_, int24 lower_, int24 upper_, uint128 liquidity_) external {
        manager.unlock(abi.encode(key_, lower_, upper_, liquidity_));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        if (msg.sender != address(manager)) revert();
        (PoolKey memory key_, int24 lower_, int24 upper_, uint128 liquidity_) =
            abi.decode(data_, (PoolKey, int24, int24, uint128));
        manager.modifyLiquidity(
            key_,
            ModifyLiquidityParams({
                tickLower: lower_,
                tickUpper: upper_,
                liquidityDelta: int256(uint256(liquidity_)),
                salt: bytes32(uint256(1))
            }),
            ""
        );
        _settle(key_.currency0);
        _settle(key_.currency1);
        return "";
    }

    function _settle(Currency currency_) internal {
        int256 delta_ = TransientStateLibrary.currencyDelta(manager, address(this), currency_);
        if (delta_ == 0) return;
        if (delta_ < 0) {
            uint256 debt_ = uint256(-delta_);
            manager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).transfer(address(manager), debt_);
            if (manager.settle() != debt_) revert();
        } else {
            manager.take(currency_, address(this), uint256(delta_));
        }
    }
}
