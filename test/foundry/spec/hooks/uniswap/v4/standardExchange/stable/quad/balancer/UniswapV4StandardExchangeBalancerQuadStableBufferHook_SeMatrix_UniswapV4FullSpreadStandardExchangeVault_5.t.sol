// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IFullSpreadV4MatrixMoney} from "../../../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice Five-leg Balancer row: one FullSpread face, PairToken identity, three sorted raw records.
/// @dev Inherits the row's runtime-length overrides, never the behavior's fixed-four helpers.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5 is
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault
{
    function setUp() public override {
        TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.setUp();
        _initializeBalancer(5);
    }

    function test_row_identity_pairToken() public {
        emit log_named_bytes("FS-HOOK-04 PairToken rejection; FS-A26 OPEN", identityRevert);
        if (!identityAccepted) {
            assertGt(identityRevert.length, 0, "FS-HOOK-04 recorded; FS-A26 not passed");
            return;
        }
        assertEq(quad.numTokens(), 5, "five active records");
        assertEq(rawTokens.length, 3);
        assertLt(uint160(rawTokens[0]), uint160(rawTokens[1]));
        assertLt(uint160(rawTokens[1]), uint160(rawTokens[2]));
        _seedBalancer();
        address pair_ = pairRecord.share();
        uint256 supply_ = IERC20(pair_).totalSupply();
        vm.expectCall(pair_, abi.encodeWithSelector(IFullSpreadV4MatrixMoney.exchangeIn.selector), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSelector(IStandardExchangeOut.exchangeOut.selector), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSignature(
            "exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)"
        ), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSignature(
            "exchangeBundleOut(address,uint256,uint256[],address,bool,uint256)"
        ), uint64(0));
        _balancerDirections(pair_);
        _balancerDirections(rawTokens[0]);
        assertEq(IERC20(pair_).totalSupply(), supply_, "no PairToken mint or redeem");
    }

    // The two-leg file owns both rate-target pools; this larger row keeps currency0.
    function test_row_rateTarget_currency1() public override {
        assertEq(quad.rateProvider(faceIdx), fullSpread.currency0Provider());
        assertEq(quad.token(faceIdx), fullSpread.faceToken());
        _seedBalancer();
        _balancerDirections(rawTokens[0]);
    }
}
