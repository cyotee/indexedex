// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV2StandardExchange
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title TestBase_UniswapV2StandardExchange_Decimals
 * @notice Uni V2 SE two-token combos. pairToken = tokenA; other = tokenB. vaultShare stays 18.
 * @dev Gold MultiPool constructs 18-dec stubs; this base does not call that setUp.
 *      After Uniswap pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 */
abstract contract TestBase_UniswapV2StandardExchange_Decimals is TestBase_UniswapV2StandardExchange {
    /// @notice Dust floor for LP slices. Gold uses 1e12; 6-dec LP is ~1e10 so that would skip.
    uint256 constant MIN_TEST_AMOUNT = 1e3;

    enum PoolConfig {
        Balanced,
        Unbalanced,
        Extreme
    }

    MintableERC20Decimals internal uniswapBalancedTokenA;
    MintableERC20Decimals internal uniswapBalancedTokenB;
    MintableERC20Decimals internal uniswapUnbalancedTokenA;
    MintableERC20Decimals internal uniswapUnbalancedTokenB;
    MintableERC20Decimals internal uniswapExtremeTokenA;
    MintableERC20Decimals internal uniswapExtremeTokenB;

    IUniswapV2Pair internal uniswapBalancedPair;
    IUniswapV2Pair internal uniswapUnbalancedPair;
    IUniswapV2Pair internal uniswapExtremeUnbalancedPair;

    IStandardExchangeProxy internal balancedVault;
    IStandardExchangeProxy internal unbalancedVault;
    IStandardExchangeProxy internal extremeVault;

    function _tokenADecimals() internal pure virtual returns (uint8);
    function _tokenBDecimals() internal pure virtual returns (uint8);

    /// @dev Raw units of pairToken / tokenA (`human * 10 ** decimals`).
    function _uA(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    /// @dev Raw units of the other pool token / tokenB.
    function _uB(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }

    /// @dev Raw units of an arbitrary pool token (use after pair sort).
    function _uToken(address token, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(MintableERC20Decimals(token).decimals()));
    }

    /// @dev Map an 18-dec gold wad onto `token` decimals. Floor at 1 raw unit.
    function _from18(address token, uint256 wad) internal view returns (uint256 raw) {
        uint8 d = MintableERC20Decimals(token).decimals();
        if (d == 18) return wad;
        if (d > 18) return wad * (10 ** (uint256(d) - 18));
        raw = wad / (10 ** (18 - uint256(d)));
        if (raw == 0) raw = 1;
    }

    function setUp() public virtual override {
        TestBase_UniswapV2StandardExchange.setUp();
        _initDecimalPoolsAndVaults();
    }

    function _initDecimalPoolsAndVaults() internal {
        uint8 aDec = _tokenADecimals();
        uint8 bDec = _tokenBDecimals();

        uniswapBalancedTokenA = new MintableERC20Decimals("UniswapBalancedTokenA", "UNIBALA", aDec);
        uniswapBalancedTokenB = new MintableERC20Decimals("UniswapBalancedTokenB", "UNIBALB", bDec);
        uniswapUnbalancedTokenA = new MintableERC20Decimals("UniswapUnbalancedTokenA", "UNIUNA", aDec);
        uniswapUnbalancedTokenB = new MintableERC20Decimals("UniswapUnbalancedTokenB", "UNIUNB", bDec);
        uniswapExtremeTokenA = new MintableERC20Decimals("UniswapExtremeTokenA", "UNIEXA", aDec);
        uniswapExtremeTokenB = new MintableERC20Decimals("UniswapExtremeTokenB", "UNIEXB", bDec);

        vm.label(address(uniswapBalancedTokenA), "pairToken-balanced");
        vm.label(address(uniswapBalancedTokenB), "otherToken-balanced");
        vm.label(address(uniswapUnbalancedTokenA), "pairToken-unbalanced");
        vm.label(address(uniswapUnbalancedTokenB), "otherToken-unbalanced");
        vm.label(address(uniswapExtremeTokenA), "pairToken-extreme");
        vm.label(address(uniswapExtremeTokenB), "otherToken-extreme");

        uniswapBalancedPair = IUniswapV2Pair(
            uniswapV2Factory.createPair(address(uniswapBalancedTokenA), address(uniswapBalancedTokenB))
        );
        uniswapUnbalancedPair = IUniswapV2Pair(
            uniswapV2Factory.createPair(address(uniswapUnbalancedTokenA), address(uniswapUnbalancedTokenB))
        );
        uniswapExtremeUnbalancedPair =
            IUniswapV2Pair(uniswapV2Factory.createPair(address(uniswapExtremeTokenA), address(uniswapExtremeTokenB)));

        _addLiquidity(uniswapBalancedTokenA, uniswapBalancedTokenB, _uA(10_000), _uB(10_000));
        _addLiquidity(uniswapUnbalancedTokenA, uniswapUnbalancedTokenB, _uA(10_000), _uB(1_000));
        _addLiquidity(uniswapExtremeTokenA, uniswapExtremeTokenB, _uA(10_000), _uB(100));

        balancedVault = IStandardExchangeProxy(uniswapV2StandardExchangeDFPkg.deployVault(uniswapBalancedPair));
        unbalancedVault = IStandardExchangeProxy(uniswapV2StandardExchangeDFPkg.deployVault(uniswapUnbalancedPair));
        extremeVault = IStandardExchangeProxy(uniswapV2StandardExchangeDFPkg.deployVault(uniswapExtremeUnbalancedPair));

        vm.label(address(balancedVault), "UniswapBalancedVault");
        vm.label(address(unbalancedVault), "UniswapUnbalancedVault");
        vm.label(address(extremeVault), "UniswapExtremeVault");
    }

    function _addLiquidity(
        MintableERC20Decimals tokenA,
        MintableERC20Decimals tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        tokenA.mint(address(this), amountA);
        tokenB.mint(address(this), amountB);
        tokenA.approve(address(uniswapV2Router), amountA);
        tokenB.approve(address(uniswapV2Router), amountB);
        uniswapV2Router.addLiquidity(
            address(tokenA), address(tokenB), amountA, amountB, 1, 1, address(this), block.timestamp
        );
    }

    function _getVault(PoolConfig config) internal view returns (IStandardExchangeProxy) {
        if (config == PoolConfig.Balanced) return balancedVault;
        if (config == PoolConfig.Unbalanced) return unbalancedVault;
        return extremeVault;
    }

    function _getPool(PoolConfig config) internal view returns (IUniswapV2Pair) {
        if (config == PoolConfig.Balanced) return uniswapBalancedPair;
        if (config == PoolConfig.Unbalanced) return uniswapUnbalancedPair;
        return uniswapExtremeUnbalancedPair;
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }
}
