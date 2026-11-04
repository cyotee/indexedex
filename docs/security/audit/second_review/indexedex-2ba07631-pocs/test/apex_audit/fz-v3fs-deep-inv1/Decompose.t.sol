// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {V3FSFixture} from "./V3FSFixtureCopy.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as ILR} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";

contract DecomposeDeepInv1 is V3FSFixture {
    bytes32 constant MINT_T = keccak256("Mint(address,address,int24,int24,uint128,uint256,uint256)");
    bytes32 constant BURN_T = keccak256("Burn(address,int24,int24,uint128,uint256,uint256)");
    bytes32 constant SWAP_T = keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)");

    function setUp() public override {
        super.setUp();
        h.setSandwichMask(0xf8);
        h.setHonestJoinAtBookRatio(false);
    }

    function _prefix(bool skew) internal {
        h.a_dualDeposit(9116, 65536, true);
        h.a_singleDeposit(3597075808, 1598653050, false, 20);
        h.a_singleDeposit(11391, 4294967295, false, 5343);
        h.a_donate(3429, 12791);
        h.h_dualDeposit(17, 1000000000000000000000000);
        h.a_syDeposit(10000, 2000);
        h.a_syRedeemInternal(23446, 507);
        if (skew) {
            h.a_mintExactOut(264337247292056892107557765863231274529764461761558680744927113126014301973, 1424754830932723113572014995355094734951284697228594985502, true, 169182039051130134);
            h.a_mintExactOut(51551, 8556181810076920434953, false, 444720070199188493);
        }
    }

    function _state(string memory tag) internal view {
        (uint256 r0, uint256 r1) = h.book();
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        console2.log(tag);
        console2.log("   profit", h.attackerProfit()); console2.log("   allowance", h.atkAllowance());
        console2.log("   free0/free1", IERC20(pool.token0()).balanceOf(address(vault)), IERC20(pool.token1()).balanceOf(address(vault)));
        console2.log("   dep0/dep1", d0, d1);
        console2.log("   book", r0, r1);
        console2.log("   honest total", h.valueOf(address(h.passive())) + h.valueOf(address(h.hon(0))) + h.valueOf(address(h.hon(1))) + h.valueOf(address(h.hon(2))));
    }

    function _dumpLogs() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(pool)) continue;
            bytes32 t = logs[i].topics[0];
            if (t == MINT_T) {
                (address s, uint128 L, uint256 a0, uint256 a1) = abi.decode(logs[i].data, (address, uint128, uint256, uint256));
                if (address(uint160(uint256(logs[i].topics[1]))) == address(vault)) console2.log("   VAULT MINT L/a0/a1", uint256(L), a0, a1);
                s;
            } else if (t == BURN_T) {
                (uint128 L, uint256 a0, uint256 a1) = abi.decode(logs[i].data, (uint128, uint256, uint256));
                if (address(uint160(uint256(logs[i].topics[1]))) == address(vault)) console2.log("   VAULT BURN L/a0/a1", uint256(L), a0, a1);
            } else if (t == SWAP_T) {
                (int256 a0, int256 a1, uint160 sp,,) = abi.decode(logs[i].data, (int256, int256, uint160, uint128, int24));
                console2.log("   SWAP sender", address(uint160(uint256(logs[i].topics[1]))));
                console2.log("        a0", a0); console2.log("        a1", a1);
                console2.log("        sqrtP", uint256(sp));
            }
        }
    }

    function _int(int256 a, int256 b) internal pure returns (int256) { return a - b; }

    function _run(bool skew, uint256 sub, uint256 pushBps, string memory tag) internal {
        _prefix(skew);
        _state(string.concat(tag, " BEFORE"));
        int256 p0 = h.attackerProfit();
        uint256 al0 = h.atkAllowance();
        vm.recordLogs();
        h.a_sandwich(sub, true, pushBps, 6772108004893480073632, 11082);
        // the handler's step modifier consumed recordLogs; re-dump nothing here, events are logged in a separate replay
        _state(string.concat(tag, " AFTER"));
        console2.log("   lastSub", uint256(h.lastSub()));
        console2.log("   STEP attacker gain (wei)", h.attackerProfit() - p0);
        console2.log("   STEP allowance delta", h.atkAllowance() - al0);
    }

    function test_A_replay_sub3_push5000() public { _run(true, 297, 4194304, "A skew+sub3(zapOut)+push5000"); }
    function test_B_sub6_rebalanceOnly_push5000() public { _run(true, 6, 4194304, "B skew+sub6(rebalance only)+push5000"); }
    function test_C_sub3_minPush() public { _run(true, 3, 5, "C skew+sub3+push5bps"); }
    function test_D_noSkew_sub3_push5000() public { _run(false, 297, 4194304, "D noskew+sub3+push5000"); }
    function test_E_sub5_dualExit_push5000() public { _run(true, 5, 4194304, "E skew+sub5(dualExit)+push5000"); }

    /// raw (non-handler) replay of step 10 to dump vault Mint/Burn and Swap events
    function test_F_rawEvents() public {
        _prefix(true);
        IERC20 t0 = IERC20(pool.token0());
        uint160 sp0 = h.sp0();
        // reproduce: attacker push, then zapOut exactIn of `bound(amt,1,bal)` shares to t0, then push back
        // (executed through the handler to keep exact amounts; event dump via recordLogs inside the sandwich)
        vm.recordLogs();
        h.a_sandwich(297, true, 4194304, 6772108004893480073632, 11082);
        t0; sp0;
        console2.log("(events consumed by handler modifier; see A/B for value deltas)");
    }
}
