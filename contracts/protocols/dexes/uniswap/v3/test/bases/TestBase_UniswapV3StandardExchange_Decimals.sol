// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

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
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title TestBase_UniswapV3StandardExchange_Decimals
 * @notice Two-token Uni V3 SE TestBase. pairToken = tokenA. Copies gold deploy sequence;
 *         pair tokens are `MintableERC20Decimals`. Pool init is human 1:1 after address sort.
 * @dev Gold `_createPoolOneToOne` / `_seedExternalLiquidity` are non-virtual and mint
 *      `100_000_000 ether`. This file reimplements them with scaled raw units.
 */
abstract contract TestBase_UniswapV3StandardExchange_Decimals is
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

    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;

    /// @dev pairToken role.
    function _tokenADecimals() internal pure virtual returns (uint8);
    /// @dev Other pool token role.
    function _tokenBDecimals() internal pure virtual returns (uint8);

    function _uA(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    function _uB(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }

    function _uToken(address token, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(IERC20Metadata(token).decimals()));
    }

    function _u0(uint256 human) internal view returns (uint256) {
        return _uToken(pool.token0(), human);
    }

    function _u1(uint256 human) internal view returns (uint256) {
        return _uToken(pool.token1(), human);
    }

    function _toWad(address token, uint256 raw) internal view returns (uint256) {
        uint8 d = IERC20Metadata(token).decimals();
        if (d == 18) return raw;
        if (d < 18) return raw * (10 ** uint256(18 - d));
        return raw / (10 ** uint256(d - 18));
    }

    function _mint(address token, address to, uint256 amount) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("mint(address,uint256)", to, amount));
        require(ok, "mint");
    }

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        uniswapV3Factory = new UniswapV3Factory();
        vm.label(address(uniswapV3Factory), "uniswapV3Factory");

        uniswapV3StandardExchangeInFacet = create3Factory.deployUniswapV3StandardExchangeInFacet();
        uniswapV3StandardExchangeInQueryFacet = create3Factory.deployUniswapV3StandardExchangeInQueryFacet();
        uniswapV3StandardExchangeOutFacet = create3Factory.deployUniswapV3StandardExchangeOutFacet();
        uniswapV3StandardExchangeOutQueryFacet = create3Factory.deployUniswapV3StandardExchangeOutQueryFacet();
        uniswapV3StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV3StandardExchangePositionImportFacet();
        uniswapV3StandardExchangeLiquidReserveFacet =
            create3Factory.deployUniswapV3StandardExchangeLiquidReserveFacet();
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

    function _deployPairTokens() internal {
        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
    }

    /// @dev Human 1:1 after address sort. NatSpec on combo wrappers records pairToken vs other role decimals.
    function _createPoolOneToOne(address tokenA_, address tokenB_, uint24 fee)
        internal
        returns (IUniswapV3Pool pool_)
    {
        (address token0, address token1) = tokenA_ < tokenB_ ? (tokenA_, tokenB_) : (tokenB_, tokenA_);
        pool_ = IUniswapV3Pool(uniswapV3Factory.createPool(token0, token1, fee));
        uint8 d0 = IERC20Metadata(token0).decimals();
        uint8 d1 = IERC20Metadata(token1).decimals();
        pool_.initialize(_humanOneToOneSqrtPriceX96(d0, d1));
        vm.label(address(pool_), "V3Pool");
    }

    function _humanOneToOneSqrtPriceX96(uint8 d0, uint8 d1) internal pure returns (uint160) {
        uint256 amount0 = 10 ** uint256(d0);
        uint256 amount1 = 10 ** uint256(d1);
        return uint160(Math.sqrt(FullMath.mulDiv(amount1, uint256(1) << 192, amount0)));
    }

    function _deployVault(IUniswapV3Pool pool_) internal returns (IStandardExchangeProxy vault_) {
        vault_ = IStandardExchangeProxy(uniswapV3StandardExchangeDFPkg.deployVault(pool_));
    }

    /// @dev Mints `100_000_000` human units of each leg (not `100_000_000 ether`). Liquidity is
    ///      the geometric-mean scale so a human-1:1 full-range mint fits both balances.
    function _seedExternalLiquidity(IUniswapV3Pool pool_, uint128) internal {
        int24 tickSpacing = pool_.tickSpacing();
        int24 tickLower = (-887220 / tickSpacing) * tickSpacing;
        int24 tickUpper = (887220 / tickSpacing) * tickSpacing;
        if (tickLower >= tickUpper) {
            tickLower = -tickSpacing * 1000;
            tickUpper = tickSpacing * 1000;
        }

        address token0 = pool_.token0();
        address token1 = pool_.token1();
        uint8 d0 = IERC20Metadata(token0).decimals();
        uint8 d1 = IERC20Metadata(token1).decimals();
        _mint(token0, address(this), 100_000_000 * (10 ** uint256(d0)));
        _mint(token1, address(this), 100_000_000 * (10 ** uint256(d1)));

        uint256 geom = 10 ** (uint256(d0 + d1) / 2);
        uint128 liq = uint128(50_000_000 * geom);
        pool_.mint(address(this), tickLower, tickUpper, liq, abi.encode(address(this)));
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data)
        external
        override
    {
        address payer = abi.decode(data, (address));
        require(payer == address(this), "unexpected payer");
        IUniswapV3Pool pool_ = IUniswapV3Pool(msg.sender);
        if (amount0Owed > 0) IERC20(pool_.token0()).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(pool_.token1()).transfer(msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
        external
        override
    {
        address payer = abi.decode(data, (address));
        require(payer == address(this), "unexpected payer");
        IUniswapV3Pool pool_ = IUniswapV3Pool(msg.sender);
        if (amount0Delta > 0) IERC20(pool_.token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(pool_.token1()).transfer(msg.sender, uint256(amount1Delta));
    }

    function _externalSwapExactIn(IUniswapV3Pool pool_, bool zeroForOne, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        address tokenIn = zeroForOne ? pool_.token0() : pool_.token1();
        _mint(tokenIn, address(this), amountIn);
        (int256 amount0, int256 amount1) = pool_.swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(address(this))
        );
        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
    }

    function _swapHuman(IUniswapV3Pool pool_, bool zeroForOne, uint256 human)
        internal
        returns (uint256 amountOut)
    {
        address tokenIn = zeroForOne ? pool_.token0() : pool_.token1();
        return _externalSwapExactIn(pool_, zeroForOne, _uToken(tokenIn, human));
    }

    function _floorTick(int24 tick, int24 spacing) internal pure returns (int24) {
        int24 compressed = tick / spacing;
        if (tick < 0 && tick % spacing != 0) compressed--;
        return compressed * spacing;
    }

    function _ticksAroundSpot(IUniswapV3Pool pool_, int24 width)
        internal
        view
        returns (int24 lower, int24 upper)
    {
        int24 spacing = pool_.tickSpacing();
        (, int24 tick,,,,,) = pool_.slot0();
        int24 aligned = _floorTick(tick, spacing);
        lower = aligned - spacing * width;
        upper = aligned + spacing * width;
        int24 minU = TickMath.minUsableTick(spacing);
        int24 maxU = TickMath.maxUsableTick(spacing);
        if (lower < minU) lower = minU;
        if (upper > maxU) upper = maxU;
        if (lower >= upper) {
            lower = aligned - spacing;
            upper = aligned + spacing;
        }
    }
}
