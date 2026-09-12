// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

/**
 * @title IDetfClaimPurchase
 * @notice DETF standard purchase surface and funded staking-token discovery.
 * @dev Buy raw DETF through this address, then use the returned staking token's
 *      Standard Exchange surface for exact held-DETF staking.
 */
interface IDetfClaimPurchase is IStandardExchangeIn {
    function rebasingClaimToken() external view returns (address);
}
