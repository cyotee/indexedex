// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {StandardExchangeInExecutionBase} from "contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol";
import {UniswapV4PairTokenStandardExchangeVaultExecution as Execution} from "./UniswapV4PairTokenStandardExchangeVaultExecution.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultMoneyTarget[]
/// @notice Caller-preserving paired, scalar, donation and maintenance entrypoints.
contract UniswapV4PairTokenStandardExchangeVaultMoneyTarget is StandardExchangeInExecutionBase {
    // tag::exchangeIn-d02d3063[]
    /// @notice Exact-input SE using ERC-20 faces only.
    /// @custom:signature exchangeIn(address,uint256,address,uint256,address,bool,uint256)
    /// @custom:selector 0xd02d3063
function exchangeIn(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_,
        address recipient_, bool prepaid_, uint256 deadline_
    ) external returns (uint256 amountOut, uint256 amountRefunded) {
        return (_exchangeIn(in_, amount_, out_, minimum_, recipient_, prepaid_, deadline_), 0);
    }
    // end::exchangeIn-d02d3063[]

    function _exchangeIn(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_,
        address recipient_, bool prepaid_, uint256 deadline_
    ) internal override returns (uint256) {
        return Execution.exchangeIn(
            address(in_), amount_, address(out_), minimum_, recipient_, prepaid_, deadline_, false
        );
    }

    // tag::depositPair-047adf08[]
    /// @notice Deposit accepted portions of the maxima, refunding unused native input only.
    /// @custom:signature depositPair(uint256,uint256,uint256,address,uint256)
    /// @custom:selector 0x047adf08
    function depositPair(uint256 max0_, uint256 max1_, uint256 minimum_, address recipient_, uint256 deadline_)
        external payable returns (uint256)
    {
        return Execution.depositPair(max0_, max1_, minimum_, recipient_, deadline_);
    }
    // end::depositPair-047adf08[]

    // tag::redeemPair-d43ad6e4[]
    /// @notice Burn caller shares and deliver both actual pool currencies.
    /// @custom:signature redeemPair(uint256,uint256,uint256,address,uint256)
    /// @custom:selector 0xd43ad6e4
    function redeemPair(uint256 shares_, uint256 min0_, uint256 min1_, address recipient_, uint256 deadline_)
        external returns (uint256, uint256)
    {
        return Execution.redeemPair(shares_, min0_, min1_, recipient_, deadline_);
    }
    // end::redeemPair-d43ad6e4[]

    // tag::donate-e69d849d[]
    /// @notice Adopt only this call's positive donation without creating shares.
    /// @custom:signature donate(address,uint256)
    /// @custom:selector 0xe69d849d
    function donate(address token_, uint256 amount_) external payable {
        Execution.donate(token_, amount_);
    }
    // end::donate-e69d849d[]

    // tag::compound-f69e2046[]
    /// @notice Permissionless incumbent maintenance, including when issuance is disabled.
    /// @custom:signature compound()
    /// @custom:selector 0xf69e2046
    function compound() external returns (uint256, uint256) {
        return Execution.compound();
    }
    // end::compound-f69e2046[]
}
// end::UniswapV4PairTokenStandardExchangeVaultMoneyTarget[]
