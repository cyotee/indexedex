// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeAccountingHandler} from "test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
contract Handler_ERC4626StandardExchange is StandardExchangeAccountingHandler {
    
    constructor(IStandardExchangeIn se_, IStandardExchangeOut, SimpleMintableERC20 base_, address a0_, address a1_, address attacker_) StandardExchangeAccountingHandler(se_, IERC20(address(base_)), IERC20(address(se_)), true, a0_, a1_, attacker_) {  }
    function _fund(address actor_, uint256 amount_) internal override { SimpleMintableERC20(address(base)).mint(actor_, amount_); }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract ERC4626StandardExchange_Invariant is TestBase_ERC4626StandardExchange {
    Handler_ERC4626StandardExchange internal handler;
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0);
        vm.stopPrank();
        address a0 = makeAddr("erc4626Inv0");
        address a1 = makeAddr("erc4626Inv1");
        address att = makeAddr("erc4626Attacker");
        handler = new Handler_ERC4626StandardExchange(
            IStandardExchangeIn(se), IStandardExchangeOut(se), underlying, a0, a1, att
        );
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        uint256 backing = protocolVault.convertToAssets(protocolVault.balanceOf(se)) + underlying.balanceOf(se);
        uint256 supply = IERC20(se).totalSupply();
        uint256 claim = supply == 0 ? 0 : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), supply, IERC20(address(underlying)));
        assertLe(claim, backing, "all shares backed by local assets and protocol receipts");
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
