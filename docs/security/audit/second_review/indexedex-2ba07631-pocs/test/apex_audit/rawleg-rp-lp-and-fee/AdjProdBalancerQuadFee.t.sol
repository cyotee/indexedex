// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {BalancerQuadPhantomFee} from "./BalancerQuadPhantomFee.t.sol";

/// @notice Business-logic adjudication variant of APEX-2026-030 at production fee parameters
///         (FixtureEconomics: USAGE_FEE 5e16, DEX_SWAP_FEE 3e14) and a realistic LST-like rate (1.05).
contract AdjProdBalancerQuadFee is BalancerQuadPhantomFee {
    function _go(uint256 rate, uint256 rounds) internal {
        _deployWithRawRp(rate);
        _setUsageFee(5e16);
        _setDexFee(3e14);
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 vs = IERC20(hook).balanceOf(user);
        uint256 vb = _fairValue(vs, rate);
        uint256 f0 = IERC20(hook).balanceOf(feeTo);
        _grief(rounds);
        uint256 f1 = IERC20(hook).balanceOf(feeTo);
        uint256 va = _fairValue(vs, rate);
        console2.log("rate", rate);
        console2.log("liquidity ops", rounds * 2);
        console2.log("feeTo LP minted", f1 - f0);
        console2.log("victim before", vb);
        console2.log("victim after ", va);
        console2.log("victim loss bps", vb > va ? (vb - va) * 10_000 / vb : 0);
        console2.log("victim loss per op (1e-6 of value)", vb > va ? (vb - va) * 1e6 / vb / (rounds * 2) : 0);
    }

    function test_adj_prod_rate105_10ops() public { _go(1.05e18, 5); }
    function test_adj_prod_rate105_200ops() public { _go(1.05e18, 100); }
    function test_adj_prod_rate1_control() public { _go(1e18, 100); }
}
