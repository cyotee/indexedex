// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {TestBase_TokenStaking} from "contracts/protocols/staking/token/TestBase_TokenStaking.sol";

/// Hermetic TokenStaking (HEAD code): reward conservation and reassign accounting under adversarial sequences.
contract GxTokenStakingHermeticTest is TestBase_TokenStaking {
    address internal stakerC;

    function setUp() public override {
        super.setUp();
        stakerC = makeAddr("stakerC");
        stakeToken.mint(stakerC, 1_000e18);
        address[3] memory us = [stakerA, stakerB, stakerC];
        for (uint256 i; i < 3; ++i) {
            vm.prank(us[i]);
            stakeToken.approve(address(staking), type(uint256).max);
        }
        vm.prank(owner);
        stakeToken.approve(address(staking), type(uint256).max);
    }

    function _bal(address a) internal view returns (uint256) { return stakeToken.balanceOf(a); }

    function _notify(uint256 r) internal {
        vm.prank(owner);
        staking.notifyRewardAmount(r);
    }

    /// G: reward paid out never exceeds reward funded; principal fully returned; contract stays solvent at every step.
    function test_G_rewardConservationAdversarialSequence() public {
        uint256 R = 700e18;
        vm.prank(stakerA); staking.stake(100e18);
        _notify(R);
        uint256 t0 = block.timestamp;
        address[3] memory us = [stakerA, stakerB, stakerC];
        uint256[3] memory start = [_bal(stakerA) + 100e18, _bal(stakerB), _bal(stakerC)];
        // pseudo-random interleaving incl. reassign, 1-wei stakes, withdraw-all, mid-period notify
        for (uint256 i; i < 40; ++i) {
            vm.warp(block.timestamp + 3 hours + (i * 7919) % 5 hours);
            address u = us[i % 3];
            uint256 op = uint256(keccak256(abi.encode(i))) % 6;
            uint256 b = staking.balanceOf(u);
            vm.startPrank(u);
            if (op == 0) staking.stake(1 + (i * 1e17) % 50e18);
            else if (op == 1 && b > 0) staking.withdraw(b / 2 + 1 > b ? b : b / 2 + 1);
            else if (op == 2) staking.getReward();
            else if (op == 3 && b > 1) staking.reassign(us[(i + 1) % 3], b / 3 + 1);
            else if (op == 4) staking.stake(1);
            else if (b > 0) staking.exit();
            vm.stopPrank();
            assertGe(_bal(address(staking)), staking.totalSupply(), "principal backed");
            if (i == 20) _notify(100e18);
        }
        vm.warp(t0 + 30 days);
        for (uint256 i; i < 3; ++i) {
            vm.startPrank(us[i]);
            if (staking.balanceOf(us[i]) > 0) staking.exit(); else staking.getReward();
            vm.stopPrank();
        }
        uint256 paid;
        for (uint256 i; i < 3; ++i) paid += _bal(us[i]) - start[i];
        uint256 funded = R + 100e18;
        console2.log("funded", funded, "paid", paid);
        console2.log("residual in contract", _bal(address(staking)));
        assertLe(paid, funded, "no over-payment");
        assertEq(staking.totalSupply(), 0);
        assertEq(_bal(address(staking)), funded - paid, "residual == unpaid rewards");
    }

    /// H: reassign never creates rewards; recipient cannot double count; sender keeps proportional remainder.
    function test_H_reassignDoesNotCreateRewards() public {
        vm.prank(stakerA); staking.stake(100e18);
        vm.prank(stakerB); staking.stake(100e18);
        _notify(700e18);
        vm.warp(block.timestamp + 2 days);
        uint256 eA = staking.earned(stakerA);
        uint256 eB = staking.earned(stakerB);
        uint256 eC = staking.earned(stakerC);
        // ping-pong reassign many times in the same block
        for (uint256 i; i < 10; ++i) {
            vm.prank(stakerA); staking.reassign(stakerC, 10e18);
            vm.prank(stakerC); staking.reassign(stakerA, 10e18);
            vm.prank(stakerB); staking.reassign(stakerC, 1);
        }
        uint256 sumBefore = eA + eB + eC;
        uint256 sumAfter = staking.earned(stakerA) + staking.earned(stakerB) + staking.earned(stakerC);
        console2.log("earned sum before/after", sumBefore, sumAfter);
        assertLe(sumAfter, sumBefore, "reassign creates no rewards");
        assertApproxEqAbs(sumAfter, sumBefore, 100, "only rounding lost");
        assertEq(staking.totalSupply(), 200e18);
    }

    /// H2: reassign is callable in any phase; check it cannot be used to grief/steal in Staking via self-dust tricks.
    function test_H2_reassignZeroBalanceAndSelfReverts() public {
        vm.prank(stakerA);
        vm.expectRevert();
        staking.reassign(stakerB, 1);
        vm.prank(stakerA); staking.stake(1e18);
        vm.prank(stakerA);
        vm.expectRevert();
        staking.reassign(stakerA, 1);
    }
}

interface ITS {
    function phase() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function withdrawClaim(uint256) external returns (uint256);
    function reassign(address, uint256) external;
    function previewClaim(address, uint256) external view returns (uint256);
    function claimVault() external view returns (address);
}

/// Live 4663 TokenStaking 0xE4c9Ff4C (Wrapped phase): withdrawClaim pro-rata rounding and dust-split behaviour.
contract GxTokenStakingLiveTest is Test {
    ITS constant TS = ITS(0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00);
    address constant H1 = 0x0cC7CEdb0935ceaB0B4A6B38eE7dcfd403b19A7b; // 5,000,000 stake
    address constant H2 = 0x1De6459390DD59Bcd8EE7Ffba9B8d6e6284a67bC; // 2,060,142 stake
    address constant ATT = address(0xA77A);

    function setUp() public {
        vm.createSelectFork("https://rpc.mainnet.chain.robinhood.com");
    }

    function _claimTok() internal view returns (IERC20) {
        (bool ok, bytes memory r) = TS.claimVault().staticcall(abi.encodeWithSignature("asset()"));
        require(ok);
        return IERC20(abi.decode(r, (address)));
    }

    /// I: whole vs chunked withdraw; dust-splitting (reassign 1-wei pieces) never extracts more than pro-rata.
    function test_I_liveWithdrawClaimChunkingAndDust() public {
        assertEq(TS.phase(), 2, "Wrapped");
        IERC20 c = _claimTok();
        uint256 b = TS.balanceOf(H1);
        uint256 snap = vm.snapshotState();
        vm.prank(H1);
        uint256 whole = TS.withdrawClaim(b);
        vm.revertToState(snap);
        uint256 chunked;
        for (uint256 i; i < 10; ++i) {
            uint256 amt = i == 9 ? TS.balanceOf(H1) : b / 10;
            vm.prank(H1);
            chunked += TS.withdrawClaim(amt);
        }
        console2.log("whole/chunked", whole, chunked);
        assertLe(chunked, whole, "chunking never beats whole");
        vm.revertToState(snap);
        // dust attack: holder splits tiny pieces to an attacker EOA then withdraws them
        uint256 sup = TS.totalSupply();
        uint256 vs = IERC20(TS.claimVault()).balanceOf(address(TS));
        uint256 piece = sup / vs + 1; // smallest stake that rounds to >=1 vault share
        uint256 got;
        uint256 before = c.balanceOf(ATT);
        for (uint256 i; i < 20; ++i) {
            vm.prank(H2);
            TS.reassign(ATT, piece);
            vm.prank(ATT);
            got += TS.withdrawClaim(piece);
        }
        uint256 fair = TS.previewClaim(H2, piece * 20);
        console2.log("dust got/fair(20 pieces)", got, fair);
        assertEq(c.balanceOf(ATT) - before, got);
        assertLe(got, fair + 20, "dust splitting does not beat pro-rata");
        // other holders unaffected: H1 preview per unit not reduced
        assertGe(TS.previewClaim(H1, b), whole - 1);
    }
}
