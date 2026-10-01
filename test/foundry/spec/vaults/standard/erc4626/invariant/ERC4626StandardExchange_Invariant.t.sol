// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    LendingAccountingHandler,
    LendingAccountingToken,
    ILendingAccountingHost
} from "test/foundry/spec/vaults/standard/exchange/invariant/LendingAccountingHandler.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

contract Handler_ERC4626StandardExchange is LendingAccountingHandler {
    constructor(address se_, address base_, ILendingAccountingHost host_, address a0_, address a1_, address attacker_)
        LendingAccountingHandler(se_, base_, host_, a0_, a1_, attacker_)
    {}
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract ERC4626StandardExchange_Invariant is TestBase_ERC4626StandardExchange, ILendingAccountingHost {
    Handler_ERC4626StandardExchange internal handler;
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = SimpleMintableERC20(address(new LendingAccountingToken()));
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
            se, address(underlying), ILendingAccountingHost(address(this)), a0, a1, att
        );
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function fundBase(address to_, uint256 amount_) external {
        underlying.mint(to_, amount_);
    }

    function custodyCash() public view returns (uint256) {
        return
            underlying.balanceOf(se) + underlying.balanceOf(address(protocolVault))
                + underlying.balanceOf(address(this));
    }

    function accountingState() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                IBasicVault(se).reserveOfToken(address(underlying)),
                protocolVault.balanceOf(se),
                protocolVault.totalAssets(),
                protocolVault.totalSupply(),
                underlying.allowance(se, address(protocolVault)),
                custodyCash()
            )
        );
    }

    function accrueYield(uint256 amount_) external returns (uint256) {
        uint256 before_ = protocolVault.convertToAssets(protocolVault.balanceOf(se));
        underlying.mint(address(this), amount_);
        underlying.approve(address(protocolVault), amount_);
        protocolVault.simulateYield(amount_);
        assertGt(
            protocolVault.convertToAssets(protocolVault.balanceOf(se)),
            before_,
            "real protocol yield increases SE receipt claim"
        );
        return amount_;
    }

    function setFee(uint256 fee_) external {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(fee_);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, fee_);
        vm.stopPrank();
    }

    function feeTo() external view returns (address) {
        return address(feeCollector);
    }

    function collectFee(address to_, uint256 amount_) external {
        vm.prank(owner);
        IFeeCollectorManager(address(feeCollector)).pullFee(IERC20(se), amount_, to_);
        IFeeCollectorManager(address(feeCollector)).syncReserve(IERC20(se));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        handler.assertLendingAccounting();
        uint256 backing = protocolVault.convertToAssets(protocolVault.balanceOf(se)) + underlying.balanceOf(se);
        uint256 supply = IERC20(se).totalSupply();
        uint256 claim = supply == 0
            ? 0
            : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), supply, IERC20(address(underlying)));
        assertLe(claim, backing, "all shares backed by local assets and protocol receipts");
    }

    function afterInvariant() public view {
        assertGe(handler.cycles(), 4, "randomized campaign reaches funded actions");
        for (uint256 i; i < 3; ++i) {
            assertGt(handler.actorCycles(handler.actors(i)), 0, "each honest actor participated");
        }
        invariant_APEX_accounting();
    }

    function test_APEX_deterministicLifecycle() public {
        for (uint256 i; i < 4; ++i) {
            handler.cycle(1 ether + i, 1e14 + i);
        }
        assertEq(handler.ghost_out(), 4, "four nonzero exits");
        afterInvariant();
    }

    /// @dev Exact19-call sequence retained from the original R11 campaign failure.
    function test_APEX_sweepQuoteRegressionSequence() public {
        handler.cycle(3, 2689760466567724952050780);
        handler.cycle(9283, 85000);
        handler.cycle(17786000705887224, 2251950992378);
        handler.cycle(7500, 1000000000);
        handler.cycle(
            1165348800165884646583272833570758497999479995094779,
            23762952222059118103674288070318533863969822909982850837281
        );
        handler.cycle(7200, 1000000000000);
        handler.cycle(53951929, 140648644897767126213674513004449886085657150899840);
        handler.cycle(18487938676292617984406060787333308297862084921603553104606700240717010906, 3);
        handler.cycle(1090671, 262374);
        handler.cycle(8, 1000000000000);
        handler.cycle(30083186092847802128466689385442702949769386, 3464588557125847478747412525570365494195631);
        handler.cycle(24146, 12);
        handler.cycle(9629, 7293);
        handler.cycle(3, 1588925160);
        handler.cycle(5498, 659918);
        handler.cycle(249568577306390681288121996924496510797997928484539482977799154290972926850, 125023701002427631);
        handler.cycle(
            246462717853273786611537, 115792089237316195423570985008687907853269984665640564039457584007913129639932
        );
        handler.cycle(6946, 1000000000);
        handler.cycle(20, 39);
        assertEq(handler.cycles(), 19, "entire original failure sequence completed");
        afterInvariant();
    }
}
