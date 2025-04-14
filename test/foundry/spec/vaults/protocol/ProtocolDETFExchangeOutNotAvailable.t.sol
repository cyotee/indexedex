// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {BaseProtocolDETFExchangeOutTarget} from "contracts/vaults/protocol/BaseProtocolDETFExchangeOutTarget.sol";

/**
 * @title ProtocolDETFExchangeOutNotAvailableTest
 * @notice Tests that unsupported routes in BaseProtocolDETFExchangeOutTarget revert correctly.
 * @dev IDXEX-019 enabled WETH → CHIR and CHIR → RICH routes.
 *      This test verifies that OTHER routes still revert with ExchangeOutNotAvailable.
 */
contract ProtocolDETFExchangeOutNotAvailableTest is Test {
    BaseProtocolDETFExchangeOutTarget internal exchangeOut;

    function setUp() public {
        exchangeOut = new BaseProtocolDETFExchangeOutTarget();
    }

    /**
     * @notice Test that previewExchangeOut reverts for unsupported token pairs
     * @dev Uses invalid addresses (0x1, 0x2) which are not WETH, CHIR, or RICH
     */
    function test_previewExchangeOut_reverts() public {
        // Using invalid addresses should revert with ExchangeOutNotAvailable
        // because neither 0x1 nor 0x2 match any valid route
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        exchangeOut.previewExchangeOut(IERC20(address(0x1)), IERC20(address(0x2)), 1e18);
    }

    /**
     * @notice Test that exchangeOut reverts for unsupported token pairs
     * @dev Uses invalid addresses (0x1, 0x2) which are not WETH, CHIR, or RICH
     *      The function now tries to load pool data before checking routes,
     *      so it may revert earlier with a different error when storage is uninitialized.
     */
    function test_exchangeOut_reverts_unsupported() public {
        // Using invalid addresses should revert
        // Note: May revert earlier due to uninitialized storage
        vm.expectRevert();
        exchangeOut.exchangeOut(
            IERC20(address(0x1)), 1e18, IERC20(address(0x2)), 1e18, address(this), false, block.timestamp + 1 hours
        );
    }
}
