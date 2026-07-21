// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20TestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/ERC20TestToken.sol";
import {
    TestBase_CommonBufferMultiVaultWeightedPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool.sol";

/// @notice Minimal invariant handler driving real router paths on the CBMV pool.
contract Handler_CommonBufferMultiVault {
    TestBase_CommonBufferMultiVaultWeightedPool public immutable base;

    constructor(TestBase_CommonBufferMultiVaultWeightedPool base_) {
        base = base_;
    }

    function swap_buffer_in(uint256 amountSeed) external {
        uint256 amount = _bound(amountSeed, 1e16, 30e18);
        address user = base.handlerAlice();
        ERC20TestToken(address(base.handlerDai())).mint(user, amount);
        try base.swapExactIn(user, base.handlerDai(), IERC20(base.handlerSeVault0()), amount) {} catch {}
    }

    function swap_share_in(uint256 amountSeed) external {
        uint256 amount = _bound(amountSeed, 1e16, 20e18);
        address user = base.handlerAlice();
        address se = base.handlerSeVault0();
        if (IERC20(se).balanceOf(user) < amount) {
            try base.mintSharesForVault(0, user, amount * 3) {} catch {}
        }
        try base.swapExactIn(user, IERC20(se), base.handlerDai(), amount) {} catch {}
    }

    function lp_add_proportional(uint256 seed) external {
        // Stand-in activity: small buffer-in (proportional LP needs multi-asset arrays).
        uint256 amount = _bound(seed, 1e16, 30e18);
        address user = base.handlerAlice();
        ERC20TestToken(address(base.handlerDai())).mint(user, amount);
        try base.swapExactIn(user, base.handlerDai(), IERC20(base.handlerSeVault0()), amount) {} catch {}
    }

    function _bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (max <= min) return min;
        return min + (x % (max - min + 1));
    }
}
