// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {ERC20TestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/ERC20TestToken.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    TestBase_StandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {
    IMixedLegWeightedBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol";
import {
    MixedLegWeightedBufferPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPool_FactoryService.sol";

/**
 * @title TestBase_MixedLegWeightedBufferPool
 * @notice Hermetic mixed-leg weighted buffer TestBase.
 * @dev Default fixture: U=2 unpaired (USDC, WETH) + P=1 pair (DAI buffer / SE vault) → 4 tokens.
 *      Unpaired avoids pair buffers: pair0=DAI, pair1=USDT so unpaired is USDC/WETH/WSTETH.
 *      Override `_targetUnpairedCount()` / `_targetPairCount()` for other layouts.
 *      Pair0 uses parent seVault (DAI/USDC aero). Extra pairs follow multi-pair pattern.
 */
abstract contract TestBase_MixedLegWeightedBufferPool is TestBase_StandardExchangeBufferPool {
    using MixedLegWeightedBufferPool_FactoryService for IVaultRegistryDeployment;

    IMixedLegWeightedBufferPoolPkg public mixedLegPkg;
    address public mixedLegPool;

    uint256 internal constant ML_INIT_BUFFER = 1_000e18;
    uint256 internal constant ML_INIT_SHARES = 1_000e18;
    uint256 internal constant ML_INIT_UNPAIRED = 1_000e18;

    // Extra SE legs (pair 0 = parent seVault / dai).
    IStandardExchangeProxy public seVault1;
    IStandardExchangeProxy public seVault2;
    IStandardExchangeProxy public seVault3;
    Pool public aeroUsdtUsdcPool;
    Pool public aeroWethUsdcPool;
    Pool public aeroWstethUsdcPool;

    IERC20 public buffer0; // DAI
    IERC20 public buffer1; // USDT
    IERC20 public buffer2; // WETH
    IERC20 public buffer3; // WSTETH

    /// @dev Number of unpaired tokens in the default fixture (0..8).
    function _targetUnpairedCount() internal pure virtual returns (uint8) {
        return 2;
    }

    /// @dev Number of buffer/share pairs (0..4). Require 2 <= U+2P <= 8.
    function _targetPairCount() internal pure virtual returns (uint8) {
        return 1;
    }

    function _deployBufferPoolFacets() internal virtual override {
        TestBase_StandardExchangeBufferPool._deployBufferPoolFacets();
        bufferPoolFacet =
            MixedLegWeightedBufferPool_FactoryService.deployMixedLegBufferPoolFacet(create3Factory);
        poolLiquidityFacet =
            MixedLegWeightedBufferPool_FactoryService.deployMixedLegLiquidityFacet(create3Factory);
        hookFacet = MixedLegWeightedBufferPool_FactoryService.deployMixedLegHookFacet(create3Factory);
    }

    function _deployBufferPoolPkg() internal virtual override {
        IMixedLegWeightedBufferPoolPkg.PkgInit memory pkgInit;
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
        mixedLegPkg = MixedLegWeightedBufferPool_FactoryService.deployMixedLegBufferPoolPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(mixedLegPkg), "MixedLegBufferPoolPkg");
    }

    /// @dev `virtual` so T=8 fixtures can approve extra unpaired tokens before `_initPool`.
    function _deployBufferPool() internal virtual override {
        _deployBufferPoolFacets();
        _deployBufferPoolPkg();

        buffer0 = IERC20(address(dai));
        buffer1 = IERC20(address(usdt));
        buffer2 = IERC20(address(weth));
        buffer3 = IERC20(address(wsteth));

        uint8 p = _targetPairCount();
        if (p >= 2) _deployExtraSeVault(1);
        if (p >= 3) _deployExtraSeVault(2);
        if (p >= 4) _deployExtraSeVault(3);

        mixedLegPool = _deployMixedPool(_targetUnpairedCount(), p);
        bufferPool = mixedLegPool;
        vm.label(mixedLegPool, "MixedLegBufferPool");
        approveForPool(IERC20(mixedLegPool));

        // Permit2 for multi-leg buffer / unpaired tokens.
        for (uint256 i = 0; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(address(weth)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(weth), address(router), type(uint160).max, type(uint48).max);
            IERC20(address(usdt)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(usdt), address(router), type(uint160).max, type(uint48).max);
            IERC20(address(wsteth)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(wsteth), address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
    }

    function _deployExtraSeVault(uint8 pairIndex) internal {
        address tokenA;
        if (pairIndex == 1) tokenA = address(usdt);
        else if (pairIndex == 2) tokenA = address(weth);
        else tokenA = address(wsteth);
        address tokenB = address(usdc);

        address poolAddr = aeroPoolFactory.createPool(tokenA, tokenB, false);
        Pool aeroPool = Pool(poolAddr);
        vm.label(poolAddr, string.concat("AeroPool_pair", vm.toString(uint256(pairIndex))));

        uint256 amt = AERODROME_INIT_AMOUNT;
        _mintToken(tokenA, lp, amt);
        usdc.mint(lp, amt);
        vm.startPrank(lp);
        IERC20(tokenA).approve(address(aeroRouter), amt);
        usdc.approve(address(aeroRouter), amt);
        aeroRouter.addLiquidity(tokenA, tokenB, false, amt, amt, 1, 1, lp, block.timestamp + 1 hours);
        vm.stopPrank();

        address vaultAddr = aeroStdExDFPkg.deployVault(IPool(poolAddr));
        IStandardExchangeProxy se = IStandardExchangeProxy(vaultAddr);
        vm.label(vaultAddr, string.concat("SeVault_pair", vm.toString(uint256(pairIndex))));

        for (uint256 i = 0; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(poolAddr).approve(vaultAddr, type(uint256).max);
            IERC20(vaultAddr).approve(address(permit2), type(uint256).max);
            permit2.approve(vaultAddr, address(router), type(uint160).max, type(uint48).max);
            IERC20(tokenA).approve(address(permit2), type(uint256).max);
            permit2.approve(tokenA, address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }

        if (pairIndex == 1) {
            seVault1 = se;
            aeroUsdtUsdcPool = aeroPool;
        } else if (pairIndex == 2) {
            seVault2 = se;
            aeroWethUsdcPool = aeroPool;
        } else {
            seVault3 = se;
            aeroWstethUsdcPool = aeroPool;
        }
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

    function _seVaultAt(uint8 i) internal view returns (IStandardExchange) {
        if (i == 0) return IStandardExchange(address(seVault));
        if (i == 1) return IStandardExchange(address(seVault1));
        if (i == 2) return IStandardExchange(address(seVault2));
        return IStandardExchange(address(seVault3));
    }

    function _bufferAt(uint8 i) internal view returns (IERC20) {
        if (i == 0) return buffer0;
        if (i == 1) return buffer1;
        if (i == 2) return buffer2;
        return buffer3;
    }

    function _aeroPoolAt(uint8 i) internal view returns (Pool) {
        if (i == 0) return aeroDaiUsdcPool;
        if (i == 1) return aeroUsdtUsdcPool;
        if (i == 2) return aeroWethUsdcPool;
        return aeroWstethUsdcPool;
    }

    /// @dev Unpaired tokens that avoid pair buffers: pair0=DAI,1=USDT,2=WETH,3=WSTETH.
    ///      Prefer USDC then (when not used as buffers) free tokens. Index 0 always USDC.
    function _unpairedTokenAt(uint8 i) internal view virtual returns (IERC20) {
        if (i == 0) return IERC20(address(usdc));
        // For default U=2 P=1: second unpaired = WETH (not a pair0 buffer).
        // When P>=3 WETH is buffer - still OK for U<=1; for U>=2 with high P use only USDC in fixtures.
        if (i == 1) return IERC20(address(weth));
        if (i == 2) return IERC20(address(wsteth));
        return IERC20(address(usdt));
    }

    function _deployMixedPool(uint8 unpairedCount, uint8 pairCount) internal returns (address pool) {
        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = _buildPkgArgs(unpairedCount, pairCount);
        pool = mixedLegPkg.deployPool(args);
    }

    function _buildPkgArgs(uint8 unpairedCount, uint8 pairCount)
        internal
        view
        returns (IMixedLegWeightedBufferPoolPkg.PkgArgs memory args)
    {
        args.unpairedCount = unpairedCount;
        args.pairCount = pairCount;
        args.unpairedTokens = new IERC20[](unpairedCount);
        args.unpairedRateProviders = new IRateProvider[](unpairedCount);
        for (uint8 i; i < unpairedCount; ++i) {
            args.unpairedTokens[i] = _unpairedTokenAt(i);
            args.unpairedRateProviders[i] = IRateProvider(address(0));
        }
        args.bufferTokens = new IERC20[](pairCount);
        args.standardExchangeVaults = new IStandardExchange[](pairCount);
        args.pairRateProviders = new IRateProvider[](pairCount);
        for (uint8 i; i < pairCount; ++i) {
            args.bufferTokens[i] = _bufferAt(i);
            args.standardExchangeVaults[i] = _seVaultAt(i);
            args.pairRateProviders[i] = IRateProvider(address(0));
        }
        args.weights = _equalWeights(uint256(unpairedCount) + uint256(pairCount) * 2);
    }

    function _equalWeights(uint256 n) internal pure returns (uint256[] memory weights) {
        weights = new uint256[](n);
        if (n == 0) return weights;
        uint256 each = 1e18 / n;
        uint256 sum;
        for (uint256 t; t < n; ++t) {
            weights[t] = each;
            sum += each;
        }
        weights[0] += (1e18 - sum);
    }

    function _initPool() internal virtual override {
        uint8 u = _targetUnpairedCount();
        uint8 p = _targetPairCount();

        for (uint8 i; i < p; ++i) {
            mintSharesForPair(i, alice, ML_INIT_SHARES * 3);
            _mintToken(address(_bufferAt(i)), alice, ML_INIT_BUFFER * 2);
        }
        for (uint8 i; i < u; ++i) {
            _mintToken(address(_unpairedTokenAt(i)), alice, ML_INIT_UNPAIRED * 2);
        }

        vm.startPrank(alice);
        for (uint8 i; i < p; ++i) {
            _bufferAt(i).approve(address(router), type(uint256).max);
            IERC20(address(_seVaultAt(i))).approve(address(router), type(uint256).max);
        }
        for (uint8 i; i < u; ++i) {
            _unpairedTokenAt(i).approve(address(router), type(uint256).max);
        }

        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(mixedLegPool);
        uint256[] memory amounts = new uint256[](poolTokens.length);
        IMixedLegWeightedBufferPool poolView = IMixedLegWeightedBufferPool(mixedLegPool);
        for (uint256 t; t < poolTokens.length; ++t) {
            (IMixedLegWeightedBufferPool.TokenKind kind,) = poolView.resolveTokenIndex(t);
            if (kind == IMixedLegWeightedBufferPool.TokenKind.Unpaired) {
                amounts[t] = ML_INIT_UNPAIRED;
            } else if (kind == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
                amounts[t] = ML_INIT_BUFFER;
            } else {
                amounts[t] = ML_INIT_SHARES;
            }
        }
        router.initialize(mixedLegPool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function mintSharesForPair(uint8 pairIndex, address recipient, uint256 tokenAmount)
        public
        returns (uint256 sharesOut)
    {
        address tokenA = address(_bufferAt(pairIndex));
        _mintToken(tokenA, recipient, tokenAmount);
        usdc.mint(recipient, tokenAmount);
        sharesOut = _addLpAndDeposit(pairIndex, recipient, tokenA, tokenAmount);
    }

    function _addLpAndDeposit(uint8 pairIndex, address recipient, address tokenA, uint256 tokenAmount)
        internal
        returns (uint256 sharesOut)
    {
        IStandardExchangeProxy se = IStandardExchangeProxy(address(_seVaultAt(pairIndex)));
        address aero = address(_aeroPoolAt(pairIndex));
        vm.startPrank(recipient);
        IERC20(tokenA).approve(address(aeroRouter), tokenAmount);
        usdc.approve(address(aeroRouter), tokenAmount);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            tokenA, address(usdc), false, tokenAmount, tokenAmount, 1, 1, recipient, block.timestamp + 1 hours
        );
        IERC20(aero).approve(address(se), lpOut);
        sharesOut = se.deposit(lpOut, recipient);
        vm.stopPrank();
    }

    function swapExactIn(address user, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn)
        public
        returns (uint256 amountOut)
    {
        vm.startPrank(user);
        amountOut = router.swapSingleTokenExactIn(
            mixedLegPool, tokenIn, tokenOut, amountIn, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
    }

    function ml() internal view returns (IMixedLegWeightedBufferPool) {
        return IMixedLegWeightedBufferPool(mixedLegPool);
    }

    function rawPoolBufferBalance(uint256 pairIndex) public view returns (uint256) {
        (IERC20[] memory tokens,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(mixedLegPool);
        address buf = address(_bufferAt(uint8(pairIndex)));
        for (uint256 i; i < tokens.length; ++i) {
            if (address(tokens[i]) == buf) return balancesRaw[i];
        }
        return 0;
    }
}
