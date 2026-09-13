// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {TestBase_Aerodrome} from "@crane/contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_Aerodrome.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/IAerodromeStandardExchangeDFPkg.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    Aerodrome_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title TestBase_AerodromeStandardExchange_Decimals
 * @notice Aerodrome SE with combo-decimal pair tokens. Does not call gold Pools setUp
 *         (18-dec ERC20PermitMintableStub). pairToken = tokenA. Crane usdc 18 is not 6-dec.
 * @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
 *      vaultShare stays 18. Amounts are raw units via `_uA` / `_uB` / `_testAmt`.
 */
abstract contract TestBase_AerodromeStandardExchange_Decimals is
    TestBase_Permit2,
    TestBase_Aerodrome,
    TestBase_VaultComponents
{
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for IIndexedexManagerProxy;

    IFacet aerodromeStandardExchangeInFacet;
    IFacet aerodromeStandardExchangeOutFacet;
    IFacet aerodromeStandardExchangeOutQueryFacet;
    IAerodromeStandardExchangeDFPkg aerodromeStandardExchangeDFPkg;

    MintableERC20Decimals aeroBalancedTokenA;
    MintableERC20Decimals aeroBalancedTokenB;
    MintableERC20Decimals aeroUnbalancedTokenA;
    MintableERC20Decimals aeroUnbalancedTokenB;
    MintableERC20Decimals aeroExtremeTokenA;
    MintableERC20Decimals aeroExtremeTokenB;
    MintableERC20Decimals aeroStableTokenA;
    MintableERC20Decimals aeroStableTokenB;

    Pool aeroBalancedPool;
    Pool aeroUnbalancedPool;
    Pool aeroExtremeUnbalancedPool;
    Pool aeroStablePool;

    /// @notice Dust floor. Gold MultiPool used 1e12, which exceeds 6-dec reserves.
    uint256 constant MIN_TEST_AMOUNT = 1e3;

    enum PoolConfig {
        Balanced,
        Unbalanced,
        Extreme
    }

    IStandardExchangeProxy balancedVault;
    IStandardExchangeProxy unbalancedVault;
    IStandardExchangeProxy extremeVault;

    function _tokenADecimals() internal pure virtual returns (uint8);
    function _tokenBDecimals() internal pure virtual returns (uint8);

    function _uA(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    function _uB(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }

    /// @dev Raw units of an arbitrary pool token (use after address sort).
    function _uToken(address token, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(MintableERC20Decimals(token).decimals()));
    }

    /// @dev 1000 human units of `token` (gold TEST_AMOUNT was 1000e18).
    function _testAmt(MintableERC20Decimals token) internal view returns (uint256) {
        return 1000 * (10 ** uint256(token.decimals()));
    }

    /// @dev Map an 18-dec gold wad onto `token` decimals. Floor at 1 raw unit.
    function _from18(address token, uint256 wad) internal view returns (uint256 raw) {
        uint8 d = MintableERC20Decimals(token).decimals();
        if (d == 18) return wad;
        if (d > 18) return wad * (10 ** (uint256(d) - 18));
        raw = wad / (10 ** (18 - uint256(d)));
        if (raw == 0) raw = 1;
    }

    function setUp()
        public
        virtual
        override(TestBase_Permit2, TestBase_Aerodrome, TestBase_VaultComponents)
    {
        TestBase_Permit2.setUp();
        TestBase_Aerodrome.setUp();
        TestBase_VaultComponents.setUp();
        _createAerodromeTokens();
        _createAerodromePools();
        _initializeAerodromeBalancedPools();
        _initializeAerodromeUnbalancedPools();
        _initializeAerodromeExtremeUnbalancedPools();

        aerodromeStandardExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        aerodromeStandardExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();
        aerodromeStandardExchangeOutQueryFacet = create3Factory.deployAerodromeStandardExchangeOutQueryFacet();
        vm.startPrank(owner);
        {
            IAerodromeStandardExchangeDFPkg.PkgInit memory pkgInit_;
            pkgInit_.erc20Facet = erc20Facet;
            pkgInit_.erc2612Facet = erc2612Facet;
            pkgInit_.erc5267Facet = erc5267Facet;
            pkgInit_.erc4626Facet = erc4626Facet;
            pkgInit_.multiAssetBasicVaultFacet = erc4626BasicVaultFacet;
            pkgInit_.multiAssetStandardVaultFacet = erc4626StandardVaultFacet;
            pkgInit_.aerodromeStandardExchangeInFacet = aerodromeStandardExchangeInFacet;
            pkgInit_.aerodromeStandardExchangeOutFacet = aerodromeStandardExchangeOutFacet;
            pkgInit_.aerodromeStandardExchangeOutQueryFacet = aerodromeStandardExchangeOutQueryFacet;
            pkgInit_.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(indexedexManager));
            pkgInit_.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
            pkgInit_.permit2 = permit2;
            pkgInit_.aerodromeRouter = aerodromeRouter;
            pkgInit_.aerodromePoolFactory = aerodromePoolFactory;
            aerodromeStandardExchangeDFPkg = indexedexManager.deployAerodromeStandardExchangeDFPkg(pkgInit_);
        }
        vm.stopPrank();

        balancedVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroBalancedPool));
        unbalancedVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroUnbalancedPool));
        extremeVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroExtremeUnbalancedPool));
        vm.label(address(balancedVault), "BalancedVault");
        vm.label(address(unbalancedVault), "UnbalancedVault");
        vm.label(address(extremeVault), "ExtremeVault");
    }

    function _createAerodromeTokens() internal {
        uint8 da = _tokenADecimals();
        uint8 db = _tokenBDecimals();
        aeroBalancedTokenA = new MintableERC20Decimals("AerodromeBalancedTokenA", "AEROBALA", da);
        aeroBalancedTokenB = new MintableERC20Decimals("AerodromeBalancedTokenB", "AEROBALB", db);
        aeroUnbalancedTokenA = new MintableERC20Decimals("AerodromeUnbalancedTokenA", "AEROUNA", da);
        aeroUnbalancedTokenB = new MintableERC20Decimals("AerodromeUnbalancedTokenB", "AEROUNB", db);
        aeroExtremeTokenA = new MintableERC20Decimals("AerodromeExtremeTokenA", "AEROEXA", da);
        aeroExtremeTokenB = new MintableERC20Decimals("AerodromeExtremeTokenB", "AEROEXB", db);
        aeroStableTokenA = new MintableERC20Decimals("AerodromeStableTokenA", "AEROSTA", da);
        aeroStableTokenB = new MintableERC20Decimals("AerodromeStableTokenB", "AEROSTB", db);
        vm.label(address(aeroBalancedTokenA), "pairToken-balanced");
        vm.label(address(aeroBalancedTokenB), "otherToken-balanced");
        vm.label(address(aeroUnbalancedTokenA), "pairToken-unbalanced");
        vm.label(address(aeroUnbalancedTokenB), "otherToken-unbalanced");
        vm.label(address(aeroExtremeTokenA), "pairToken-extreme");
        vm.label(address(aeroExtremeTokenB), "otherToken-extreme");
    }

    function _createAerodromePools() internal {
        aeroBalancedPool = Pool(
            aerodromePoolFactory.createPool(address(aeroBalancedTokenA), address(aeroBalancedTokenB), false)
        );
        aeroUnbalancedPool = Pool(
            aerodromePoolFactory.createPool(address(aeroUnbalancedTokenA), address(aeroUnbalancedTokenB), false)
        );
        aeroExtremeUnbalancedPool = Pool(
            aerodromePoolFactory.createPool(address(aeroExtremeTokenA), address(aeroExtremeTokenB), false)
        );
        aeroStablePool = Pool(
            aerodromePoolFactory.createPool(address(aeroStableTokenA), address(aeroStableTokenB), true)
        );
    }

    function _initializeAerodromeBalancedPools() internal {
        uint256 liqA = _uA(10_000);
        uint256 liqB = _uB(10_000);
        aeroBalancedTokenA.mint(address(this), liqA);
        aeroBalancedTokenA.approve(address(aerodromeRouter), liqA);
        aeroBalancedTokenB.mint(address(this), liqB);
        aeroBalancedTokenB.approve(address(aerodromeRouter), liqB);
        aerodromeRouter.addLiquidity(
            address(aeroBalancedTokenA),
            address(aeroBalancedTokenB),
            false,
            liqA,
            liqB,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function _initializeAerodromeUnbalancedPools() internal {
        uint256 amtA = _uA(10_000);
        uint256 amtB = _uB(1_000);
        aeroUnbalancedTokenA.mint(address(this), amtA);
        aeroUnbalancedTokenA.approve(address(aerodromeRouter), amtA);
        aeroUnbalancedTokenB.mint(address(this), amtB);
        aeroUnbalancedTokenB.approve(address(aerodromeRouter), amtB);
        aerodromeRouter.addLiquidity(
            address(aeroUnbalancedTokenA),
            address(aeroUnbalancedTokenB),
            false,
            amtA,
            amtB,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function _initializeAerodromeExtremeUnbalancedPools() internal {
        uint256 amtA = _uA(10_000);
        uint256 amtB = _uB(100);
        aeroExtremeTokenA.mint(address(this), amtA);
        aeroExtremeTokenA.approve(address(aerodromeRouter), amtA);
        aeroExtremeTokenB.mint(address(this), amtB);
        aeroExtremeTokenB.approve(address(aerodromeRouter), amtB);
        aerodromeRouter.addLiquidity(
            address(aeroExtremeTokenA),
            address(aeroExtremeTokenB),
            false,
            amtA,
            amtB,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function _initializeAerodromeStablePool() internal {
        uint256 liqA = _uA(10_000);
        uint256 liqB = _uB(10_000);
        aeroStableTokenA.mint(address(this), liqA);
        aeroStableTokenA.approve(address(aerodromeRouter), liqA);
        aeroStableTokenB.mint(address(this), liqB);
        aeroStableTokenB.approve(address(aerodromeRouter), liqB);
        aerodromeRouter.addLiquidity(
            address(aeroStableTokenA),
            address(aeroStableTokenB),
            true,
            liqA,
            liqB,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function _getVault(PoolConfig config) internal view returns (IStandardExchangeProxy) {
        if (config == PoolConfig.Balanced) return balancedVault;
        if (config == PoolConfig.Unbalanced) return unbalancedVault;
        return extremeVault;
    }

    function _getPool(PoolConfig config) internal view returns (IPool) {
        if (config == PoolConfig.Balanced) return aeroBalancedPool;
        if (config == PoolConfig.Unbalanced) return aeroUnbalancedPool;
        return aeroExtremeUnbalancedPool;
    }

    function _getTokens(PoolConfig config)
        internal
        view
        returns (MintableERC20Decimals tokenA, MintableERC20Decimals tokenB)
    {
        if (config == PoolConfig.Balanced) {
            return (aeroBalancedTokenA, aeroBalancedTokenB);
        }
        if (config == PoolConfig.Unbalanced) {
            return (aeroUnbalancedTokenA, aeroUnbalancedTokenB);
        }
        return (aeroExtremeTokenA, aeroExtremeTokenB);
    }

    function _mintAndApprove(PoolConfig config, address recipient, uint256 amountA, uint256 amountB) internal {
        (MintableERC20Decimals tokenA, MintableERC20Decimals tokenB) = _getTokens(config);
        IStandardExchangeProxy vault = _getVault(config);

        if (amountA > 0) {
            tokenA.mint(recipient, amountA);
            vm.prank(recipient);
            tokenA.approve(address(vault), amountA);
        }
        if (amountB > 0) {
            tokenB.mint(recipient, amountB);
            vm.prank(recipient);
            tokenB.approve(address(vault), amountB);
        }
    }

    function _mintLPAndApprove(PoolConfig config, address recipient, uint256 amount) internal {
        IPool pool = _getPool(config);
        IStandardExchangeProxy vault = _getVault(config);
        IERC20(address(pool)).transfer(recipient, amount);
        vm.prank(recipient);
        IERC20(address(pool)).approve(address(vault), amount);
    }

    function _approveVaultShares(PoolConfig config, address user, uint256 amount) internal {
        IStandardExchangeProxy vault = _getVault(config);
        vm.prank(user);
        vault.approve(address(vault), amount);
    }

    function _getReserves(PoolConfig config) internal view returns (uint256 reserveA, uint256 reserveB) {
        IPool pool = _getPool(config);
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        (MintableERC20Decimals tokenA,) = _getTokens(config);
        if (address(tokenA) == pool.token0()) {
            return (reserve0, reserve1);
        }
        return (reserve1, reserve0);
    }

    function _getLPTotalSupply(PoolConfig config) internal view returns (uint256) {
        return IERC20(address(_getPool(config))).totalSupply();
    }

    function _getLPBalance(PoolConfig config, address account) internal view returns (uint256) {
        return IERC20(address(_getPool(config))).balanceOf(account);
    }

    function _generatePoolFees(PoolConfig config) internal {
        (MintableERC20Decimals tokenA, MintableERC20Decimals tokenB) = _getTokens(config);
        _executeAerodromeTradesToGenerateFees(tokenA, tokenB);
    }

    function _executeAerodromeTradesToGenerateFees(MintableERC20Decimals tokenA, MintableERC20Decimals tokenB)
        internal
    {
        uint256 swapAmountA = _testAmt(tokenA) / 10;
        tokenA.mint(address(this), swapAmountA);
        tokenA.approve(address(aerodromeRouter), swapAmountA);

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: address(tokenA), to: address(tokenB), stable: false, factory: address(aerodromePoolFactory)
        });

        aerodromeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            swapAmountA, 0, routes, address(this), block.timestamp + 300
        );

        uint256 balanceB = tokenB.balanceOf(address(this));
        if (balanceB > 0) {
            tokenB.approve(address(aerodromeRouter), balanceB);
            IRouter.Route[] memory routesRev = new IRouter.Route[](1);
            routesRev[0] = IRouter.Route({
                from: address(tokenB), to: address(tokenA), stable: false, factory: address(aerodromePoolFactory)
            });
            aerodromeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                balanceB, 0, routesRev, address(this), block.timestamp + 300
            );
        }

        uint256 balanceA = tokenA.balanceOf(address(this));
        if (balanceA > 0) {
            tokenA.approve(address(aerodromeRouter), balanceA);
            aerodromeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                balanceA, 0, routes, address(this), block.timestamp + 300
            );
        }
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _expiredDeadline() internal view returns (uint256) {
        return block.timestamp - 1;
    }
}
