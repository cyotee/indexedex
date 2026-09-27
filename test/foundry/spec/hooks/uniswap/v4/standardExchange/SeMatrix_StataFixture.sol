// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IAToken} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAToken.sol";
import {IACLManager} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IACLManager.sol";
import {IPoolConfigurator} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolConfigurator.sol";
import {IPoolAddressesProvider} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/types/DataTypes.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";
import {IStataTokenFactory} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenFactory.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IAaveV3StataStandardExchangeDFPkg} from "contracts/protocols/lending/aave/v3.6/IAaveV3StataStandardExchangeDFPkg.sol";
import {
    AaveV3Stata_Component_FactoryService
} from "contracts/protocols/lending/aave/v3.6/AaveV3Stata_Component_FactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {BaseTest} from "lib/crane/test/foundry/spec/protocols/lending/aave/3.6/extensions/stata-token/TestBase.sol";
import {TestBase_AaveV3StataStandardExchange_U6} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange_U6.sol";
import {TestBase_AaveV3StataStandardExchange_U9} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange_U9.sol";

/**
 * @dev Protocol harness only: the real Crane Aave V3.6 market plus the StataTokenV2 factory,
 *      stood up by Crane `BaseTest.setUp` (`initTestEnvironment(false)`, `createStataTokens` on the
 *      listed reserves, `underlying = weth`). That is the same wiring
 *      `TestBase_AaveV3StataStandardExchange_Decimals._setUpCraneAaveStata` performs when
 *      `_underlyingDecimals() == 18` (`_selectUnderlying` returns `tokenList.weth`). Deployed with
 *      `new` by the fixture so its `setUp` does not collide with the hook TestBase's.
 */
contract SeMatrix_StataHarness is BaseTest {
    function protocol() external returns (address stata, IStataTokenFactory factory_) {
        BaseTest.setUp();
        stata = address(stataTokenV2);
        factory_ = IStataTokenFactory(address(factory));
    }
}

/**
 * @dev Decimal-face protocol harness (M14): the Crane Aave V3.6 market plus StataTokenV2 on the
 *      6-decimal Crane `usdx` reserve, stood up by only `_setUpCraneAaveStata` (not the family's full
 *      IndexedEx `setUp`) so it does not collide with the hook TestBase's manager, exactly as the
 *      18-decimal `SeMatrix_StataHarness` calls only `BaseTest.setUp`. Deployed with `new` by the fixture.
 */
contract SeMatrix_StataHarnessU6 is TestBase_AaveV3StataStandardExchange_U6 {
    function protocol() external returns (address stata, IStataTokenFactory factory_) {
        _setUpCraneAaveStata();
        stata = address(stataTokenV2);
        factory_ = IStataTokenFactory(address(factory));
    }

    /// @dev `usdx` is a `TestnetERC20` whose `mint` is owner gated; `deal` sets the balance directly,
    ///      matching the family base's `_fundUnderlying`.
    function dealUnderlying(address to, uint256 amount) external {
        deal(underlying, to, amount);
    }
}

/// @dev Decimal-face protocol harness (M14): the same wiring on the listed 9-decimal `NINE` reserve.
contract SeMatrix_StataHarnessU9 is TestBase_AaveV3StataStandardExchange_U9 {
    function protocol() external returns (address stata, IStataTokenFactory factory_) {
        _setUpCraneAaveStata();
        stata = address(stataTokenV2);
        factory_ = IStataTokenFactory(address(factory));
    }

    function dealUnderlying(address to, uint256 amount) external {
        deal(underlying, to, amount);
    }
}

/// @dev Decimal-face harness view used by the fixture to fund a non-WETH underlying.
interface ISeMatrix_StataDealer {
    function dealUnderlying(address to, uint256 amount) external;
}

/// @dev Getter of the concrete `AaveV3StataStandardExchangeDFPkg` (`public immutable STATA_TOKEN_FACTORY`)
///      that the package interface does not declare; used only on the package-reuse path.
interface ISeMatrix_StataPkgFactoryView {
    function STATA_TOKEN_FACTORY() external view returns (IStataTokenFactory);
}

/**
 * @title SeMatrix_StataFixture
 * @notice Aave V3 Stata SE row fixture (open item 1 PRD §5, M6, M13). Face token: the 18-decimal
 *         Aave underlying (Crane testnet WETH) of a StataTokenV2 on the real Crane Aave V3.6 pool.
 *         The SE is the registry-deployed `AaveV3StataStandardExchangeDFPkg` vault for that stata,
 *         deployed exactly as `TestBase_AaveV3StataStandardExchange` (and the former
 *         `SeMatrix_StataDeploy` library this fixture replaces, M6) do:
 *         `indexedexManager.deployAaveV3StataStandardExchangeDFPkg`, then `pkg.deployVault`.
 * @dev Package reuse: the package salt is fixed per family
 *      (`AaveV3Stata_Component_FactoryService.deployAaveV3StataStandardExchangeDFPkgFromVaultRegistry`),
 *      so a second package on the same manager would collide. Passing a non-zero `existingPkg`
 *      reuses that package and its market: the WETH stata is resolved from the package's
 *      `STATA_TOKEN_FACTORY` and the SE already registered for it is rebound (idempotent). A second
 *      distinct face on the same market would need a second listed reserve; out of scope (M13).
 *      The R14 partial case is `IPoolConfigurator.setSupplyCap` (see
 *      `AaveV3StataStandardExchange_APEX_R14.t.sol` `_setSupplyCap`); the cap is whole tokens, so
 *      the reserve is padded by a third-party supply until exactly `allowFace` remains.
 */
contract SeMatrix_StataFixture is SeMatrixFixture {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using AaveV3Stata_Component_FactoryService for ICreate3FactoryProxy;

    uint256 internal constant RAY = 1e27;

    error PackageReuseWithoutStata(address pkg);

    IAaveV3StataStandardExchangeDFPkg internal pkg_;
    IStataTokenV2 public stata;
    address internal underlying_;
    IPool internal pool;
    IPoolAddressesProvider internal provider;
    address internal seVault;

    /// @dev True when the face is the 18-decimal WETH reserve (real WETH9 minting); false for the
    ///      M14 6-/9-decimal faces, which fund through the decimal harness's `deal`.
    bool internal wethFace;
    /// @dev The M14 decimal harness (usdx / NINE); zero on the 18-decimal WETH path.
    address internal dealer;

    /// @param faceDecimals The face underlying's decimals: 18 keeps the original WETH harness
    ///        byte-identical; 6 / 9 (M14) stand up the market on Crane `usdx` / listed `NINE`.
    constructor(Ctx memory c, address existingPkg, uint8 faceDecimals) SeMatrixFixture(c) {
        if (existingPkg == address(0)) {
            (address stata_, IStataTokenFactory factory_) = _standUpMarket(faceDecimals);
            stata = IStataTokenV2(stata_);
            pkg_ = _deployPkg(c, factory_);
        } else {
            pkg_ = IAaveV3StataStandardExchangeDFPkg(existingPkg);
            stata = IStataTokenV2(_resolveWethStata(ISeMatrix_StataPkgFactoryView(existingPkg).STATA_TOKEN_FACTORY()));
            if (address(stata) == address(0)) revert PackageReuseWithoutStata(existingPkg);
            // Package reuse resolves the 18-decimal WETH stata.
            wethFace = true;
        }
        underlying_ = stata.asset();
        pool = stata.POOL();
        provider = stata.POOL_ADDRESSES_PROVIDER();
        seVault = _bindSe(c);
    }

    /* ----------------------------- deployment ---------------------------- */

    /// @dev Stand up the Crane Aave market + StataTokenV2 at the chosen face decimals. The 18-decimal
    ///      path is the original WETH `SeMatrix_StataHarness` unchanged; 6 / 9 use the family
    ///      `_Decimals` TestBase (usdx / NINE) and record the harness as the funding `dealer`.
    function _standUpMarket(uint8 faceDecimals)
        internal
        returns (address stata_, IStataTokenFactory factory_)
    {
        if (faceDecimals == 18) {
            wethFace = true;
            return (new SeMatrix_StataHarness()).protocol();
        }
        if (faceDecimals == 6) {
            SeMatrix_StataHarnessU6 h = new SeMatrix_StataHarnessU6();
            (stata_, factory_) = h.protocol();
            dealer = address(h);
            return (stata_, factory_);
        }
        if (faceDecimals == 9) {
            SeMatrix_StataHarnessU9 h = new SeMatrix_StataHarnessU9();
            (stata_, factory_) = h.protocol();
            dealer = address(h);
            return (stata_, factory_);
        }
        revert("SeMatrix_StataFixture: unsupported face decimals");
    }

    /// @dev Same PkgInit as `TestBase_AaveV3StataStandardExchange._buildAaveV3StataPkgInit` with the
    ///      real stata factory, deployed through the IndexedEx manager as the registry owner.
    function _deployPkg(Ctx memory c, IStataTokenFactory factory_)
        internal
        returns (IAaveV3StataStandardExchangeDFPkg instance)
    {
        IAaveV3StataStandardExchangeDFPkg.PkgInit memory init;
        init.erc20Facet = c.erc20Facet;
        init.erc5267Facet = c.erc5267Facet;
        init.erc2612Facet = c.erc2612Facet;
        vm.startPrank(_factoryOwner());
        init.erc4626Facet = c.create3Factory.deployReceiptBackedERC4626Facet();
        init.erc4626StandardVaultFacet = c.erc4626StandardVaultFacet;
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        init.aaveV3StataStandardExchangeInFacet = c.create3Factory.deployAaveV3StataStandardExchangeInFacet();
        init.aaveV3StataStandardExchangeOutFacet = c.create3Factory.deployAaveV3StataStandardExchangeOutFacet();
        init.aaveV3StataMarkerFacet = c.create3Factory.deployAaveV3StataMarkerFacet();
        vm.stopPrank();
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.permit2 = c.permit2;
        init.stataTokenFactory = factory_;
        vm.prank(c.owner);
        // Multi-leg matrix rows deploy several stata packages on the one shared manager (a distinct Aave
        // market, hence a distinct stata, per leg). The fixture address is unique per instance, so it
        // discriminates the package salt to a distinct address; disc==0 (the canonical single-package
        // address) is unchanged for every other caller.
        instance = AaveV3Stata_Component_FactoryService.deployAaveV3StataStandardExchangeDFPkg(
            c.indexedexManager, init, bytes32(uint256(uint160(address(this))))
        );
    }

    /// @dev The 18-decimal reserve of the factory's pool that already has a stata (Crane testnet WETH).
    function _resolveWethStata(IStataTokenFactory factory_) internal view returns (address) {
        address[] memory reserves = factory_.POOL().getReservesList();
        for (uint256 i = 0; i < reserves.length; ++i) {
            if (IERC20Metadata(reserves[i]).decimals() != 18) continue;
            address s = factory_.getStataToken(reserves[i]);
            if (s != address(0)) return s;
        }
        return address(0);
    }

    /// @dev Rebind the SE already registered for this stata, otherwise deploy it through the package.
    function _bindSe(Ctx memory c) internal returns (address vault) {
        address[] memory existing =
            IVaultRegistryVaultQuery(address(c.indexedexManager)).vaultsOfPkgOfToken(address(pkg_), address(stata));
        if (existing.length > 0) return existing[0];
        vm.prank(c.owner);
        vault = pkg_.deployVault(IERC20(address(stata)));
    }

    /* ------------------------------ identity ------------------------------ */

    function pkg() external view returns (address) {
        return address(pkg_);
    }

    function familyName() external pure override returns (string memory) {
        return "AaveV3StataStandardExchange";
    }

    function faceToken() public view override returns (address) {
        return underlying_;
    }

    function se() public view override returns (address) {
        return seVault;
    }

    /* ------------------------------- funding ------------------------------ */

    /// @dev 18-decimal WETH face: real WETH9 minting (`deposit` ETH, hand the wrapped units over).
    ///      6-/9-decimal faces (M14): `deal` the harness's underlying, since usdx / NINE are owner-gated.
    function fund(address to, uint256 amount) external override {
        if (wethFace) {
            vm.deal(address(this), amount);
            WETH9(payable(underlying_)).deposit{value: amount}();
            IERC20(underlying_).transfer(to, amount);
        } else {
            ISeMatrix_StataDealer(dealer).dealUnderlying(to, amount);
        }
    }

    /* -------------------------- R14 partial case -------------------------- */

    function hasPartialCase() external pure override returns (bool) {
        return true;
    }

    /// @dev `ERC4626StataTokenUpgradeable.maxDeposit` is `supplyCap * 10**dec - currentSupply` with
    ///      `currentSupply = (scaledTotalSupply + accruedToTreasury).mulDiv(rate, RAY, Ceil)`. The cap
    ///      is whole tokens, so set `cap = ceil((current + allow) / unit)` and top the reserve up with a
    ///      third-party supply of `cap * unit - current - allow` so exactly `allow` remains.
    function limitCapacity(uint256 allowFace) external override {
        uint256 unit = 10 ** uint256(IERC20Metadata(underlying_).decimals());
        uint256 current = _currentSupplyCeil();
        uint256 cap = (current + allowFace + unit - 1) / unit;
        uint256 pad = cap * unit - current - allowFace;
        _ensurePoolAdmin();
        IPoolConfigurator(provider.getPoolConfigurator()).setSupplyCap(underlying_, cap);
        if (pad > 0) {
            if (wethFace) {
                vm.deal(address(this), pad);
                WETH9(payable(underlying_)).deposit{value: pad}();
            } else {
                ISeMatrix_StataDealer(dealer).dealUnderlying(address(this), pad);
            }
            IERC20(underlying_).approve(address(pool), pad);
            pool.supply(underlying_, pad, address(this), 0);
        }
        require(stata.maxDeposit(seVault) == allowFace, "SeMatrix_StataFixture: capacity != allow");
    }

    /// @dev Cap 0 is unbounded (`AaveV3StataStandardExchange_APEX_R14.t.sol` `_setSupplyCap(0)`).
    function openCapacity() external override {
        _ensurePoolAdmin();
        IPoolConfigurator(provider.getPoolConfigurator()).setSupplyCap(underlying_, 0);
    }

    /// @dev Booked local underlying on the SE (R14 `_booked`: `reserveOfToken(realBase)`).
    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(underlying_);
    }

    function _currentSupplyCeil() internal view returns (uint256) {
        DataTypes.ReserveDataLegacy memory rd = pool.getReserveData(underlying_);
        uint256 scaled = IAToken(rd.aTokenAddress).scaledTotalSupply() + uint256(rd.accruedToTreasury);
        uint256 rate = pool.getReserveNormalizedIncome(underlying_);
        return (scaled * rate + RAY - 1) / RAY;
    }

    /// @dev `roleList.marketOwner` is the ACL admin (R14 `_setSupplyCap`); read it from the provider.
    function _ensurePoolAdmin() internal {
        IACLManager acl = IACLManager(provider.getACLManager());
        if (acl.isPoolAdmin(address(this))) return;
        address admin = provider.getACLAdmin();
        vm.prank(admin);
        acl.addPoolAdmin(address(this));
    }

    /* --------------------------- operative failure ------------------------ */

    /// @dev The hook's underlying→SE route ends in `AaveV3StataStandardExchangeCommon._investUnderlyingIntoStata`
    ///      → `StataTokenV2.deposit` → `POOL.deposit` (`ERC4626StataTokenUpgradeable._deposit`); the
    ///      aToken-output route uses `POOL.supply`. Both pool entry points are made to revert so every
    ///      precheck (`maxDeposit`, previews) still passes and only the operative call fails.
    function armOperativeRevert() external override {
        vm.mockCallRevert(address(pool), abi.encodeWithSelector(IPool.deposit.selector), rejectBytes());
        vm.mockCallRevert(address(pool), abi.encodeWithSelector(IPool.supply.selector), rejectBytes());
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    /* ------------------------------- AMM ---------------------------------- */

    function isAmm() external pure override returns (bool) {
        return false;
    }
}
