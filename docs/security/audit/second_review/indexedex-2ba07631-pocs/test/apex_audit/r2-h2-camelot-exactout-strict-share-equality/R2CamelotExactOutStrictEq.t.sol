// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";

/// @notice h2-dos-stuck: Camelot exact-out LP->vault-share mint requires
/// convertToSharesDown(convertToAssetsUp(amountOut)) == amountOut exactly
/// (CamelotV2StandardExchangeOutTarget.sol:610-620). With decimalOffset 9 (DFPkg.sol:584)
/// one LP wei is worth ~1e9 shares, so the round trip overshoots unless amountOut lies on the
/// share/LP grid. UniV2 uses `<` at the same point (UniswapV2StandardExchangeOutTarget.sol:649).
contract R2CamelotExactOutStrictEq is TestBase_CamelotV2StandardExchange {
    ERC20PermitMintableStub tokenA;
    ERC20PermitMintableStub tokenB;
    IStandardExchangeProxy vault;
    ICamelotPair pair;
    address alice = address(0xA11CE);

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 1_000_000 ether);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 1_000_000 ether);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), 1000 ether);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), 1000 ether);
        vault = IStandardExchangeProxy(camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), 1000 ether, IERC20(address(tokenB)), 1000 ether, address(this)
        ));
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));
        // alice obtains LP honestly from the pair
        tokenA.transfer(address(pair), 100 ether);
        tokenB.transfer(address(pair), 100 ether);
        pair.mint(alice);
        vm.prank(alice);
        IERC20(address(pair)).approve(address(vault), type(uint256).max);
    }

    function aliceExactOut(uint256 sharesOut) external returns (uint256 used) {
        require(msg.sender == address(this));
        vm.prank(alice);
        used = IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(pair)), type(uint256).max, IERC20(address(vault)), sharesOut, alice, false, block.timestamp + 1 hours
        );
    }

    function _try(uint256 sharesOut) internal returns (bool ok) {
        uint256 snap = vm.snapshotState();
        try this.aliceExactOut(sharesOut) returns (uint256) { ok = true; } catch (bytes memory r) {
            ok = false;
            assertEq(bytes4(r), bytes4(keccak256("AmountOutNotMet(uint256,uint256)")), "reverts with AmountOutNotMet");
        }
        vm.revertToState(snap);
    }

    function test_camelot_exactout_mint_reverts_off_grid() public {
        uint256 preview = IStandardExchangeOut(address(vault)).previewExchangeOut(
            IERC20(address(pair)), IERC20(address(vault)), 1e18 + 12345
        );
        emit log_named_uint("preview LP for 1e18+12345 shares", preview);
        uint256 fails;
        uint256 n = 20;
        for (uint256 i = 1; i <= n; ++i) {
            uint256 want = i * 1e18 + i * 7919; // ordinary user-chosen share amounts
            bool ok = _try(want);
            if (!ok) ++fails;
        }
        emit log_named_uint("exact-out mints tried", n);
        emit log_named_uint("exact-out mints reverted", fails);
        assertGt(preview, 0, "preview quotes a price");
        assertEq(fails, n, "every off-grid exact-out mint reverts despite a non-zero preview");
    }

    /// Control: amountOut chosen ON the share/LP grid (shares quoted for an integer LP amount) succeeds,
    /// proving the revert is caused purely by the grid / strict equality.
    function test_control_on_grid_succeeds() public {
        uint256 ok;
        for (uint256 n = 1; n <= 10; ++n) {
            uint256 lp = n * 1e17 + n * 13;(uint256 sharesOnGrid,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(pair)), lp, IERC20(address(vault)));
            if (_try(sharesOnGrid)) ++ok;
        }
        emit log_named_uint("on-grid exact-out mints succeeded /10", ok);
        assertEq(ok, 10, "on-grid amounts succeed");// actually execute one on-grid mint and check balances
        (uint256 s,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(pair)), 1e18, IERC20(address(vault)));
        uint256 lpBefore = IERC20(address(pair)).balanceOf(alice);
        uint256 used = this.aliceExactOut(s);
        assertEq(IERC20(address(vault)).balanceOf(alice), s, "alice got exact shares");
        assertEq(lpBefore - IERC20(address(pair)).balanceOf(alice), used, "LP used");
        emit log_named_uint("on-grid shares", s);
        emit log_named_uint("on-grid LP used", used);
    }

    /// Pseudo-random user amounts: fraction that revert, plus the fraction that are on-grid.
    function test_random_amount_failure_rate() public {
        uint256 fails; uint256 n = 100;
        for (uint256 i; i < n; ++i) {
            uint256 want = 1e15 + (uint256(keccak256(abi.encode(i))) % 50e18);
            if (!_try(want)) ++fails;
        }
        emit log_named_uint("random exact-out mints tried", n);
        emit log_named_uint("random exact-out mints reverted", fails);
        assertGe(fails, 95, "nearly all random amounts revert");
    }

    /// Off-grid request: the preview LP amount would actually mint >= requested shares (overshoot),
    /// i.e. UniV2's `<` semantics would accept; Camelot's `!=` rejects. Also: no funds move on revert.
    function test_overshoot_and_no_fund_loss() public {
        uint256 want = 3e18 + 23757;
        uint256 lpNeeded = IStandardExchangeOut(address(vault)).previewExchangeOut(IERC20(address(pair)), IERC20(address(vault)), want);(uint256 sharesForLp,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(pair)), lpNeeded, IERC20(address(vault)));
        emit log_named_uint("requested shares", want);
        emit log_named_uint("preview LP needed", lpNeeded);
        emit log_named_uint("shares that LP actually buys", sharesForLp);
        emit log_named_uint("overshoot (shares)", sharesForLp - want);
        assertGt(sharesForLp, want, "round-up overshoots request (UniV2 '<' check would pass)");
        uint256 lpBefore = IERC20(address(pair)).balanceOf(alice);
        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        assertFalse(_try(want), "strict != reverts");
        assertEq(IERC20(address(pair)).balanceOf(alice), lpBefore, "no LP lost");
        assertEq(IERC20(address(vault)).totalSupply(), supplyBefore, "no supply change");
        // exact-in alternative route works for the same LP
        vm.prank(alice);(uint256 got,) = IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(pair)), lpNeeded, IERC20(address(vault)), want, alice, false, block.timestamp + 1 hours);
        emit log_named_uint("exact-in workaround shares", got);
        assertGe(got, want);
    }
}
