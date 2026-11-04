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
contract CamelotExactOutSkeptic is TestBase_CamelotV2StandardExchange {
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

    function _count(uint256 base) internal returns (uint256 fails) {
        for (uint256 i = 1; i <= 10; ++i) { if (!_try(i * base)) ++fails; }
    }
    function test_round_amounts_fresh_and_after_fee_growth() public {
        emit log_named_uint("fresh: round 1e18 multiples failing /10", _count(1e18));
        emit log_named_uint("fresh: round 1e15 multiples failing /10", _count(1e15));
        // Grow vault LP reserve via a donation-free path: alice deposits exact-in (on-grid) then pair fees accrue
        // simulate trading fee growth honestly: swap through pair many times
        for (uint256 k; k < 20; ++k) {
            tokenA.transfer(address(pair), 10 ether);
            (uint112 r0, uint112 r1,,) = pair.getReserves();
            bool aIs0 = pair.token0() == address(tokenA);
            uint256 rin = aIs0 ? r0 : r1; uint256 rout = aIs0 ? r1 : r0;
            uint256 out = (10 ether * 997 * rout) / (rin * 1000 + 10 ether * 997) / 2;
            pair.swap(aIs0 ? 0 : out, aIs0 ? out : 0, address(this), "");
            tokenB.transfer(address(pair), out);
            (r0, r1,,) = pair.getReserves();
            rin = aIs0 ? r1 : r0; rout = aIs0 ? r0 : r1;
            uint256 out2 = (out * 997 * rout) / (rin * 1000 + out * 997) / 2;
            pair.swap(aIs0 ? out2 : 0, aIs0 ? 0 : out2, address(this), "");
        }
        // make the vault realize fees via an honest exact-in deposit by alice
        vm.prank(alice);IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(pair)), 1 ether, IERC20(address(vault)), 0, alice, false, block.timestamp + 1 hours);
        emit log_named_uint("aged: round 1e18 multiples failing /10", _count(1e18));
        emit log_named_uint("aged: round 1e15 multiples failing /10", _count(1e15));(uint256 q,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(pair)), 5 ether, IERC20(address(vault)));
        emit log_named_uint("aged: previewExchangeIn-derived amount ok(1)", _try(q) ? 1 : 0);
    }
}

