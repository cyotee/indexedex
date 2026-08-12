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

import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";
import {
    IMultiPairStandardExchangeBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol";
import {
    MultiPairStandardExchangeBufferPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPool_FactoryService.sol";

/**
 * @title TestBase_MultiPairStandardExchangeBufferPool
 * @notice Hermetic multi-pair buffer TestBase. Override `_targetPairCount()` for P=1..4.
 * @dev Extra SE vaults: Aerodrome volatile pools
 *      pair0: DAI/USDC (parent seVault), buffer DAI
 *      pair1: USDT/USDC, buffer USDT
 *      pair2: WETH/USDC, buffer WETH
 *      pair3: WSTETH/USDC, buffer WSTETH
 */
abstract contract TestBase_MultiPairStandardExchangeBufferPool is TestBase_StandardExchangeBufferPool {
    using MultiPairStandardExchangeBufferPool_FactoryService for IVaultRegistryDeployment;

    IMultiPairStandardExchangeBufferPoolPkg public multiPairPkg;
    address public multiPairPool;

    uint256 internal constant MP_INIT_BUFFER = 1_000e18;
    uint256 internal constant MP_INIT_SHARES = 1_000e18;

    // Extra SE legs (pair 0 uses parent seVault/tta).
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

    /// @dev Override in subclasses for multi-pair fixtures (1..4).
    function _targetPairCount() internal pure virtual returns (uint8) {
        return 1;
    }

    function _deployBufferPoolFacets() internal virtual override {
        TestBase_StandardExchangeBufferPool._deployBufferPoolFacets();
        bufferPoolFacet = MultiPairStandardExchangeBufferPool_FactoryService.deployMultiPairBufferPoolFacet(
            create3Factory
        );
        poolLiquidityFacet = MultiPairStandardExchangeBufferPool_FactoryService.deployMultiPairPoolLiquidityFacet(
            create3Factory
        );
        hookFacet = MultiPairStandardExchangeBufferPool_FactoryService.deployMultiPairHookFacet(create3Factory);
    }

    function _deployBufferPoolPkg() internal virtual override {
        IMultiPairStandardExchangeBufferPoolPkg.PkgInit memory pkgInit;
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
        multiPairPkg = MultiPairStandardExchangeBufferPool_FactoryService.deployMultiPairBufferPoolPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(multiPairPkg), "MultiPairBufferPoolPkg");
    }

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

        multiPairPool = _deployPoolWithPairs(p);
        bufferPool = multiPairPool;
        vm.label(multiPairPool, "MultiPairBufferPool");
        approveForPool(IERC20(multiPairPool));
    }

    function _deployExtraSeVault(uint8 pairIndex) internal {
        address tokenA;
        address tokenB = address(usdc);
        if (pairIndex == 1) tokenA = address(usdt);
        else if (pairIndex == 2) tokenA = address(weth);
        else tokenA = address(wsteth);

        address poolAddr = aeroPoolFactory.createPool(tokenA, tokenB, false);
        Pool aeroPool = Pool(poolAddr);
        vm.label(poolAddr, string.concat("AeroPool_pair", vm.toString(uint256(pairIndex))));

        // Seed LP
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

    function _mintToken(address token, address to, uint256 amount) internal {
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

    function _deployPoolWithPairs(uint8 pairCount) internal returns (address pool) {
        IERC20[] memory buffers = new IERC20[](pairCount);
        IStandardExchange[] memory vaults = new IStandardExchange[](pairCount);
        IRateProvider[] memory rps = new IRateProvider[](pairCount);
        for (uint8 i; i < pairCount; ++i) {
            buffers[i] = _bufferAt(i);
            vaults[i] = _seVaultAt(i);
            rps[i] = IRateProvider(address(0));
        }

        // Equal weights in Balancer address-sorted order of all 2P tokens.
        uint256 n = uint256(pairCount) * 2;
        address[] memory all = new address[](n);
        for (uint8 i; i < pairCount; ++i) {
            all[uint256(i) * 2] = address(buffers[i]);
            all[uint256(i) * 2 + 1] = address(vaults[i]);
        }
        // sort
        for (uint256 i = 1; i < n; ++i) {
            address key = all[i];
            uint256 j = i;
            while (j > 0 && all[j - 1] > key) {
                all[j] = all[j - 1];
                unchecked {
                    --j;
                }
            }
            all[j] = key;
        }
        uint256[] memory weights = new uint256[](n);
        uint256 each = 1e18 / n;
        uint256 sum;
        for (uint256 t; t < n; ++t) {
            weights[t] = each;
            sum += each;
        }
        // fix rounding to exact 1e18
        weights[0] += (1e18 - sum);

        IMultiPairStandardExchangeBufferPoolPkg.PkgArgs memory args = IMultiPairStandardExchangeBufferPoolPkg.PkgArgs({
            pairCount: pairCount,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            rateProviders: rps,
            weights: weights
        });
        pool = multiPairPkg.deployPool(args);
    }

    function _initPool() internal virtual override {
        uint8 p = _targetPairCount();
        for (uint8 i; i < p; ++i) {
            mintSharesForPair(i, alice, MP_INIT_SHARES * 3);
            _mintToken(address(_bufferAt(i)), alice, MP_INIT_BUFFER * 2);
        }

        vm.startPrank(alice);
        for (uint8 i; i < p; ++i) {
            _bufferAt(i).approve(address(router), type(uint256).max);
            IERC20(address(_seVaultAt(i))).approve(address(router), type(uint256).max);
        }

        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(multiPairPool);
        uint256[] memory amounts = new uint256[](poolTokens.length);
        for (uint256 t; t < poolTokens.length; ++t) {
            bool isBuffer;
            for (uint8 i; i < p; ++i) {
                if (address(poolTokens[t]) == address(_bufferAt(i))) {
                    amounts[t] = MP_INIT_BUFFER;
                    isBuffer = true;
                    break;
                }
            }
            if (!isBuffer) amounts[t] = MP_INIT_SHARES;
        }
        router.initialize(multiPairPool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    /// @notice Mint SE shares for pair `pairIndex` via aero LP → deposit.
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
            multiPairPool, tokenIn, tokenOut, amountIn, 0, block.timestamp, false, bytes("")
        );
        vm.stopPrank();
    }

    function mp() internal view returns (IMultiPairStandardExchangeBufferPool) {
        return IMultiPairStandardExchangeBufferPool(multiPairPool);
    }

    /// @dev Raw buffer balance held by BV3 vault for this pool (eventual-zero target).
    function rawPoolBufferBalance(uint256 pairIndex) public view returns (uint256) {
        (IERC20[] memory tokens,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(multiPairPool);
        address buf = address(_bufferAt(uint8(pairIndex)));
        for (uint256 i; i < tokens.length; ++i) {
            if (address(tokens[i]) == buf) return balancesRaw[i];
        }
        return 0;
    }
}
