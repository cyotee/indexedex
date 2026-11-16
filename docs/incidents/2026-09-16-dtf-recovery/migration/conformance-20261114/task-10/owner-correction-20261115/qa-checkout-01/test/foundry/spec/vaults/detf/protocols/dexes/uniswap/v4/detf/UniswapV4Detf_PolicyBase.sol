// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";

/**
 * @title UniswapV4Detf_PolicyBase
 * @notice Gold-full Policy IDs for unified Uni V4 DETF (PRD §7.2). Shared bodies live on the Policy TestBase.
 * @dev Stage 11 must inherit UniswapV4Detf_PolicyLayerBase, not this gold-full abstract (R-24).
 */
abstract contract UniswapV4Detf_PolicyBase is TestBase_UniswapV4Detf_Policy {
    function test_T7_8_policy_isMintingAllowed_token() public {
        address d = _deployPolicyLaunchRichLive();
        _assert_T7_8_policy_isMintingAllowed_token(d);
    }

    function test_policy_mint_blocked_in_deadband_then_allowed_after_push() public virtual {
        address d = _deployPolicyLaunchRichLive();
        _assert_policy_mint_blocked_in_deadband_then_allowed_after_push(d);
    }

    function test_policy_burn_allowed_when_synthetic_below_burnThreshold() public virtual {
        address d = _deployPolicyLaunchRichLive();
        _assert_policy_burn_allowed_when_synthetic_below_burnThreshold(d);
    }

    function test_open_never_expands() public {
        address d = _deployOpenLive();
        _assert_open_never_expands(d);
    }

    function test_D31_1_policyMint_realizesThenGates() public {
        address d = _deployD31LaunchRichLive();
        _assert_D31_1_policyMint_realizesThenGates(d);
    }

    function test_D31_2_realizeWouldCloseMint_revertsUnchanged() public {
        address d = _deployD31LaunchRichLive();
        _assert_D31_2_realizeWouldCloseMint_revertsUnchanged(d);
    }

    function test_D31_3_policyBurn_realizesThenGates() public virtual {
        address d = _deployD31LaunchRichLive();
        _assert_D31_3_policyBurn_realizesThenGates(d);
    }

    function test_D31_4_openMintDoesNotExpand() public {
        address d = _deployOpenLive();
        _assert_D31_4_openMintDoesNotExpand(d);
    }

    function test_compound_raises_protocolLp() public {
        address d = _deployOpenLive();
        _assert_compound_raises_protocolLp(d);
    }

    function test_donate_doesNotRealizeExpansion() public {
        address d = _deployD31LaunchRichLive();
        _assert_donate_doesNotRealizeExpansion(d);
    }
}
