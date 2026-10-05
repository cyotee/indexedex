// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMiner} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IPositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/external/IWETH9.sol";
import {PositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionManager.sol";
import {PositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionDescriptor.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {PonsV2FeeEscrow} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2FeeEscrow.sol";
import {PonsV2BuybackVault} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BuybackVault.sol";
import {PonsV2LaunchLocker} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchLocker.sol";
import {PonsV2MemeHook} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol";
import {PonsV2LaunchFactory} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchFactory.sol";
import {PonsV2LaunchDeployer} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchDeployer.sol";
import {PonsV2GraduationExecutor} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2GraduationExecutor.sol";
import {PonsV2LauncherToken} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LauncherToken.sol";
import {PonsV2BondingCurve} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BondingCurve.sol";
import {GraduationPhase} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";
import {IPonsV2LaunchFactory} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    IUniswapV4FullSpreadPonsFamilyHookDFPkg
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/IUniswapV4FullSpreadPonsFamilyHookDFPkg.sol";
import {
    UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService as PonsFactory
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.sol";
import {
    IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {UniswapV4TwapOracleFactoryService} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapOracleFactoryService.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrixRejectingERC20} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {Univ4LiquiditySeeder} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title SeMatrix_FullSpreadPonsV2Fixture
 * @notice Pons-family row for the hook x SE matrix. One shared mined meme hook and package;
 *         each fixture launches and graduates its own pool so multi-leg rows get distinct faces.
 * @dev Hook fee is 0. Fee-semantics coverage stays in the Pons family suite. Graduation only
 *      sweeps 4.2 pair units, so the fixture adds in-range liquidity before any 1-unit quote.
 *      Share exact-out remains InvalidRoute. Bounds are not widened.
 */
contract SeMatrix_FullSpreadPonsV2Fixture is SeMatrixFixture, IUnlockCallback {
    using stdStorage for StdStorage;
    using PonsFactory for ICreate3FactoryProxy;
    using PonsFactory for IIndexedexManagerProxy;
    using UniswapV4TwapOracleFactoryService for ICreate3FactoryProxy;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 internal constant FAMILY_SLEEVE_WAD = 0.2e18;
    uint256 internal constant IDLE_SLEEVE_WAD = 1e18;
    uint256 internal constant BOOTSTRAP_AMOUNT = 100 ether;
    uint256 internal constant LAUNCH_FEE = 0.0005 ether;
    uint256 internal constant SUPPLY = 1_000_000_000 ether;
    uint256 internal constant PHANTOM = 1 ether;
    uint256 internal constant GRADUATION = 4.2 ether;
    uint24 internal constant POOL_FEE = 0;
    int24 internal constant TICK_SPACING = 60;
    uint160 internal constant MEME_HOOK_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
    );
    bytes32 internal constant REGISTRY_SALT = keccak256("SeMatrix_FullSpreadPonsV2_Registry");
    bytes32 internal constant POOL_MANAGER_SALT = keccak256("SeMatrix_FullSpreadPonsV2_PoolManager");

    StdStorage internal store_;
    IUniswapV4FullSpreadPonsFamilyHookDFPkg internal pkg_;
    SeMatrixPonsRegistry internal registry;
    SeMatrixRejectingERC20 public face;
    address public launchToken;
    PoolKey internal poolKey;
    address internal seVault;

    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        registry = _registry(c);
        _ensureStack(c);
        pkg_ = existingPkg == address(0) ? _deployPkg(c) : IUniswapV4FullSpreadPonsFamilyHookDFPkg(existingPkg);
        require(keccak256(bytes(pkg_.packageName())) == keccak256("UniswapV4FullSpreadPonsFamilyHookDFPkg"), "matrix: stale family");
        _launchAndVault(c);
    }

    function _registry(Ctx memory c) internal returns (SeMatrixPonsRegistry reg) {
        address factoryOwner = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.prank(factoryOwner);
        reg = SeMatrixPonsRegistry(c.create3Factory.create3WithArgs(type(SeMatrixPonsRegistry).creationCode, "", REGISTRY_SALT));
    }

    function _ensureStack(Ctx memory c) internal {
        if (registry.ready()) return;
        address factoryOwner = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.prank(factoryOwner);
        IPoolManager pm = IPoolManager(c.create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(c.create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            POOL_MANAGER_SALT
        ));
        IWETH weth = IWETH(address(new WETH9()));
        address ponsOwner = vm.addr(uint256(keccak256("seMatrixPonsOwner")));
        address sink = vm.addr(uint256(keccak256("seMatrixPonsSink")));
        address launcher = vm.addr(uint256(keccak256("seMatrixPonsLauncher")));
        PonsV2FeeEscrow escrow = new PonsV2FeeEscrow();
        bytes memory hookArgs = abi.encode(pm, escrow, sink, ponsOwner);
        (address predicted, bytes32 salt) = HookMiner.find(
            address(registry), MEME_HOOK_FLAGS,
            ArtifactCreationCode.creationCode(c.create3Factory, "PonsV2MemeHook.sol:PonsV2MemeHook"), hookArgs
        );
        PonsV2MemeHook hook = registry.deployHook(pm, escrow, sink, ponsOwner, salt);
        require(address(hook) == predicted, "hook address mismatch");
        IPositionManager positionManager = _positionManager(pm, weth, c);
        (PonsV2LaunchFactory factory, uint256 configId) = _wireFactory(c, pm, hook, escrow, ponsOwner, positionManager);
        SeMatrixPonsRegistry.Init memory init_;
        init_.poolManager = pm;
        init_.hook = hook;
        init_.factory = factory;
        init_.positionManager = positionManager;
        init_.weth = weth;
        init_.launcher = launcher;
        init_.owner = ponsOwner;
        init_.configId = configId;
        registry.init(init_);
        vm.deal(launcher, 100 ether);
        vm.deal(address(this), 100 ether);
    }

    function _positionManager(IPoolManager pm, IWETH weth, Ctx memory c) internal returns (IPositionManager) {
        IPositionDescriptor descriptor = new PositionDescriptor(pm, address(weth), bytes32("ETH"));
        return IPositionManager(address(new PositionManager(
            pm, IAllowanceTransfer(address(c.permit2)), 100_000, descriptor, IWETH9(address(weth))
        )));
    }

    function _wireFactory(
        Ctx memory c, IPoolManager pm, PonsV2MemeHook hook, PonsV2FeeEscrow escrow, address ponsOwner, IPositionManager positionManager
    ) internal returns (PonsV2LaunchFactory factory, uint256 configId) {
        vm.startPrank(ponsOwner);
        PonsV2BuybackVault buyback = new PonsV2BuybackVault(ponsOwner, hook, escrow);
        PonsV2LaunchLocker locker = new PonsV2LaunchLocker(ponsOwner, address(positionManager));
        factory = new PonsV2LaunchFactory(
            ponsOwner, pm, positionManager, IAllowanceTransfer(address(c.permit2)), locker, hook, escrow, buyback, LAUNCH_FEE
        );
        factory.setLaunchDeployer(new PonsV2LaunchDeployer(address(factory)));
        factory.setGraduationExecutor(new PonsV2GraduationExecutor(
            positionManager, IAllowanceTransfer(address(c.permit2)), locker, address(factory)
        ));
        hook.setFactory(address(factory));
        hook.setBuybackVault(buyback);
        buyback.setFactory(address(factory));
        locker.setFactory(address(factory));
        configId = factory.addLaunchConfig(PonsV2LaunchFactory.LaunchConfig({
            supply: SUPPLY, curveFeeBps: 100, phantomQuote: PHANTOM, graduationThreshold: GRADUATION,
            poolFee: POOL_FEE, tickSpacing: TICK_SPACING, enabled: true
        }));
        factory.setSnipeTaxStartBps(0);
        factory.setLaunchEnabled(true);
        hook.setHookFeeBps(0);
        vm.stopPrank();
    }

    function _deployPkg(Ctx memory c) internal returns (IUniswapV4FullSpreadPonsFamilyHookDFPkg pkgOut) {
        address factoryOwner = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.startPrank(factoryOwner);
        IUniswapV4MultiPoolTwapOracleDFPkg twapPkg = c.create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(
            c.create3Factory.deployUniswapV4MultiPoolTwapOracleFacet(), c.create3Factory.diamondPackageFactory()
        );
        IUniswapV4MultiPoolTwapOracle twap = twapPkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(registry.poolManager())})
        );
        PonsFactory.Univ4SePkgInitCore memory core;
        core.erc20Facet = c.erc20Facet;
        core.erc5267Facet = c.erc5267Facet;
        core.erc2612Facet = c.erc2612Facet;
        core.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        core.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        core.uniswapV4StandardExchangeInFacet = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookInFacet();
        core.uniswapV4StandardExchangeInQueryFacet = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookInQueryFacet();
        core.uniswapV4StandardExchangePositionImportFacet = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookPositionImportFacet();
        core.uniswapV4StandardExchangeOutFacet = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookOutFacet();
        core.uniswapV4StandardExchangeOutQueryFacet = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookOutQueryFacet();
        core.uniswapV4StandardExchangeLiquidReserveFacet = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet();
        core.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        core.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        core.permit2 = c.permit2;
        core.poolManager = registry.poolManager();
        core.weth = registry.weth();
        IFacet inMulti = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookInMultiFacet();
        IFacet inMultiQuery = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookInMultiQueryFacet();
        IFacet outMulti = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookOutMultiFacet();
        IFacet outMultiQuery = c.create3Factory.deployUniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet();
        vm.stopPrank();
        IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory init = PonsFactory.buildArgsUniswapV4FullSpreadPonsFamilyHookPkgInit(core);
        init = PonsFactory.attachTwapOracle(init, twap);
        init.positionManager = registry.positionManager();
        init.expectedHook = address(registry.hook());
        init = PonsFactory.attachUniswapV4FullSpreadPonsFamilyHookMultiFacets(init, inMulti, inMultiQuery, outMulti, outMultiQuery);
        vm.startPrank(c.owner);
        IVaultFeeOracleManager(address(c.indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV4FullSpreadPonsFamilyHookLiquidReserve).interfaceId, FAMILY_SLEEVE_WAD
        );
        pkgOut = c.indexedexManager.deployUniswapV4FullSpreadPonsFamilyHookDFPkg(init);
        vm.stopPrank();
    }

    function _launchAndVault(Ctx memory c) internal {
        uint256 nonce = registry.nextNonce();
        face = new SeMatrixRejectingERC20(string.concat("PonsFace", _digits(nonce)), string.concat("PF", _digits(nonce)));
        PonsV2LaunchFactory factory = registry.factory();
        vm.startPrank(registry.owner());
        factory.setPairTokenEconomics(address(face), PHANTOM, GRADUATION, 18);
        factory.setPairTokenApproved(address(face), true);
        vm.stopPrank();
        PonsV2LaunchFactory.TokenParams memory params = PonsV2LaunchFactory.TokenParams({
            name: string.concat("PonsLeg", _digits(nonce)),
            symbol: string.concat("PL", _digits(nonce)),
            logo: "ipfs://logo",
            description: "matrix pons leg",
            socials: PonsV2LauncherToken.Socials({twitter: "https://x.com/pons", telegram: "", discord: "", website: "https://pons.family", farcaster: ""}),
            creatorFeeRecipient: address(0),
            creatorTaxBps: 0,
            buybackEnabled: false,
            expectedEconomics: bytes32(0),
            salt: keccak256(abi.encode("se-matrix-pons", nonce))
        });
        vm.deal(address(this), 1 ether);
        vm.deal(registry.launcher(), 1 ether);
        vm.prank(registry.launcher());
        (address token_, address curve_) = factory.launchToken{value: LAUNCH_FEE}(params, registry.configId(), address(face));
        launchToken = token_;
        face.mint(address(this), 10 ether);
        face.approve(curve_, 10 ether);
        PonsV2BondingCurve(payable(curve_)).buy(10 ether, 0, address(this));
        IPonsV2LaunchFactory.LaunchedToken memory rec = factory.getLaunchedToken(token_);
        if (rec.phase == GraduationPhase.NotGraduated) factory.graduate(token_);
        rec = factory.getLaunchedToken(token_);
        if (rec.phase == GraduationPhase.Swept) factory.createGraduatedPool(token_);
        rec = factory.getLaunchedToken(token_);
        require(rec.phase == GraduationPhase.PoolCreated, "pons matrix not graduated");
        poolKey = _key(token_, rec);
        _deepen();
        vm.prank(c.owner);
        seVault = pkg_.deployVault(poolKey);
        _setSleeve(IDLE_SLEEVE_WAD);
        _bootstrap();
    }

    function _key(address token, IPonsV2LaunchFactory.LaunchedToken memory rec) internal view returns (PoolKey memory key) {
        (address token0, address token1) = rec.pairToken < token ? (rec.pairToken, token) : (token, rec.pairToken);
        key = PoolKey({
            currency0: Currency.wrap(token0), currency1: Currency.wrap(token1),
            fee: rec.poolFee, tickSpacing: rec.tickSpacing, hooks: IHooks(address(registry.hook()))
        });
    }

    function _deepen() internal {
        IPoolManager pm = registry.poolManager();
        (uint160 sqrtP, int24 tick,,) = pm.getSlot0(poolKey.toId());
        int24 spacing = poolKey.tickSpacing;
        int24 center = (tick / spacing) * spacing;
        int24 lower = center - (40 * spacing);
        int24 upper = center + (40 * spacing);
        uint256 faceFunding = 1_000_000 ether;
        uint256 otherFunding = _otherForFace(sqrtP, faceFunding);
        if (otherFunding == 0) otherFunding = 1;
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP, TickMath.getSqrtPriceAtTick(lower), TickMath.getSqrtPriceAtTick(upper),
            address(face) == Currency.unwrap(poolKey.currency0) ? faceFunding : otherFunding,
            address(face) == Currency.unwrap(poolKey.currency0) ? otherFunding : faceFunding
        );
        Univ4LiquiditySeeder seeder = new Univ4LiquiditySeeder(pm);
        face.mint(address(seeder), faceFunding);
        _deal(launchToken, address(seeder), otherFunding);
        seeder.addLiquidity(poolKey, lower, upper, liq);
    }

    function _bootstrap() internal {
        address[] memory discovered = IBasicVault(seVault).vaultTokens();
        address[] memory toks = new address[](2);
        uint256 n;
        for (uint256 i; i < discovered.length && n < 2; ++i) {
            if (discovered[i] == seVault) continue;
            toks[n++] = discovered[i];
        }
        require(n == 2, "two pool assets");
        uint256[] memory amts = new uint256[](2);
        amts[0] = BOOTSTRAP_AMOUNT;
        amts[1] = BOOTSTRAP_AMOUNT;
        _pay(toks[0], address(this), amts[0]);
        _pay(toks[1], address(this), amts[1]);
        IERC20(toks[0]).approve(seVault, amts[0]);
        IERC20(toks[1]).approve(seVault, amts[1]);
        IStandardExchangeInMulti(seVault).exchangeInManyToOne(toks, amts, IERC20(seVault), 0, address(this), false, block.timestamp);
    }

    function _deal(address token, address to, uint256 give) internal {
        store_.target(token).sig("balanceOf(address)").with_key(to).checked_write(give);
    }

    function _pay(address token, address to, uint256 amount) internal {
        if (token == address(face)) face.mint(to, amount);
        else _deal(token, to, IERC20(token).balanceOf(to) + amount);
    }

    function _digits(uint256 n) internal pure returns (string memory) {
        if (n == 0) return "0";
        bytes memory buf = new bytes(8);
        uint256 len;
        while (n != 0) {
            buf[len++] = bytes1(uint8(48 + n % 10));
            n /= 10;
        }
        bytes memory out = new bytes(len);
        for (uint256 i; i < len; ++i) out[i] = buf[len - 1 - i];
        return string(out);
    }

    function _lr() internal view returns (IUniswapV4FullSpreadPonsFamilyHookLiquidReserve) {
        return IUniswapV4FullSpreadPonsFamilyHookLiquidReserve(seVault);
    }

    function _setSleeve(uint256 pct) internal {
        vm.prank(ctx.owner);
        IVaultFeeOracleManager(address(ctx.indexedexManager)).setLiquidReservePercentageOfVault(seVault, pct);
    }

    function familyName() external pure override returns (string memory) {
        return "UniswapV4FullSpreadPonsFamilyHook";
    }

    function pkg() external view returns (address) { return address(pkg_); }
    function market() external view returns (PoolKey memory) { return poolKey; }

    /// @dev Other-token raw amount that matches `faceAmt` at the graduated spot. Behavior rows that
    ///      pass `1 ether` assume a 1:1 book; this Pons pool is not 1:1.
    function fairOther(uint256 faceAmt) external view returns (uint256) {
        (uint160 sqrtP,,,) = registry.poolManager().getSlot0(poolKey.toId());
        return _otherForFace(sqrtP, faceAmt);
    }

    function _otherForFace(uint160 sqrtP, uint256 faceAmt) internal view returns (uint256) {
        uint256 priceX192 = uint256(sqrtP) * uint256(sqrtP);
        if (address(face) == Currency.unwrap(poolKey.currency0)) return Math.mulDiv(faceAmt, priceX192, uint256(1) << 192);
        if (priceX192 == 0) return 0;
        return Math.mulDiv(faceAmt, uint256(1) << 192, priceX192);
    }
    function faceToken() public view override returns (address) { return address(face); }
    function se() public view override returns (address) { return seVault; }
    function fund(address to, uint256 amount) external override { face.mint(to, amount); }
    function otherToken() external view override returns (address) { return launchToken; }
    function fundOther(address to, uint256 amount) external override { _pay(launchToken, to, amount); }
    function isAmm() external pure override returns (bool) { return true; }
    function hasPartialCase() external pure override returns (bool) { return true; }

    function limitCapacity(uint256 allowFace) external override {
        require(allowFace == 0, "P capacity is measured under an actual outer unlock");
        _setSleeve(IDLE_SLEEVE_WAD);
    }

    function openCapacity() external override { _setSleeve(FAMILY_SLEEVE_WAD); }
    function seBooked() external view override returns (uint256) { return _lr().localReserve(address(face)); }

    function armOperativeRevert() external override { face.setRejection(seVault, rejectBytes()); }
    function disarmOperativeRevert() external override { face.setRejection(address(0), bytes("")); }

    function domainReason(address output) public view returns (bytes memory) {
        return output == address(face)
            ? abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, seVault, address(face))
            : abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(face), seVault);
    }

    function _digest(address target, IERC20 input, IERC20 output, address caller) private view returns (bytes32) {
        return keccak256(abi.encode(_ownSeDigest(target), _custodyDigest(target, input, output, caller), _callerDigest(target, input, output, caller)));
    }

    function _ownSeDigest(address target) private view returns (bytes32) {
        (uint256 d0, uint256 d1) = _lr().deployedReserve();
        return keccak256(abi.encode(IERC20(seVault).totalSupply(), IERC20(seVault).balanceOf(target),
            IERC20(address(face)).balanceOf(seVault), IERC20(launchToken).balanceOf(seVault), d0, d1));
    }

    function _callerDigest(address target, IERC20 input, IERC20 output, address caller) private view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256(abi.encode(input.balanceOf(address(this)), input.balanceOf(target), input.balanceOf(caller))),
            output.balanceOf(target), output.balanceOf(caller), input.allowance(address(this), caller)
        ));
    }

    function _custodyDigest(address target, IERC20 input, IERC20 output, address caller) private view returns (bytes32 digest) {
        digest = keccak256(abi.encode(output.balanceOf(address(this)),
            IBasicVault(seVault).reserveOfToken(address(face)), IBasicVault(seVault).reserveOfToken(launchToken),
            IBasicVault(seVault).reserveOfToken(seVault), input.allowance(caller, target), input.allowance(target, seVault)));
    }

    function assertExactOutRejected(address target, address input, address output, bool prepaid) external {
        IERC20 tin = IERC20(input);
        IERC20 tout = IERC20(output);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 maximum = 10 ether;
        if (input != seVault) _pay(input, address(this), maximum);
        tin.approve(address(caller), maximum);
        bytes32 beforeState = _digest(target, tin, tout, address(caller));
        bytes memory reason = domainReason(output);
        vm.expectRevert(reason);
        IStandardExchangeOut(target).previewExchangeOut(tin, tout, 1e12);
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut, (tin, maximum, tout, 1e12, address(caller), prepaid, block.timestamp));
        vm.expectRevert(reason);
        if (prepaid) caller.consumePretransfer(tin, address(this), target, maximum, data);
        else caller.consumePull(tin, address(this), target, maximum, data);
        require(_digest(target, tin, tout, address(caller)) == beforeState, "EO rollback");
    }

    function assertRouterExactOutRejected(address router, PoolKey memory key, address input, address output) external {
        _assertRouterExactOutRejected(router, key, input, output);
    }

    function _assertRouterExactOutRejected(address router, PoolKey memory key, address input, address output) private {
        uint256 maximum = 10 ether;
        if (input != seVault) _pay(input, address(this), maximum);
        IERC20(input).approve(router, maximum);
        bytes32 beforeState = _digest(address(key.hooks), IERC20(input), IERC20(output), router);
        bool zeroForOne = input == Currency.unwrap(key.currency0);
        SwapParams memory params = SwapParams(zeroForOne, int256(1e12), zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        bytes memory reason = abi.encodeWithSelector(CustomRevert.WrappedError.selector, address(key.hooks),
            IHooks.beforeSwap.selector, domainReason(output), abi.encodePacked(Hooks.HookCallFailed.selector));
        vm.expectRevert(reason);
        WrapperExactOutRouter(router).swapExactOut(key, params, maximum, bytes(""));
        require(_digest(address(key.hooks), IERC20(input), IERC20(output), router) == beforeState, "router EO rollback");
    }

    struct RouterState { uint256 quote; uint256 input; uint256 output; uint256 resting; uint256 held; uint256 supply; }

    function assertRouterPairRoutes(address router, address hook, address input, address output, int24 spacing) external {
        PoolKey memory key = PoolKey(Currency.wrap(input < output ? input : output), Currency.wrap(input < output ? output : input),
            LPFeeLibrary.DYNAMIC_FEE_FLAG, spacing, IHooks(hook));
        _pay(input, address(this), 1 ether);
        IERC20(input).approve(router, 1 ether);
        RouterState memory state;
        state.quote = IStandardExchangeIn(hook).previewExchangeIn(IERC20(input), 1 ether, IERC20(output));
        require(state.quote > 0, "nonzero EI quote");
        state.input = IERC20(input).balanceOf(address(this));
        state.output = IERC20(output).balanceOf(address(this));
        state.resting = IERC20(output).balanceOf(hook);
        state.held = IERC20(seVault).balanceOf(hook);
        state.supply = IERC20(seVault).totalSupply();
        bool zfo = input < output;
        WrapperExactOutRouter(router).swapExactIn(key, SwapParams(zfo, -int256(1 ether), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), bytes(""));
        require(IERC20(input).balanceOf(address(this)) == state.input - 1 ether, "exact EI input");
        require(IERC20(output).balanceOf(address(this)) == state.output + state.quote, "exact EI payout parity");
        uint256 afterFace = IERC20(output).balanceOf(hook);
        if (output == address(face)) {
            require(afterFace > state.resting ? afterFace - state.resting <= 10 : state.resting - afterFace <= 10, "no output dust subsidy");
            uint256 burned = state.held - IERC20(seVault).balanceOf(hook);
            require(burned > 0 && burned < state.held && state.supply - IERC20(seVault).totalSupply() == burned, "exact output share burn");
        } else {
            require(afterFace + state.quote == state.resting, "raw output reserve pays exactly the quote");
        }
        _assertRouterExactOutRejected(router, key, input, output);
    }

    function assertBlockedAccounting(address holder) external {
        uint256 held = IERC20(seVault).balanceOf(holder);
        (uint256 d0, uint256 d1) = _lr().deployedReserve();
        require(d0 > 0 && d1 > 0 && _lr().localReserve(address(face)) > 0 && _lr().localReserve(launchToken) > 0, "p=1 is funded half-book, not all-local");
        address[2] memory inputs = [address(face), launchToken];
        for (uint256 i; i < 2; ++i) {
            address input = inputs[i];
            address other = inputs[1 - i];
            _pay(input, address(this), 1 ether);
            IERC20(input).approve(seVault, 1 ether);
            uint256 booked = IBasicVault(seVault).reserveOfToken(input);
            uint256 untouched = IERC20(other).balanceOf(seVault);
            uint256 sharesBefore = IERC20(seVault).balanceOf(address(this));
            uint256 usedBefore = IERC20(input).balanceOf(address(this));
            uint256 minted = abi.decode(registry.poolManager().unlock(abi.encode(input)), (uint256));
            require(minted > 0 && IERC20(seVault).balanceOf(address(this)) == sharesBefore + minted, "funded shares");
            require(IERC20(input).balanceOf(address(this)) == usedBefore - 1 ether, "no input refund");
            require(IBasicVault(seVault).reserveOfToken(input) == booked + 1 ether, "entire blocked input booked");
            require(IERC20(other).balanceOf(seVault) == untouched, "no other caller funds consumed");
        }
        require(IERC20(seVault).balanceOf(holder) == held, "holder shares unchanged");
        (uint256 after0, uint256 after1) = _lr().deployedReserve();
        require(d0 == after0 && d1 == after1, "blocked path does not touch liquidity");
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(registry.poolManager()), "manager only");
        require(!_lr().canOpenPoolManagerUnlock(), "real blocked state");
        IERC20 input = IERC20(abi.decode(data, (address)));
        uint256 quoted = IStandardExchangeIn(seVault).previewExchangeIn(input, 1 ether, IERC20(seVault));
        uint256 minted = IStandardExchangeIn(seVault).exchangeIn(input, 1 ether, IERC20(seVault), quoted, address(this), false, block.timestamp);
        require(minted == quoted, "blocked quote parity");
        return abi.encode(minted);
    }
}

/// @dev CREATE2 hook deployer shared by every Pons matrix fixture in a test.
contract SeMatrixPonsRegistry {
    struct Init {
        IPoolManager poolManager;
        PonsV2MemeHook hook;
        PonsV2LaunchFactory factory;
        IPositionManager positionManager;
        IWETH weth;
        address launcher;
        address owner;
        uint256 configId;
    }

    IPoolManager public poolManager;
    PonsV2MemeHook public hook;
    PonsV2LaunchFactory public factory;
    IPositionManager public positionManager;
    IWETH public weth;
    address public launcher;
    address public owner;
    uint256 public configId;
    uint256 public launchNonce;
    bool public ready;

    function init(Init memory init_) external {
        require(!ready, "already init");
        poolManager = init_.poolManager;
        hook = init_.hook;
        factory = init_.factory;
        positionManager = init_.positionManager;
        weth = init_.weth;
        launcher = init_.launcher;
        owner = init_.owner;
        configId = init_.configId;
        ready = true;
    }

    function deployHook(IPoolManager pm, PonsV2FeeEscrow escrow, address sink, address owner_, bytes32 salt) external returns (PonsV2MemeHook) {
        return new PonsV2MemeHook{salt: salt}(pm, escrow, sink, owner_);
    }

    function nextNonce() external returns (uint256) {
        return ++launchNonce;
    }
}
