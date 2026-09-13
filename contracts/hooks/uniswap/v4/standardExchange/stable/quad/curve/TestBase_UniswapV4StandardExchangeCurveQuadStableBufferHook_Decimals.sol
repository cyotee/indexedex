// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";

/**
 * @title TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals
 * @notice Quad SE Curve book-decimal underlyings. Hook LP / vaultShare stay 18.
 * @dev Does not call gold setUp (gold constructs 18-dec SimpleMintableERC20). pairToken is
 *      constructed first at `_dec0()`. After address sort token0..token3 permute; NatSpec on
 *      wrappers records roles. SE on sorted token0 like gold.
 */
abstract contract TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals is
    TestBase_ERC4626StandardExchange
{
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    uint256 internal constant WAD = 1e18;
    uint256 internal constant DEFAULT_BASE_AMP = 100;
    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    MintableERC20Decimals internal pairToken;
    MintableERC20Decimals internal token0;
    MintableERC20Decimals internal token1;
    MintableERC20Decimals internal token2;
    MintableERC20Decimals internal token3;
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;

    SimpleYieldERC4626 internal vault0;
    SimpleYieldERC4626 internal vault1;
    SimpleYieldERC4626 internal vault2;
    SimpleYieldERC4626 internal vault3;

    address internal se0;
    address internal se1;
    address internal se2;
    address internal se3;
    address internal seA;

    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage internal hookPkg;
    address internal hook;
    IUniswapV4StandardExchangeCurveQuadStableBufferHook internal quad;
    IUniswapV4StandardExchangeCurveQuadStableBufferHook internal weighted;
    WrapperExactOutRouter internal swapRouter;
    PoolKey internal poolKey01;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    function _dec0() internal pure virtual returns (uint8);
    function _dec1() internal pure virtual returns (uint8);
    function _dec2() internal pure virtual returns (uint8);
    function _dec3() internal pure virtual returns (uint8);

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        feeRecipient = address(feeCollector);

        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new MintableERC20Decimals("Pair", "PAIR", _dec0());
        MintableERC20Decimals b = new MintableERC20Decimals("Leg1", "L1", _dec1());
        MintableERC20Decimals c = new MintableERC20Decimals("Leg2", "L2", _dec2());
        MintableERC20Decimals d = new MintableERC20Decimals("Leg3", "L3", _dec3());
        (token0, token1, token2, token3) = _sortFour(pairToken, b, c, d);
        tokenA = token0;
        tokenB = token1;

        vault0 = new SimpleYieldERC4626(token0);
        vault1 = new SimpleYieldERC4626(token1);
        vault2 = new SimpleYieldERC4626(token2);
        vault3 = new SimpleYieldERC4626(token3);
        se0 = _deployERC4626SE(address(vault0));
        se1 = _deployERC4626SE(address(vault1));
        se2 = _deployERC4626SE(address(vault2));
        se3 = _deployERC4626SE(address(vault3));
        seA = se0;

        pm = IPoolManager(address(IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals_PoolManager")
        ))));
        _deployFactoryAndPackage();
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        _deployHookWithArgs(_defaultPkgArgs());

        swapRouter = new WrapperExactOutRouter(pm);
        poolKey01 = PairPoolLib.pairKey(address(token0), address(token1), 1, IHooks(hook));

        _setUsageFee(0);
        _setDexFee(0);

        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        vm.startPrank(user);
        IERC20(se0).approve(hook, type(uint256).max);
        IERC20(se1).approve(hook, type(uint256).max);
        IERC20(se2).approve(hook, type(uint256).max);
        IERC20(se3).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _deployFactoryAndPackage() internal {
        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: hookFlagsFacet
            })
        );

        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgInit memory init;
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        init.joinQueryFacet = PkgFactory.deployJoinQueryFacet(create3Factory);
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(indexedexManager));
        init.liquidityFacet = PkgFactory.deployLiquidityFacet(create3Factory);
        init.exitFacet = PkgFactory.deployExitFacet(create3Factory);
        init.seFacet = PkgFactory.deploySeFacet(create3Factory);
        init.hooksFacet = PkgFactory.deployHooksFacet(create3Factory);
        init.erc20Facet = erc20Facet;
        init.erc5267Facet = erc5267Facet;
        init.erc2612Facet = erc2612Facet;
        init.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        init.multiStepOwnableFacet = multiStepOwnableFacet;
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            init,
            abi.encode(
                type(IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage).name,
                "v1",
                _dec0(),
                _dec1(),
                _dec2(),
                _dec3()
            )._hash()
        );
    }

    function _raw(MintableERC20Decimals t, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(t.decimals()));
    }

    function _rawAddr(address t, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(IERC20Metadata(t).decimals()));
    }

    function _u0(uint256 human) internal view returns (uint256) {
        return _raw(token0, human);
    }

    function _u1(uint256 human) internal view returns (uint256) {
        return _raw(token1, human);
    }

    function _u2(uint256 human) internal view returns (uint256) {
        return _raw(token2, human);
    }

    function _u3(uint256 human) internal view returns (uint256) {
        return _raw(token3, human);
    }

    function _balancedAmounts(uint256 human) internal view returns (uint256[] memory amounts) {
        amounts = new uint256[](4);
        amounts[0] = _u0(human);
        amounts[1] = _u1(human);
        amounts[2] = _u2(human);
        amounts[3] = _u3(human);
    }

    /// @notice Single-asset join: lowest-decimal pair so the add hits the small inv reserve.
    ///         Mixed 6/9 vs 18 books Newton-fail when the join is 18-dec face against dust inv.
    function _singleJoinTokenAndAmt(uint256 human)
        internal
        view
        returns (address tok, uint256 amt)
    {
        tok = quad.token(0);
        uint8 minDec = IERC20Metadata(tok).decimals();
        for (uint256 i = 1; i < 4; ++i) {
            address t = quad.token(i);
            uint8 d = IERC20Metadata(t).decimals();
            if (d < minDec) {
                minDec = d;
                tok = t;
            }
        }
        amt = _rawAddr(tok, human);
    }

    /// @dev Exact first; 0.01% + 1 wei slack if mixed-decimal 1-wei fails.
    function _assertPreviewEq(uint256 actual, uint256 expected) internal pure {
        if (actual == expected) return;
        uint256 slack = expected / 10_000 + 1;
        assertApproxEqAbs(actual, expected, slack);
    }

    function _fundAndApprove(MintableERC20Decimals t) internal {
        t.mint(user, _raw(t, 1_000_000));
        // Inv-wad first mint / Newton joins pass `human * 1e18` of 6/9-dec pair (1:1 SE shares).
        if (t.decimals() != 18) t.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        t.approve(hook, type(uint256).max);
        t.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _deployHookWithArgs(IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory args)
        internal
    {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        if (
            IDiamondLoupe(hook).facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector)
                != address(0)
        ) {
            _ensureProductDoorsAndFinalize(
                hook, args.tokens[0], args.tokens[1], args.tokens[2], args.tokens[3]
            );
        }
        quad = IUniswapV4StandardExchangeCurveQuadStableBufferHook(hook);
        weighted = quad;
        poolKey01 = PairPoolLib.pairKey(args.tokens[0], args.tokens[1], 1, IHooks(hook));
    }

    function _ensureProductDoorsAndFinalize(address hook_) internal {
        _ensureProductDoorsAndFinalize(
            hook_, address(token0), address(token1), address(token2), address(token3)
        );
    }

    function _ensureProductDoorsAndFinalize(
        address hook_,
        address token0_,
        address token1_,
        address token2_,
        address token3_
    ) internal {
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(token0_, token1_);
        init.deployPair(token0_, token2_);
        init.deployPair(token0_, token3_);
        init.deployPair(token1_, token2_);
        init.deployPair(token1_, token3_);
        init.deployPair(token2_, token3_);
        bool ok = init.finalizeInitialization();
        require(ok, "finalize");
    }

    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory)
    {
        address[4] memory toks;
        toks[0] = address(token0);
        toks[1] = address(token1);
        toks[2] = address(token2);
        toks[3] = address(token3);
        address[4] memory ses;
        ses[0] = se0;
        if (token1.decimals() != 18) ses[1] = se1;
        if (token2.decimals() != 18) ses[2] = se2;
        if (token3.decimals() != 18) ses[3] = se3;
        address[4] memory rps;
        return IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            tokens: toks,
            standardExchanges: ses,
            rateProviders: rps,
            tokenDecimals: HookPkgArgsDecimalsLib.tokenDecimals4(toks),
            seDecimals: HookPkgArgsDecimalsLib.seDecimals4(ses),
            baseAmp: DEFAULT_BASE_AMP,
            ownerOnlyLiquidity: _pkgOwnerOnlyLiquidity(),
            owner: _pkgOwner()
        });
    }

    function _pkgOwnerOnlyLiquidity() internal view virtual returns (bool) {
        return false;
    }

    function _pkgOwner() internal view virtual returns (address) {
        return owner;
    }

    /// @notice Equal human units on each pair (`human * 10**decimals`). Rated/swap domain stays
    ///         wad-balanced. Inventory on 1:1 6/9-dec SE legs is share-count (dust vs 18-dec).
    function _firstMintEqual(uint256 humanEach) internal returns (uint256 shares) {
        uint256[] memory amounts = _balancedAmounts(humanEach);
        vm.prank(user);
        (shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 days);
    }

    /// @notice First mint with invWad-balanced inventory: buffered non-18 legs take `humanEach * 1e18`
    ///         pair (1:1 18-dec SE shares). Use only for Newton single-asset / unbalanced cells —
    ///         the rated/swap book is then 10^(18-dec) skewed.
    function _firstMintInvWad(uint256 humanEach) internal returns (uint256 shares) {
        uint256[] memory amounts = new uint256[](4);
        MintableERC20Decimals[4] memory toks = [token0, token1, token2, token3];
        uint256 wadFace = humanEach * 1 ether;
        for (uint256 i; i < 4; ++i) {
            if (quad.isBuffered(i) && toks[i].decimals() != 18) {
                amounts[i] = wadFace;
            } else {
                amounts[i] = _raw(toks[i], humanEach);
            }
        }
        vm.prank(user);
        (shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 days);
    }

    function _seedFullBook(uint256 humanEach) internal returns (uint256 shares) {
        return _firstMintEqual(humanEach);
    }

    function _assertAllDoorsLive() internal view {
        address[] memory toks = quad.tokens();
        assertEq(toks.length, 4);
        assertEq(quad.pairDoorCount(), 6);
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                PoolKey memory key = PairPoolLib.pairKey(toks[i], toks[j], 1, IHooks(hook));
                assertTrue(PairPoolLib.isPoolLive(pm, key), "door live");
            }
        }
    }

    function _swapExactIn(address tokenIn, address tokenOut, uint256 amountIn) internal {
        bool zeroForOne = tokenIn < tokenOut;
        PoolKey memory key = PairPoolLib.pairKey(tokenIn, tokenOut, 1, IHooks(hook));
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        vm.prank(user);
        swapRouter.swapExactIn(key, params, "");
    }

    function _swapExactOut(address tokenIn, address tokenOut, uint256 amountOut) internal {
        bool zeroForOne = tokenIn < tokenOut;
        PoolKey memory key = PairPoolLib.pairKey(tokenIn, tokenOut, 1, IHooks(hook));
        uint256 previewIn = IUniswapV4StandardExchangeCurveQuadStableBufferHook(hook).previewSwapExactOut(
            tokenIn, tokenOut, amountOut
        );
        uint256 slack = _rawAddr(tokenIn, 1);
        uint256 maxIn = previewIn + (previewIn / 10) + slack;
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountOut),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        vm.prank(user);
        swapRouter.swapExactOut(key, params, maxIn, "");
    }

    function _argsSeCount(uint8 seCount)
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory a)
    {
        require(seCount >= 1 && seCount <= 4, "seCount");
        a.poolManager = address(pm);
        a.feeOracle = address(indexedexManager);
        a.baseAmp = DEFAULT_BASE_AMP;
        a.tokens[0] = address(token0);
        a.tokens[1] = address(token1);
        a.tokens[2] = address(token2);
        a.tokens[3] = address(token3);
        address[4] memory sesAll = [se0, se1, se2, se3];
        for (uint8 i; i < seCount; ++i) {
            a.standardExchanges[i] = sesAll[i];
        }
        a.ownerOnlyLiquidity = _pkgOwnerOnlyLiquidity();
        a.owner = _pkgOwner();
        a.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals4(a.tokens);
        a.seDecimals = HookPkgArgsDecimalsLib.seDecimals4(a.standardExchanges);
    }

    function _pkgArgs(
        address[4] memory toks,
        address[4] memory ses,
        address[4] memory rps,
        uint256 baseAmp
    ) internal view returns (IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory a) {
        a.poolManager = address(pm);
        a.feeOracle = address(indexedexManager);
        a.tokens = toks;
        a.standardExchanges = ses;
        a.rateProviders = rps;
        a.baseAmp = baseAmp;
        a.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals4(a.tokens);
        a.seDecimals = HookPkgArgsDecimalsLib.seDecimals4(a.standardExchanges);
        a.ownerOnlyLiquidity = _pkgOwnerOnlyLiquidity();
        a.owner = _pkgOwner();
    }

    function _setDexFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
    }

    function _setUsageFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, feeWad);
    }

    function _ensureFeeTo() internal {
        address ft = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        if (ft == address(0)) {
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(feeCollector)));
        }
    }

    function _reserveOf(address token) internal view returns (uint256) {
        return IBasicVault(hook).reserveOfToken(token);
    }

    /// @notice Mint pair, buffer into SE, leave SE shares on `user` (B6 funding helper).
    function _userAcquireSeShares(address se, MintableERC20Decimals pairTok, uint256 pairAmt)
        internal
        returns (uint256 seOut)
    {
        pairTok.mint(user, pairAmt);
        vm.startPrank(user);
        pairTok.approve(se, type(uint256).max);
        seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairTok)),
            pairAmt,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        IERC20(se).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    /// @notice B6 first mint: SE shares on buffered leg0 + pair face on raw legs 1–3. Args are human units.
    function _firstMintSeShareBuffered(uint256 pairForSeHuman, uint256 rawHuman)
        internal
        returns (uint256 shares, uint256 seUsed)
    {
        uint256 seAmt = _userAcquireSeShares(se0, token0, _u0(pairForSeHuman));
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = seAmt;
        amounts[1] = _u1(rawHuman);
        amounts[2] = _u2(rawHuman);
        amounts[3] = _u3(rawHuman);
        bool[] memory isSe = new bool[](4);
        isSe[0] = true;
        vm.prank(user);
        (shares,) = quad.joinProportionalFlexible(amounts, isSe, user, 0, block.timestamp + 1 days);
        seUsed = seAmt;
    }

    function _sortFour(
        MintableERC20Decimals a,
        MintableERC20Decimals b,
        MintableERC20Decimals c,
        MintableERC20Decimals d
    )
        internal
        pure
        returns (MintableERC20Decimals, MintableERC20Decimals, MintableERC20Decimals, MintableERC20Decimals)
    {
        address[4] memory addrs = [address(a), address(b), address(c), address(d)];
        MintableERC20Decimals[4] memory toks = [a, b, c, d];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j + 1 < 4; ++j) {
                if (addrs[j] > addrs[j + 1]) {
                    (addrs[j], addrs[j + 1]) = (addrs[j + 1], addrs[j]);
                    (toks[j], toks[j + 1]) = (toks[j + 1], toks[j]);
                }
            }
        }
        return (toks[0], toks[1], toks[2], toks[3]);
    }
}
