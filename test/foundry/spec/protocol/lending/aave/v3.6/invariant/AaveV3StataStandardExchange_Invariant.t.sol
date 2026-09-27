// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    LendingAccountingHandler,
    LendingAccountingToken,
    ILendingAccountingHost
} from "test/foundry/spec/vaults/standard/exchange/invariant/LendingAccountingHandler.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";
import {AaveV3StataDecimalsListing} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";
import {
    MockAggregator
} from "@crane/contracts/protocols/lending/aave/v3.6/utils/mocks/oracle/CLAggregators/MockAggregator.sol";
import {StataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/StataTokenV2.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    AaveV3StataStandardExchange_Real_Decimals
} from "test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_Real_Decimals.sol";

contract Handler_AaveV3StataStandardExchange is LendingAccountingHandler {
    constructor(address se_, address base_, ILendingAccountingHost host_, address a0_, address a1_, address attacker_)
        LendingAccountingHandler(se_, base_, host_, a0_, a1_, attacker_)
    {}
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract AaveV3StataStandardExchange_Invariant is AaveV3StataStandardExchange_Real_Decimals, ILendingAccountingHost {
    Handler_AaveV3StataStandardExchange internal handler;
    address internal constant YIELD_BORROWER = address(0xB0220);

    function _underlyingDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function fundBase(address to, uint256 amt) external {
        LendingAccountingToken(realBase).mint(to, amt);
    }

    function setUp() public override {
        super.setUp();
        address asset = address(new LendingAccountingToken());
        AaveV3StataDecimalsListing listing =
            new AaveV3StataDecimalsListing(asset, address(new MockAggregator(int256(1e8))), report.configEngine);
        vm.prank(roleList.marketOwner);
        contracts.aclManager.addPoolAdmin(address(listing));
        listing.execute();
        address[] memory assets = new address[](1);
        assets[0] = asset;
        factory.createStataTokens(assets);
        underlying = asset;
        realBase = asset;
        aToken = contracts.poolProxy.getReserveAToken(asset);
        stataTokenV2 = StataTokenV2(factory.getStataToken(asset));
        realStata = address(stataTokenV2);
        realVault = _deployStataVault(realStata);
        deal(tokenList.weth, YIELD_BORROWER, 1 ether);
        vm.startPrank(YIELD_BORROWER);
        IERC20(tokenList.weth).approve(address(contracts.poolProxy), 1 ether);
        contracts.poolProxy.supply(tokenList.weth, 1 ether, YIELD_BORROWER, 0);
        vm.stopPrank();
        _setTestUsageFee(0);
        address a0 = makeAddr("stataInv0");
        address a1 = makeAddr("stataInv1");
        address att = makeAddr("stataInvAttacker");
        handler = new Handler_AaveV3StataStandardExchange(
            realVault, realBase, ILendingAccountingHost(address(this)), a0, a1, att
        );
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function custodyCash() external view returns (uint256) {
        return IERC20(realBase).balanceOf(realVault) + IERC20(realBase).balanceOf(aToken)
            + IERC20(realBase).balanceOf(realStata) + IERC20(realBase).balanceOf(address(this))
            + IERC20(realBase).balanceOf(YIELD_BORROWER);
    }

    function accountingState() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                IBasicVault(realVault).reserveOfToken(realBase),
                IERC20(realStata).balanceOf(realVault),
                stataTokenV2.totalAssets(),
                IERC20(aToken).balanceOf(realStata),
                IERC20(realBase).allowance(realVault, realStata),
                contracts.poolProxy.getReserveNormalizedIncome(realBase),
                IERC20(contracts.poolProxy.getReserveVariableDebtToken(realBase)).balanceOf(YIELD_BORROWER)
            )
        );
    }

    function accrueYield(uint256) external returns (uint256 created_) {
        uint256 before_ = stataTokenV2.convertToAssets(IERC20(realStata).balanceOf(realVault));
        vm.prank(YIELD_BORROWER);
        contracts.poolProxy.borrow(realBase, 1e12, 2, 0, YIELD_BORROWER);
        vm.warp(block.timestamp + 1 hours);
        uint256 debt = IERC20(contracts.poolProxy.getReserveVariableDebtToken(realBase)).balanceOf(YIELD_BORROWER);
        uint256 held = IERC20(realBase).balanceOf(YIELD_BORROWER);
        created_ = debt > held ? debt - held : 0;
        LendingAccountingToken(realBase).mint(YIELD_BORROWER, created_);
        vm.startPrank(YIELD_BORROWER);
        IERC20(realBase).approve(address(contracts.poolProxy), debt);
        uint256 repaid = contracts.poolProxy.repay(realBase, type(uint256).max, 2, YIELD_BORROWER);
        vm.stopPrank();
        assertEq(repaid, debt, "full real variable debt repaid");
        assertEq(
            IERC20(contracts.poolProxy.getReserveVariableDebtToken(realBase)).balanceOf(YIELD_BORROWER),
            0,
            "yield borrower debt closed"
        );
        assertGt(
            stataTokenV2.convertToAssets(IERC20(realStata).balanceOf(realVault)),
            before_,
            "actual lending interest reaches Stata receipt claim"
        );
    }

    function setFee(uint256 fee_) external {
        _setTestUsageFee(fee_);
    }

    function feeTo() external view returns (address) {
        return address(feeCollector);
    }

    function collectFee(address to_, uint256 amount_) external {
        vm.prank(owner);
        IFeeCollectorManager(address(feeCollector)).pullFee(IERC20(realVault), amount_, to_);
        IFeeCollectorManager(address(feeCollector)).syncReserve(IERC20(realVault));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        handler.assertLendingAccounting();
        uint256 backing = stataTokenV2.convertToAssets(IERC20(realStata).balanceOf(realVault))
            + IERC20(realBase).balanceOf(realVault);
        uint256 supply = IERC20(realVault).totalSupply();
        uint256 claim = supply == 0
            ? 0
            : IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realVault), supply, IERC20(realBase));
        assertLe(claim, backing, "all Stata shares backed by protocol receipts and local principal");
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
}
