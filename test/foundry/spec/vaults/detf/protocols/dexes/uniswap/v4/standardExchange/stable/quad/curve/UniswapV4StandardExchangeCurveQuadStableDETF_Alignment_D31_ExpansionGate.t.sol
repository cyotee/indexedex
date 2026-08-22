// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";

contract UniswapV4StandardExchangeCurveQuadStableDETF_Alignment_D31_ExpansionGate is
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
{
    function setUp() public override {
        super.setUp();
        detf = _deployDetfWired(_openArgsUnique("d31"));
        _bindDetfPointers();
        _setBondTermsFor(detf);
        _firstBondOn(detf, _amts(50 ether), pair0);
    }

    function test_D31_4_openMintDoesNotExpand() public {
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Open));
        uint256 last_ = detfInfo.lastExpansionTimestamp();
        vm.warp(block.timestamp + 8 hours * 20);
        _mintOn(detf, pair0, 5 ether);
        assertEq(detfInfo.lastExpansionTimestamp(), last_, "D31-4");
    }

    function _amts(uint256 v_) internal view returns (uint256[] memory a) {
        a = new uint256[](detfInfo.m());
        for (uint256 i; i < a.length; ++i) a[i] = v_;
    }
}
