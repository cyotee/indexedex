// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {BaseHook} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/BaseHook.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BeforeSwapDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "../../interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookConsumingHook[]
/// @notice Test counterparty that performs a real H deposit from a real core beforeSwap callback.
contract UniswapV4FullSpreadPonsFamilyHookConsumingHook is BaseHook {
    address public immutable vault;
    IERC20 public immutable input;
    bool public observedBlocked;
    uint256 public minted;

    constructor(IPoolManager manager_, address vault_, IERC20 input_) BaseHook(manager_) {
        vault = vault_;
        input = input_;
        input_.approve(vault_, type(uint256).max);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions_) {
        permissions_.beforeSwap = true;
    }

    function _beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        internal override returns (bytes4, BeforeSwapDelta, uint24)
    {
        observedBlocked = !Reserve(vault).canOpenPoolManagerUnlock();
        uint256 quote = IStandardExchangeIn(vault).previewExchangeIn(input, 1e18, IERC20(vault));
        minted = IStandardExchangeIn(vault).exchangeIn(input, 1e18, IERC20(vault), quote, address(this), false, block.timestamp);
        return (this.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookConsumingHook[]
