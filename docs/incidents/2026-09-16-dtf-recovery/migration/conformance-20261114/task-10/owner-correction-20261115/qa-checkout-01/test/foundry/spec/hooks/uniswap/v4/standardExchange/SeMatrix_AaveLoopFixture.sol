// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IMultiStepOwnableView} from "@crane/contracts/access/ERC8023/IMultiStepOwnableView.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IAToken} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAToken.sol";
import {IACLManager} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IACLManager.sol";
import {IPoolConfigurator} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolConfigurator.sol";
import {IPoolAddressesProvider} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {DataTypes} from "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/types/DataTypes.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";
import {IAaveOracle as IAaveOracleV4} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";
import {IAaveCrossVersionLoopVault} from "contracts/interfaces/IAaveCrossVersionLoopVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IAaveCrossVersionLoopDFPkg} from "contracts/protocols/lending/aave/cross-version/IAaveCrossVersionLoopDFPkg.sol";
import {
    AaveCrossVersionLoop_Component_FactoryService
} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol";
import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @dev Protocol harness only: the local Aave V3.6 + V4 markets with the two pair test tokens, stood
 *      up by `TestBase_AaveCrossVersionLoopV3Market.setUp` (V4 hub/spoke, then the V3 batch
 *      orchestration listing tokenA/tokenB). `seedBorrowLiquidity` ports
 *      `AaveCrossVersionLoop_APEX_D43.t.sol` `_seedBorrowLiquidity` so the loop can borrow tokenB on
 *      V3 and tokenA on V4. Deployed with `new` by the fixture so its `setUp` does not collide with
 *      the hook TestBase's.
 */
contract SeMatrix_AaveLoopHarness is TestBase_AaveCrossVersionLoopV3Market {
    struct Markets {
        IERC20 tokenA;
        IERC20 tokenB;
        IPool v36Pool;
        IPoolAddressesProvider v36AddressesProvider;
        IAaveOracle v36Oracle;
        ISpoke v4Spoke;
        IHub v4Hub;
        IAaveOracleV4 v4Oracle;
    }

    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);

    function protocol() external returns (Markets memory m) {
        TestBase_AaveCrossVersionLoopV3Market.setUp();
        m.tokenA = tokenA;
        m.tokenB = tokenB;
        m.v36Pool = v36Pool;
        m.v36AddressesProvider = IPoolAddressesProvider(v36AddressesProvider);
        m.v36Oracle = IAaveOracle(v36Oracle);
        m.v4Spoke = v4Spoke;
        m.v4Hub = v4Hub;
        m.v4Oracle = IAaveOracleV4(address(v4Oracle));
    }

    /// @dev Verbatim `AaveCrossVersionLoop_APEX_D43_Test._seedBorrowLiquidity`.
    function seedBorrowLiquidity() external {
        _mint(tokenB, v3lp, 2_000_000e6);
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), 2_000_000e6);
        v36Pool.supply(address(tokenB), 2_000_000e6, v3lp, 0);
        vm.stopPrank();
        _mint(tokenA, v4lp, 1_000e18);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), 1_000e18);
        v4Spoke.supply(v4ReserveIdA, 1_000e18, v4lp);
        vm.stopPrank();
    }
}

/**
 * @dev Decimal-face protocol harness (M14): the same local Aave V3.6 + V4 markets as
 *      `SeMatrix_AaveLoopHarness`, but with `tokenA` (the face) at 6 / 9 decimals via
 *      `TestBase_AaveCrossVersionLoopV3Market_Decimals`. `seedBorrowLiquidity` is the decimal-aware
 *      port of the gold harness's seed (`_uA` / `_uB`). `tokenB` stays at the gold 6 decimals.
 */
abstract contract SeMatrix_AaveLoopHarnessDecimals is TestBase_AaveCrossVersionLoopV3Market_Decimals {
    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);

    function protocol() external returns (SeMatrix_AaveLoopHarness.Markets memory m) {
        TestBase_AaveCrossVersionLoopV3Market_Decimals.setUp();
        m.tokenA = tokenA;
        m.tokenB = tokenB;
        m.v36Pool = v36Pool;
        m.v36AddressesProvider = IPoolAddressesProvider(v36AddressesProvider);
        m.v36Oracle = IAaveOracle(v36Oracle);
        m.v4Spoke = v4Spoke;
        m.v4Hub = v4Hub;
        m.v4Oracle = IAaveOracleV4(address(v4Oracle));
    }

    /// @dev Decimal-aware port of `SeMatrix_AaveLoopHarness.seedBorrowLiquidity` (D43 `_seedBorrowLiquidity`).
    function seedBorrowLiquidity() external {
        _mint(tokenB, v3lp, _uB(2_000_000));
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), _uB(2_000_000));
        v36Pool.supply(address(tokenB), _uB(2_000_000), v3lp, 0);
        vm.stopPrank();
        _mint(tokenA, v4lp, _uA(1_000));
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), _uA(1_000));
        v4Spoke.supply(v4ReserveIdA, _uA(1_000), v4lp);
        vm.stopPrank();
    }
}

/// @dev M14 combo `F6`: face `tokenA` 6 decimals, `tokenB` 6 decimals (gold value).
contract SeMatrix_AaveLoopHarnessF6 is SeMatrix_AaveLoopHarnessDecimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}

/// @dev M14 combo `F9`: face `tokenA` 9 decimals, `tokenB` 6 decimals (gold value).
contract SeMatrix_AaveLoopHarnessF9 is SeMatrix_AaveLoopHarnessDecimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}

/**
 * @title SeMatrix_AaveLoopFixture
 * @notice Aave Cross-Version Loop SE row fixture (open item 1 PRD §5, M6, M13). Face token: tokenA
 *         (18-decimal "Cross Loop Token A") of the local Aave V3.6 + V4 markets. The SE is the
 *         registry-deployed `AaveCrossVersionLoopDFPkg` vault for (tokenA, tokenB), deployed exactly
 *         as `AaveCrossVersionLoop_APEX_D43.t.sol` `_initVault` (and the former
 *         `SeMatrix_AaveLoopDeploy` library this fixture replaces, M6) do:
 *         `indexedexManager.deployCrossVersionLoopDFPkg`, then `pkg.deployVault(tokenA, tokenB)`.
 * @dev Package reuse: the package salt is fixed per family
 *      (`AaveCrossVersionLoop_Component_FactoryService.deployCrossVersionLoopDFPkg`), so a second
 *      package on the same manager would collide. Passing a non-zero `existingPkg` reuses that
 *      package and its market: the package keeps its market handles internal, so they are read from
 *      the first vault the registry holds for it (`IAaveCrossVersionLoopVault.tokenA/tokenB/
 *      aaveV36Pool/aaveV4Spoke/aaveV4Hub`) and that vault is rebound as the SE (idempotent).
 *      The R14 partial case is the V3 tokenA supply cap (D43 `_setSupplyCapA`); the cap is whole
 *      tokens, so the reserve is padded by a third-party supply until exactly `allowFace` remains.
 */
contract SeMatrix_AaveLoopFixture is SeMatrixFixture {
    using AaveCrossVersionLoop_Component_FactoryService for ICreate3FactoryProxy;

    uint256 internal constant RAY = 1e27;

    error PackageReuseWithoutVault(address pkg);

    IAaveCrossVersionLoopDFPkg internal pkg_;
    IERC20 public tokenA;
    IERC20 public tokenB;
    IPool internal pool;
    IPoolAddressesProvider internal provider;
    ISpoke internal v4Spoke;
    IHub internal v4Hub;
    address internal seVault;

    /// @param faceDecimals The face `tokenA` decimals: 18 keeps the original gold harness
    ///        byte-identical; 6 / 9 (M14) stand up the market with `tokenA` at that face.
    constructor(Ctx memory c, address existingPkg, uint8 faceDecimals) SeMatrixFixture(c) {
        if (existingPkg == address(0)) {
            SeMatrix_AaveLoopHarness.Markets memory m = _standUpMarket(faceDecimals);
            tokenA = m.tokenA;
            tokenB = m.tokenB;
            pool = m.v36Pool;
            provider = m.v36AddressesProvider;
            v4Spoke = m.v4Spoke;
            v4Hub = m.v4Hub;
            pkg_ = _deployPkg(c, m);
            vm.prank(c.owner);
            seVault = pkg_.deployVault(tokenA, tokenB);
        } else {
            pkg_ = IAaveCrossVersionLoopDFPkg(existingPkg);
            address[] memory existing = IVaultRegistryVaultQuery(address(c.indexedexManager)).vaultsOfPackage(existingPkg);
            if (existing.length == 0) revert PackageReuseWithoutVault(existingPkg);
            seVault = existing[0];
            IAaveCrossVersionLoopVault v = IAaveCrossVersionLoopVault(seVault);
            tokenA = v.tokenA();
            tokenB = v.tokenB();
            pool = IPool(v.aaveV36Pool());
            provider = pool.ADDRESSES_PROVIDER();
            v4Spoke = ISpoke(v.aaveV4Spoke());
            v4Hub = IHub(v.aaveV4Hub());
        }
    }

    /* ----------------------------- deployment ---------------------------- */

    /// @dev Stand up the local Aave loop markets at the chosen face decimals and seed borrow
    ///      liquidity. 18 is the original gold `SeMatrix_AaveLoopHarness` unchanged; 6 / 9 (M14) use
    ///      the decimal harness with `tokenA` at that face.
    function _standUpMarket(uint8 faceDecimals) internal returns (SeMatrix_AaveLoopHarness.Markets memory m) {
        if (faceDecimals == 18) {
            SeMatrix_AaveLoopHarness harness = new SeMatrix_AaveLoopHarness();
            m = harness.protocol();
            harness.seedBorrowLiquidity();
        } else if (faceDecimals == 6) {
            SeMatrix_AaveLoopHarnessF6 harness = new SeMatrix_AaveLoopHarnessF6();
            m = harness.protocol();
            harness.seedBorrowLiquidity();
        } else if (faceDecimals == 9) {
            SeMatrix_AaveLoopHarnessF9 harness = new SeMatrix_AaveLoopHarnessF9();
            m = harness.protocol();
            harness.seedBorrowLiquidity();
        } else {
            revert("SeMatrix_AaveLoopFixture: unsupported face decimals");
        }
    }

    /// @dev Same PkgInit as D43 `_initVault`, on the hook TestBase's manager and permit2.
    function _deployPkg(Ctx memory c, SeMatrix_AaveLoopHarness.Markets memory m)
        internal
        returns (IAaveCrossVersionLoopDFPkg instance)
    {
        IAaveCrossVersionLoopDFPkg.PkgInit memory init;
        init.erc20Facet = c.erc20Facet;
        init.erc5267Facet = c.erc5267Facet;
        init.erc2612Facet = c.erc2612Facet;
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        vm.startPrank(_factoryOwner());
        init.exchangeInFacet = c.create3Factory.deployExchangeInFacet();
        init.exchangeOutFacet = c.create3Factory.deployExchangeOutFacet();
        init.rebalanceFacet = c.create3Factory.deployRebalanceFacet();
        init.markerFacet = c.create3Factory.deployMarkerFacet();
        init.transitionQuoteFacet = c.create3Factory.deployTransitionQuoteFacet();
        vm.stopPrank();
        init.v36Pool = m.v36Pool;
        init.v36AddressesProvider = m.v36AddressesProvider;
        init.v36Oracle = m.v36Oracle;
        init.v4Spoke = m.v4Spoke;
        init.v4Hub = m.v4Hub;
        init.v4Oracle = m.v4Oracle;
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.permit2 = c.permit2;
        vm.prank(c.owner);
        // Multi-leg matrix rows deploy several loop packages on the one shared manager (a distinct Aave
        // market per leg). The fixture address is unique per instance, so it discriminates the package
        // salt to a distinct address; disc==0 (the canonical single-package address) is unchanged for
        // every other caller.
        instance = AaveCrossVersionLoop_Component_FactoryService.deployCrossVersionLoopDFPkg(
            c.indexedexManager, init, bytes32(uint256(uint160(address(this))))
        );
    }

    /* ------------------------------ identity ------------------------------ */

    function pkg() external view returns (address) {
        return address(pkg_);
    }

    function familyName() external pure override returns (string memory) {
        return "AaveCrossVersionLoop";
    }

    function faceToken() public view override returns (address) {
        return address(tokenA);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    /* ------------------------------- funding ------------------------------ */

    /// @dev The pair tokens are `ERC20MintBurnOwnableOperableDFPkg` diamonds owned by the harness
    ///      (`TestBase_AaveCrossVersionLoop._mint`); mint as that owner.
    function fund(address to, uint256 amount) external override {
        _mintAs(tokenA, to, amount);
    }

    function _mintAs(IERC20 token, address to, uint256 amount) internal {
        address tokenOwner = IMultiStepOwnableView(address(token)).owner();
        vm.prank(tokenOwner);
        IERC20MintBurn(address(token)).mint(to, amount);
    }

    /* -------------------------- R14 partial case -------------------------- */

    function hasPartialCase() external pure override returns (bool) {
        return true;
    }

    /// @dev `CrossVersionLoopExecutor.tokenASupplyCapacity` is `supplyCap * 10**dec - used` with
    ///      `used = (scaledTotalSupply + accruedToTreasury).getATokenBalance(normalizedIncome)`. The
    ///      cap is whole tokens (D43 `_setSupplyCapA(wholeTokens)`), so set
    ///      `cap = ceil((used + allow) / unit)` and top the reserve up with a third-party supply of
    ///      `cap * unit - used - allow` so exactly `allow` remains.
    function limitCapacity(uint256 allowFace) external override {
        uint256 unit = 10 ** uint256(IERC20Metadata(address(tokenA)).decimals());
        uint256 used = _currentSupplyCeil();
        uint256 cap = (used + allowFace + unit - 1) / unit;
        uint256 pad = cap * unit - used - allowFace;
        _ensurePoolAdmin();
        IPoolConfigurator(provider.getPoolConfigurator()).setSupplyCap(address(tokenA), cap);
        if (pad > 0) {
            _mintAs(tokenA, address(this), pad);
            tokenA.approve(address(pool), pad);
            pool.supply(address(tokenA), pad, address(this), 0);
        }
    }

    /// @dev Cap 0 is unbounded (D43 `_setSupplyCapA(0)` before the sweep).
    function openCapacity() external override {
        _ensurePoolAdmin();
        IPoolConfigurator(provider.getPoolConfigurator()).setSupplyCap(address(tokenA), 0);
    }

    /// @dev Unsupplied principal retained locally: `CrossVersionLoopExecutor.localTokenA` is
    ///      `tokenA.balanceOf(vault)`, the view D43 asserts ("principal retained locally").
    function seBooked() external view override returns (uint256) {
        return tokenA.balanceOf(seVault);
    }

    function _currentSupplyCeil() internal view returns (uint256) {
        DataTypes.ReserveDataLegacy memory rd = pool.getReserveData(address(tokenA));
        uint256 scaled = IAToken(rd.aTokenAddress).scaledTotalSupply() + uint256(rd.accruedToTreasury);
        uint256 index = pool.getReserveNormalizedIncome(address(tokenA));
        return (scaled * index + RAY - 1) / RAY;
    }

    /// @dev D43 `_setSupplyCapA` adds the market owner as pool admin; the market owner is the ACL admin.
    function _ensurePoolAdmin() internal {
        IACLManager acl = IACLManager(provider.getACLManager());
        if (acl.isPoolAdmin(address(this))) return;
        address admin = provider.getACLAdmin();
        vm.prank(admin);
        acl.addPoolAdmin(address(this));
    }

    /* --------------------------- operative failure ------------------------ */

    /// @dev The hook's tokenA→SE route ends in `CrossVersionLoopExecutor.depositLoopAFirst` →
    ///      `AaveV36Service.supply` → `pool.supply(...)`; the capacity precheck
    ///      (`tokenASupplyCapacity`) is a view and still passes.
    function armOperativeRevert() external override {
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
