// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4FullSpreadStandardExchangeVaultDFPkg
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {
    UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol";
import {
    IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {UniswapV4TwapOracleFactoryService} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapOracleFactoryService.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    FullSpreadLiquidityProvider
} from "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/adversarial/StandardExchangeFullSpreadAdversarialBehavior.sol";

/**
 * @title SeMatrix_FullSpreadV4Fixture
 * @notice `UniswapV4FullSpreadStandardExchangeVault` row fixture, ERC-20 variant only (open item 1
 *         PRD §5 / M6; the native-ETH variant is out of scope for the hook rows). Face token = pool
 *         `currency0` (18-decimal `SimpleMintableERC20` minted here); `otherToken()` = `currency1`.
 *         The SE is deployed through the production FullSpread V4 package on its own CREATE3
 *         `PoolManager` (separate from the hook's) with a 3000-fee / 60-spacing pool that an
 *         independent LP (`FullSpreadLiquidityProvider`, the `_seedMarket` pattern of
 *         `TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial`) seeds with 50_000e18
 *         full-range liquidity so the SE can quote. The fixture bootstraps the SE with a 100/100
 *         dual deposit so single-sided face buffering mints shares.
 * @dev Sleeve model (R14 = the `LiquidReserve` sleeve, `_configureSleeve` pattern):
 *      - Default per-vault sleeve is 100% (`IDLE_SLEEVE_WAD`), the configuration the family's own
 *        A0 / E6 / CROPS suites run under (`_configureSleeve(1e18)`): every buffered face stays local
 *        (`localReserve(face)`), no position exists, and an other-token caller never re-pairs the
 *        booked face (D33 row).
 *      - A face-only deposit never deploys at any sleeve: the full-range center plan takes face and
 *        pair 1:1 at the seeded price, so `getLiquidityForAmounts(excess0, 0) == 0`. The pair-side
 *        excess therefore bounds the face that can be invested, which is how `limitCapacity` and
 *        `openCapacity` are expressed (see those functions).
 *      - `seBooked()` is the SE's local face reserve view, `localReserve(currency0)`.
 *      - Package deployment is idempotent across fixtures: pass `pkg()` of an earlier fixture as
 *        `existingPkg`. The `PoolManager` singleton is CREATE3-deployed under a fixed salt, which
 *        the Crane factory resolves idempotently (`Create3FactoryService._create3WithArgs`), so a
 *        reused package and a new fixture always meet on the same `PoolManager`.
 */
contract SeMatrix_FullSpreadV4Fixture is SeMatrixFixture {
    using UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4TwapOracleFactoryService for ICreate3FactoryProxy;

    /// @dev `TestBase_UniswapV4FullSpreadStandardExchangeVault.DEFAULT_V4_LIQUID_RESERVE_PCT`.
    uint256 public constant FAMILY_SLEEVE_WAD = 0.2e18;
    /// @dev 100% liquid reserve: nothing is deployed, everything stays local.
    uint256 public constant IDLE_SLEEVE_WAD = 1e18;
    /// @dev Lower clamp; 0 would fall back to the type default in the fee oracle.
    uint256 internal constant MIN_SLEEVE_WAD = 0.01e18;
    uint128 internal constant EXTERNAL_LIQUIDITY = 50_000 ether;
    uint256 internal constant EXTERNAL_FUNDING = 100_000 ether;
    uint256 internal constant BOOTSTRAP_AMOUNT = 100 ether;
    uint24 internal constant POOL_FEE = 3000;
    int24 internal constant POOL_TICK_SPACING = 60;
    bytes32 internal constant POOL_MANAGER_SALT = keccak256("SeMatrix_FullSpreadV4_PoolManager");

    IUniswapV4FullSpreadStandardExchangeVaultDFPkg internal pkg_;
    IPoolManager public poolManager;
    IWETH public weth;
    SimpleMintableERC20 public token0;
    SimpleMintableERC20 public token1;
    FullSpreadLiquidityProvider public provider;
    PoolKey internal poolKey;
    address internal seVault;

    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        _deployPoolManagerSingleton(c);
        pkg_ = existingPkg == address(0)
            ? _deployPkg(c)
            : IUniswapV4FullSpreadStandardExchangeVaultDFPkg(existingPkg);
        _createMarket();
        vm.prank(c.owner);
        seVault = pkg_.deployVault(poolKey);
        _setSleeve(IDLE_SLEEVE_WAD);
        _seedMarket();
        _bootstrapVault();
    }

    /* ----------------------------- deployment ----------------------------- */

    /// @dev Shared heavy singleton: CREATE3 under a fixed salt through the Crane factory, which
    ///      returns the existing deployment when the salt is occupied (constructor args ignored then).
    function _deployPoolManagerSingleton(Ctx memory c) internal {
        address factoryOwner = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.startPrank(factoryOwner);
        poolManager = IPoolManager(
            c.create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(c.create3Factory, "PoolManager.sol:PoolManager"),
                abi.encode(address(this)),
                POOL_MANAGER_SALT
            )
        );
        vm.stopPrank();
    }

    function _deployPkg(Ctx memory c) internal returns (IUniswapV4FullSpreadStandardExchangeVaultDFPkg pkgOut) {
        address factoryOwner = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.startPrank(factoryOwner);
        IUniswapV4MultiPoolTwapOracle twap = _deployTwap(c);
        IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory init = _facetInit(c);
        vm.stopPrank();
        weth = IWETH(address(new WETH9()));
        init.weth = weth;
        init = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.attachTwapOracle(init, twap);
        init.positionManager = IPositionManager(address(0));
        vm.startPrank(c.owner);
        IVaultFeeOracleManager(address(c.indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve).interfaceId, FAMILY_SLEEVE_WAD
        );
        pkgOut = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService
            .deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(c.indexedexManager, init);
        vm.stopPrank();
    }

    /// @dev Same TWAP wiring as `TestBase_UniswapV4FullSpreadStandardExchangeVault.setUp`.
    function _deployTwap(Ctx memory c) internal returns (IUniswapV4MultiPoolTwapOracle twap) {
        IUniswapV4MultiPoolTwapOracleDFPkg twapPkg = c.create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(
            c.create3Factory.deployUniswapV4MultiPoolTwapOracleFacet(), c.create3Factory.diamondPackageFactory()
        );
        twap = twapPkg.deployOracle(IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(poolManager)}));
    }

    /// @dev Same facet wiring as `TestBase_UniswapV4FullSpreadStandardExchangeVault._univ4SePkgInitCore`.
    function _facetInit(Ctx memory c)
        internal
        returns (IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory init)
    {
        UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.Univ4SePkgInitCore memory core;
        core.erc20Facet = c.erc20Facet;
        core.erc5267Facet = c.erc5267Facet;
        core.erc2612Facet = c.erc2612Facet;
        core.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        core.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        core.uniswapV4StandardExchangeInFacet =
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInFacet();
        core.uniswapV4StandardExchangeInQueryFacet =
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInQueryFacet();
        core.uniswapV4StandardExchangePositionImportFacet =
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultPositionImportFacet();
        core.uniswapV4StandardExchangeOutFacet =
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutFacet();
        core.uniswapV4StandardExchangeOutQueryFacet =
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutQueryFacet();
        core.uniswapV4StandardExchangeLiquidReserveFacet =
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet();
        core.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        core.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        core.permit2 = c.permit2;
        core.poolManager = poolManager;
        init = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService
            .buildArgsUniswapV4FullSpreadStandardExchangeVaultPkgInit(core);
        init = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService
            .attachUniswapV4FullSpreadStandardExchangeVaultMultiFacets(
            init,
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInMultiFacet(),
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet(),
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutMultiFacet(),
            c.create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet()
        );
    }

    function _createMarket() internal {
        SimpleMintableERC20 a = new SimpleMintableERC20("FullSpread V4 Face", "FS4A");
        SimpleMintableERC20 b = new SimpleMintableERC20("FullSpread V4 Pair", "FS4B");
        (token0, token1) = address(a) < address(b) ? (a, b) : (b, a);
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: POOL_FEE,
            tickSpacing: POOL_TICK_SPACING,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(poolKey, uint160(uint256(1) << 96));
    }

    /// @dev `_seedMarket` of the V4 adversarial TestBase: an independent LP adds full-range liquidity.
    ///      `weth` is only consulted by the provider for native currencies; ERC-20 pools ignore it.
    function _seedMarket() internal {
        provider = new FullSpreadLiquidityProvider();
        token0.mint(address(provider), EXTERNAL_FUNDING);
        token1.mint(address(provider), EXTERNAL_FUNDING);
        provider.addV4(poolManager, poolKey, weth, EXTERNAL_LIQUIDITY);
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

    function _lr() internal view returns (IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve) {
        return IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve(seVault);
    }

    /// @dev `_configureSleeve` of the adversarial TestBase: owner sets the per-vault liquid reserve.
    function _setSleeve(uint256 pct) internal {
        vm.prank(ctx.owner);
        IVaultFeeOracleManager(address(ctx.indexedexManager)).setLiquidReservePercentageOfVault(seVault, pct);
    }

    /// @dev The independent LP adds the pair side through the SE's real deposit route while the
    ///      sleeve is idle (no deployment), then the family default sleeve is restored, so the NEXT
    ///      face deposit finds excess on both sides and deploys through `poolManager.unlock`.
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
        return "UniswapV4FullSpreadStandardExchangeVault";
    }

    function pkg() external view returns (address) {
        return address(pkg_);
    }

    function market() external view returns (PoolKey memory) {
        return poolKey;
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

    /// @notice Makes the SE's operative investment call (`IPoolManager.unlock` on the SE's own
    ///         `PoolManager`, reached from `_rebalanceLiquidReserveBestEffort` ->
    ///         `_deployExcessLiquidity` -> `_executeUnlock(AddLiquidity)`) revert with
    ///         `rejectBytes()`. The pair side is supplied first so the next face deposit reaches that
    ///         call; previews stay view-only and keep passing. The hook's own `PoolManager` is a
    ///         different instance and is not touched.
    function armOperativeRevert() external override {
        _openInvestment();
        vm.mockCallRevert(address(poolManager), abi.encodeWithSelector(IPoolManager.unlock.selector), rejectBytes());
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
