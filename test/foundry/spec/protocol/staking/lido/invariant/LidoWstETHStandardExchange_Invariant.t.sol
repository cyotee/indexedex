// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {HostileWETH} from "contracts/protocols/staking/lido/test/hermetic/HostileWETH.sol";
import {StakingStandardExchangeAccountingHandler, IStakingAccountingHost} from "test/foundry/spec/vaults/standard/exchange/invariant/StakingStandardExchangeAccountingHandler.sol";
import {ILidoWstETHStandardVault} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract LidoWstETHStandardExchange_Invariant_Test is TestBase_LidoWstETHStandardExchange, IStakingAccountingHost {
    LidoWstETHAccountingHandler internal handler;
    uint256 internal settledThrough;

    function setUp() public override {
        super.setUp();
        // Replace only the external WETH dependency, then deploy a fresh production vault
        // through its registry package. The proxy/facets/guard are the real SUT.
        hermeticWeth = new HostileWETH();
        seVault = _deployLidoSe();
        lidoSe = ILidoWstETHStandardVault(seVault);
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        vm.stopPrank();
        handler = new LidoWstETHAccountingHandler(seVault, IERC20(address(hermeticWstEth)), address(hermeticWeth), IStakingAccountingHost(address(this)));
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function fundReceipt(address to_, uint256 amount_) external { _mintWstViaSt(to_, amount_); }
    function settleRequests() external {
        uint256 last = hermeticQueue.lastRequestId();
        for (uint256 id = settledThrough + 1; id <= last; ++id) {
            (, uint256 amount,,) = hermeticQueue.requests(id);
            vm.deal(address(this), amount);
            hermeticQueue.finalizeForTest{value: amount}(id);
        }
        settledThrough = last;
    }

    function accountingState() external view returns (bytes32) {
        uint256[9] memory values;
        values[0] = IBasicVault(seVault).reserveOfToken(address(hermeticWeth));
        values[1] = IBasicVault(seVault).reserveOfToken(address(hermeticWstEth));
        values[2] = lidoSe.totalReserveEth();
        values[3] = lidoSe.lockedReserveEth();
        values[4] = hermeticWstEth.balanceOf(seVault);
        values[5] = hermeticWeth.allowance(seVault, address(handler));
        values[6] = hermeticStEth.balanceOf(seVault); values[7] = hermeticStEth.allowance(seVault, address(hermeticWstEth)); values[8] = hermeticQueue.lastRequestId();
        return keccak256(abi.encode(values));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        handler.assertStakingAccounting();
        assertEq(lidoSe.liquidReserveEth(), hermeticWeth.balanceOf(seVault), "native liquid custody");
        assertEq(lidoSe.totalReserveEth(), lidoSe.liquidReserveEth() + lidoSe.lockedReserveEth(), "receipt plus liquid plus pending backing");
        if (IERC20(seVault).totalSupply() > 0) assertGt(lidoSe.totalReserveEth(), 0, "issued shares have backing");
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

contract LidoWstETHAccountingHandler is StakingStandardExchangeAccountingHandler {
    constructor(address se_, IERC20 receipt_, address weth_, IStakingAccountingHost host_)
        StakingStandardExchangeAccountingHandler(se_, receipt_, weth_, host_) {}
}
