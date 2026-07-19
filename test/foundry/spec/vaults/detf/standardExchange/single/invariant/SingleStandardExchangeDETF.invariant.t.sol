// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {
    Handler_SingleStandardExchangeDETF,
    ISingleSeDetfInvHost
} from "test/foundry/spec/vaults/detf/standardExchange/single/invariant/Handler_SingleStandardExchangeDETF.sol";

/// forge-config: default.invariant.runs = 24
/// forge-config: default.invariant.depth = 10
contract SingleStandardExchangeDETFInvariant is TestBase_SingleStandardExchangeDETF, ISingleSeDetfInvHost {
    Handler_SingleStandardExchangeDETF internal handler;
    address internal invInstanceAddr;
    address internal invActor0;
    address internal invActor1;

    function setUp() public virtual override {
        super.setUp();
        invActor0 = makeAddr("sseInv0");
        invActor1 = makeAddr("sseInv1");

        invInstanceAddr = _deployOpenThresholdDetf("SSE Inv", "sseI");
        _bootstrapDetf(invInstanceAddr, invActor0, 2_000e18);
        assertTrue(ISingleStandardExchangeDETFInfo(invInstanceAddr).isReserveLive(), "live");

        handler = new Handler_SingleStandardExchangeDETF(ISingleSeDetfInvHost(address(this)));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Handler_SingleStandardExchangeDETF.mint.selector;
        selectors[1] = Handler_SingleStandardExchangeDETF.burn.selector;
        selectors[2] = Handler_SingleStandardExchangeDETF.donateShares.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invInstance() external view override returns (address) {
        return invInstanceAddr;
    }

    function invShare() external view override returns (IERC20) {
        return seShare;
    }

    function invActor(uint256 idx) external view override returns (address) {
        return idx % 2 == 0 ? invActor0 : invActor1;
    }

    function invMint(address user, uint256 lpAmount) external override returns (uint256 out_) {
        uint256 shares_ = _fundSeShares(user, lpAmount);
        vm.startPrank(user);
        seShare.approve(invInstanceAddr, shares_);
        out_ = IStandardExchangeIn(invInstanceAddr).exchangeIn(
            seShare, shares_, IERC20(invInstanceAddr), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function invBurn(address user, uint256 detfAmount) external override returns (uint256 out_) {
        vm.startPrank(user);
        IERC20(invInstanceAddr).approve(invInstanceAddr, detfAmount);
        out_ = IStandardExchangeIn(invInstanceAddr).exchangeIn(
            IERC20(invInstanceAddr), detfAmount, seShare, 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function invDonateShares(address from, uint256 shareAmount) external override {
        vm.prank(from);
        seShare.transfer(invInstanceAddr, shareAmount);
    }

    function invariant_residualDetfZero() public view {
        assertEq(IERC20(invInstanceAddr).balanceOf(invInstanceAddr), 0, "P-RESID free DETF");
        if (handler.ghost_donateCount() == 0) {
            assertEq(seShare.balanceOf(invInstanceAddr), 0, "P-RESID free SE share");
        }
    }

    function invariant_ghostConsistent() public view {
        if (handler.ghost_mintCount() == 0) {
            assertEq(handler.ghost_totalDetfMinted(), 0, "P-GHOST");
        }
    }

    function invariant_actorBalancesLeSupply() public view {
        uint256 supply_ = IERC20(invInstanceAddr).totalSupply();
        assertLe(
            IERC20(invInstanceAddr).balanceOf(invActor0) + IERC20(invInstanceAddr).balanceOf(invActor1),
            supply_,
            "P-SUPPLY"
        );
    }

    function invariant_stillLive() public view {
        assertTrue(ISingleStandardExchangeDETFInfo(invInstanceAddr).isReserveLive(), "live");
    }
}
