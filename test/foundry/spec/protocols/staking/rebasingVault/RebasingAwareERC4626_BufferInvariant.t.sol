// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";

/// @notice Composed buffer campaign is gated on the §8 amendment. Wrapper fee invariant
///         holds independently; family join/swap/exit live in RebasingAwareERC4626_Buffers.
contract RebasingAwareERC4626_BufferInvariant is TestBase_RebasingAwareERC4626 {
    function test_composedBufferCampaign_amendmentPresent() public {
        string memory path = string.concat(
            vm.projectRoot(),
            "/contracts/hooks/uniswap/v4/standardExchange/REBASING_WRAPPER_SHARE_INVENTORY_AMENDMENT.md"
        );
        assertTrue(vm.exists(path));
    }

    function invariant_INV12_wrapperFeeTypeRemainsZero() public view {
        assertEq(IStandardVault(address(vault)).vaultFeeTypeIds(), bytes32(0));
        assertEq(pkg.vaultFeeTypeIds(), bytes32(0));
    }
}
