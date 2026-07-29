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
    ICommonBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePool.sol";
import {
    ICommonBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolStandardVaultPkg.sol";
import {
    CommonBufferMultiVaultStablePool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePool_FactoryService.sol";

/**
 * @title TestBase_CommonBufferMultiVaultStablePool
 * @notice Default: N=1, buffer=DAI → seVault. Override N for multi-vault.
 * @dev Production-first: CREATE3 facets + manager registry DFPkg; real Aerodrome SE vaults.
 */
abstract contract TestBase_CommonBufferMultiVaultStablePool is TestBase_StandardExchangeBufferPool {
    using CommonBufferMultiVaultStablePool_FactoryService for IVaultRegistryDeployment;

    ICommonBufferMultiVaultStablePoolPkg public cbmvsPkg;
    address public cbmvsPool;

    uint256 internal constant CBMVS_INIT_BUFFER = 1_000e18;
    uint256 internal constant CBMVS_INIT_SHARES = 1_000e18;
    /// @dev Fixed deploy-time amp (raw, without precision).
    uint256 internal constant CBMVS_AMP = 200;

    IStandardExchangeProxy public seVault1;
    IStandardExchangeProxy public seVault2;
    Pool public aeroDaiUsdcPool1;
    Pool public aeroDaiUsdcPool2;

    function _targetVaultCount() internal pure virtual returns (uint8) {
        return 1;
    }

    function _bufferToken() internal view virtual returns (IERC20) {
        return IERC20(address(dai));
    }

    function _amplificationParameter() internal pure virtual returns (uint256) {
        return CBMVS_AMP;
    }

    function _deployBufferPoolFacets() internal virtual override {
        TestBase_StandardExchangeBufferPool._deployBufferPoolFacets();
        bufferPoolFacet =
            CommonBufferMultiVaultStablePool_FactoryService.deployCommonBufferMultiVaultStablePoolFacet(create3Factory);
        poolLiquidityFacet =
            CommonBufferMultiVaultStablePool_FactoryService.deployCommonBufferMultiVaultStableLiquidityFacet(
                    create3Factory
                );
        hookFacet =
            CommonBufferMultiVaultStablePool_FactoryService.deployCommonBufferMultiVaultStableHookFacet(create3Factory);
    }

    function _deployBufferPoolPkg() internal virtual override {
        ICommonBufferMultiVaultStablePoolPkg.PkgInit memory pkgInit;
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
        cbmvsPkg = CommonBufferMultiVaultStablePool_FactoryService.deployCommonBufferMultiVaultStablePoolPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(cbmvsPkg), "CommonBufferMultiVaultStablePkg");
    }

    function _deployBufferPool() internal virtual override {
        _deployBufferPoolFacets();
        _deployBufferPoolPkg();

        uint8 n = _targetVaultCount();
        if (n >= 2) _deployExtraDaiSeVault(1);
        if (n >= 3) _deployExtraDaiSeVault(2);

        cbmvsPool = _deployCbmvsPool(n);
        bufferPool = cbmvsPool;
        vm.label(cbmvsPool, "CommonBufferMultiVaultStablePool");
        approveForPool(IERC20(cbmvsPool));
    }

    function _deployExtraDaiSeVault(uint8 idx) internal {
        address tokenA = address(dai);
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

    function _pairTokenB(uint8 vaultIndex) internal view virtual returns (address) {
        if (vaultIndex == 0) return address(usdc);
        if (vaultIndex == 1) return address(usdt);
        return address(weth);
    }

    function _deployCbmvsPool(uint8 vaultCount) internal returns (address pool) {
        ICommonBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(vaultCount);
        pool = cbmvsPkg.deployPool(args);
    }

    function _buildPkgArgs(uint8 vaultCount)
        internal
        view
        virtual
        returns (ICommonBufferMultiVaultStablePoolPkg.PkgArgs memory args)
    {
        args.bufferToken = _bufferToken();
        args.vaultCount = vaultCount;
        args.standardExchangeVaults = new IStandardExchange[](vaultCount);
        args.vaultShareRateProviders = new IRateProvider[](vaultCount);
        for (uint8 i; i < vaultCount; ++i) {
            args.standardExchangeVaults[i] = _seVaultAt(i);
            args.vaultShareRateProviders[i] = IRateProvider(address(0));
        }
        args.amplificationParameter = _amplificationParameter();
    }

    function _initPool() internal virtual override {
        uint8 n = _targetVaultCount();
        IERC20 buffer = _bufferToken();

        for (uint8 i; i < n; ++i) {
            mintSharesForVault(i, alice, CBMVS_INIT_SHARES * 3);
        }
        _mintToken(address(buffer), alice, CBMVS_INIT_BUFFER * 4);

        vm.startPrank(alice);
        buffer.approve(address(router), type(uint256).max);
        for (uint8 i; i < n; ++i) {
            IERC20(address(_seVaultAt(i))).approve(address(router), type(uint256).max);
        }

        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(cbmvsPool);
        uint256[] memory amounts = new uint256[](poolTokens.length);
        ICommonBufferMultiVaultStablePool poolView = ICommonBufferMultiVaultStablePool(cbmvsPool);
        for (uint256 t; t < poolTokens.length; ++t) {
            (ICommonBufferMultiVaultStablePool.TokenKind kind,) = poolView.resolveTokenIndex(t);
            if (kind == ICommonBufferMultiVaultStablePool.TokenKind.Buffer) {
                amounts[t] = CBMVS_INIT_BUFFER;
            } else {
                amounts[t] = CBMVS_INIT_SHARES;
            }
        }
        router.initialize(cbmvsPool, poolTokens, amounts, 0, false, bytes(""));
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
            cbmvsPool, tokenIn, tokenOut, amountIn, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
    }

    function cbmvs() internal view returns (ICommonBufferMultiVaultStablePool) {
        return ICommonBufferMultiVaultStablePool(cbmvsPool);
    }

    function rawPoolBufferBalance() public view returns (uint256) {
        (IERC20[] memory tokens,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(cbmvsPool);
        address buf = address(_bufferToken());
        for (uint256 i; i < tokens.length; ++i) {
            if (address(tokens[i]) == buf) return balancesRaw[i];
        }
        return 0;
    }
}
