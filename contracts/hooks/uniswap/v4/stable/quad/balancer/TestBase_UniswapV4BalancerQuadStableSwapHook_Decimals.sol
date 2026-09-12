// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4BalancerQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHook.sol";
import {
    IUniswapV4BalancerQuadStableSwapHookPackage
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHookPackage.sol";
import {
    UniswapV4BalancerQuadStableSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_FactoryService.sol";
import {
    UniswapV4BalancerQuadStableSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookPairPoolLib.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";

/**
 * @title TestBase_UniswapV4BalancerQuadStableSwapHook_Decimals
 * @notice Quad Balancer book-decimal underlyings. Hook LP stays 18.
 * @dev Does not call gold setUp (gold constructs 6/6/18/18). pairToken is constructed first
 *      at `_dec0()`. After address sort t0..t3 permute; NatSpec on wrappers records roles.
 */
abstract contract TestBase_UniswapV4BalancerQuadStableSwapHook_Decimals is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    MintableERC20Decimals internal pairToken;
    MintableERC20Decimals internal t0;
    MintableERC20Decimals internal t1;
    MintableERC20Decimals internal t2;
    MintableERC20Decimals internal t3;

    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4BalancerQuadStableSwapHookPackage internal hookPkg;
    address internal hook;
    IUniswapV4BalancerQuadStableSwapHook internal quad;

    address internal user = address(0xBEEF);

    uint24 internal constant DEMO_FEE = 500;
    uint256 internal constant DEMO_AMP = 100;
    uint256 internal constant DUST = 1;

    function _dec0() internal pure virtual returns (uint8);
    function _dec1() internal pure virtual returns (uint8);
    function _dec2() internal pure virtual returns (uint8);
    function _dec3() internal pure virtual returns (uint8);

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();

        pairToken = new MintableERC20Decimals("Pair", "PAIR", _dec0());
        MintableERC20Decimals b = new MintableERC20Decimals("Leg1", "L1", _dec1());
        MintableERC20Decimals c = new MintableERC20Decimals("Leg2", "L2", _dec2());
        MintableERC20Decimals d = new MintableERC20Decimals("Leg3", "L3", _dec3());
        (t0, t1, t2, t3) = _sortFour(pairToken, b, c, d);

        pm = IPoolManager(address(new PoolManager(address(this))));

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
        IFacet liquidityFacet = PkgFactory.deployLiquidityFacet(create3Factory);
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4BalancerQuadStableSwapHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                hooksFacet: hooksFacet,
                liquidityFacet: liquidityFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
            }),
            abi.encode(type(IUniswapV4BalancerQuadStableSwapHookPackage).name, "v1")._hash()
        );

        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        quad = IUniswapV4BalancerQuadStableSwapHook(hook);

        _fundUser();
        vm.startPrank(user);
        t0.approve(hook, type(uint256).max);
        t1.approve(hook, type(uint256).max);
        t2.approve(hook, type(uint256).max);
        t3.approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory)
    {
        address[4] memory providers;
        return IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            token0: address(t0),
            token1: address(t1),
            token2: address(t2),
            token3: address(t3),
            lpFeePips: DEMO_FEE,
            baseAmp: DEMO_AMP,
            rateProviders: providers
        });
    }

    function _pkgArgs(
        address token0_,
        address token1_,
        address token2_,
        address token3_,
        uint24 fee,
        uint256 amp,
        address[4] memory providers
    ) internal view returns (IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory) {
        return IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            token0: token0_,
            token1: token1_,
            token2: token2_,
            token3: token3_,
            lpFeePips: fee,
            baseAmp: amp,
            rateProviders: providers
        });
    }

    function _deployHook(IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory args)
        internal
        returns (address h)
    {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h, args.token0, args.token1, args.token2, args.token3);
    }

    function _ensureProductDoorsAndFinalize(address hook_) internal {
        _ensureProductDoorsAndFinalize(hook_, address(t0), address(t1), address(t2), address(t3));
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

    function _poolKeys() internal view returns (PoolKey[6] memory) {
        return PairPoolLib.computeKeys(
            hook, address(t0), address(t1), address(t2), address(t3), DEMO_FEE
        );
    }

    function _raw(MintableERC20Decimals t, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(t.decimals()));
    }

    function _balancedAmounts(uint256 human) internal view returns (uint256[4] memory amounts) {
        amounts[0] = _raw(t0, human);
        amounts[1] = _raw(t1, human);
        amounts[2] = _raw(t2, human);
        amounts[3] = _raw(t3, human);
    }

    function _fundUser() internal {
        t0.mint(user, _raw(t0, 10_000_000));
        t1.mint(user, _raw(t1, 10_000_000));
        t2.mint(user, _raw(t2, 10_000_000));
        t3.mint(user, _raw(t3, 10_000_000));
    }

    function _addLiquidityFirst(uint256 human) internal returns (uint256 shares) {
        uint256[4] memory amounts = _balancedAmounts(human);
        uint256[4] memory mins;
        vm.prank(user);
        (shares,) = quad.addLiquidity(amounts, mins, user, 0);
    }

    function _bookReserves(address h) internal view returns (uint256[4] memory r) {
        IUniswapV4BalancerQuadStableSwapHook q = IUniswapV4BalancerQuadStableSwapHook(h);
        r[0] = q.reserveOf(q.token0());
        r[1] = q.reserveOf(q.token1());
        r[2] = q.reserveOf(q.token2());
        r[3] = q.reserveOf(q.token3());
    }

    function _bookReserves() internal view returns (uint256[4] memory) {
        return _bookReserves(hook);
    }

    function _sortFour(
        MintableERC20Decimals a,
        MintableERC20Decimals b,
        MintableERC20Decimals c,
        MintableERC20Decimals d
    ) internal pure returns (MintableERC20Decimals, MintableERC20Decimals, MintableERC20Decimals, MintableERC20Decimals) {
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

    function _registry() internal view returns (IVaultRegistryVaultQuery) {
        return IVaultRegistryVaultQuery(address(indexedexManager));
    }
}
