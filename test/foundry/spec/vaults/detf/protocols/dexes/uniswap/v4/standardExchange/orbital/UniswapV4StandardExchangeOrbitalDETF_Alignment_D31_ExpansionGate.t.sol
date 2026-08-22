// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

contract UniswapV4StandardExchangeOrbitalDETF_Alignment_D31_ExpansionGate is
    TestBase_UniswapV4StandardExchangeOrbitalDETF
{
    function setUp() public override {
        super.setUp();
        detf = _deployDetfWired(_openArgsUnique("d31"));
        _bindDetfPointers();
        _firstBondBothPairs(200 ether, 200 ether);
    }

    function test_D31_4_openMintDoesNotExpand() public {
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Open));
        uint256 last_ = detfInfo.lastExpansionTimestamp();
        vm.warp(block.timestamp + 8 hours * 20);
        _mintPair(pair0, 10 ether);
        assertEq(detfInfo.lastExpansionTimestamp(), last_, "D31-4");
    }
}
