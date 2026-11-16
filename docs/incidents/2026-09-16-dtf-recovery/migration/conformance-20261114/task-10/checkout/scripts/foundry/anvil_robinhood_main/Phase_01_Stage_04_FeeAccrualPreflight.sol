// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {ICreate3Factory} from "@crane/contracts/interfaces/ICreate3Factory.sol";
import {IPonsV2LaunchFactory, GraduationPhase} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";

interface IPonsFeeAccrualInfrastructure {
    function poolManager() external view returns (address);
    function memeHook() external view returns (address);
}

library Phase_01_Stage_04_FeeAccrualPreflight {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    function verifyCore(address manager, address collector, address create3Factory, ITokenStaking staking, address dtf)
        internal view
    {
        require(address(IVaultFeeOracleQuery(manager).feeTo()) == collector, "Fee accrual: collector mismatch");
        require(address(staking.stakingToken()) == dtf, "Fee accrual: staking asset mismatch");
        bool owner = IMultiStepOwnable(create3Factory).owner() == manager;
        bool operator = IOperable(create3Factory).isOperator(manager);
        require(owner || operator || IOperable(create3Factory).isOperatorFor(ICreate3Factory.create3WithArgs.selector, manager), "Fee accrual: registry lacks CREATE3 authorization");
    }

    function verifyPool(IPonsV2LaunchFactory factory, IPoolManager manager, PoolKey memory key) internal view {
        IPonsFeeAccrualInfrastructure infrastructure = IPonsFeeAccrualInfrastructure(address(factory));
        require(infrastructure.poolManager() == address(manager), "Fee accrual: Pons PoolManager mismatch");
        require(infrastructure.memeHook() == address(key.hooks), "Fee accrual: Pons hook mismatch");
        require(Currency.unwrap(key.currency0) == address(0), "Fee accrual: native ETH base pool required");
        IPonsV2LaunchFactory.LaunchedToken memory launch = factory.getLaunchedToken(Currency.unwrap(key.currency1));
        require(launch.exists && launch.phase == GraduationPhase.PoolCreated, "Fee accrual: DTF not graduated");
        require(launch.pairToken == address(0) && launch.poolFee == key.fee && launch.tickSpacing == key.tickSpacing, "Fee accrual: launch key mismatch");
        (uint160 price,,,) = manager.getSlot0(key.toId());
        require(price > 0 && manager.getLiquidity(key.toId()) > 0, "Fee accrual: unfunded base pool");
    }
}
