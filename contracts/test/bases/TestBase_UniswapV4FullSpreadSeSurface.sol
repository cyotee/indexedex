// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {DeployPermit2} from "@crane/contracts/protocols/utils/permit2/test/utils/DeployPermit2.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {FullSpreadV4ExternalLp} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {IStandardExchangeBundleIn} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService as Components} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultComponentBindings as IBindings} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";

/// @notice Hookless FullSpread vault bound as the Uni V4 standard exchange for DETF fixtures.
abstract contract TestBase_UniswapV4FullSpreadSeSurface is TestBase_VaultComponents, DeployPermit2 {
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    IPoolManager internal poolManager;
    PoolKey internal graduatedPoolKey;
    IWETH internal weth;
    address internal launchToken;
    IStandardExchangeProxy internal ponsSe;
    IPermit2 internal permit2;

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();
        permit2 = IPermit2(deployPermit2());
        weth = IWETH(address(new WETH9()));
        launchToken = address(new SimpleMintableERC20("Launch", "DTF"));
        poolManager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("FullSpreadSeSurface.PoolManager")
        ));
        (address token0, address token1) = launchToken < address(weth)
            ? (launchToken, address(weth))
            : (address(weth), launchToken);
        graduatedPoolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(graduatedPoolKey, uint160(1) << 96);
        IPackage.PkgInit memory init_ = _packageInit();
        vm.prank(owner);
        IPackage pkg = Components.deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(indexedexManager, init_);
        ponsSe = IStandardExchangeProxy(pkg.deployVault(IPackage.PkgArgs(graduatedPoolKey)));
        vm.label(address(ponsSe), "UniV4Se_FullSpread");
        SimpleMintableERC20(launchToken).mint(address(this), 1_000_000 ether);
        deal(address(weth), address(this), 1_000_000 ether);
        _seedGraduatedPool();
    }

    /// @dev A full-book one-sided exit is the rate quote. It swaps the unwanted face, so the pool
    ///      needs liquidity that is not the vault's own position.
    function _seedGraduatedPool() internal {
        int24 lower_ = TickMath.minUsableTick(graduatedPoolKey.tickSpacing);
        int24 upper_ = TickMath.maxUsableTick(graduatedPoolKey.tickSpacing);
        uint128 liquidity_ = LiquidityAmounts.getLiquidityForAmounts(
            uint160(1) << 96,
            TickMath.getSqrtPriceAtTick(lower_),
            TickMath.getSqrtPriceAtTick(upper_),
            500_000 ether,
            500_000 ether
        );
        FullSpreadV4ExternalLp lp_ = new FullSpreadV4ExternalLp(poolManager);
        SimpleMintableERC20(launchToken).mint(address(lp_), 500_000 ether);
        deal(address(weth), address(lp_), 500_000 ether);
        lp_.add(graduatedPoolKey, lower_, upper_, liquidity_);
    }

    /// @dev Equal raw amounts at the initialized price, so activation is a bundle deposit, not a swap.
    function _activatePonsSe() internal virtual {
        uint256 amount_ = 10_000 ether;
        IERC20(launchToken).approve(address(ponsSe), amount_);
        IERC20(address(weth)).approve(address(ponsSe), amount_);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = amount_;
        amounts_[1] = amount_;
        IStandardExchangeBundleIn(address(ponsSe)).exchangeBundleInForSingleOut(
            amounts_, address(ponsSe), 0, address(this), false, _deadline()
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _wrapWeth(address to, uint256 amount) internal {
        vm.deal(to, to.balance + amount);
        vm.prank(to);
        weth.deposit{value: amount}();
    }

    function _packageInit() internal returns (IPackage.PkgInit memory init_) {
        address infra_ = address(new FullSpreadSeSurfaceInfrastructure());
        IFacet money_ = Components.deployMoneyFacet(create3Factory);
        init_.erc20Facet = create3Factory.deployERC20Facet();
        init_.erc2612Facet = create3Factory.deployERC2612Facet();
        init_.erc5267Facet = create3Factory.deployERC5267Facet();
        init_.basicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        init_.standardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        init_.moneyFacet = money_;
        init_.quoteFacet = Components.deployQuoteFacet(create3Factory);
        init_.outFacet = Components.deployOutFacet(create3Factory);
        init_.queryFacet = Components.deployQueryFacet(create3Factory);
        init_.callbackFacet = Components.deployCallbackFacet(create3Factory);
        init_.uniswapV4ProtocolAwareFacet = Components.deployProtocolAwareFacet(create3Factory);
        init_.uniswapV4SinglePositionAwareFacet = Components.deploySinglePositionAwareFacet(create3Factory);
        init_.poolManager = poolManager;
        init_.positionDescriptor = infra_;
        init_.positionManager = infra_;
        init_.quoter = infra_;
        init_.stateView = infra_;
        init_.reservesLens = infra_;
        init_.universalRouter = infra_;
        init_.registry = indexedexManager;
        init_.oracle = IVaultFeeOracleQuery(address(indexedexManager));
        init_.weth = weth;
        init_.diamondFactory = diamondFactory;
        init_.linkedLibraries = IBindings(address(money_)).linkedComponents();
    }
}

contract FullSpreadSeSurfaceInfrastructure {}
