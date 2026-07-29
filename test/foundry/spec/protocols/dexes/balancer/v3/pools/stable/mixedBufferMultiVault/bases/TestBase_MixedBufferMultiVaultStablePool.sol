// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
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
 * @title TestBase_MixedBufferMultiVaultStablePool
 * @notice Default C0: U=1 free leg + N=1 vault, buffer=DAI → seVault. Override U/N for matrix configs.
 * @dev Production-first Aerodrome SE hermetic; CREATE3 + manager registry DFPkg. StableMath + fixed amp.
 */
abstract contract TestBase_MixedBufferMultiVaultStablePool is TestBase_StandardExchangeBufferPool {
    using MixedBufferMultiVaultStablePool_FactoryService for IVaultRegistryDeployment;

    IMixedBufferMultiVaultStablePoolPkg public mbmvsPkg;
    address public mbmvsPool;

    uint256 internal constant MBMVS_INIT_BUFFER = 1_000e18;
    uint256 internal constant MBMVS_INIT_SHARES = 1_000e18;
    uint256 internal constant MBMVS_INIT_UNPAIRED = 1_000e18;
    uint256 internal constant MBMVS_AMP = 200;

    // Extra SE vaults all on DAI/USDC (same buffer token).
    IStandardExchangeProxy public seVault1;
    IStandardExchangeProxy public seVault2;
    Pool public aeroDaiUsdcPool1;
    Pool public aeroDaiUsdcPool2;

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

    function _deployBufferPoolFacets() internal virtual override {
        TestBase_StandardExchangeBufferPool._deployBufferPoolFacets();
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
        vm.label(address(mbmvsPkg), "MixedBufferMultiVaultStablePkg");
    }

    function _deployBufferPool() internal virtual override {
        _deployBufferPoolFacets();
        _deployBufferPoolPkg();

        uint8 n = _targetVaultCount();
        if (n >= 2) _deployExtraDaiSeVault(1);
        if (n >= 3) _deployExtraDaiSeVault(2); // DAI/WETH third vault

        mbmvsPool = _deployMbmvsPool(_targetUnpairedCount(), n);
        bufferPool = mbmvsPool;
        vm.label(mbmvsPool, "MixedBufferMultiVaultStablePool");
        approveForPool(IERC20(mbmvsPool));
    }

    /// @dev Extra SE vaults that accept DAI as buffer, but pair with distinct second assets
    ///      (avoids PoolAlreadyExists on aero factory for duplicate DAI/USDC).
    function _deployExtraDaiSeVault(uint8 idx) internal {
        address tokenA = address(dai);
        // idx 1: DAI/USDT, idx 2: DAI/WETH
        address tokenB = idx == 1 ? address(usdt) : address(weth);
        address poolAddr = aeroPoolFactory.createPool(tokenA, tokenB, false);
        Pool aeroPool = Pool(poolAddr);
        vm.label(poolAddr, string.concat("AeroDaiPair_", vm.toString(uint256(idx))));

        uint256 amt = AERODROME_INIT_AMOUNT;
        dai.mint(lp, amt);
        _mintToken(tokenB, lp, amt);
        vm.startPrank(lp);
        dai.approve(address(aeroRouter), amt);
        IERC20(tokenB).approve(address(aeroRouter), amt);
        aeroRouter.addLiquidity(tokenA, tokenB, false, amt, amt, 1, 1, lp, block.timestamp + 1 hours);
        vm.stopPrank();

        address vaultAddr = aeroStdExDFPkg.deployVault(IPool(poolAddr));
        IStandardExchangeProxy se = IStandardExchangeProxy(vaultAddr);
        vm.label(vaultAddr, string.concat("SeVault_dai_", vm.toString(uint256(idx))));

        for (uint256 i = 0; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(poolAddr).approve(vaultAddr, type(uint256).max);
            IERC20(vaultAddr).approve(address(permit2), type(uint256).max);
            permit2.approve(vaultAddr, address(router), type(uint160).max, type(uint48).max);
            dai.approve(address(permit2), type(uint256).max);
            permit2.approve(address(dai), address(router), type(uint160).max, type(uint48).max);
            IERC20(tokenB).approve(address(permit2), type(uint256).max);
            permit2.approve(tokenB, address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }

        if (idx == 1) {
            seVault1 = se;
            aeroDaiUsdcPool1 = aeroPool;
        } else {
            seVault2 = se;
            aeroDaiUsdcPool2 = aeroPool;
        }
    }

    function _seVaultAt(uint8 i) internal view virtual returns (IStandardExchange) {
        if (i == 0) return IStandardExchange(address(seVault));
        if (i == 1) return IStandardExchange(address(seVault1));
        if (i == 2) return IStandardExchange(address(seVault2));
        revert("vault index");
    }

    function _aeroPoolAt(uint8 i) internal view virtual returns (Pool) {
        if (i == 0) return aeroDaiUsdcPool;
        if (i == 1) return aeroDaiUsdcPool1;
        if (i == 2) return aeroDaiUsdcPool2;
        revert("aero index");
    }

    function _unpairedTokenAt(uint8 i) internal view virtual returns (IERC20) {
        if (i == 0) return IERC20(address(usdc));
        if (i == 1) return IERC20(address(weth));
        if (i == 2) return IERC20(address(usdt));
        return IERC20(address(wsteth));
    }

    function _pairTokenB(uint8 vaultIndex) internal view virtual returns (address) {
        if (vaultIndex == 0) return address(usdc);
        if (vaultIndex == 1) return address(usdt);
        return address(weth);
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
        for (uint8 i; i < vaultCount; ++i) {
            args.standardExchangeVaults[i] = _seVaultAt(i);
            args.vaultShareRateProviders[i] = IRateProvider(address(0)); // L17: no auto SE RP
        }
        args.amplificationParameter = _amplificationParameter();
    }

    function _initPool() internal virtual override {
        uint8 u = _targetUnpairedCount();
        uint8 n = _targetVaultCount();
        IERC20 buffer = _bufferToken();

        for (uint8 i; i < n; ++i) {
            mintSharesForVault(i, alice, MBMVS_INIT_SHARES * 3);
        }
        _mintToken(address(buffer), alice, MBMVS_INIT_BUFFER * 4);
        for (uint8 i; i < u; ++i) {
            _mintToken(address(_unpairedTokenAt(i)), alice, MBMVS_INIT_UNPAIRED * 2);
        }

        vm.startPrank(alice);
        buffer.approve(address(router), type(uint256).max);
        for (uint8 i; i < n; ++i) {
            IERC20(address(_seVaultAt(i))).approve(address(router), type(uint256).max);
        }
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

    function mintSharesForVault(uint8 vaultIndex, address recipient, uint256 tokenAmount)
        public
        returns (uint256 sharesOut)
    {
        address tokenA = address(_bufferToken());
        address tokenB = _pairTokenB(vaultIndex);
        _mintToken(tokenA, recipient, tokenAmount);
        _mintToken(tokenB, recipient, tokenAmount);
        sharesOut = _addLpAndDeposit(vaultIndex, recipient, tokenA, tokenB, tokenAmount);
    }

    function _addLpAndDeposit(uint8 vaultIndex, address recipient, address tokenA, address tokenB, uint256 tokenAmount)
        internal
        returns (uint256 sharesOut)
    {
        address se = address(_seVaultAt(vaultIndex));
        address aero = address(_aeroPoolAt(vaultIndex));
        vm.startPrank(recipient);
        IERC20(tokenA).approve(address(aeroRouter), tokenAmount);
        IERC20(tokenB).approve(address(aeroRouter), tokenAmount);
        sharesOut = _lpAndDepositInner(tokenA, tokenB, tokenAmount, recipient, aero, se);
        vm.stopPrank();
    }

    function _lpAndDepositInner(
        address tokenA,
        address tokenB,
        uint256 amt,
        address recipient,
        address aero,
        address se
    ) private returns (uint256 sharesOut) {
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            tokenA, tokenB, false, amt, amt, 1, 1, recipient, block.timestamp + 1 hours
        );
        IERC20(aero).approve(se, lpOut);
        sharesOut = IStandardExchangeProxy(se).deposit(lpOut, recipient);
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

    /// @dev Public accessors for invariant handler.
    function handlerAlice() public view returns (address) {
        return alice;
    }

    function handlerDai() public view returns (IERC20) {
        return IERC20(address(dai));
    }

    function handlerSeVault0() public view returns (address) {
        return address(seVault);
    }

    function handlerPool() public view returns (address) {
        return mbmvsPool;
    }

    function handlerUnpaired0() public view returns (IERC20) {
        return _unpairedTokenAt(0);
    }
}
