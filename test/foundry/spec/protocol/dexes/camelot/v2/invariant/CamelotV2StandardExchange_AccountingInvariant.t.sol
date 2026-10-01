// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {
    AccountingPoolToken,
    IAccountingPair,
    ConstantProductAccountingHandler
} from "test/foundry/spec/vaults/standard/exchange/invariant/ConstantProductAccountingHandler.sol";

contract Handler_CamelotV2APEX is ConstantProductAccountingHandler {
    constructor(address vault_, address pair_) ConstantProductAccountingHandler(vault_, pair_, 1) {}
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract CamelotV2StandardExchange_AccountingInvariant is TestBase_CamelotV2StandardExchange {
    ConstantProductAccountingHandler internal handler;

    function setUp() public override {
        super.setUp();
        AccountingPoolToken a = new AccountingPoolToken("CallbackA");
        AccountingPoolToken b = new AccountingPoolToken("CallbackB");
        address pair = camelotV2Factory.createPair(address(a), address(b));
        a.mint(pair, 1_000_000 ether);
        b.mint(pair, 1_000_000 ether);
        IAccountingPair(pair).mint(address(this));
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        address vault = camelotV2StandardExchangeDFPkg.deployVault(ICamelotPair(pair));
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(vault, 0);
        vm.stopPrank();
        handler = new Handler_CamelotV2APEX(vault, pair);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        handler.assertPoolAccounting();
    }

    function afterInvariant() public view {
        assertGe(handler.cycles(), 4, "randomized positive money flow required");
        for (uint256 i; i < 3; ++i) {
            assertGt(handler.actorCycles(handler.actors(i)), 0, "three actual funded actors");
        }
        invariant_APEX_accounting();
    }

    function test_APEX_deterministicLifecycle() public {
        for (uint256 i; i < 4; ++i) {
            handler.cycle(1 ether + i, i);
        }
        afterInvariant();
    }
}
