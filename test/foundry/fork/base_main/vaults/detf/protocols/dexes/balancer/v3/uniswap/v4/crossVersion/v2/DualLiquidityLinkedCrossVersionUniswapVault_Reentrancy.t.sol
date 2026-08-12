// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {ReentrantMockERC20} from "contracts/test/stubs/ReentrantMockERC20.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Hostile tokenB re-enters exchangeIn/exchangeOut via transferFrom; expect IsLocked.
/// @dev ReentrantMockERC20 is an attacker fixture, not a protocol mock of the vault itself.
contract DualLiquidityLinkedCrossVersionUniswapVault_Reentrancy is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    ReentrantMockERC20 internal hostileB;

    function _deployTokenB() internal override returns (IERC20) {
        hostileB = new ReentrantMockERC20("Hostile B", "HSTB", 18);
        hostileB.mint(address(this), TEST_TOKEN_TOTAL_SUPPLY);
        return IERC20(address(hostileB));
    }

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
    }

    function test_reentrancy_exchangeIn_deposit_revertsIsLocked() public {
        // Arm tokenB to re-enter exchangeIn mid-transferFrom (linked-token deposit pulls tokenB).
        bytes memory reentry = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (tokenB, uint256(1e18), IERC20(linkedVault), uint256(0), address(this), false, block.timestamp)
        );
        hostileB.arm(linkedVault, reentry);

        tokenB.approve(linkedVault, LEG_SEED);
        vm.expectRevert(IReentrancyLock.IsLocked.selector);
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, LEG_SEED, IERC20(linkedVault), 0, address(this), false, block.timestamp
        );
    }

    function test_reentrancy_crossFunction_exchangeOut_revertsIsLocked() public {
        uint256 shares = _depositCommon(address(this), LEG_SEED);

        // Deposit path pulls tokenB while re-entering exchangeOut (shared lock slot).
        bytes memory reentry = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (IERC20(linkedVault), shares, commonToken, uint256(1), address(this), false, block.timestamp)
        );
        hostileB.arm(linkedVault, reentry);

        tokenB.approve(linkedVault, LEG_SEED);
        vm.expectRevert(IReentrancyLock.IsLocked.selector);
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, LEG_SEED, IERC20(linkedVault), 0, address(this), false, block.timestamp
        );
    }
}
