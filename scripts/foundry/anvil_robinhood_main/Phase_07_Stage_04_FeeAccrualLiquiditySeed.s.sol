// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_07_Stage_04_FeeAccrualLiquiditySeed as Seed} from "./Phase_07_Stage_04_FeeAccrualLiquiditySeed.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

contract Phase_07_Stage_04_FeeAccrualLiquiditySeed is FeeAccrualStageBase {
    function run() external {
        _startFee("Phase 07 Stage 04: Initialize fee accrual liquidity SE");
        liquidityVault = _loadProduct(LIQUIDITY_FILE, "liquidityVault");
        Seed.Config memory c_ = Seed.Config(liquidityVault, vm.parseJsonAddress(feeConfig, ".bootstrap.actor"),
            dtf, wethToken, vm.parseJsonUint(feeConfig, ".bootstrap.liquiditySeedWethInput"),
            vm.parseJsonUint(feeConfig, ".bootstrap.maxDtfInput"),
            block.timestamp + vm.parseJsonUint(feeConfig, ".bootstrap.deadlineSeconds"));
        require(c_.actor == deployer && c_.actor != address(staking), "Liquidity seed: funding actor");
        require(c_.wethInput < vm.parseJsonUint(feeConfig, ".bootstrap.wethInput"), "Liquidity seed: exceeds total budget");
        _broadcast();
        (uint256 shares_, uint256 dtfInput_) = Seed.execute(IPoolManager(_configAddress(".poolManager")), _basePoolKey(), c_);
        vm.stopBroadcast();
        string memory obj_ = "liquidity-seed";
        vm.serializeBytes32(obj_, "configHash", feeConfigHash);
        vm.serializeBytes32(obj_, "codeHash", liquidityVault.codehash);
        vm.serializeAddress(obj_, "liquidityVault", liquidityVault);
        vm.serializeUint(obj_, "wethInput", c_.wethInput);
        vm.serializeUint(obj_, "dtfInput", dtfInput_);
        vm.serializeUint(obj_, "shares", shares_);
        _writeJson(vm.serializeBool(obj_, "receiptVerified", false), "phase07_stage04_fee_accrual_liquidity_seed.json");
    }
}
