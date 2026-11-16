// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

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

    /// @inheritdoc IFeeCollectorManager
    function redeemReserveLiquidity(
        IERC20 reserveLp, uint256 amount, uint256[] calldata amountsMin, address recipient, uint256 deadline
    ) external onlyOwner returns (uint256[] memory amounts) {
        reserveLp.forceApprove(address(reserveLp), amount);
        amounts = IUniswapV4SeBufferHook(address(reserveLp)).exitProportional(amount, recipient, amountsMin, deadline);
        reserveLp.forceApprove(address(reserveLp), 0);
        syncReserve(reserveLp);
        if (recipient == address(this)) {
            address[] memory underlying = IUniswapV4SeBufferHook(address(reserveLp)).tokens();
            for (uint256 i; i < underlying.length; ++i) syncReserve(IERC20(underlying[i]));
        }
    }

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
