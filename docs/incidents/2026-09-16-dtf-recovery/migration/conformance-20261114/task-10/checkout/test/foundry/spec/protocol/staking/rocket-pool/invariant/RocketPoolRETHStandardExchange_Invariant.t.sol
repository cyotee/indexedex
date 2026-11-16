// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_RocketPoolRETHStandardExchange} from "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {HostileWETH} from "contracts/protocols/staking/rocket-pool/test/hermetic/HostileWETH.sol";
import {StakingStandardExchangeAccountingHandler, IStakingAccountingHost} from "test/foundry/spec/vaults/standard/exchange/invariant/StakingStandardExchangeAccountingHandler.sol";
import {IRocketPoolRETHStandardVault} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract RocketPoolRETHStandardExchange_Invariant_Test is TestBase_RocketPoolRETHStandardExchange, IStakingAccountingHost {
    RocketPoolRETHAccountingHandler internal handler;
    uint256 internal settledThrough;

    function setUp() public override {
        super.setUp();
        // Replace only the external WETH dependency, then deploy a fresh production vault
        // through its registry package. The proxy/facets/guard are the real SUT.
        hermeticWeth = new HostileWETH();
        seVault = _deployRocketPoolSe();
        rocketPoolSe = IRocketPoolRETHStandardVault(seVault);
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        vm.stopPrank();
        handler = new RocketPoolRETHAccountingHandler(seVault, IERC20(address(hermeticReth)), address(hermeticWeth), IStakingAccountingHost(address(this)));
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function fundReceipt(address to_, uint256 amount_) external {
        _mintReth(to_, amount_);
        // Receipt funding includes the external protocol collateral required by honest burns.
        _enableBurn(hermeticReth.getEthValue(amount_));
    }
    function settleRequests() external {
        // Rocket pool uses immediate burn/stake rather than asynchronous requests.
    }

    function accountingState() external view returns (bytes32) {
        uint256[9] memory values;
        values[0] = IBasicVault(seVault).reserveOfToken(address(hermeticWeth));
        values[1] = IBasicVault(seVault).reserveOfToken(address(hermeticReth));
        values[2] = rocketPoolSe.totalReserveEth();
        values[3] = rocketPoolSe.lockedReserveEth();
        values[4] = hermeticReth.balanceOf(seVault);
        values[5] = hermeticWeth.allowance(seVault, address(handler));
        values[6] = hermeticReth.collateralEth(); values[7] = hermeticPool.getMaximumDepositAmount(); values[8] = address(hermeticPool).balance;
        return keccak256(abi.encode(values));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        handler.assertStakingAccounting();
        assertEq(rocketPoolSe.liquidReserveEth(), hermeticWeth.balanceOf(seVault), "native liquid custody");
        assertEq(rocketPoolSe.totalReserveEth(), rocketPoolSe.liquidReserveEth() + rocketPoolSe.lockedReserveEth(), "receipt plus liquid plus pending backing");
        if (IERC20(seVault).totalSupply() > 0) assertGt(rocketPoolSe.totalReserveEth(), 0, "issued shares have backing");
    }
    function afterInvariant() public view {
        assertGe(handler.cycles(), 4, "randomized money actions required");
        for (uint256 i; i < 3; ++i) assertGt(handler.actorCycles(handler.actors(i)), 0, "three funded actors");
        invariant_APEX_accounting();
    }
    function test_APEX_deterministicLifecycle() public {
        for (uint256 i; i < 4; ++i) handler.cycle(1 ether + i, i);
        afterInvariant();
    }
    function test_APEX_receiptSameStatePullPretransferExactIn() public {
        handler.seedParity();
        handler.assertPretransferParity(false, false, false);
    }
    function test_APEX_receiptSameStatePullPretransferExactOut() public {
        handler.seedParity();
        handler.assertPretransferParity(false, true, false);
    }
    function test_APEX_receiptSameStatePullPretransferExactOutRefund() public {
        handler.seedParity();
        handler.assertPretransferParity(false, true, true);
    }
    function test_APEX_wethSameStatePullPretransferExactIn() public {
        handler.seedParity();
        handler.assertPretransferParity(true, false, false);
    }
    function test_APEX_wethSameStatePullPretransferExactOut() public {
        handler.seedParity();
        handler.assertPretransferParity(true, true, false);
    }
    function test_APEX_wethSameStatePullPretransferExactOutRefund() public {
        handler.seedParity();
        handler.assertPretransferParity(true, true, true);
    }
}

contract RocketPoolRETHAccountingHandler is StakingStandardExchangeAccountingHandler {
    constructor(address se_, IERC20 receipt_, address weth_, IStakingAccountingHost host_)
        StakingStandardExchangeAccountingHandler(se_, receipt_, weth_, host_) {}
}
