// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3FlashCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3FlashCallback.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangePretransfer} from "contracts/vaults/standard/exchange/protocols/uniswap/IStandardExchangePretransfer.sol";

/// @dev Real protocol callback caller, not a replacement for any SUT component.
contract StandardExchangeLockedCaller is IUniswapV3FlashCallback, IUnlockCallback {
    address private immutable pool;
    bool private immutable v4;
    uint256 private result;
    constructor(address pool_, bool v4_) { pool = pool_; v4 = v4_; }
    function run(address vault, bytes memory callData, address[] memory tokens, uint256[] memory amounts)
        external returns (uint256)
    {
        bytes memory data = abi.encode(vault, callData, tokens, amounts);
        if (v4) IPoolManager(pool).unlock(data);
        else IUniswapV3Pool(pool).flash(address(this), 0, 0, data);
        return result;
    }
    function uniswapV3FlashCallback(uint256, uint256, bytes calldata data) external {
        require(msg.sender == pool, "pool");
        _execute(data);
    }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == pool, "manager");
        _execute(data);
        return "";
    }
    function _execute(bytes calldata data) private {
        (address vault, bytes memory callData, address[] memory tokens, uint256[] memory amounts) =
            abi.decode(data, (address, bytes, address[], uint256[]));
        if (tokens.length != 0) {
            IStandardExchangePretransfer(vault).preparePretransfer(tokens, amounts, keccak256(callData));
            for (uint256 i; i < tokens.length; ++i) IERC20(tokens[i]).transfer(vault, amounts[i]);
        }
        (bool ok, bytes memory returned) = vault.call(callData);
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        result = abi.decode(returned, (uint256));
    }
}
