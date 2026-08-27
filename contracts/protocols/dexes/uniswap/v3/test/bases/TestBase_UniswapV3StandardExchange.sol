// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IUniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";

/**
 * @title TestBase_UniswapV3StandardExchange
 * @notice Gold TestBase: CREATE3 facets + manager-registry DFPkg + hermetic Uni V3 factory/pools.
 */
contract TestBase_UniswapV3StandardExchange is
    TestBase_Permit2,
    TestBase_VaultComponents,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback
{
    using UniswapV3_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV3_Component_FactoryService for IFacet;
    using UniswapV3_Component_FactoryService for IIndexedexManagerProxy;

    uint24 internal constant FEE_MEDIUM = 3000;
    uint256 internal constant DEFAULT_V3_LIQUID_RESERVE_PCT = 0.20e18;

    IUniswapV3Factory internal uniswapV3Factory;
    IFacet internal uniswapV3StandardExchangeInFacet;
    IFacet internal uniswapV3StandardExchangeInQueryFacet;
    IFacet internal uniswapV3StandardExchangeOutFacet;
    IFacet internal uniswapV3StandardExchangeOutQueryFacet;
    IFacet internal uniswapV3StandardExchangePositionImportFacet;
    IFacet internal uniswapV3StandardExchangeLiquidReserveFacet;
    IFacet internal uniswapV3StandardExchangeInMultiFacet;
    IFacet internal uniswapV3StandardExchangeInMultiQueryFacet;
    IFacet internal uniswapV3StandardExchangeOutMultiFacet;
    IFacet internal uniswapV3StandardExchangeOutMultiQueryFacet;
    IUniswapV3StandardExchangeDFPkg internal uniswapV3StandardExchangeDFPkg;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        uniswapV3Factory = new UniswapV3Factory();
        vm.label(address(uniswapV3Factory), "uniswapV3Factory");

        uniswapV3StandardExchangeInFacet = create3Factory.deployUniswapV3StandardExchangeInFacet();
        uniswapV3StandardExchangeInQueryFacet = create3Factory.deployUniswapV3StandardExchangeInQueryFacet();
        uniswapV3StandardExchangeOutFacet = create3Factory.deployUniswapV3StandardExchangeOutFacet();
        uniswapV3StandardExchangeOutQueryFacet = create3Factory.deployUniswapV3StandardExchangeOutQueryFacet();
        uniswapV3StandardExchangePositionImportFacet = create3Factory.deployUniswapV3StandardExchangePositionImportFacet();
        uniswapV3StandardExchangeLiquidReserveFacet = create3Factory.deployUniswapV3StandardExchangeLiquidReserveFacet();
        uniswapV3StandardExchangeInMultiFacet = create3Factory.deployUniswapV3StandardExchangeInMultiFacet();
        uniswapV3StandardExchangeInMultiQueryFacet = create3Factory.deployUniswapV3StandardExchangeInMultiQueryFacet();
        uniswapV3StandardExchangeOutMultiFacet = create3Factory.deployUniswapV3StandardExchangeOutMultiFacet();
        uniswapV3StandardExchangeOutMultiQueryFacet = create3Factory.deployUniswapV3StandardExchangeOutMultiQueryFacet();

        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV3StandardExchangeInFacet = uniswapV3StandardExchangeInFacet;
        pkgInit.uniswapV3StandardExchangeInQueryFacet = uniswapV3StandardExchangeInQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutFacet = uniswapV3StandardExchangeOutFacet;
        pkgInit.uniswapV3StandardExchangeOutQueryFacet = uniswapV3StandardExchangeOutQueryFacet;
        pkgInit.uniswapV3StandardExchangePositionImportFacet = uniswapV3StandardExchangePositionImportFacet;
        pkgInit.uniswapV3StandardExchangeLiquidReserveFacet = uniswapV3StandardExchangeLiquidReserveFacet;
        pkgInit = UniswapV3_Component_FactoryService.attachUniswapV3StandardExchangeMultiFacets(
            pkgInit,
            uniswapV3StandardExchangeInMultiFacet,
            uniswapV3StandardExchangeInMultiQueryFacet,
            uniswapV3StandardExchangeOutMultiFacet,
            uniswapV3StandardExchangeOutMultiQueryFacet
        );
        pkgInit.vaultFeeOracleQuery = indexedexManager;
        pkgInit.vaultRegistryDeployment = indexedexManager;
        pkgInit.permit2 = permit2;
        pkgInit.uniswapV3Factory = uniswapV3Factory;

        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV3StandardExchangeLiquidReserve).interfaceId, DEFAULT_V3_LIQUID_RESERVE_PCT
        );
        uniswapV3StandardExchangeDFPkg = indexedexManager.deployUniswapV3StandardExchangeDFPkg(pkgInit);
        vm.stopPrank();
    }

    function _createPoolOneToOne(address tokenA, address tokenB, uint24 fee)
        internal
        returns (IUniswapV3Pool pool)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pool = IUniswapV3Pool(uniswapV3Factory.createPool(token0, token1, fee));
        pool.initialize(uint160(uint256(1) << 96));
        vm.label(address(pool), "V3Pool");
    }

    function _deployVault(IUniswapV3Pool pool) internal returns (IStandardExchangeProxy vault) {
        vault = IStandardExchangeProxy(uniswapV3StandardExchangeDFPkg.deployVault(pool));
    }

    function _seedExternalLiquidity(IUniswapV3Pool pool, uint128 liquidity) internal {
        int24 tickSpacing = pool.tickSpacing();
        int24 tickLower = (-887220 / tickSpacing) * tickSpacing;
        int24 tickUpper = (887220 / tickSpacing) * tickSpacing;
        if (tickLower >= tickUpper) {
            tickLower = -tickSpacing * 1000;
            tickUpper = tickSpacing * 1000;
        }

        address token0 = pool.token0();
        address token1 = pool.token1();
        ERC20PermitMintableStub(token0).mint(address(this), 100_000_000 ether);
        ERC20PermitMintableStub(token1).mint(address(this), 100_000_000 ether);

        uint128 liq = liquidity < 1e18 ? 50_000_000e18 : liquidity;
        pool.mint(address(this), tickLower, tickUpper, liq, abi.encode(address(this)));
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        address payer = abi.decode(data, (address));
        require(payer == address(this), "unexpected payer");
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender);
        if (amount0Owed > 0) IERC20(pool.token0()).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(pool.token1()).transfer(msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        address payer = abi.decode(data, (address));
        require(payer == address(this), "unexpected payer");
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender);
        if (amount0Delta > 0) IERC20(pool.token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(pool.token1()).transfer(msg.sender, uint256(amount1Delta));
    }

    function _externalSwapExactIn(IUniswapV3Pool pool, bool zeroForOne, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        address tokenIn = zeroForOne ? pool.token0() : pool.token1();
        ERC20PermitMintableStub(tokenIn).mint(address(this), amountIn);
        (int256 amount0, int256 amount1) = pool.swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(address(this))
        );
        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
    }
}
