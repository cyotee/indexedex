// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_EtherFiWeETHStandardExchange} from
    "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {
    IEtherFiWeETHStandardVault,
    IEtherFiWeETHRebalance
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

contract Handler_EtherFiWeETHStandardExchange {
    TestBase_EtherFiWeETHStandardExchange internal base;
    address internal se;
    IERC20 internal weth;
    IERC20 internal we;
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;
    IEtherFiWeETHRebalance internal seReb;
    IEtherFiWeETHStandardVault internal etherFiSe;

    constructor(address testBase_) {
        base = TestBase_EtherFiWeETHStandardExchange(testBase_);
        se = base.seVault();
        weth = IERC20(address(base.hermeticWeth()));
        we = IERC20(address(base.hermeticWeEth()));
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);
        seReb = IEtherFiWeETHRebalance(se);
        etherFiSe = IEtherFiWeETHStandardVault(se);
    }

    function exchangeInWeth(uint256 amount) external {
        amount = bound(amount, 1e15, 5 ether);
        base._dealWeth(address(this), amount);
        weth.approve(se, amount);
        try seIn.exchangeIn(weth, amount, IERC20(se), 0, address(this), false, block.timestamp + 1 hours) {}
        catch {}
    }

    function exchangeOutWeth(uint256 amountOut) external {
        uint256 liquid = etherFiSe.liquidReserveEth();
        if (liquid == 0) return;
        amountOut = bound(amountOut, 1, liquid);
        uint256 bal = IERC20(se).balanceOf(address(this));
        if (bal == 0) return;
        try seOut.exchangeOut(IERC20(se), bal, weth, amountOut, address(this), false, block.timestamp + 1 hours) {}
        catch {}
    }

    function exchangeInWe(uint256 amount) external {
        amount = bound(amount, 1e15, 5 ether);
        base._mintWeViaE(address(this), amount);
        we.approve(se, amount);
        try seIn.exchangeIn(we, amount, IERC20(se), 0, address(this), false, block.timestamp + 1 hours) {}
        catch {}
    }

    function rebalance() external {
        try seReb.rebalance() {} catch {}
    }

    function donateWeth(uint256 amount) external {
        amount = bound(amount, 1e15, 2 ether);
        base._dealWeth(address(this), amount);
        weth.transfer(se, amount);
    }

    function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (max <= min) return min;
        return min + (x % (max - min + 1));
    }
}

/**
 * @title EtherFiWeETHStandardExchange_Invariant_Test
 * @notice Invariants I1/I2/I4/I5 sleeve accounting and solvency under handler fuzz.
 */
contract EtherFiWeETHStandardExchange_Invariant_Test is TestBase_EtherFiWeETHStandardExchange {
    Handler_EtherFiWeETHStandardExchange internal handler;

    function setUp() public override {
        super.setUp();
        handler = new Handler_EtherFiWeETHStandardExchange(address(this));
        _seedVaultInventory(20 ether, 20 ether);
        IERC20(seVault).transfer(address(handler), IERC20(seVault).balanceOf(address(this)) / 2);

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = Handler_EtherFiWeETHStandardExchange.exchangeInWeth.selector;
        selectors[1] = Handler_EtherFiWeETHStandardExchange.exchangeOutWeth.selector;
        selectors[2] = Handler_EtherFiWeETHStandardExchange.exchangeInWe.selector;
        selectors[3] = Handler_EtherFiWeETHStandardExchange.rebalance.selector;
        selectors[4] = Handler_EtherFiWeETHStandardExchange.donateWeth.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_I2_sleeveEqualsWethBalance() public view {
        assertEq(etherFiSe.liquidReserveEth(), hermeticWeth.balanceOf(seVault));
    }

    function invariant_I1_totalEqualsLiquidPlusLocked() public view {
        assertEq(etherFiSe.totalReserveEth(), etherFiSe.liquidReserveEth() + etherFiSe.lockedReserveEth());
    }

    function invariant_I4_supplyNonNegative() public view {
        assertGe(IERC20(seVault).totalSupply(), 0);
        if (IERC20(seVault).totalSupply() > 0) {
            assertGt(etherFiSe.totalReserveEth(), 0);
        }
    }

    function invariant_I5_nonzeroMintForOneEth() public {
        uint256 amount = 1 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 shares = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertGt(shares, 0, "I5: 1 ETH deposit must mint shares even after donations");
    }

    /// @dev I9: rebalance/policy does not mint free WETH without claim/redeem inventory path
    function invariant_I9_liquidNotExceedTotal() public view {
        assertLe(etherFiSe.liquidReserveEth(), etherFiSe.totalReserveEth());
    }
}
