// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";

/**
 * @title UniswapV4Detf_PolicyLayerBase
 * @notice Stage 11 Policy IDs only (PRD §7.0 Policy row). Does not include Open/compound/D31-4/donate-no-realize.
 */
abstract contract UniswapV4Detf_PolicyLayerBase is TestBase_UniswapV4Detf_Policy {
    function test_T7_8_policy_isMintingAllowed_token() public {
        address d = _deployPolicyLaunchRichLive();
        _assert_T7_8_policy_isMintingAllowed_token(d);
    }

    function test_policy_mint_blocked_in_deadband_then_allowed_after_push() public {
        address d = _deployPolicyLaunchRichLive();
        _assert_policy_mint_blocked_in_deadband_then_allowed_after_push(d);
    }

    function test_policy_burn_allowed_when_synthetic_below_burnThreshold() public {
        address d = _deployPolicyLaunchRichLive();
        _assert_policy_burn_allowed_when_synthetic_below_burnThreshold(d);
    }

    function test_D31_1_policyMint_realizesThenGates() public {
        address d = _deployD31LaunchRichLive();
        _assert_D31_1_policyMint_realizesThenGates(d);
    }

    function test_D31_2_realizeWouldCloseMint_revertsUnchanged() public {
        address d = _deployD31LaunchRichLive();
        _assert_D31_2_realizeWouldCloseMint_revertsUnchanged(d);
    }

    function test_D31_3_policyBurn_realizesThenGates() public {
        address d = _deployD31LaunchRichLive();
        _assert_D31_3_policyBurn_realizesThenGates(d);
    }
}
