// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {IUniversalRouter} from "@crane/contracts/external/uniswap/universal-router/interfaces/IUniversalRouter.sol";
import {Commands} from "@crane/contracts/external/uniswap/universal-router/libraries/Commands.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {ActionConstants} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/ActionConstants.sol";
import {IV4Router} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IV4Router.sol";
import {IV4Quoter} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IV4Quoter.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PathKey} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PathKey.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";

/// @title UniswapV4UniversalRouterAdapter
library UniswapV4UniversalRouterAdapter {
    using SafeERC20 for IERC20;

    uint8 internal constant TEMPLATE_A_SINGLE = 1;
    uint8 internal constant TEMPLATE_B_MULTI = 2;

    struct TemplateA {
        PoolKey poolKey;
        bool zeroForOne;
        bytes hookData;
        uint128 amountOutMinimum;
    }

    function execute(address router, uint256 amountIn, uint256 deadline, bytes memory data) public {
        uint8 templateId = _templateId(data);
        if (templateId == TEMPLATE_A_SINGLE) {
            _execA(router, amountIn, deadline, data);
            return;
        }
        if (templateId == TEMPLATE_B_MULTI) {
            _execB(router, amountIn, deadline, data);
            return;
        }
        revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
    }

    function query(address v4Quoter, uint256 amountIn, bytes memory data) public returns (uint256 amountOut) {
        if (v4Quoter == address(0)) revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        uint8 templateId = _templateId(data);
        if (templateId == TEMPLATE_A_SINGLE) {
            TemplateA memory t = _decodeA(data);
            (amountOut,) = IV4Quoter(v4Quoter)
                .quoteExactInputSingle(
                    IV4Quoter.QuoteExactSingleParams({
                        poolKey: t.poolKey,
                        zeroForOne: t.zeroForOne,
                        exactAmount: uint128(amountIn),
                        hookData: t.hookData
                    })
                );
            return amountOut;
        }
        if (templateId == TEMPLATE_B_MULTI) {
            (, Currency currencyIn, PathKey[] memory path,) = abi.decode(data, (uint8, Currency, PathKey[], uint128));
            (amountOut,) = IV4Quoter(v4Quoter)
                .quoteExactInput(
                    IV4Quoter.QuoteExactParams({exactCurrency: currencyIn, path: path, exactAmount: uint128(amountIn)})
                );
            return amountOut;
        }
        revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
    }

    function _templateId(bytes memory data) private pure returns (uint8 id) {
        assembly {
            id := mload(add(data, 0x20))
        }
    }

    function _decodeA(bytes memory data) private pure returns (TemplateA memory t) {
        (, t.poolKey, t.zeroForOne, t.hookData, t.amountOutMinimum) =
            abi.decode(data, (uint8, PoolKey, bool, bytes, uint128));
    }

    function _execA(address router, uint256 amountIn, uint256 deadline, bytes memory data) private {
        TemplateA memory t = _decodeA(data);
        Currency settleCurrency = t.zeroForOne ? t.poolKey.currency0 : t.poolKey.currency1;
        // Fund UR then settle from router balance (payerIsUser=false) — avoids Permit2 AllowanceExpired.
        IERC20(Currency.unwrap(settleCurrency)).safeTransfer(router, amountIn);
        (bytes memory commands, bytes[] memory inputs) = _encodeA(t, uint128(amountIn));
        IUniversalRouter(router).execute(commands, inputs, deadline);
    }

    function _execB(address router, uint256 amountIn, uint256 deadline, bytes memory data) private {
        (, Currency currencyIn, PathKey[] memory path, uint128 amountOutMinimum) =
            abi.decode(data, (uint8, Currency, PathKey[], uint128));
        IERC20(Currency.unwrap(currencyIn)).safeTransfer(router, amountIn);
        (bytes memory commands, bytes[] memory inputs) = _encodeB(currencyIn, path, uint128(amountIn), amountOutMinimum);
        IUniversalRouter(router).execute(commands, inputs, deadline);
    }

    function _encodeA(TemplateA memory t, uint128 amountIn)
        private
        pure
        returns (bytes memory commands, bytes[] memory inputs)
    {
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE), uint8(Actions.TAKE));
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: t.poolKey,
                zeroForOne: t.zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: t.amountOutMinimum,
                hookData: t.hookData
            })
        );
        Currency settleCurrency = t.zeroForOne ? t.poolKey.currency0 : t.poolKey.currency1;
        // payerIsUser=false → settle from Universal Router balance (pre-funded above).
        params[1] = abi.encode(settleCurrency, uint256(amountIn), false);
        Currency takeCurrency = t.zeroForOne ? t.poolKey.currency1 : t.poolKey.currency0;
        // TAKE to coordinator (msg.sender of UR.execute); OPEN_DELTA takes full swap output.
        params[2] = abi.encode(takeCurrency, ActionConstants.MSG_SENDER, uint256(ActionConstants.OPEN_DELTA));
        commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);
    }

    function _encodeB(Currency currencyIn, PathKey[] memory path, uint128 amountIn, uint128 amountOutMinimum)
        private
        pure
        returns (bytes memory commands, bytes[] memory inputs)
    {
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN), uint8(Actions.SETTLE), uint8(Actions.TAKE));
        bytes[] memory params = new bytes[](3);
        uint256[] memory maxHopSlippage = new uint256[](0);
        params[0] = abi.encode(
            IV4Router.ExactInputParams({
                currencyIn: currencyIn,
                path: path,
                maxHopSlippage: maxHopSlippage,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum
            })
        );
        params[1] = abi.encode(currencyIn, uint256(amountIn), false);
        Currency takeCurrency = path[path.length - 1].intermediateCurrency;
        params[2] = abi.encode(takeCurrency, ActionConstants.MSG_SENDER, uint256(ActionConstants.OPEN_DELTA));
        commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);
    }
}
