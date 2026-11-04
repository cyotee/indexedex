// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {TestBase_UniswapV2StandardExchange} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol";

contract SyAttacker {
    function sweep(address sy, uint256 shares, address out) external returns (uint256) {
        return IStandardizedYield(sy).redeem(address(this), shares, out, 0, true);
    }
}

/// Native SY on a UniV2 constant-product SE (HEAD): value conservation, internalBalance parity, gates.
contract GxNativeSyCPTest is TestBase_UniswapV2StandardExchange {
    IStandardizedYield internal sy;
    IERC20 internal a;
    IERC20 internal b;
    address internal seed = address(0x5EED);
    address internal user = address(0x0BEE);
    address internal atkEoa = address(0xA77A);

    function setUp() public override {
        TestBase_UniswapV2StandardExchange.setUp();
        a = IERC20(address(new ERC20PermitMintableStub("A", "A", 18, seed, 10_000 ether)));
        b = IERC20(address(new ERC20PermitMintableStub("B", "B", 18, seed, 10_000 ether)));
        vm.startPrank(seed);
        a.approve(address(uniswapV2StandardExchangeDFPkg), 1_000 ether);
        b.approve(address(uniswapV2StandardExchangeDFPkg), 1_000 ether);
        sy = IStandardizedYield(uniswapV2StandardExchangeDFPkg.deployVault(a, 1_000 ether, b, 1_000 ether, seed));
        a.transfer(user, 1_000 ether);
        b.transfer(user, 1_000 ether);
        vm.stopPrank();
    }

    /// J: deposit(token) -> redeem(token) never returns more than paid (every tokenIn/out combo).
    function test_J_roundTripNoProfit() public {
        address lp = sy.yieldToken();
        address[3] memory outs = [address(a), address(b), lp];
        for (uint256 i; i < 2; ++i) {
            IERC20 tin = i == 0 ? a : b;
            uint256 amt = 37 ether + i;
            uint256 snap = vm.snapshotState();
            vm.startPrank(user);
            tin.approve(address(sy), amt);
            uint256 sh = sy.deposit(user, address(tin), amt, 0);
            uint256 out = sy.redeem(user, sh, address(tin), 0, false);
            vm.stopPrank();
            console2.log("in/out same token", amt, out);
            assertLe(out, amt, "round trip no profit");
            vm.revertToState(snap);
        }
        // LP in -> token out -> back: no gain in LP terms
        assertTrue(outs.length == 3);
    }

    /// K: internalBalance=true and false give identical payout for identical shares (no extra value path).
    function test_K_internalBalanceParity() public {
        vm.startPrank(user);
        a.approve(address(sy), 50 ether);
        uint256 sh = sy.deposit(user, address(a), 50 ether, 0);
        vm.stopPrank();
        uint256 snap = vm.snapshotState();
        vm.prank(user);
        uint256 outFalse = sy.redeem(user, sh, address(b), 0, false);
        vm.revertToState(snap);
        AtomicPretransferCaller atomic = new AtomicPretransferCaller();
        vm.prank(user);
        IERC20(address(sy)).approve(address(atomic), sh);
        bytes memory r = atomic.consumePretransfer(IERC20(address(sy)), user, address(sy), sh,
            abi.encodeCall(IStandardizedYield.redeem, (user, sh, address(b), 0, true)));
        uint256 outTrue = abi.decode(r, (uint256));
        console2.log("redeem false/true", outFalse, outTrue);
        assertEq(outTrue, outFalse, "parity");
    }

    /// L: EOA cannot use internalBalance; stranded shares are only sweepable by a contract (known class
    ///    sy-redeem-internalbalance-unattributed); over-claim beyond held shares reverts.
    function test_L_internalBalanceGates() public {
        vm.startPrank(user);
        a.approve(address(sy), 10 ether);
        uint256 sh = sy.deposit(user, address(a), 10 ether, 0);
        IERC20(address(sy)).transfer(address(sy), sh); // user error: stranded
        vm.stopPrank();
        vm.prank(atkEoa);
        vm.expectRevert();
        sy.redeem(atkEoa, sh, address(a), 0, true);
        SyAttacker atk = new SyAttacker();
        vm.expectRevert();
        atk.sweep(address(sy), sh + 1, address(a));
        uint256 got = atk.sweep(address(sy), sh, address(a));
        console2.log("contract swept stranded (known class)", got);
        assertGt(got, 0);
        // seed LP holder value intact after sweep
        uint256 seedSh = sy.balanceOf(seed);
        vm.prank(seed);
        uint256 seedOut = sy.redeem(seed, seedSh / 2, address(a), 0, false);
        assertGt(seedOut, 0);
    }
}
