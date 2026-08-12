// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20TestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/ERC20TestToken.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

import {
    TestBase_StandardExchangeBufferPool_UniswapV2
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/uniswapV2/bases/TestBase_StandardExchangeBufferPool_UniswapV2.sol";

import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {
    IMixedBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";
import {
    MixedBufferMultiVaultStablePool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_FactoryService.sol";

/**
 * @title TestBase_MixedBufferMultiVaultStable_UniV2
 * @notice Real multi-protocol matrix row: Uniswap V2 hermetic SE vault as buffer legs.
 * @dev Extends UniV2 buffer TestBase (not Aerodrome). C0: U=1 free + buffer DAI + 1 UniV2 SE share.
 *      Free leg uses USDT so it does not collide with UniV2 DAI/USDC pair underlyings used for SE.
 */
abstract contract TestBase_MixedBufferMultiVaultStable_UniV2 is TestBase_StandardExchangeBufferPool_UniswapV2 {
    using MixedBufferMultiVaultStablePool_FactoryService for IVaultRegistryDeployment;

    IMixedBufferMultiVaultStablePoolPkg public mbmvsPkg;
    address public mbmvsPool;

    uint256 internal constant MBMVS_INIT_BUFFER = 1_000e18;
    uint256 internal constant MBMVS_INIT_SHARES = 1_000e18;
    uint256 internal constant MBMVS_INIT_UNPAIRED = 1_000e18;
    uint256 internal constant MBMVS_AMP = 200;

    function _targetUnpairedCount() internal pure virtual returns (uint8) {
        return 1;
    }

    function _targetVaultCount() internal pure virtual returns (uint8) {
        return 1;
    }

    function _bufferToken() internal view virtual returns (IERC20) {
        return IERC20(address(dai));
    }

    function _amplificationParameter() internal pure virtual returns (uint256) {
        return MBMVS_AMP;
    }

    function _unpairedTokenAt(uint8 i) internal view virtual returns (IERC20) {
        // Prefer USDT so free leg ≠ buffer DAI and ≠ UniV2 counter USDC when possible.
        if (i == 0) return IERC20(address(usdt));
        if (i == 1) return IERC20(address(weth));
        return IERC20(address(wsteth));
    }

    function _deployBufferPoolFacets() internal virtual override {
        super._deployBufferPoolFacets();
        bufferPoolFacet =
            MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStablePoolFacet(create3Factory);
        poolLiquidityFacet =
            MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStableLiquidityFacet(
                    create3Factory
                );
        hookFacet =
            MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStableHookFacet(create3Factory);
    }

    function _deployBufferPoolPkg() internal virtual override {
        IMixedBufferMultiVaultStablePoolPkg.PkgInit memory pkgInit;
        pkgInit.basicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.standardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        pkgInit.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        pkgInit.defaultPoolInfoFacet = defaultPoolInfoFacet;
        pkgInit.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        pkgInit.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        pkgInit.bufferPoolFacet = bufferPoolFacet;
        pkgInit.poolLiquidityFacet = poolLiquidityFacet;
        pkgInit.hookFacet = hookFacet;
        pkgInit.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.balancerV3Vault = bv3Vault;
        pkgInit.diamondFactory = diamondPackageFactory;
        pkgInit.rateProviderPkg = seRateProviderPkg;

        vm.startPrank(owner);
        mbmvsPkg = MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStablePoolPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(mbmvsPkg), "MixedBufferMultiVaultStablePkg_UniV2");
    }

    function _deployBufferPool() internal virtual override {
        _deployBufferPoolFacets();
        _deployBufferPoolPkg();

        mbmvsPool = _deployMbmvsPool(_targetUnpairedCount(), _targetVaultCount());
        bufferPool = mbmvsPool;
        vm.label(mbmvsPool, "MixedBufferMultiVaultStablePool_UniV2");
        approveForPool(IERC20(mbmvsPool));
    }

    function _deployMbmvsPool(uint8 unpairedCount, uint8 vaultCount) internal returns (address pool) {
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(unpairedCount, vaultCount);
        pool = mbmvsPkg.deployPool(args);
    }

    function _buildPkgArgs(uint8 unpairedCount, uint8 vaultCount)
        internal
        view
        virtual
        returns (IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args)
    {
        args.unpairedCount = unpairedCount;
        args.unpairedTokens = new IERC20[](unpairedCount);
        args.unpairedRateProviders = new IRateProvider[](unpairedCount);
        for (uint8 i; i < unpairedCount; ++i) {
            args.unpairedTokens[i] = _unpairedTokenAt(i);
            args.unpairedRateProviders[i] = IRateProvider(address(0));
        }
        args.bufferToken = _bufferToken();
        args.vaultCount = vaultCount;
        args.standardExchangeVaults = new IStandardExchange[](vaultCount);
        args.vaultShareRateProviders = new IRateProvider[](vaultCount);
        // UniV2 SE vault from parent fixture (seVault).
        args.standardExchangeVaults[0] = IStandardExchange(address(seVault));
        args.amplificationParameter = _amplificationParameter();
    }

    function _initPool() internal virtual override {
        uint8 u = _targetUnpairedCount();
        IERC20 buffer = _bufferToken();

        mintShares(alice, MBMVS_INIT_SHARES * 3);
        _mintToken(address(buffer), alice, MBMVS_INIT_BUFFER * 4);
        for (uint8 i; i < u; ++i) {
            _mintToken(address(_unpairedTokenAt(i)), alice, MBMVS_INIT_UNPAIRED * 2);
        }

        vm.startPrank(alice);
        buffer.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        for (uint8 i; i < u; ++i) {
            _unpairedTokenAt(i).approve(address(router), type(uint256).max);
        }

        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        uint256[] memory amounts = new uint256[](poolTokens.length);
        IMixedBufferMultiVaultStablePool poolView = IMixedBufferMultiVaultStablePool(mbmvsPool);
        for (uint256 t; t < poolTokens.length; ++t) {
            (IMixedBufferMultiVaultStablePool.TokenKind kind,) = poolView.resolveTokenIndex(t);
            if (kind == IMixedBufferMultiVaultStablePool.TokenKind.Unpaired) {
                amounts[t] = MBMVS_INIT_UNPAIRED;
            } else if (kind == IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
                amounts[t] = MBMVS_INIT_BUFFER;
            } else {
                amounts[t] = MBMVS_INIT_SHARES;
            }
        }
        router.initialize(mbmvsPool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function _mintToken(address token, address to, uint256 amount) internal virtual {
        if (token == address(weth)) {
            vm.deal(to, amount);
            vm.prank(to);
            weth.deposit{value: amount}();
        } else {
            ERC20TestToken(token).mint(to, amount);
        }
    }

    function swapExactIn(address user, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn)
        public
        returns (uint256 amountOut)
    {
        vm.startPrank(user);
        amountOut = router.swapSingleTokenExactIn(
            mbmvsPool, tokenIn, tokenOut, amountIn, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
    }

    function mbmvs() internal view returns (IMixedBufferMultiVaultStablePool) {
        return IMixedBufferMultiVaultStablePool(mbmvsPool);
    }

    function rawPoolBufferBalance() public view returns (uint256) {
        (IERC20[] memory tokens,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        address buf = address(_bufferToken());
        for (uint256 i; i < tokens.length; ++i) {
            if (address(tokens[i]) == buf) return balancesRaw[i];
        }
        return 0;
    }

    function _seProtocolFamily() internal pure virtual returns (string memory) {
        return "uniswap-v2";
    }
}
