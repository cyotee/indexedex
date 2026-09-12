// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";

/// @notice Wrapper settlement vs a rebasing claim-token stand-in. TokenStaking consumer
///         paths are out of scope; the generic wrapper must still never call synchronizeRewards.
contract RebasingAwareERC4626_StakedDETF is TestBase_RebasingAwareERC4626 {
    function test_F18_transferTriggeredRebaseRevertsThenExplicitRebaseSucceeds() public {
        RebasingERC20Harness claim = new RebasingERC20Harness("sDETF-like", "sD", 9);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(claim)));
        claim.mint(alice, 1_000e9);
        claim.setRebaseOnTransfer(int256(1e9), address(wrapped));
        vm.startPrank(alice);
        claim.approve(address(wrapped), type(uint256).max);
        vm.expectRevert();
        wrapped.deposit(10e9, alice);
        vm.stopPrank();
        claim.setRebaseOnTransfer(0, address(0));
        claim.rebase(address(wrapped), int256(1e9));
        vm.prank(alice);
        uint256 shares = wrapped.deposit(10e9, alice);
        assertGt(shares, 0);
        vm.prank(alice);
        uint256 assets = wrapped.redeem(shares, alice, alice);
        assertGt(assets, 0);
    }

    function test_genericWrapperNeverCallsSynchronizeRewardsSelector() public {
        bytes memory code = address(rebasingAwareErc4626Facet).code;
        bytes4 sel = bytes4(keccak256("synchronizeRewards()"));
        assertFalse(_containsSelector(code, sel));
        assertFalse(_containsSelector(address(standardExchangeFacet).code, sel));
        assertFalse(_containsSelector(address(standardYieldFacet).code, sel));
    }

    function _containsSelector(bytes memory code, bytes4 sel) internal pure returns (bool) {
        if (code.length < 4) return false;
        for (uint256 i; i + 3 < code.length; ++i) {
            if (
                code[i] == sel[0] && code[i + 1] == sel[1] && code[i + 2] == sel[2]
                    && code[i + 3] == sel[3]
            ) {
                return true;
            }
        }
        return false;
    }
}
