// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";

contract UniswapV4StandardExchangeWeightedDETF_Alignment_D31_ExpansionGate is
    TestBase_UniswapV4StandardExchangeWeightedDETF
{
    function setUp() public override {
        _setUpPlatform();
        detf = _deployDetfWired(_openArgsUnique("d31"));
        _bindDetfPointers();
        _firstBondOn(detf, _one(200 ether), pair0);
    }

    function test_D31_4_openMintDoesNotExpand() public {
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Open));
        uint256 last_ = detfInfo.lastExpansionTimestamp();
        vm.warp(block.timestamp + 8 hours * 20);
        _mintOn(detf, pair0, 10 ether);
        assertEq(detfInfo.lastExpansionTimestamp(), last_, "D31-4");
    }

    function _one(uint256 amt_) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = amt_;
    }
}
