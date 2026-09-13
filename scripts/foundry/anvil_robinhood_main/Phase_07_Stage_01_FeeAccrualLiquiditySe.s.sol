// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_07_Stage_01_FeeAccrualLiquiditySe as Liquidity} from "./Phase_07_Stage_01_FeeAccrualLiquiditySe.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/IUniswapV4StandardExchangeDFPkg.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

contract Phase_07_Stage_01_FeeAccrualLiquiditySe is FeeAccrualStageBase {
    function run() external {
        _startFee("Phase 07 Stage 01: Fee accrual Pons liquidity SE");
        PoolKey memory key = _basePoolKey();
        IDiamondPackageCallBackFactory factory = IDiamondPackageCallBackFactory(_configAddress(".diamondPackageFactory"));
        IUniswapV4StandardExchangeDFPkg pkg = IUniswapV4StandardExchangeDFPkg(_configAddress(".packages.uniswapV4Se"));
        IPoolManager pm = IPoolManager(_configAddress(".poolManager"));
        _broadcast();
        liquidityVault = Liquidity.execute(manager, factory, pkg, pm, key);
        vm.stopBroadcast();
        _exportProduct(LIQUIDITY_FILE, "liquidityVault", liquidityVault);
    }
}
