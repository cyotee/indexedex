// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_UniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    UniswapV4WeightedSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookPairPoolLib.sol";

/**
 * @title TestBase_UniswapV4WeightedSwapHook_Decimals
 * @notice Combo/book underlyings via `MintableERC20Decimals`. Hook LP stays 18.
 * @dev Gold setUp does not construct tokens. pairToken is constructed first; after address
 *      sort PkgArgs order may permute. Wrappers override `_pairDecimals`/`_rateDecimals` or `_bookDec`.
 */
abstract contract TestBase_UniswapV4WeightedSwapHook_Decimals is TestBase_UniswapV4WeightedSwapHook {
    function _pairDecimals() internal pure virtual returns (uint8) {
        return 18;
    }

    function _rateDecimals() internal pure virtual returns (uint8) {
        return 18;
    }

    /// @notice Book leg `i` (construction order: 0 = pairToken). Remaining 18 unless overridden.
    function _bookDec(uint256 i) internal pure virtual returns (uint8) {
        i;
        return 18;
    }

    function _raw(MintableERC20Decimals t, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(t.decimals()));
    }

    function _fundAndApproveDec(address hook_, address[] memory tokens) internal {
        for (uint256 i; i < tokens.length; ++i) {
            MintableERC20Decimals t = MintableERC20Decimals(tokens[i]);
            t.mint(user, 1_000_000_000 * (10 ** uint256(t.decimals())));
            vm.prank(user);
            t.approve(hook_, type(uint256).max);
        }
    }

    function _sortTwo(MintableERC20Decimals a, MintableERC20Decimals b)
        internal
        pure
        returns (MintableERC20Decimals, MintableERC20Decimals)
    {
        return address(a) < address(b) ? (a, b) : (b, a);
    }

    function _sortAddrs(address[] memory toks) internal pure {
        uint256 n = toks.length;
        for (uint256 i; i < n; ++i) {
            for (uint256 j; j + 1 < n; ++j) {
                if (toks[j] > toks[j + 1]) (toks[j], toks[j + 1]) = (toks[j + 1], toks[j]);
            }
        }
    }

    function _equalWeights(uint256 n) internal pure returns (uint256[] memory w) {
        w = new uint256[](n);
        uint256 sum;
        for (uint256 i; i < n; ++i) {
            if (i + 1 == n) w[i] = Math.WAD - sum;
            else w[i] = Math.WAD / n;
            sum += w[i];
        }
    }

    function _deployN2Combo()
        internal
        returns (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1)
    {
        MintableERC20Decimals pair_ = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        MintableERC20Decimals rate_ = new MintableERC20Decimals("Rate", "RATE", _rateDecimals());
        (t0, t1) = _sortTwo(pair_, rate_);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        (hook_,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApproveDec(hook_, tokens);
    }

    function _deployNn(uint256 n)
        internal
        returns (address hook_, MintableERC20Decimals[] memory toks)
    {
        require(n >= 2 && n <= 8, "n");
        toks = new MintableERC20Decimals[](n);
        address[] memory tokens = new address[](n);
        for (uint256 i; i < n; ++i) {
            toks[i] = new MintableERC20Decimals(
                string(abi.encodePacked("T", vm.toString(i))),
                string(abi.encodePacked("T", vm.toString(i))),
                _bookDec(i)
            );
            tokens[i] = address(toks[i]);
        }
        _sortAddrs(tokens);
        for (uint256 i; i < n; ++i) {
            toks[i] = MintableERC20Decimals(tokens[i]);
        }
        uint256[] memory weights;
        if (n == 3) {
            weights = new uint256[](3);
            weights[0] = 4e17;
            weights[1] = 3e17;
            weights[2] = 3e17;
        } else if (n == 4) {
            weights = new uint256[](4);
            weights[0] = 4e17;
            weights[1] = 3e17;
            weights[2] = 2e17;
            weights[3] = 1e17;
        } else {
            weights = _equalWeights(n);
        }
        address[] memory providers = new address[](n);
        (hook_,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApproveDec(hook_, tokens);
    }

    function _joinFull(address hook_, MintableERC20Decimals[] memory toks, uint256 human)
        internal
        returns (uint256 shares)
    {
        uint256 n = toks.length;
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amounts[i] = _raw(toks[i], human);
        }
        vm.prank(user);
        (shares,) = IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function _joinFullN2(address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1, uint256 human)
        internal
        returns (uint256 shares)
    {
        MintableERC20Decimals[] memory toks = new MintableERC20Decimals[](2);
        toks[0] = t0;
        toks[1] = t1;
        return _joinFull(hook_, toks, human);
    }

    function _pairPoolKeysDec(address hook_) internal view returns (PoolKey[] memory) {
        return PairPoolLib.computePairKeys(
            IUniswapV4WeightedSwapHook(hook_).tokens(), hook_, int24(int256(Math.TICK_SPACING))
        );
    }

    function _poolKeyForDec(address a, address b, address hook_) internal pure returns (PoolKey memory key) {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: int24(int256(Math.TICK_SPACING)),
            hooks: IHooks(hook_)
        });
    }
}
