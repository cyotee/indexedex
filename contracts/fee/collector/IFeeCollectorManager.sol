// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

// tag::IFeeCollectorManager[]
/**
 * @title IFeeCollectorManager - Interface for managing the Fee Collector.
 * @author cyotee doge <not_cyotee@proton.me>
 */
interface IFeeCollectorManager {
    // tag::syncReserve(address)[]
    /**
     * @notice Syncs the reserve of a token held by the Fee Collector.
     * @param token The token to sync the reserve for.
     * @return Boolean indicating success to save gas.
     */
    function syncReserve(IERC20 token) external returns (bool);
    // end::syncReserve(address)[]

    // tag::syncReserves(address[])[]
    /**
     * @notice Syncs the reserves of multiple tokens held by the Fee Collector.
     * @param tokens The tokens to sync the reserves for.
     * @return Boolean indicating success to save gas.
     */
    function syncReserves(IERC20[] calldata tokens) external returns (bool);
    // end::syncReserves(address[])[]
    // tag::pullFee(address_uint256_address)[]
    /**
     * @param token The token to pull from the Fee Collector.
     * @param amount The amount of the token to pull from the Fee Collector.
     * @param recipient The address to send the pulled tokens to.
     * @return Boolean indicating success to save gas.
     */
    function pullFee(IERC20 token, uint256 amount, address recipient) external returns (bool);
    // end::pullFee(address_uint256_address)[]
}
// end::IFeeCollectorManager[]
