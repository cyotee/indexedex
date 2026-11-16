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
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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
    mapping(address => bool) public fixtureVault;
    SimpleMintableERC20[12] internal fundingTokens;

    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        weth = IWETH(address(new WETH9()));
        _deployManager(c);
        pkg_ = existingPkg == address(0) ? _deployPkg(c) : IPackage(existingPkg);
        _createMarket();
        vm.prank(c.owner);
        seVault = pkg_.deployVault(IPackage.PkgArgs(key()));
        fixtureVault[seVault] = true;
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

    /// @dev Parent requires the override. This family has no sleeve capacity gate.
    function limitCapacity(uint256) external override {}

    /// @dev Parent requires the override. This family has no sleeve capacity gate.
    function openCapacity() external override {}

    /// @dev Parent requires the override. This family does not report a booked balance.
    function seBooked() external pure override returns (uint256) {
        return 0;
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
        address infra_ = address(new FullSpreadV4InfrastructureStub());
        init_.positionDescriptor = infra_;
        init_.positionManager = infra_;
        init_.quoter = infra_;
        init_.stateView = infra_;
        init_.reservesLens = infra_;
        init_.universalRouter = infra_;
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
        // Deploy once, then sort and assign complete records. No address or salt is searched.
        // The middle two are primary members, the outer pairs back either sibling orientation,
        // and the remaining three tokens per side are raw controls.
        for (uint256 i_; i_ < fundingTokens.length; ++i_) {
            fundingTokens[i_] = new SimpleMintableERC20(string.concat("FullSpread Face ", vm.toString(i_)), "FS4");
        }
        for (uint256 i_; i_ < fundingTokens.length; ++i_) {
            for (uint256 j_ = i_ + 1; j_ < fundingTokens.length; ++j_) {
                if (address(fundingTokens[j_]) < address(fundingTokens[i_])) {
                    (fundingTokens[i_], fundingTokens[j_]) = (fundingTokens[j_], fundingTokens[i_]);
                }
            }
        }
        token0 = fundingTokens[5];
        token1 = fundingTokens[6];
        poolManager.initialize(key(), uint160(uint256(1) << 96));
    }

    /// @notice Raw controls already deployed on either side of both primary members.
    function rawToken(bool above_, uint256 index_) external view returns (address) {
        require(index_ < 3, "raw control index");
        return address(fundingTokens[(above_ ? 7 : 2) + index_]);
    }

    /// @dev Independent full-range liquidity, the V3 fixture's external LP. A full-book one-token
    ///      exit removes this vault's position and must still swap the unwanted face through the pool.
    struct Sibling {
        address share;
        address provider;
        address otherProvider;
        address face0;
        address face1;
        PoolKey poolKey;
    }

    /// @notice Deploy a second genuine FullSpread vault using the same package and manager.
    /// @dev Select member-token placement, never the vault address. The backing keys are disjoint.
    function deploySibling(address face_, bool faceAtZero_)
        external
        returns (Sibling memory sib_)
    {
        SimpleMintableERC20 c0_ = fundingTokens[faceAtZero_ ? 10 : 0];
        SimpleMintableERC20 c1_ = fundingTokens[faceAtZero_ ? 11 : 1];
        require((face_ < address(c0_)) == faceAtZero_, "member product orientation");
        sib_.face0 = address(c0_);
        sib_.face1 = address(c1_);
        sib_.poolKey = PoolKey(Currency.wrap(sib_.face0), Currency.wrap(sib_.face1), FEE, SPACING, IHooks(address(0)));
        poolManager.initialize(sib_.poolKey, uint160(uint256(1) << 96));
        _seedExternalOn(c0_, c1_, sib_.poolKey);
        vm.prank(ctx.owner);
        sib_.share = pkg_.deployVault(IPackage.PkgArgs(sib_.poolKey));
        fixtureVault[sib_.share] = true;
        uint256 seed_ = BOOTSTRAP;
        c0_.mint(address(this), seed_);
        c1_.mint(address(this), seed_);
        c0_.approve(sib_.share, seed_);
        c1_.approve(sib_.share, seed_);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = seed_;
        amounts_[1] = seed_;
        IFullSpreadBundleIn(sib_.share).exchangeBundleInForSingleOut(
            amounts_, sib_.share, 1, msg.sender, false, block.timestamp
        );
        sib_.provider = _rateProvider(sib_.share, sib_.face0);
        sib_.otherProvider = _rateProvider(sib_.share, sib_.face1);
    }

    /// @notice Acquire caller-owned SE shares before a Hook LP bootstrap.
    /// @dev Only funding tokens are minted. The real vault executes its supported public route.
    function acquireShares(address vault_, address member_, address to_, uint256 amount_)
        external
        returns (uint256 shares_)
    {
        require(fixtureVault[vault_], "not a fixture vault");
        address[] memory members_ = IBasicVault(vault_).vaultTokens();
        require(member_ == members_[0] || member_ == members_[1], "not a member");
        SimpleMintableERC20(member_).mint(address(this), amount_);
        IERC20(member_).approve(vault_, amount_);
        uint256 before_ = IERC20(vault_).balanceOf(to_);
        (shares_,) = IStandardExchangeIn(vault_).exchangeIn(
            IERC20(member_), amount_, IERC20(vault_), 1, to_, false, block.timestamp
        );
        require(shares_ > 0 && IERC20(vault_).balanceOf(to_) - before_ == shares_, "share receipt");
    }

    function _seedExternal() internal {
        _seedExternalOn(token0, token1, key());
    }

    function _seedExternalOn(SimpleMintableERC20 token0_, SimpleMintableERC20 token1_, PoolKey memory key_) internal {
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
        token0_.mint(address(lp_), EXTERNAL * 2);
        token1_.mint(address(lp_), EXTERNAL * 2);
        lp_.add(key_, lower_, upper_, liquidity_);
    }

    function _rateProvider(address share_, address face_) internal returns (address) {
        address factoryOwner_ = IMultiStepOwnable(address(ctx.create3Factory)).owner();
        IDiamondPackageCallBackFactory diamond_ = ctx.create3Factory.diamondPackageFactory();
        vm.startPrank(factoryOwner_);
        IFacet facet_ = ctx.create3Factory.deployStandardExchangeRateProviderFacet();
        IStandardExchangeRateProviderDFPkg providerPkg_ =
            ctx.create3Factory.deployStandardExchangeRateProviderDFPkg(facet_, diamond_);
        vm.stopPrank();
        return address(providerPkg_.deployRateProvider(IStandardExchange(share_), IERC20(face_)));
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

contract FullSpreadV4InfrastructureStub {}
