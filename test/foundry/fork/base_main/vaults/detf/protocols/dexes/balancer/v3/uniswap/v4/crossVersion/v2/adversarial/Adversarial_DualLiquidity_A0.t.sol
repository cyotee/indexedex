// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice A0: first BPT deposit cannot absorb idle `reserveBpt` sitting on an empty share book.
/// @dev `SEC-DETF-DL-004` / `WP-SEC-DETF-DL-A0-001`. Starts from `totalSupply == 0` with positive
///      donated BPT on the **proxy**. ShareInflation A3 (post-bootstrap donation) is a different class.
contract Adversarial_DualLiquidity_A0_Test is TestBase_DualLiquidityLinkedCrossVersionUniswapVault {
    address internal constant DEAD_SHARES = address(0xdead);

    /// @notice Donate `reserveBpt` before first share mint; first mover cannot redeem the donation.
    function test_A0_idleReserveBpt_firstWeiDeposit_cannotClaimDonation() public {
        uint256 mintedBpt_ = _initializeReservePool();
        IERC20 pool_ = IERC20(_reservePool());
        assertEq(IERC20(linkedVault).totalSupply(), 0, "A0: start empty");
        assertEq(pool_.balanceOf(linkedVault), 0, "A0: diamond holds no BPT yet");
        require(mintedBpt_ > 2e18, "A0: need BPT to split donate vs deposit");

        uint256 donated_ = mintedBpt_ - 1e18;
        pool_.transfer(linkedVault, donated_);
        assertEq(pool_.balanceOf(linkedVault), donated_, "A0: idle BPT on proxy");
        assertEq(IERC20(linkedVault).totalSupply(), 0, "A0: still no shares");

        address attacker_ = makeAddr("a0Attacker");
        uint256 attackerIn_ = 1e18;
        pool_.transfer(attacker_, attackerIn_);

        vm.startPrank(attacker_);
        pool_.approve(linkedVault, attackerIn_);
        uint256 shares_ = IStandardExchangeIn(linkedVault).exchangeIn(
            pool_, attackerIn_, IERC20(linkedVault), 0, attacker_, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(shares_, 0, "A0: attacker minted for their own BPT");
        assertLt(shares_, IERC20(linkedVault).totalSupply(), "A0: first minter is not 100%");
        assertEq(IERC20(linkedVault).balanceOf(DEAD_SHARES), donated_, "A0: idle BPT locked as dead shares");

        vm.startPrank(attacker_);
        uint256 redeemed_ = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), shares_, pool_, 0, attacker_, false, block.timestamp
        );
        vm.stopPrank();

        assertLe(redeemed_, attackerIn_ + 10, "A0: cannot drain donated reserveBpt");
        assertGe(pool_.balanceOf(linkedVault), donated_ - 10, "A0: donation remains on diamond");
    }
}
