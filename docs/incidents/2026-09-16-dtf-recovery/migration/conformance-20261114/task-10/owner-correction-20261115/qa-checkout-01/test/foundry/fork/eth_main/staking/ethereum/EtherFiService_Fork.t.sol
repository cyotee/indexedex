// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IEtherFiLiquidityPool} from
    "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IEtherFiLiquidityPool.sol";
import {IWeETH} from "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IWeETH.sol";
import {EtherFiService} from "@crane/contracts/protocols/staking/ethereum/etherfi/services/EtherFiService.sol";
import {WeETHRateProvider} from "@crane/contracts/protocols/staking/ethereum/etherfi/rate/WeETHRateProvider.sol";
import {
    TestBase_EthereumStakingFork,
    EthereumStakingAddresses
} from "./TestBase_EthereumStakingFork.sol";

contract EtherFiServiceHarness {
    function depositAndWrap(IEtherFiLiquidityPool pool, IWeETH weeth) external payable returns (uint256) {
        return EtherFiService._depositAndWrap(pool, weeth);
    }

    function unwrap(IWeETH weeth, uint256 amount) external returns (uint256) {
        return EtherFiService._unwrap(weeth, amount);
    }
}

contract EtherFiServiceFork is TestBase_EthereumStakingFork {
    EtherFiServiceHarness internal harness;
    IEtherFiLiquidityPool internal pool;
    IWeETH internal weeth;
    WeETHRateProvider internal rateProvider;

    function setUp() public {
        if (!_forkEthereum()) return;
        harness = new EtherFiServiceHarness();
        pool = IEtherFiLiquidityPool(EthereumStakingAddresses.ETHERFI_LIQUIDITY_POOL);
        weeth = IWeETH(EthereumStakingAddresses.WE_ETH);
        rateProvider = new WeETHRateProvider(weeth);
        _dealETH(address(this), 50 ether);
    }

    function test_Fork_Rate_GreaterThanZero() public {
        uint256 rate = rateProvider.getRate();
        assertGt(rate, 0, "weETH rate > 0");
        assertEq(rate, weeth.getRate());
    }

    function test_Fork_DepositAndWrap_IncreasesWeETH_UnwrapRecoversEETH() public {
        uint256 amount = 0.5 ether;
        uint256 weBefore = IERC20(address(weeth)).balanceOf(address(harness));
        uint256 weOut = harness.depositAndWrap{value: amount}(pool, weeth);
        assertGt(weOut, 0, "weETH minted");
        assertEq(IERC20(address(weeth)).balanceOf(address(harness)) - weBefore, weOut);

        address eeth = weeth.eETH();
        uint256 eBefore = IERC20(eeth).balanceOf(address(harness));
        uint256 eBack = harness.unwrap(weeth, weOut);
        assertGt(eBack, 0, "eETH recovered");
        // Share math can leave 1-2 wei dust on wrap/unwrap round-trip.
        assertApproxEqAbs(IERC20(eeth).balanceOf(address(harness)) - eBefore, eBack, 2, "eETH delta");
        assertApproxEqAbs(eBack, amount, 1e15, "unwrap recovers ~deposited ETH value as eETH");
    }
}
