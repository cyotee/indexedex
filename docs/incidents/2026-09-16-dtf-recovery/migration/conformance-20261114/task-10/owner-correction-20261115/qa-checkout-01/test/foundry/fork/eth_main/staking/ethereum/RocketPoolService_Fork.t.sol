// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRETH} from "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRETH.sol";
import {IRocketDepositPool} from
    "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRocketDepositPool.sol";
import {IRocketStorage} from
    "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRocketStorage.sol";
import {RocketPoolService} from
    "@crane/contracts/protocols/staking/ethereum/rocket-pool/services/RocketPoolService.sol";
import {RETHRateProvider} from
    "@crane/contracts/protocols/staking/ethereum/rocket-pool/rate/RETHRateProvider.sol";
import {
    TestBase_EthereumStakingFork,
    EthereumStakingAddresses
} from "./TestBase_EthereumStakingFork.sol";

contract RocketPoolServiceHarness {
    function deposit(IRocketDepositPool pool, IRETH reth) external payable returns (uint256) {
        return RocketPoolService._deposit(pool, reth);
    }

    function exchangeRate(IRETH reth) external view returns (uint256) {
        return RocketPoolService._exchangeRate(reth);
    }

    function maxDeposit(IRocketDepositPool pool) external view returns (uint256) {
        return RocketPoolService._maxDeposit(pool);
    }
}

contract RocketPoolServiceFork is TestBase_EthereumStakingFork {
    RocketPoolServiceHarness internal harness;
    IRETH internal reth;
    IRocketDepositPool internal pool;
    RETHRateProvider internal rateProvider;

    function setUp() public {
        if (!_forkEthereum()) return;
        harness = new RocketPoolServiceHarness();
        reth = IRETH(EthereumStakingAddresses.R_ETH);
        IRocketStorage storage_ = IRocketStorage(EthereumStakingAddresses.ROCKET_STORAGE);
        pool = RocketPoolService._depositPool(storage_);
        // Fallback to known rETH if storage lookup empty
        if (address(pool) == address(0)) {
            // resolve via storage key in test context
            pool = IRocketDepositPool(storage_.getAddress(RocketPoolService.DEPOSIT_POOL_KEY));
        }
        rateProvider = new RETHRateProvider(reth);
        _dealETH(address(this), 50 ether);
    }

    function test_Fork_Rate_GreaterThanZero() public {
        uint256 rate = rateProvider.getRate();
        assertGt(rate, 0, "rETH rate > 0");
        assertEq(rate, harness.exchangeRate(reth), "provider matches service");
    }

    function test_Fork_Deposit_WhenCapacity() public {
        uint256 maxDep = harness.maxDeposit(pool);
        if (maxDep == 0) {
            // Document empty-pool: deposit not possible; rate assertion already covers green path.
            emit log("Rocket Pool deposit pool empty - deposit path skipped");
            return;
        }
        uint256 amount = maxDep < 0.5 ether ? maxDep : 0.5 ether;
        if (amount == 0) return;
        uint256 beforeBal = IERC20(address(reth)).balanceOf(address(harness));
        uint256 minted = harness.deposit{value: amount}(pool, reth);
        assertGt(minted, 0, "rETH minted");
        assertEq(IERC20(address(reth)).balanceOf(address(harness)) - beforeBal, minted);
    }
}
