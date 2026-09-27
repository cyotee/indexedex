// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeAccountingHandler} from "test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol";
import {Test} from "forge-std/Test.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {ERC20TestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/ERC20TestToken.sol";
import {
    TestBase_BalancerV3_8020WeightedPool
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3_8020WeightedPool.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

contract Handler_BalancerV3SinglePoolSE is StandardExchangeAccountingHandler {
    
    constructor(IStandardExchangeIn se_, ERC20TestToken base_, IERC20 share_, address a0_, address a1_, address attacker_) StandardExchangeAccountingHandler(se_, IERC20(address(base_)), share_, true, a0_, a1_, attacker_) {  }
    function _fund(address actor_, uint256 amount_) internal override { ERC20TestToken(address(base)).mint(actor_, amount_); }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract BalancerV3SinglePoolStandardExchange_Invariant is TestBase_BalancerV3_8020WeightedPool {
    Handler_BalancerV3SinglePoolSE internal handler;
    IStandardExchange internal adapter;
    IERC20 internal bpt;

    function setUp() public virtual override {
        TestBase_BalancerV3_8020WeightedPool.setUp();
        if (address(create3Factory) == address(0)) {
            (create3Factory, diamondPackageFactory) = InitDevService.initEnv(address(this));
            diamondFactory = diamondPackageFactory;
        }
        initDaiUsdc8020WeightedPool();
        IERC20[] memory poolTokens_ = new IERC20[](2);
        poolTokens_[0] = IERC20(daiUsdc8020WeightedPoolTokens[0]);
        poolTokens_[1] = IERC20(daiUsdc8020WeightedPoolTokens[1]);
        adapter = IStandardExchange(
            create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(
                    create3Factory,
                    "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:BalancerV3SinglePoolStandardExchange"
                ),
                abi.encode(
                    IRouter(address(router)),
                    address(daiUsdc8020WeightedPool),
                    IERC20(address(daiUsdc8020WeightedPool)),
                    poolTokens_
                ),
                keccak256("BalancerV3SinglePoolStandardExchangeInv")
            )
        );
        bpt = IERC20(address(daiUsdc8020WeightedPool));
        address a0 = makeAddr("spInv0");
        address a1 = makeAddr("spInv1");
        address att = makeAddr("spInvAttacker");
        handler = new Handler_BalancerV3SinglePoolSE(
            IStandardExchangeIn(address(adapter)), dai, bpt, a0, a1, att
        );
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        assertEq(bpt.balanceOf(address(adapter)), 0, "adapter retains no caller BPT");
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
