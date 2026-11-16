// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_08_Stage_04_FeeAccrualBootstrap as Bootstrap} from "./Phase_08_Stage_04_FeeAccrualBootstrap.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

contract Phase_08_Stage_04_FeeAccrualBootstrap is FeeAccrualStageBase {
    function run() external {
        _startFee("Phase 08 Stage 04: Fee accrual first bond");
        _loadFeeDetf(false);
        Bootstrap.Config memory c;
        c.actor = vm.parseJsonAddress(feeConfig, ".bootstrap.actor");
        require(c.actor == deployer && c.actor != address(staking), "Bootstrap: use configured funding actor");
        c.recipient = vm.parseJsonAddress(feeConfig, ".bootstrap.recipient");
        c.dtf = dtf;
        c.weth = wethToken;
        c.wethInput = vm.parseJsonUint(feeConfig, ".bootstrap.wethInput");
        c.maxDtfInput = vm.parseJsonUint(feeConfig, ".bootstrap.maxDtfInput");
        require(_loadProduct("phase07_stage04_fee_accrual_liquidity_seed.json", "liquidityVault") == liquidityVault, "Bootstrap: seed vault mismatch");
        string memory seed = vm.readFile(_artifactPath("phase07_stage04_fee_accrual_liquidity_seed.json"));
        uint256 seedWeth = vm.parseJsonUint(seed, ".wethInput");
        uint256 seedDtf = vm.parseJsonUint(seed, ".dtfInput");
        require(seedWeth == vm.parseJsonUint(feeConfig, ".bootstrap.liquiditySeedWethInput"), "Bootstrap: seed budget mismatch");
        require(seedWeth < c.wethInput && seedDtf < c.maxDtfInput, "Bootstrap: seed exhausted budget");
        c.wethInput -= seedWeth;
        c.maxDtfInput -= seedDtf;
        c.lockDuration = vm.parseJsonUint(feeConfig, ".bootstrap.lockDuration");
        c.minBondShares = vm.parseJsonUint(feeConfig, ".bootstrap.minBondShares");
        uint256 ttl = vm.parseJsonUint(feeConfig, ".bootstrap.deadlineSeconds");
        require(ttl > 0, "Bootstrap: missing deadline TTL");
        c.deadline = block.timestamp + ttl;
        uint256 snapshotId = vm.snapshotState();
        vm.startPrank(c.actor);
        Bootstrap.execute(IUniswapV4Detf(targetDetf), c);
        vm.stopPrank();
        require(vm.revertToStateAndDelete(snapshotId), "Bootstrap: quote rollback failed");
        _broadcast();
        (uint256 tokenId, uint256 shares) = Bootstrap.execute(IUniswapV4Detf(targetDetf), c);
        vm.stopBroadcast();
        _loadFeeDetf(true);
        string memory obj = "fee-bootstrap";
        vm.serializeBytes32(obj, "configHash", feeConfigHash);
        vm.serializeAddress(obj, "feeDetf", targetDetf);
        vm.serializeUint(obj, "tokenId", tokenId);
        vm.serializeUint(obj, "shares", shares);
        vm.serializeUint(obj, "syntheticPrice", IUniswapV4Detf(targetDetf).syntheticPrice());
        _writeJson(vm.serializeBool(obj, "receiptVerified", false), "phase08_stage04_fee_accrual_bootstrap.json");
    }
}
