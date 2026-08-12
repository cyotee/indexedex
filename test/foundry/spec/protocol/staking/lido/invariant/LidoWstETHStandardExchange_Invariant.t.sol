// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_LidoWstETHStandardExchange} from
    "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {ILidoWstETHStandardVault} from
    "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ILidoWstETHRebalance} from
    "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";

contract Handler_LidoWstETHStandardExchange {
    TestBase_LidoWstETHStandardExchange internal base;
    address internal se;
    IERC20 internal weth;
    IERC20 internal wst;
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;
    ILidoWstETHRebalance internal seReb;
    ILidoWstETHStandardVault internal lidoSe;

    constructor(address testBase_) {
        base = TestBase_LidoWstETHStandardExchange(testBase_);
        se = base.seVault();
        weth = IERC20(address(base.hermeticWeth()));
        wst = IERC20(address(base.hermeticWstEth()));
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);
        seReb = ILidoWstETHRebalance(se);
        lidoSe = ILidoWstETHStandardVault(se);
    }

    function exchangeInWeth(uint256 amount) external {
        amount = bound(amount, 1e15, 5 ether);
        base._dealWeth(address(this), amount);
        weth.approve(se, amount);
        try seIn.exchangeIn(weth, amount, IERC20(se), 0, address(this), false, block.timestamp + 1 hours) {}
        catch {}
    }

    function exchangeOutWeth(uint256 amountOut) external {
        uint256 liquid = lidoSe.liquidReserveEth();
        if (liquid == 0) return;
        amountOut = bound(amountOut, 1, liquid);
        uint256 bal = IERC20(se).balanceOf(address(this));
        if (bal == 0) return;
        try seOut.exchangeOut(IERC20(se), bal, weth, amountOut, address(this), false, block.timestamp + 1 hours) {}
        catch {}
    }

    function exchangeInWst(uint256 amount) external {
        amount = bound(amount, 1e15, 5 ether);
        base._mintWstViaSt(address(this), amount);
        wst.approve(se, amount);
        try seIn.exchangeIn(wst, amount, IERC20(se), 0, address(this), false, block.timestamp + 1 hours) {}
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
 * @title LidoWstETHStandardExchange_Invariant_Test
 * @notice Invariants I1/I2/I4 sleeve accounting and solvency under handler fuzz.
 */
contract LidoWstETHStandardExchange_Invariant_Test is TestBase_LidoWstETHStandardExchange {
    Handler_LidoWstETHStandardExchange internal handler;

    function setUp() public override {
        super.setUp();
        handler = new Handler_LidoWstETHStandardExchange(address(this));
        // seed so actions can run
        _seedVaultInventory(20 ether, 20 ether);
        // fund handler with SE shares for outs
        IERC20(seVault).transfer(address(handler), IERC20(seVault).balanceOf(address(this)) / 2);

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = Handler_LidoWstETHStandardExchange.exchangeInWeth.selector;
        selectors[1] = Handler_LidoWstETHStandardExchange.exchangeOutWeth.selector;
        selectors[2] = Handler_LidoWstETHStandardExchange.exchangeInWst.selector;
        selectors[3] = Handler_LidoWstETHStandardExchange.rebalance.selector;
        selectors[4] = Handler_LidoWstETHStandardExchange.donateWeth.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @dev I2: liquidReserveEth == WETH balance
    function invariant_I2_sleeveEqualsWethBalance() public view {
        assertEq(lidoSe.liquidReserveEth(), hermeticWeth.balanceOf(seVault));
    }

    /// @dev I1: totalReserve is sum of liquid + locked
    function invariant_I1_totalEqualsLiquidPlusLocked() public view {
        assertEq(lidoSe.totalReserveEth(), lidoSe.liquidReserveEth() + lidoSe.lockedReserveEth());
    }

    /// @dev I4: total supply is finite; convert consistency
    function invariant_I4_supplyNonNegative() public view {
        assertGe(IERC20(seVault).totalSupply(), 0);
        if (IERC20(seVault).totalSupply() > 0) {
            assertGt(lidoSe.totalReserveEth(), 0);
        }
    }

    /// @dev I5: deposit of meaningful size always mints >0 shares (virtual offset inflation defense).
    ///      Uses a fixed deposit size against live state; if liquid/mint path works, shares must be positive.
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
}
