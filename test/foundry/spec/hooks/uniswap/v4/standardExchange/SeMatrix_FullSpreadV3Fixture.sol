// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultDFPkg
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {
    UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    FullSpreadLiquidityProvider
} from "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/adversarial/StandardExchangeFullSpreadAdversarialBehavior.sol";

/**
 * @title SeMatrix_FullSpreadV3Fixture
 * @notice `UniswapV3FullSpreadStandardExchangeVault` row fixture (open item 1 PRD §5 / M6).
 *         Face token = pool `token0` (18-decimal `SimpleMintableERC20` minted here); `otherToken()`
 *         = pool `token1`. The SE is deployed through the production FullSpread V3 package on a
 *         hermetic Uniswap V3 3000-fee pool that an independent LP (`FullSpreadLiquidityProvider`,
 *         the `_seedMarket` pattern of `TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial`)
 *         seeds with 50_000e18 full-range liquidity so the SE can quote. The fixture bootstraps the
 *         SE with a 100/100 dual deposit so single-sided face buffering mints shares.
 * @dev Sleeve model (R14 = the `LiquidReserve` sleeve, `_configureSleeve` pattern):
 *      - Default per-vault sleeve is 100% (`IDLE_SLEEVE_WAD`), the configuration the family's own
 *        A0 / E6 / CROPS suites run under (`_configureSleeve(1e18)`): every buffered face stays local
 *        (`localReserve(face)`), no position exists, and an other-token caller never re-pairs the
 *        booked face (D33 row).
 *      - A face-only deposit never deploys at any sleeve: the full-range center plan takes face and
 *        pair 1:1 at the seeded price, so `getLiquidityForAmounts(excess0, 0) == 0`. The pair-side
 *        excess therefore bounds the face that can be invested, which is how `limitCapacity` and
 *        `openCapacity` are expressed (see those functions).
 *      - `seBooked()` is the SE's local face reserve view, `localReserve(token0)`.
 *      - Package deployment is idempotent across fixtures: pass `pkg()` of an earlier fixture as
 *        `existingPkg`. The V3 factory singleton is CREATE3-deployed under a fixed salt, which the
 *        Crane factory resolves idempotently (`Create3FactoryService._create3`).
 */
contract SeMatrix_FullSpreadV3Fixture is SeMatrixFixture {
    using UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;

    /// @dev `TestBase_UniswapV3FullSpreadStandardExchangeVault.DEFAULT_V3_LIQUID_RESERVE_PCT`.
    uint256 public constant FAMILY_SLEEVE_WAD = 0.20e18;
    /// @dev 100% liquid reserve: nothing is deployed, everything stays local.
    uint256 public constant IDLE_SLEEVE_WAD = 1e18;
    /// @dev Lower clamp; 0 would fall back to the type default in the fee oracle.
    uint256 internal constant MIN_SLEEVE_WAD = 0.01e18;
    uint128 internal constant EXTERNAL_LIQUIDITY = 50_000 ether;
    uint256 internal constant EXTERNAL_FUNDING = 100_000 ether;
    uint256 internal constant BOOTSTRAP_AMOUNT = 100 ether;
    uint24 internal constant FEE_MEDIUM = 3000;
    bytes32 internal constant FACTORY_SALT = keccak256("SeMatrix_FullSpreadV3_UniswapV3Factory");

    IUniswapV3FullSpreadStandardExchangeVaultDFPkg internal pkg_;
    IUniswapV3Factory public uniswapV3Factory;
    IUniswapV3Pool public pool;
    SimpleMintableERC20 public token0;
    SimpleMintableERC20 public token1;
    FullSpreadLiquidityProvider public provider;
    address internal seVault;

    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        _deployFactorySingleton(c);
        pkg_ = existingPkg == address(0)
            ? _deployPkg(c)
            : IUniswapV3FullSpreadStandardExchangeVaultDFPkg(existingPkg);
        _createMarket();
        vm.prank(c.owner);
        seVault = pkg_.deployVault(pool);
        _setSleeve(IDLE_SLEEVE_WAD);
        _seedMarket();
        _bootstrapVault();
    }

    /* ----------------------------- deployment ----------------------------- */

    /// @dev Shared heavy singleton: CREATE3 under a fixed salt through the Crane factory, which
    ///      returns the existing deployment when the salt is occupied. Creation code is loaded from
    ///      `out/` so the fixture's own runtime stays under EIP-170.
    function _deployFactorySingleton(Ctx memory c) internal {
        bytes memory code = ArtifactCreationCode.creationCode("UniswapV3Factory.sol:UniswapV3Factory");
        address factoryOwner = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.prank(factoryOwner);
        uniswapV3Factory = IUniswapV3Factory(c.create3Factory.create3(code, FACTORY_SALT));
    }

    function _deployPkg(Ctx memory c) internal returns (IUniswapV3FullSpreadStandardExchangeVaultDFPkg pkgOut) {
        address factoryOwner = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.startPrank(factoryOwner);
        IUniswapV3FullSpreadStandardExchangeVaultDFPkg.PkgInit memory init = _facetInit(c);
        vm.stopPrank();
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.permit2 = c.permit2;
        init.uniswapV3Factory = uniswapV3Factory;
        vm.startPrank(c.owner);
        IVaultFeeOracleManager(address(c.indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId, FAMILY_SLEEVE_WAD
        );
        pkgOut = UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService
            .deployUniswapV3FullSpreadStandardExchangeVaultDFPkg(c.indexedexManager, init);
        vm.stopPrank();
    }

    /// @dev Same facet wiring as `TestBase_UniswapV3FullSpreadStandardExchangeVault.setUp`.
    function _facetInit(Ctx memory c)
        internal
        returns (IUniswapV3FullSpreadStandardExchangeVaultDFPkg.PkgInit memory init)
    {
        init.erc20Facet = c.erc20Facet;
        init.erc5267Facet = c.erc5267Facet;
        init.erc2612Facet = c.erc2612Facet;
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        init.uniswapV3StandardExchangeInFacet =
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInFacet();
        init.uniswapV3StandardExchangeInQueryFacet =
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInQueryFacet();
        init.uniswapV3StandardExchangeOutFacet =
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutFacet();
        init.uniswapV3StandardExchangeOutQueryFacet =
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutQueryFacet();
        init.uniswapV3StandardExchangePositionImportFacet =
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultPositionImportFacet();
        init.uniswapV3StandardExchangeLiquidReserveFacet =
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet();
        init = UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService
            .attachUniswapV3FullSpreadStandardExchangeVaultMultiFacets(
            init,
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInMultiFacet(),
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet(),
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutMultiFacet(),
            c.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet()
        );
    }

    function _createMarket() internal {
        SimpleMintableERC20 a = new SimpleMintableERC20("FullSpread V3 Face", "FS3A");
        SimpleMintableERC20 b = new SimpleMintableERC20("FullSpread V3 Pair", "FS3B");
        (token0, token1) = address(a) < address(b) ? (a, b) : (b, a);
        pool = IUniswapV3Pool(uniswapV3Factory.createPool(address(token0), address(token1), FEE_MEDIUM));
        pool.initialize(uint160(uint256(1) << 96));
    }

    /// @dev `_seedMarket` of the V3 adversarial TestBase: an independent LP mints full-range liquidity.
    function _seedMarket() internal {
        provider = new FullSpreadLiquidityProvider();
        token0.mint(address(provider), EXTERNAL_FUNDING);
        token1.mint(address(provider), EXTERNAL_FUNDING);
        provider.addV3(pool, EXTERNAL_LIQUIDITY);
    }

    /// @dev First mint through the real dual-deposit route at the idle sleeve (nothing deployed).
    function _bootstrapVault() internal {
        token0.mint(address(this), BOOTSTRAP_AMOUNT);
        token1.mint(address(this), BOOTSTRAP_AMOUNT);
        token0.approve(seVault, BOOTSTRAP_AMOUNT);
        token1.approve(seVault, BOOTSTRAP_AMOUNT);
        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory amts = new uint256[](2);
        amts[0] = BOOTSTRAP_AMOUNT;
        amts[1] = BOOTSTRAP_AMOUNT;
        IStandardExchangeInMulti(seVault).exchangeInManyToOne(
            toks, amts, IERC20(seVault), 0, address(this), false, block.timestamp
        );
    }

    /* ------------------------------- sleeve ------------------------------- */

    function _lr() internal view returns (IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve) {
        return IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve(seVault);
    }

    /// @dev `_configureSleeve` of the adversarial TestBase: owner sets the per-vault liquid reserve.
    function _setSleeve(uint256 pct) internal {
        vm.prank(ctx.owner);
        IVaultFeeOracleManager(address(ctx.indexedexManager)).setLiquidReservePercentageOfVault(seVault, pct);
    }

    /// @dev The independent LP adds the pair side through the SE's real deposit route while the
    ///      sleeve is idle (no deployment), then the family default sleeve is restored, so the NEXT
    ///      face deposit finds excess on both sides and deploys through `pool.mint`.
    function _openInvestment() internal {
        _setSleeve(IDLE_SLEEVE_WAD);
        (uint256 dep0,) = _lr().deployedReserve();
        uint256 amount = 2 * (_lr().localReserve(address(token0)) + dep0) + 1 ether;
        token1.mint(address(this), amount);
        token1.approve(seVault, amount);
        IStandardExchangeIn(seVault).exchangeIn(
            IERC20(address(token1)), amount, IERC20(seVault), 0, address(this), false, block.timestamp
        );
        _setSleeve(FAMILY_SLEEVE_WAD);
    }

    /* ------------------------------ identity ------------------------------ */

    function familyName() external pure override returns (string memory) {
        return "UniswapV3FullSpreadStandardExchangeVault";
    }

    function pkg() external view returns (address) {
        return address(pkg_);
    }

    function faceToken() public view override returns (address) {
        return address(token0);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    /* ------------------------------- funding ------------------------------ */

    function fund(address to, uint256 amount) external override {
        token0.mint(to, amount);
    }

    /* ---------------------------- R14 partial case ------------------------ */

    function hasPartialCase() external pure override returns (bool) {
        return true;
    }

    /// @notice Closest expressible allowance. The full-range center takes face and pair 1:1 at the
    ///         seeded price, so the invested face is bounded by the pair-side excess above the sleeve
    ///         target. The sleeve is set so that excess equals 99% of `allowFace`: the next face
    ///         deposit invests just under `allowFace` and books the rest locally (D22 / D31). The
    ///         1% margin absorbs rounding; `allowFace == 0` resolves to the idle sleeve.
    function limitCapacity(uint256 allowFace) external override {
        uint256 free1 = _lr().localReserve(address(token1));
        (, uint256 dep1) = _lr().deployedReserve();
        uint256 pairExcess = allowFace - allowFace / 100;
        uint256 pct;
        if (pairExcess >= free1) {
            pct = MIN_SLEEVE_WAD;
        } else {
            pct = ((free1 - pairExcess) * 1e18) / (free1 + dep1);
        }
        if (pct < MIN_SLEEVE_WAD) pct = MIN_SLEEVE_WAD;
        if (pct > IDLE_SLEEVE_WAD) pct = IDLE_SLEEVE_WAD;
        _setSleeve(pct);
    }

    /// @notice Restores the family default sleeve with enough pair-side inventory that the next
    ///         investing operation sweeps the booked face into the pool.
    function openCapacity() external override {
        _openInvestment();
    }

    function seBooked() external view override returns (uint256) {
        return _lr().localReserve(address(token0));
    }

    /* --------------------------- operative failure ------------------------ */

    /// @notice Makes the SE's operative investment call (`IUniswapV3Pool.mint`, reached from
    ///         `_rebalanceLiquidReserveBestEffort` -> `_deployExcessLiquidity` -> `_mintLiquidity`)
    ///         revert with `rejectBytes()`. The pair side is supplied first so the next face deposit
    ///         reaches that call; previews stay view-only and keep passing.
    function armOperativeRevert() external override {
        _openInvestment();
        vm.mockCallRevert(address(pool), abi.encodeWithSelector(bytes4(keccak256("mint(address,int24,int24,uint128,bytes)"))), rejectBytes());
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    /* --------------------------------- AMM -------------------------------- */

    function isAmm() external pure override returns (bool) {
        return true;
    }

    function otherToken() external view override returns (address) {
        return address(token1);
    }

    function fundOther(address to, uint256 amount) external override {
        token1.mint(to, amount);
    }
}
