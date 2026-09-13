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
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
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
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib.sol";

/**
 * @title TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals
 * @notice SE orbital buffer hook with book-decimal underlyings. Hook LP / vaultShare stay 18.
 * @dev Does not call gold token construction. pairToken = token0 construction order.
 *      Each token is wrapped in SimpleYieldERC4626 + ERC-4626 SE. Default pkg: min SE, leg0 buffered.
 */
abstract contract TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals is
    TestBase_ERC4626StandardExchange
{
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    MintableERC20Decimals internal token0;
    MintableERC20Decimals internal token1;
    MintableERC20Decimals internal token2;
    SimpleYieldERC4626 internal vault0;
    SimpleYieldERC4626 internal vault1;
    SimpleYieldERC4626 internal vault2;
    address internal se0;
    address internal se1;
    address internal se2;
    address internal rp0;
    address internal rp1;
    address internal rp2;

    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4StandardExchangeOrbitalBufferHookPackage internal hookPkg;
    address internal hook;
    IUniswapV4StandardExchangeOrbitalBufferHook internal orbital;
    PoolKey internal poolKey01;
    PoolKey internal poolKey12;
    PoolKey internal poolKey02;
    WrapperExactOutRouter internal swapRouter;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function _dec0() internal pure virtual returns (uint8);
    function _dec1() internal pure virtual returns (uint8);
    function _dec2() internal pure virtual returns (uint8);

    function _u0(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_dec0()));
    }

    function _u1(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_dec1()));
    }

    function _u2(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_dec2()));
    }

    function _uFor(address token, uint256 human) internal view returns (uint256) {
        if (token == address(token0)) return _u0(human);
        if (token == address(token1)) return _u1(human);
        require(token == address(token2), "unknown token");
        return _u2(human);
    }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        feeRecipient = address(feeCollector);

        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        token0 = new MintableERC20Decimals("Token0", "T0", _dec0());
        token1 = new MintableERC20Decimals("Token1", "T1", _dec1());
        token2 = new MintableERC20Decimals("Token2", "T2", _dec2());
        require(
            address(token0) != address(token1) && address(token1) != address(token2)
                && address(token0) != address(token2),
            "token addr"
        );

        vault0 = new SimpleYieldERC4626(token0);
        vault1 = new SimpleYieldERC4626(token1);
        vault2 = new SimpleYieldERC4626(token2);

        se0 = _deployERC4626SE(address(vault0));
        se1 = _deployERC4626SE(address(vault1));
        se2 = _deployERC4626SE(address(vault2));
        require(se0 != se1 && se1 != se2 && se0 != se2, "se distinct");

        pm = IPoolManager(address(IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals_PoolManager")
        ))));

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
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        IFacet hooksFacet = PkgFactory.deployHooksFacet(create3Factory);
        IFacet depositFacet = PkgFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = PkgFactory.deployWithdrawFacet(create3Factory);
        IFacet seFacet = PkgFactory.deploySeFacet(create3Factory);
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgInit({
                depositQueryFacet: PkgFactory.deployDepositQueryFacet(create3Factory),
                depositZapFacet: PkgFactory.deployDepositZapFacet(create3Factory),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                seFacet: seFacet,
                hooksFacet: hooksFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(
                type(IUniswapV4StandardExchangeOrbitalBufferHookPackage).name,
                "v1",
                _dec0(),
                _dec1(),
                _dec2()
            )._hash()
        );

        _deployHookWithArgs(_defaultPkgArgs());

        swapRouter = new WrapperExactOutRouter(pm);

        token0.mint(user, _u0(1_000_000));
        token1.mint(user, _u1(1_000_000));
        token2.mint(user, _u2(1_000_000));
        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        IERC20(se0).approve(hook, type(uint256).max);
        IERC20(se1).approve(hook, type(uint256).max);
        IERC20(se2).approve(hook, type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        token2.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _deployHookWithArgs(IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args)
        internal
    {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        orbital = IUniswapV4StandardExchangeOrbitalBufferHook(hook);

        int24 spacing = 60;
        poolKey01 = PairPoolLib.pairKey(address(token0), address(token1), spacing, IHooks(hook));
        poolKey12 = PairPoolLib.pairKey(address(token1), address(token2), spacing, IHooks(hook));
        poolKey02 = PairPoolLib.pairKey(address(token0), address(token2), spacing, IHooks(hook));
    }

    /// @notice Default: min SE — leg0 buffered. Raw-only rejected by package.
    function _defaultPkgArgs()
        internal
        view
        virtual
        returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory)
    {
        return IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(token0),
            token1: address(token1),
            token2: address(token2),
            decimals0: HookPkgArgsDecimalsLib.tokenDec(address(token0)),
            decimals1: HookPkgArgsDecimalsLib.tokenDec(address(token1)),
            decimals2: HookPkgArgsDecimalsLib.tokenDec(address(token2)),
            se0: se0,
            se1: token1.decimals() == 18 ? address(0) : se1,
            se2: token2.decimals() == 18 ? address(0) : se2,
            rp0: address(0),
            rp1: address(0),
            rp2: address(0),
            tickSpacing: 0,
            sqrtPriceX96: 0,
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

    function _argsZeroSE()
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory)
    {
        return IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(token0),
            token1: address(token1),
            token2: address(token2),
            decimals0: HookPkgArgsDecimalsLib.tokenDec(address(token0)),
            decimals1: HookPkgArgsDecimalsLib.tokenDec(address(token1)),
            decimals2: HookPkgArgsDecimalsLib.tokenDec(address(token2)),
            se0: address(0),
            se1: address(0),
            se2: address(0),
            rp0: address(0),
            rp1: address(0),
            rp2: address(0),
            tickSpacing: 0,
            sqrtPriceX96: 0,
            ownerOnlyLiquidity: _pkgOwnerOnlyLiquidity(),
            owner: _pkgOwner()
        });
    }

    function _argsWithSE(bool b0, bool b1, bool b2)
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory a)
    {
        a = _argsZeroSE();
        a.decimals0 = HookPkgArgsDecimalsLib.tokenDec(a.token0);
        a.decimals1 = HookPkgArgsDecimalsLib.tokenDec(a.token1);
        a.decimals2 = HookPkgArgsDecimalsLib.tokenDec(a.token2);
        if (b0) a.se0 = se0;
        if (b1) a.se1 = se1;
        if (b2) a.se2 = se2;
    }

    /// @notice Mint pair into SE, leave SE shares on `user` (B6). Share token stays 18.
    function _mintSeSharesToUser(address se, MintableERC20Decimals token, uint256 pairAmount)
        internal
        returns (uint256 seShares)
    {
        token.mint(user, pairAmount);
        vm.startPrank(user);
        token.approve(se, type(uint256).max);
        seShares = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(token)),
            pairAmount,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        IERC20(se).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _addLiquidity(uint256 a0, uint256 a1, uint256 a2)
        internal
        returns (uint256 shares, uint256 u0, uint256 u1, uint256 u2)
    {
        // All-non-18 books are fully SE-buffered. Face addLiquidity preview of empty
        // 6/9-dec SE claim is 0 wad (ERC-4626 1:1 shares). B6 share deposit is the live path.
        if (
            IERC20(hook).totalSupply() == 0 && orbital.isBuffered(0) && orbital.isBuffered(1)
                && orbital.isBuffered(2) && a0 > 0 && a1 > 0 && a2 > 0
        ) {
            uint256 s0 = _mintSeSharesToUser(se0, token0, a0);
            uint256 s1 = _mintSeSharesToUser(se1, token1, a1);
            uint256 s2 = _mintSeSharesToUser(se2, token2, a2);
            vm.startPrank(user);
            IERC20(se0).approve(hook, type(uint256).max);
            IERC20(se1).approve(hook, type(uint256).max);
            IERC20(se2).approve(hook, type(uint256).max);
            (shares, u0, u1, u2) = orbital.depositFlexible(
                s0, true, s1, true, s2, true, user, 0, block.timestamp + 1 hours
            );
            vm.stopPrank();
            return (shares, u0, u1, u2);
        }
        vm.prank(user);
        return orbital.addLiquidity(a0, a1, a2, user, 0, block.timestamp + 1 hours, "");
    }

    function _seedThreeLeg(uint256 amount) internal returns (uint256 shares) {
        (shares,,,) = _addLiquidity(amount, amount, amount);
    }

    /// @notice Equal human units on each leg (raw = human * 10**decimals).
    function _seedThreeLegHuman(uint256 human) internal returns (uint256 shares) {
        (shares,,,) = _addLiquidity(_u0(human), _u1(human), _u2(human));
    }

    function _setDexFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
    }

    function _setUsageFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, feeWad);
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function _poolKeyFor(address a, address b) internal view returns (PoolKey memory key) {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
    }

    function _swapExactIn(address tokenIn, address tokenOut, uint256 amountIn) internal {
        PoolKey memory key = _poolKeyFor(tokenIn, tokenOut);
        bool zeroForOne = tokenIn == Currency.unwrap(key.currency0);
        vm.prank(user);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            ""
        );
    }

    function _registry() internal view returns (IVaultRegistryVaultQuery) {
        return IVaultRegistryVaultQuery(address(indexedexManager));
    }

    function _requiredFlags() internal pure returns (uint160) {
        return PkgFactory.requiredFlags();
    }

    function _ensureProductDoorsAndFinalize(address hook_) internal {
        _ensureProductDoorsAndFinalize(hook_, address(token0), address(token1), address(token2));
    }

    function _ensureProductDoorsAndFinalize(address hook_, address t0, address t1, address t2)
        internal
    {
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        bool ok = init.finalizeInitialization();
        require(ok, "finalize");
    }

    function _deployBootstrapOnly(
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args
    ) internal returns (address) {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        return PkgFactory.deployHook(hookPkg, args, mineNonce);
    }

    function _assertPoolLive(PoolKey memory key) internal view {
        assertTrue(PairPoolLib.isPoolLive(pm, key), "pair door not initialized on PoolManager");
        assertEq(address(key.hooks), hook, "hooks must be product proxy");
        assertEq(key.fee, LPFeeLibrary.DYNAMIC_FEE_FLAG, "DYNAMIC_FEE");
    }

    function _assertThreeProductDoorsLive() internal view {
        _assertPoolLive(poolKey01);
        _assertPoolLive(poolKey12);
        _assertPoolLive(poolKey02);
    }

    /// @notice Mixed-decimal slack: exact, else 1 wei, else 0.01% relative.
    function _assertMoneyEq(uint256 exec_, uint256 preview_, string memory err) internal {
        uint256 diff = exec_ > preview_ ? exec_ - preview_ : preview_ - exec_;
        if (diff <= 1) return;
        assertApproxEqRel(exec_, preview_, 0.0001e18, err);
    }

    function _assertSePreviewEqualsExec(address se, MintableERC20Decimals token, uint256 amountIn)
        internal
    {
        token.mint(user, amountIn);
        vm.startPrank(user);
        token.approve(se, type(uint256).max);
        uint256 previewIn =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(address(token)), amountIn, IERC20(se));
        uint256 seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(token)), amountIn, IERC20(se), previewIn, user, false, block.timestamp
        );
        _assertMoneyEq(seOut, previewIn, "SE token->shares preview!=exec");

        IERC20(se).approve(se, type(uint256).max);
        uint256 previewOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seOut, IERC20(address(token)));
        uint256 tokenOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seOut, IERC20(address(token)), previewOut, user, false, block.timestamp
        );
        _assertMoneyEq(tokenOut, previewOut, "SE shares->token preview!=exec");
        vm.stopPrank();
    }
}
