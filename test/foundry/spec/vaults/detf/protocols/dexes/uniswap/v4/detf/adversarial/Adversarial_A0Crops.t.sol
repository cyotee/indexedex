// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";

/**
 * @title Adversarial_A0Crops
 * @notice A0 donate-before-first-bond, CROPS inbound-only disable, F1 satellite owner.
 * @dev E6 N/A no residual-return. M* N/A no calldata forwarder. D18 not tested.
 */
contract Adversarial_A0Crops is TestBase_UniswapV4Detf_Adversarial {
    function test_A0_donateBeforeFirstBond_cannotFreeMint() public {
        _assertA0_donateBeforeFirstBond_cannotFreeMint();
    }

    function test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork() public {
        _assertCROPS_disable_inboundGated_matureCloseRedeemBurnWork();
    }

    /// @notice Funding is DETF-only; retired sale selectors and upgrade cuts are absent.
    function test_F1_satellitesUnowned() public {
        _assertFundedSatelliteAuthorities();
    }
}
