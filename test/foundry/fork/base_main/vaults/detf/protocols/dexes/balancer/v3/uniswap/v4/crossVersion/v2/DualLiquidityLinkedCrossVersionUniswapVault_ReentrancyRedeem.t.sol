// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {ReentrantMockERC20} from "contracts/test/stubs/ReentrantMockERC20.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Reentrancy during deposit that re-enters a redeem path (shared lock).
contract DualLiquidityLinkedCrossVersionUniswapVault_ReentrancyRedeem is
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

    function test_reentrancy_depositReentersRedeem_IsLocked() public {
        // Hold shares so redeem path is meaningful if reentry got past lock (it must not).
        uint256 shares = _depositCommon(address(this), LEG_SEED);
        address pool = _reservePool();

        bytes memory reentry = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(linkedVault), shares / 10, IERC20(pool), uint256(0), address(this), false, block.timestamp)
        );
        hostileB.arm(linkedVault, reentry);

        tokenB.approve(linkedVault, LEG_SEED);
        vm.expectRevert(IReentrancyLock.IsLocked.selector);
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, LEG_SEED, IERC20(linkedVault), 0, address(this), false, block.timestamp
        );
    }

    function test_reentrancy_depositReentersConvenienceRedeem_IsLocked() public {
        uint256 shares = _depositCommon(address(this), LEG_SEED);
        bytes memory reentry = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(linkedVault), shares / 10, commonToken, uint256(0), address(this), false, block.timestamp)
        );
        hostileB.arm(linkedVault, reentry);

        tokenB.approve(linkedVault, LEG_SEED);
        vm.expectRevert(IReentrancyLock.IsLocked.selector);
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, LEG_SEED, IERC20(linkedVault), 0, address(this), false, block.timestamp
        );
    }
}
