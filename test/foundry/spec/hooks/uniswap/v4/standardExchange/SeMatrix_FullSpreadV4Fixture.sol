// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
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
    IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService as HooklessFactory
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.sol";
import {
    IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
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
    UniswapV4FullSpreadConsumerLiquidityProvider
} from "contracts/test/stubs/UniswapV4FullSpreadConsumerLiquidityProvider.sol";

/**
 * @title SeMatrix_FullSpreadV4Fixture
 * @notice `UniswapV4FullSpreadHooklessStandardExchangeVault` row fixture, ERC-20 variant only (open item 1
 *         PRD §5 / M6; the native-ETH variant is out of scope for the hook rows). Face token = pool
 *         `currency0` (18-decimal `SimpleMintableERC20` minted here); `otherToken()` = `currency1`.
 *         The SE is deployed through the production FullSpread V4 package on its own CREATE3
 *         `PoolManager` (separate from the hook's) with a 3000-fee / 60-spacing pool that an
 *         independent LP (`UniswapV4FullSpreadConsumerLiquidityProvider`, the `_seedMarket` pattern of
 *         `TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial`) seeds with 50_000e18
 *         full-range liquidity so the SE can quote. The fixture bootstraps the SE with a 100/100
 *         dual deposit so single-sided face buffering mints shares.
 * @dev At p=1e18 H targets half of the placeable book locally, not all-local custody.
 *      H-specific row overrides prove blocked booking using a real outer unlock and assert
 *      unsupported EO domains explicitly. Token-delivery failure uses a real rejecting ERC20.
 *      - `seBooked()` is the SE's local face reserve view, `localReserve(currency0)`.
 *      - Package deployment is idempotent across fixtures: pass `pkg()` of an earlier fixture as
 *        `existingPkg`. The `PoolManager` singleton is CREATE3-deployed under a fixed salt, which
 *        the Crane factory resolves idempotently (`Create3FactoryService._create3WithArgs`), so a
 *        reused package and a new fixture always meet on the same `PoolManager`.
 */
contract SeMatrix_FullSpreadV4Fixture is SeMatrixFixture, IUnlockCallback {
    using HooklessFactory for ICreate3FactoryProxy;
    using UniswapV4TwapOracleFactoryService for ICreate3FactoryProxy;

    /// @dev Shared H/P fee-oracle type default.
    uint256 public constant FAMILY_SLEEVE_WAD = 0.2e18;
    /// @dev Historical constant name; p=1e18 targets F=T/2, not all-local custody.
    uint256 public constant IDLE_SLEEVE_WAD = 1e18;
    /// @dev Lower clamp; 0 would fall back to the type default in the fee oracle.
    uint256 internal constant MIN_SLEEVE_WAD = 0.01e18;
    /// @dev The matrix's 500-token resting donations must remain inside the fixed
    /// composition impact domain. Limit rejection is covered by the family suites.
    uint128 internal constant EXTERNAL_LIQUIDITY = 500_000 ether;
    uint256 internal constant EXTERNAL_FUNDING = 1_000_000 ether;
    uint256 internal constant BOOTSTRAP_AMOUNT = 100 ether;
    uint24 internal constant POOL_FEE = 3000;
    int24 internal constant POOL_TICK_SPACING = 60;
    bytes32 internal constant POOL_MANAGER_SALT = keccak256("SeMatrix_FullSpreadV4_PoolManager");

    IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg internal pkg_;
    IPoolManager public poolManager;
    IWETH public weth;
    SimpleMintableERC20 public token0;
    SimpleMintableERC20 public token1;
    UniswapV4FullSpreadConsumerLiquidityProvider public provider;
    PoolKey internal poolKey;
    address internal seVault;

    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        _deployPoolManagerSingleton(c);
        pkg_ = existingPkg == address(0)
            ? _deployPkg(c)
            : IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg(existingPkg);
        require(keccak256(bytes(pkg_.packageName())) == keccak256("UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg"), "matrix: stale family");
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

    function _deployPkg(Ctx memory c) internal returns (IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg pkgOut) {
        address factoryOwner = IMultiStepOwnable(address(c.create3Factory)).owner();
        vm.startPrank(factoryOwner);
        IUniswapV4MultiPoolTwapOracle twap = _deployTwap(c);
        IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory init = _facetInit(c);
        vm.stopPrank();
        weth = IWETH(address(new WETH9()));
        init.weth = weth;
        init = HooklessFactory.attachTwapOracle(init, twap);
        init.positionManager = IPositionManager(address(0));
        vm.startPrank(c.owner);
        IVaultFeeOracleManager(address(c.indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve).interfaceId, FAMILY_SLEEVE_WAD
        );
        pkgOut = HooklessFactory
            .deployUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg(c.indexedexManager, init);
        vm.stopPrank();
    }

    /// @dev Same TWAP wiring as the H family TestBase.
    function _deployTwap(Ctx memory c) internal returns (IUniswapV4MultiPoolTwapOracle twap) {
        IUniswapV4MultiPoolTwapOracleDFPkg twapPkg = c.create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(
            c.create3Factory.deployUniswapV4MultiPoolTwapOracleFacet(), c.create3Factory.diamondPackageFactory()
        );
        twap = twapPkg.deployOracle(IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(poolManager)}));
    }

    /// @dev Each facet belongs to the H family; only generic vault facets are shared.
    function _facetInit(Ctx memory c)
        internal
        returns (IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory init)
    {
        HooklessFactory.Univ4SePkgInitCore memory core;
        core.erc20Facet = c.erc20Facet;
        core.erc5267Facet = c.erc5267Facet;
        core.erc2612Facet = c.erc2612Facet;
        core.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        core.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        core.uniswapV4StandardExchangeInFacet =
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInFacet();
        core.uniswapV4StandardExchangeInQueryFacet =
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet();
        core.uniswapV4StandardExchangePositionImportFacet =
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet();
        core.uniswapV4StandardExchangeOutFacet =
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet();
        core.uniswapV4StandardExchangeOutQueryFacet =
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet();
        core.uniswapV4StandardExchangeLiquidReserveFacet =
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet();
        core.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        core.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        core.permit2 = c.permit2;
        core.poolManager = poolManager;
        init = HooklessFactory
            .buildArgsUniswapV4FullSpreadHooklessStandardExchangeVaultPkgInit(core);
        init = HooklessFactory
            .attachUniswapV4FullSpreadHooklessStandardExchangeVaultMultiFacets(
            init,
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet(),
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet(),
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet(),
            c.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet()
        );
    }

    function _createMarket() internal {
        SimpleMintableERC20 a = new SeMatrixRejectingERC20("FullSpread V4 Face", "FS4A");
        SimpleMintableERC20 b = new SeMatrixRejectingERC20("FullSpread V4 Pair", "FS4B");
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
        provider = new UniswapV4FullSpreadConsumerLiquidityProvider();
        token0.mint(address(provider), EXTERNAL_FUNDING);
        token1.mint(address(provider), EXTERNAL_FUNDING);
        provider.addV4(poolManager, poolKey, weth, EXTERNAL_LIQUIDITY);
    }

    /// @dev First mint through the real dual-deposit route with p=1e18.
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

    function _lr() internal view returns (IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve) {
        return IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve(seVault);
    }

    /// @dev `_configureSleeve` of the adversarial TestBase: owner sets the per-vault liquid reserve.
    function _setSleeve(uint256 pct) internal {
        vm.prank(ctx.owner);
        IVaultFeeOracleManager(address(ctx.indexedexManager)).setLiquidReservePercentageOfVault(seVault, pct);
    }

    /// @dev Real pair-side funding followed by restoration of the family sleeve default.
    ///      The funding operation itself may compose and place assets; no deferred-sweep claim.
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
        return "UniswapV4FullSpreadHooklessStandardExchangeVault";
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

    /// @notice H has no configurable investment quota; its row uses a real blocked-state case.
    function limitCapacity(uint256 allowFace) external override {
        require(allowFace == 0, "H capacity is measured under an actual outer unlock");
        _setSleeve(IDLE_SLEEVE_WAD);
    }

    /// @notice Perform real pair-side funding and restore the default policy.
    function openCapacity() external override {
        _openInvestment();
    }

    function seBooked() external view override returns (uint256) {
        return _lr().localReserve(address(token0));
    }

    /* --------------------------- operative failure ------------------------ */

    /// @notice Reject the real token delivery into the SE while leaving reads and caller funding
    ///         available. This tests atomic buffering failure, not a mocked investment failure.
    function armOperativeRevert() external override {
        SeMatrixRejectingERC20(address(token0)).setRejection(seVault, rejectBytes());
    }

    function disarmOperativeRevert() external override {
        SeMatrixRejectingERC20(address(token0)).setRejection(address(0), bytes(""));
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

    function domainReason(address output) public view returns (bytes memory) {
        return output == address(token0)
            ? abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, seVault, address(token0))
            : abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(token0), seVault);
    }

    function _digest(address target, IERC20 input, IERC20 output, address caller) private view returns (bytes32) {
        return keccak256(abi.encode(_ownSeDigest(target), _custodyDigest(target, input, output, caller),
            _callerDigest(target, input, output, caller)));
    }

    function _ownSeDigest(address target) private view returns (bytes32) {
        (uint256 d0, uint256 d1) = _lr().deployedReserve();
        return keccak256(abi.encode(IERC20(seVault).totalSupply(), IERC20(seVault).balanceOf(target),
            token0.balanceOf(seVault), token1.balanceOf(seVault), d0, d1));
    }

    function _callerDigest(address target, IERC20 input, IERC20 output, address caller) private view returns (bytes32) {
        bytes32 balances = keccak256(abi.encode(input.balanceOf(address(this)), input.balanceOf(target), input.balanceOf(caller)));
        return keccak256(abi.encode(balances, output.balanceOf(target), output.balanceOf(caller), input.allowance(address(this), caller)));
    }

    function _custodyDigest(address target, IERC20 input, IERC20 output, address caller) private view returns (bytes32 digest) {
        digest = keccak256(abi.encode(output.balanceOf(address(this)),
            IBasicVault(seVault).reserveOfToken(address(token0)), IBasicVault(seVault).reserveOfToken(address(token1)),
            IBasicVault(seVault).reserveOfToken(seVault), input.allowance(caller, target), input.allowance(target, seVault)));
        (bool ok, bytes memory data) = caller.staticcall(abi.encodeWithSignature("manager()"));
        if (ok && data.length == 32) {
            address manager = abi.decode(data, (address));
            digest = keccak256(abi.encode(digest, input.balanceOf(manager), output.balanceOf(manager)));
        }
        (ok, data) = target.staticcall(abi.encodeWithSignature("tokens()"));
        if (ok && data.length >= 64) {
            address[] memory tokens = abi.decode(data, (address[]));
            for (uint256 i; i < tokens.length; ++i) {
                (bool bound, bytes memory result) = target.staticcall(abi.encodeWithSignature("standardExchangeOf(address)", tokens[i]));
                if (bound && result.length == 32) {
                    address exchange = abi.decode(result, (address));
                    if (exchange != address(0)) digest = keccak256(abi.encode(digest, _boundExchangeDigest(exchange, tokens[i], target)));
                }
            }
        }
    }

    function _boundExchangeDigest(address exchange, address token, address target) private view returns (bytes32) {
        return keccak256(abi.encode(IERC20(exchange).totalSupply(), IERC20(exchange).balanceOf(target),
            IERC20(token).balanceOf(exchange), IERC20(exchange).allowance(target, exchange)));
    }

    /// @notice Unsupported outer EO must reject its preview AND execution, including atomic pretransfer.
    function assertExactOutRejected(address target, address input, address output, bool prepaid) external {
        IERC20 tin = IERC20(input);
        IERC20 tout = IERC20(output);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 maximum = 10 ether;
        if (input != seVault) SimpleMintableERC20(input).mint(address(this), maximum);
        tin.approve(address(caller), maximum);
        bytes32 beforeState = _digest(target, tin, tout, address(caller));
        bytes memory reason = domainReason(output);
        vm.expectRevert(reason);
        IStandardExchangeOut(target).previewExchangeOut(tin, tout, 1e12);
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (tin, maximum, tout, 1e12, address(caller), prepaid, block.timestamp));
        vm.expectRevert(reason);
        if (prepaid) caller.consumePretransfer(tin, address(this), target, maximum, data);
        else caller.consumePull(tin, address(this), target, maximum, data);
        require(_digest(target, tin, tout, address(caller)) == beforeState, "EO rollback");
    }

    /// @notice Calls the real router directly, not an EO helper that can stop at preview.
    function assertRouterExactOutRejected(address router, PoolKey memory key, address input, address output) external {
        _assertRouterExactOutRejected(router, key, input, output);
    }

    function _assertRouterExactOutRejected(address router, PoolKey memory key, address input, address output) private {
        uint256 maximum = 10 ether;
        if (input != seVault) SimpleMintableERC20(input).mint(address(this), maximum);
        IERC20(input).approve(router, maximum);
        bytes32 beforeState = _digest(address(key.hooks), IERC20(input), IERC20(output), router);
        bool zeroForOne = input == Currency.unwrap(key.currency0);
        SwapParams memory params = SwapParams(zeroForOne, int256(1e12),
            zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        bytes memory reason = abi.encodeWithSelector(CustomRevert.WrappedError.selector, address(key.hooks),
            IHooks.beforeSwap.selector, domainReason(output), abi.encodePacked(Hooks.HookCallFailed.selector));
        vm.expectRevert(reason);
        WrapperExactOutRouter(router).swapExactOut(key, params, maximum, bytes(""));
        require(_digest(address(key.hooks), IERC20(input), IERC20(output), router) == beforeState, "router EO rollback");
    }

    struct RouterState {
        uint256 quote;
        uint256 input;
        uint256 output;
        uint256 resting;
        uint256 held;
        uint256 supply;
    }

    function assertRouterPairRoutes(address router, address hook, address input, address output, int24 spacing) external {
        PoolKey memory key = PoolKey(Currency.wrap(input < output ? input : output), Currency.wrap(input < output ? output : input),
            LPFeeLibrary.DYNAMIC_FEE_FLAG, spacing, IHooks(hook));
        SimpleMintableERC20(input).mint(address(this), 1 ether);
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
        WrapperExactOutRouter(router).swapExactIn(key, SwapParams(zfo, -int256(1 ether),
            zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), bytes(""));
        require(IERC20(input).balanceOf(address(this)) == state.input - 1 ether, "exact EI input");
        require(IERC20(output).balanceOf(address(this)) == state.output + state.quote, "exact EI payout parity");
        uint256 afterFace = IERC20(output).balanceOf(hook);
        if (output == address(token0)) {
            require(afterFace > state.resting ? afterFace - state.resting <= 10 : state.resting - afterFace <= 10, "no output dust subsidy");
            uint256 burned = state.held - IERC20(seVault).balanceOf(hook);
            require(burned > 0 && burned < state.held && state.supply - IERC20(seVault).totalSupply() == burned, "exact output share burn");
        } else {
            require(afterFace + state.quote == state.resting, "raw output reserve pays exactly the quote");
        }
        _assertRouterExactOutRejected(router, key, input, output);
    }

    /// @notice Funded blocked deposits book only this caller's input; existing holder shares do not move.
    function assertBlockedAccounting(address holder) external {
        uint256 held = IERC20(seVault).balanceOf(holder);
        (uint256 d0, uint256 d1) = _lr().deployedReserve();
        require(d0 > 0 && d1 > 0 && _lr().localReserve(address(token0)) > 0 && _lr().localReserve(address(token1)) > 0,
            "p=1 is funded half-book, not all-local");
        for (uint256 i; i < 2; ++i) {
            SimpleMintableERC20 input = i == 0 ? token0 : token1;
            SimpleMintableERC20 other = i == 0 ? token1 : token0;
            input.mint(address(this), 1 ether);
            input.approve(seVault, 1 ether);
            uint256 booked = IBasicVault(seVault).reserveOfToken(address(input));
            uint256 untouched = other.balanceOf(seVault);
            uint256 sharesBefore = IERC20(seVault).balanceOf(address(this));
            uint256 usedBefore = input.balanceOf(address(this));
            uint256 minted = abi.decode(poolManager.unlock(abi.encode(address(input))), (uint256));
            require(minted > 0 && IERC20(seVault).balanceOf(address(this)) == sharesBefore + minted, "funded shares");
            require(input.balanceOf(address(this)) == usedBefore - 1 ether, "no input refund");
            require(IBasicVault(seVault).reserveOfToken(address(input)) == booked + 1 ether, "entire blocked input booked");
            require(other.balanceOf(seVault) == untouched, "no other caller funds consumed");
        }
        require(IERC20(seVault).balanceOf(holder) == held, "holder shares unchanged");
        (uint256 after0, uint256 after1) = _lr().deployedReserve();
        require(d0 == after0 && d1 == after1, "blocked path does not touch liquidity");
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "manager only");
        require(!_lr().canOpenPoolManagerUnlock(), "real blocked state");
        IERC20 input = IERC20(abi.decode(data, (address)));
        uint256 quoted = IStandardExchangeIn(seVault).previewExchangeIn(input, 1 ether, IERC20(seVault));
        uint256 minted = IStandardExchangeIn(seVault).exchangeIn(input, 1 ether, IERC20(seVault), quoted, address(this), false, block.timestamp);
        require(minted == quoted, "blocked quote parity");
        return abi.encode(minted);
    }
}

/// @dev Real ERC20 failure harness, not a mocked vault, hook or PoolManager.
contract SeMatrixRejectingERC20 is SimpleMintableERC20 {
    address private immutable controller;
    address private rejectedRecipient;
    bytes private rejection;
    constructor(string memory name_, string memory symbol_) SimpleMintableERC20(name_, symbol_) { controller = msg.sender; }
    function setRejection(address recipient, bytes calldata reason) external {
        require(msg.sender == controller, "fixture controller");
        rejectedRecipient = recipient;
        rejection = reason;
    }
    function _check(address to) private view {
        if (to != address(0) && to == rejectedRecipient) {
            bytes memory reason = rejection;
            assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        }
    }
    function transfer(address to, uint256 amount) external override returns (bool) {
        _check(to);
        _transfer(msg.sender, to, amount);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _check(to);
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }
}
