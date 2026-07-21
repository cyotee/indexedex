// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IStETH.sol";
import {IWstETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IWstETH.sol";
import {LidoService} from "@crane/contracts/protocols/staking/ethereum/lido/services/LidoService.sol";
import {WstETHRateProvider} from "@crane/contracts/protocols/staking/ethereum/lido/rate/WstETHRateProvider.sol";
import {
    TestBase_EthereumStakingFork,
    EthereumStakingAddresses
} from "./TestBase_EthereumStakingFork.sol";

contract LidoServiceHarness {
    function wrap(IWstETH wst, uint256 amount) external returns (uint256) {
        return LidoService._wrap(wst, amount);
    }

    function unwrap(IWstETH wst, uint256 amount) external returns (uint256) {
        return LidoService._unwrap(wst, amount);
    }

    function submit(IStETH steth, address referral) external payable returns (uint256) {
        return LidoService._submit(steth, referral);
    }
}

contract LidoServiceFork is TestBase_EthereumStakingFork {
    LidoServiceHarness internal harness;
    IStETH internal steth;
    IWstETH internal wsteth;
    WstETHRateProvider internal rateProvider;

    function setUp() public {
        if (!_forkEthereum()) return;
        harness = new LidoServiceHarness();
        steth = IStETH(EthereumStakingAddresses.ST_ETH);
        wsteth = IWstETH(EthereumStakingAddresses.WST_ETH);
        rateProvider = new WstETHRateProvider(wsteth);
        _dealETH(address(this), 50 ether);
    }

    function test_Fork_RateProvider_MatchesStEthPerToken() public {
        uint256 rate = rateProvider.getRate();
        assertGt(rate, 0, "rate > 0");
        assertEq(rate, wsteth.stEthPerToken(), "rate == stEthPerToken");
    }

    function test_Fork_WrapUnwrap_InverseWithinOneShare() public {
        // Acquire stETH via submit on harness, transfer to harness for wrap
        uint256 stOut = harness.submit{value: 2 ether}(steth, address(0));
        assertGt(stOut, 0, "stETH minted");

        // Pull stETH into harness for wrap (submit credited harness)
        // submit mints to harness (msg.sender = harness)
        uint256 stBal = IERC20(address(steth)).balanceOf(address(harness));
        assertGt(stBal, 0);

        uint256 wstOut = harness.wrap(wsteth, stBal);
        assertGt(wstOut, 0, "wst minted");

        uint256 stBack = harness.unwrap(wsteth, wstOut);
        // Inverse within 1 wei/share tolerance for rounding
        assertApproxEqAbs(stBack, stBal, 2, "wrap/unwrap inverse within 2 wei");
    }
}
