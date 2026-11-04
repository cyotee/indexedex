// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Business-logic adjudication variants for APEX-2026-031.
// Design spec (docs/superpowers/specs/2026-05-31-standard-exchange-buffer-pool-design.md section 6.1)
// prescribes init with shares + 0/dust TTA and virtualTTA := s_init * r. That IS the "attacker init"
// state of the original PoC. Here an HONEST LP initializes that way and an honest user makes a SMALL
// (1% of pool) shares-only join through the pool's native exchangeIn(shares -> BPT), compared with a
// proportional join of the same shares. Fee: 0.05% (pkg comment's intended default) and 5% (pkg literal).

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolRoleAccounts} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {FzBase} from "./BufferSharesOnlyJoin.t.sol";

abstract contract DesignInitSmallJoin is FzBase {
    address internal lpInit;
    address internal joiner;
    uint256 internal joinerS;

    function _fee() internal pure virtual returns (uint256);

    function _initPool() internal override {
        joiner = makeAddr("honestJoiner");
        joinerS = mintShares(joiner, 10e18); // ~1% of the pool's shares
        lpInit = makeAddr("honestInitLP");
        uint256 S = mintShares(lpInit, 1_000e18);
        mintTTA(lpInit, 1e18); // dust TTA, as the design spec prescribes
        p = IStandardExchangeBufferPool(bufferPool);
        _approveAll(lpInit);
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(bufferPool);
        uint256[] memory amounts = new uint256[](2);
        amounts[p.sharesIndex()] = S;
        amounts[p.ttaIndex()] = 1e18;
        vm.prank(lpInit);
        router.initialize(bufferPool, poolTokens, amounts, 0, false, bytes(""));
    }

    function setUp() public override {
        super.setUp();
        p = IStandardExchangeBufferPool(bufferPool);
        PoolRoleAccounts memory ra = bv3Vault.getPoolRoleAccounts(bufferPool);
        vm.prank(ra.swapFeeManager);
        bv3Vault.setStaticSwapFeePercentage(bufferPool, _fee());
        console2.log("static swap fee", bv3Vault.getStaticSwapFeePercentage(bufferPool));
    }

    function test_designInit_smallNativeSharesJoin() public {
        fsv0 = _fsv();
        _logPool("design-init state");
        _approveAll(joiner);
        uint256 vin = _val(0, joinerS, fsv0);
        uint256 lpBefore = _exitValue(lpInit);
        uint256 bpt = _nativeSharesJoin(joiner, joinerS);
        (uint256 t, uint256 s) = _exitAll(joiner);
        uint256 vout = _val(t, s, fsv0);
        uint256 lpAfter = _exitValue(lpInit);
        console2.log("native join shares in / bpt", joinerS, bpt);
        console2.log("native join value in / out (fsv)", vin, vout);
        console2.log("native join loss bps", (vin - vout) * 10_000 / vin);
        console2.log("init LP exit value before/after", lpBefore, lpAfter);
    }

    function test_designInit_smallProportionalJoin_control() public {
        fsv0 = _fsv();
        _approveAll(joiner);
        mintTTA(joiner, 1e18);
        uint256 supply = bv3Vault.totalSupply(bufferPool);
        uint256 bptOut = supply * joinerS / _raw(p.sharesIndex()) * 99 / 100;
        uint256[] memory ins = addLiquidityProportional(joiner, bptOut, type(uint128).max, type(uint128).max);
        uint256 vin = _val(ins[p.ttaIndex()], ins[p.sharesIndex()], fsv0);
        (uint256 t, uint256 s) = _exitAll(joiner);
        uint256 vout = _val(t, s, fsv0);
        console2.log("proportional join tta/shares in", ins[p.ttaIndex()], ins[p.sharesIndex()]);
        console2.log("proportional join value in / out (fsv)", vin, vout);
    }
}

contract SharesOnlyJoin_DesignInit_Fee005 is DesignInitSmallJoin {
    function _fee() internal pure override returns (uint256) { return 5e14; }
}

contract SharesOnlyJoin_DesignInit_Fee5pct is DesignInitSmallJoin {
    function _fee() internal pure override returns (uint256) { return 5e16; }
}
