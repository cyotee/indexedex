// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IFeeCollectorSingleTokenPush} from "contracts/interfaces/IFeeCollectorSingleTokenPush.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

// tag::FeeCollectorSingleTokenPushTarget[]
/**
 * @title FeeCollectorSingleTokenPushTarget - Fee collection single token push implementation.
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Vaults are expected to, but not reequired, to call this when sending fee tokens.
 */
contract FeeCollectorSingleTokenPushTarget is IFeeCollectorSingleTokenPush {
    /* -------------------------------------------------------------------------- */
    /*                        IFeeCollectorSingleTokenPush                        */
    /* -------------------------------------------------------------------------- */

    // tag::pushSingleTokenFee(address)[]
    /**
     * @inheritdoc IFeeCollectorSingleTokenPush
     */
    function pushSingleTokenFee(IERC20 token) external returns (bool) {
        MultiAssetBasicVaultRepo._updateReserve(token, token.balanceOf(address(this)));
        return true;
    }
    // end::pushSingleTokenFee(address)[]
}
// end::FeeCollectorSingleTokenPushTarget[]
