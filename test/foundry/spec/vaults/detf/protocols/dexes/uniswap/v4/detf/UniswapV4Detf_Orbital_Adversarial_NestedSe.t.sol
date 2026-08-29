// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Orbital_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Adversarial.sol";

/**
 * @title UniswapV4Detf_Orbital_Adversarial_NestedSe
 * @notice Nested SE fund path T-NEST-1..3 and T-LOCAL-I1 against the bound gold SE.
 * @dev Deferred T-NEST-4..8 (R-11). Nested DETF G1 deferred. E6 N/A no residual-return.
 */
contract UniswapV4Detf_Orbital_Adversarial_NestedSe is TestBase_UniswapV4Detf_Orbital_Adversarial {
    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public {
        _assertT_NEST_1();
    }

    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public {
        _assertT_NEST_2();
    }

    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public {
        _assertT_NEST_3();
    }

    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public {
        _assertT_LOCAL_I1();
    }
}
