// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangePretransfer} from "contracts/vaults/standard/exchange/protocols/uniswap/IStandardExchangePretransfer.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

library PreparedTestInput {
    function prepare(address vault, address token, uint256 amount, bytes memory data) internal {
        address[] memory tokens = new address[](1); tokens[0] = token;
        uint256[] memory amounts = new uint256[](1); amounts[0] = amount;
        IStandardExchangePretransfer(vault).preparePretransfer(tokens, amounts, keccak256(data));
    }
    function referenceShares(uint256 reserve, uint256 other, uint256 supply, uint256 wanted) internal pure returns (uint256) {
        uint256 low = 1; uint256 high = supply - 1;
        while (low < high) {
            uint256 burn = low + (high - low) / 2;
            uint256 removedOut = reserve * burn / supply;
            uint256 removedOther = other * burn / supply;
            uint256 poolOut = reserve - removedOut;
            uint256 poolOther = other - removedOther;
            uint256 swapped = poolOut * removedOther / (poolOther + removedOther);
            if (removedOut + swapped >= wanted) high = burn;
            else low = burn + 1;
        }
        return low;
    }
}
