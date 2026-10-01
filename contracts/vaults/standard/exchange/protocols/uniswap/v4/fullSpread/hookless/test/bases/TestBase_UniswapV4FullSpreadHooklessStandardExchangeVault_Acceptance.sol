// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault} from "./TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

// tag::TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance[]
/// @notice Registry-deployed H vault, real manager/oracle, independently funded external LP.
abstract contract TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance
    is TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault, IUnlockCallback
{
    using BalanceDeltaLibrary for BalanceDelta;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    IERC20 internal token0;
    IERC20 internal token1;
    uint256 internal unit0;
    uint256 internal unit1;
    bool private inCallback;

    function _decimalsA() internal pure virtual returns (uint8) { return 18; }
    function _decimalsB() internal pure virtual returns (uint8) { return 18; }
    function _native() internal pure virtual returns (bool) { return false; }
    function _tickSpacing() internal pure virtual returns (int24) { return 60; }

    function setUp() public virtual override {
        super.setUp();
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Pair B", "B", _decimalsB(), address(this), 1e32);
        if (_native()) {
            vm.deal(address(this), 1e32);
            weth.deposit{value: 1e30}();
            token0 = IERC20(address(weth)); token1 = IERC20(address(b));
            unit0 = 1e18; unit1 = 10 ** uint256(_decimalsB());
        } else {
            IERC20 a = _deployTokenA();
            bool ordered = address(a) < address(b);
            token0 = IERC20(ordered ? address(a) : address(b)); token1 = IERC20(ordered ? address(b) : address(a));
            unit0 = 10 ** uint256(ordered ? _decimalsA() : _decimalsB());
            unit1 = 10 ** uint256(ordered ? _decimalsB() : _decimalsA());
        }
        poolKey = PoolKey(Currency.wrap(_native() ? address(0) : address(token0)), Currency.wrap(address(token1)),
            3_000, _tickSpacing(), IHooks(address(0)));
        uint160 price = uint160((uint256(1) << 96) * Math.sqrt(1e18 * unit1 / unit0) / 1e9);
        poolManager.initialize(poolKey, price);
        _seedPool(uint128(1_000_000 * Math.sqrt(unit0 * unit1)));
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
    }

    function _tokens() internal view returns (address[] memory tokens_) {
        tokens_ = new address[](2); tokens_[0] = address(token0); tokens_[1] = address(token1);
    }

    function _deployTokenA() internal virtual returns (IERC20) {
        return IERC20(address(new ERC20PermitMintableStub("Pair A", "A", _decimalsA(), address(this), 1e32)));
    }

    function _seedPool(uint128 liquidity_) internal { _outer(abi.encode(uint8(0), abi.encode(liquidity_))); }

    function _amounts(uint256 amount0_, uint256 amount1_) internal pure returns (uint256[] memory amounts_) {
        amounts_ = new uint256[](2); amounts_[0] = amount0_; amounts_[1] = amount1_;
    }

    function _bootstrap() internal returns (uint256 shares_) {
        uint256[] memory amounts = _amounts(1_000 * unit0, 1_000 * unit1);
        uint256 expected = IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(_tokens(), amounts, IERC20(address(vault)));
        shares_ = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            _tokens(), amounts, IERC20(address(vault)), expected, address(this), false, block.timestamp
        );
        assertEq(shares_, expected);
        _assertBooked();
    }

    function _assertBooked() internal view {
        assertEq(vault.reserveOfToken(address(token0)), token0.balanceOf(address(vault)));
        assertEq(vault.reserveOfToken(address(token1)), token1.balanceOf(address(vault)));
        assertEq(vault.reserveOfToken(address(vault)), vault.balanceOf(address(vault)));
        assertEq(address(vault).balance, 0);
    }

    function _nested(bytes memory call_) internal returns (bytes memory) { return _outer(abi.encode(uint8(1), call_)); }

    function _externalSwap(bool direction_, uint256 amount_) internal {
        _outer(abi.encode(uint8(2), abi.encode(direction_, amount_)));
    }

    function _outer(bytes memory data_) private returns (bytes memory result_) {
        require(!inCallback, "recursive test driver");
        inCallback = true;
        result_ = poolManager.unlock(data_);
        inCallback = false;
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(poolManager) && inCallback, "unauthorized test callback");
        (uint8 operation, bytes memory payload) = abi.decode(data_, (uint8, bytes));
        if (operation == 1) {
            (bool success, bytes memory result) = address(vault).call(payload);
            if (!success) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
            return result;
        }
        BalanceDelta delta;
        if (operation == 0) {
            (delta,) = poolManager.modifyLiquidity(poolKey, ModifyLiquidityParams(
                TickMath.minUsableTick(poolKey.tickSpacing), TickMath.maxUsableTick(poolKey.tickSpacing), int256(uint256(abi.decode(payload, (uint128)))), bytes32(0)), "");
        } else {
            (bool direction, uint256 amount) = abi.decode(payload, (bool, uint256));
            delta = poolManager.swap(poolKey, SwapParams(direction, -int256(amount),
                direction ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
        }
        _settle(poolKey.currency0, delta.amount0());
        _settle(poolKey.currency1, delta.amount1());
        return abi.encode(delta);
    }

    function _settle(Currency currency_, int128 delta_) private {
        if (delta_ < 0) {
            poolManager.sync(currency_);
            if (Currency.unwrap(currency_) == address(0)) {
                poolManager.settle{value: uint128(-delta_)}();
            } else {
                IERC20(Currency.unwrap(currency_)).transfer(address(poolManager), uint128(-delta_));
                poolManager.settle();
            }
        } else if (delta_ > 0) poolManager.take(currency_, address(this), uint128(delta_));
    }
}
// end::TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance[]
