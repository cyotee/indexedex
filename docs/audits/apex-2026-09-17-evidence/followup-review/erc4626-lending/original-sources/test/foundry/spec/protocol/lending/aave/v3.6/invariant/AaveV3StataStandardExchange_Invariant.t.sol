// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeAccountingHandler} from "test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AaveV3StataStandardExchange_Real_Decimals} from
    "test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_Real_Decimals.sol";

interface IStataInvHost {
    function mintBaseTo(address to, uint256 amt) external;
}

contract Handler_AaveV3StataStandardExchange is StandardExchangeAccountingHandler {
    IStataInvHost public immutable host;
    constructor(IStandardExchangeIn se_, IERC20 base_, IStataInvHost host_, address a0_, address a1_, address attacker_) StandardExchangeAccountingHandler(se_, base_, IERC20(address(se_)), true, a0_, a1_, attacker_) { host = host_; }
    function _fund(address actor_, uint256 amount_) internal override { host.mintBaseTo(actor_, amount_); }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract AaveV3StataStandardExchange_Invariant is AaveV3StataStandardExchange_Real_Decimals, IStataInvHost {
    Handler_AaveV3StataStandardExchange internal handler;

    function _underlyingDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function mintBaseTo(address to, uint256 amt) external {
        _fundUnderlying(amt, to);
    }

    function setUp() public override {
        super.setUp();
        _setTestUsageFee(0);
        address a0 = makeAddr("stataInv0");
        address a1 = makeAddr("stataInv1");
        address att = makeAddr("stataInvAttacker");
        handler = new Handler_AaveV3StataStandardExchange(
            IStandardExchangeIn(realVault), IERC20(realBase), IStataInvHost(address(this)), a0, a1, att
        );
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        uint256 backing = stataTokenV2.convertToAssets(IERC20(realStata).balanceOf(realVault)) + IERC20(realBase).balanceOf(realVault);
        uint256 supply = IERC20(realVault).totalSupply();
        uint256 claim = supply == 0 ? 0 : IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realVault), supply, IERC20(realBase));
        assertLe(claim, backing, "all Stata shares backed by protocol receipts and local principal");
    }

    function afterInvariant() public view {
        assertGe(handler.cycles(), 4, "randomized campaign reaches funded actions");
        for (uint256 i; i < 3; ++i) assertGt(handler.actorCycles(handler.actors(i)), 0, "each honest actor participated");
        invariant_APEX_accounting();
    }

    function test_APEX_deterministicLifecycle() public {
        for (uint256 i; i < 4; ++i) handler.cycle(1 ether + i, 1e14 + i);
        assertEq(handler.ghost_out(), 4, "four nonzero exits");
        afterInvariant();
    }
}
