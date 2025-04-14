// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";

// tag::FeeCollectorManagerTarget[]
/**
 * @title FeeCollectorManagerTarget - Fee collection managment implementation.
 * @author cyotee doge <not_cyotee@proton.me>
 */
contract FeeCollectorManagerTarget is MultiStepOwnableModifiers, IFeeCollectorManager {
    using BetterSafeERC20 for IERC20;

    /* -------------------------------------------------------------------------- */
    /*                            IFeeCollectorManager                            */
    /* -------------------------------------------------------------------------- */

    // tag::syncReserve(address)[]
    /**
     * @inheritdoc IFeeCollectorManager
     */
    function syncReserve(IERC20 token) public returns (bool) {
        MultiAssetBasicVaultRepo._updateReserve(token, token.balanceOf(address(this)));
        return true;
    }

    // end::syncReserve(address)[]

    // tag::syncReserves(address[])[]
    /**
     * @inheritdoc IFeeCollectorManager
     */
    function syncReserves(IERC20[] calldata tokens) public returns (bool) {
        for (uint256 i = 0; i < tokens.length; i++) {
            syncReserve(tokens[i]);
        }
        return true;
    }

    // end::syncReserves(address[])[]

    // tag::pullFee(address_uint256_address)[]
    /**
     * @inheritdoc IFeeCollectorManager
     */
    function pullFee(IERC20 token, uint256 amount, address recipient) external onlyOwner returns (bool) {
        token.safeTransfer(recipient, amount);
        return true;
    }
    // end::pullFee(address_uint256_address)[]
}
// end::FeeCollectorManagerTarget[]
