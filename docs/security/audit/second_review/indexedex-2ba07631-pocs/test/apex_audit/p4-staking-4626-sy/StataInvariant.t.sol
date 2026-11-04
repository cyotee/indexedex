// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    TestBase_AaveV3StataStandardExchange_Decimals,
    AaveV3StataDecimalsListing
} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";
import {
    MockAggregator
} from "@crane/contracts/protocols/lending/aave/v3.6/utils/mocks/oracle/CLAggregators/MockAggregator.sol";
import {StataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/StataTokenV2.sol";
import {LendingAccountingToken} from "test/foundry/spec/vaults/standard/exchange/invariant/LendingAccountingHandler.sol";
import {P4Handler, P4Invariants, IP4Host} from "./P4Common.sol";

/// @notice Aave V3 Stata SE on the real Crane Aave v3.6 deployment (ReceiptBacked IERC4626 + SE + SY).
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
/// forge-config: audit.invariant.fail-on-revert = false
contract P4_Stata_Invariant is TestBase_AaveV3StataStandardExchange_Decimals, P4Invariants, IP4Host {
    P4Handler internal handler;
    address internal constant YIELD_BORROWER = address(0xB0220);
    address internal constant DEAD = address(0xdEaD);

    function _underlyingDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _h() internal view override returns (P4Handler) {
        return handler;
    }

    function setUp() public override {
        super.setUp();
        // Mintable listed asset (additive funding; deal() would overwrite balances).
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
        _setTestUsageFee(0);
        // yield borrower collateral (WETH) for exogenous interest accrual
        deal(tokenList.weth, YIELD_BORROWER, 10 ether);
        vm.startPrank(YIELD_BORROWER);
        IERC20(tokenList.weth).approve(address(contracts.poolProxy), 10 ether);
        contracts.poolProxy.supply(tokenList.weth, 10 ether, YIELD_BORROWER, 0);
        vm.stopPrank();
        // QUARANTINE receiptbacked-first-deposit-inflation: permanent dead holder, supply never 0.
        _mintU(address(this), 1 ether);
        IERC20(realBase).approve(realVault, type(uint256).max);
        (bool ok,) = realVault.call(
            abi.encodeWithSignature(
                "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
                realBase, 1 ether, realVault, 1, DEAD, false, block.timestamp
            )
        );
        require(ok, "dead seed");
        handler = new P4Handler(IP4Host(address(this)));
        handler.mintExactIn(0, 1, 100 ether); // actor 0, underlying
        handler.mintExactIn(4, 0, 50 ether); // actor 0, stata
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: _selectors()}));
    }

    function _mintU(address to, uint256 amt) internal {
        LendingAccountingToken(realBase).mint(to, amt);
    }

    // ---------------------------------------------------------------- host
    function se() external view returns (address) { return realVault; }

    function tokens() public view returns (address[] memory t) {
        t = new address[](3);
        t[0] = realStata;
        t[1] = realBase;
        t[2] = aToken;
    }

    function fund(address token, address to, uint256 amount) external {
        if (token == realBase) {
            _mintU(to, amount);
        } else if (token == realStata) {
            uint256 a = stataTokenV2.previewMint(amount) + 2;
            _mintU(address(this), a);
            IERC20(realBase).approve(realStata, a);
            stataTokenV2.mint(amount, to);
        } else {
            _mintU(address(this), amount + 1);
            IERC20(realBase).approve(address(contracts.poolProxy), amount + 1);
            contracts.poolProxy.supply(realBase, amount + 1, address(this), 0);
            IERC20(aToken).transfer(to, amount);
        }
    }

    function fairValue(address token, uint256 amount) public view returns (uint256) {
        if (token == realStata) return stataTokenV2.convertToAssets(amount);
        return amount; // underlying, aToken (1:1 rebasing)
    }

    function _bookedMin(address tok) internal view returns (uint256) {
        uint256 booked = IBasicVault(realVault).reserveOfToken(tok);
        uint256 bal = IERC20(tok).balanceOf(realVault);
        return booked < bal ? booked : bal;
    }

    function fairNav() public view returns (uint256) {
        return stataTokenV2.convertToAssets(IERC20(realStata).balanceOf(realVault)) + _bookedMin(realBase)
            + _bookedMin(aToken);
    }

    function reportedNav() public view returns (uint256) {
        return stataTokenV2.convertToAssets(IERC4626(realVault).totalAssets());
    }

    function virtShares() external pure returns (uint256) { return 0; }
    function navPlus() external pure returns (uint256) { return 0; }

    function outCap(address token) external view returns (uint256) {
        if (token == realBase) return fairNav();
        return IERC20(realStata).balanceOf(realVault); // stata / aToken paid from held stata
    }

    function bare() external pure returns (address) { return address(0); }
    function hasQueue() external pure returns (bool) { return false; }
    function portPending() external pure returns (uint256, uint256) { return (0, 0); }
    function finalizeAll() external {}
    function hasRebalance() external pure returns (bool) { return false; }
    function supportsSwap() external pure returns (bool) { return true; }
    function has4626Mutators() external pure returns (bool) { return true; }

    /// exogenous lending interest: borrow, warp, repay with freshly minted interest
    function moveRate(uint256 seed) external returns (bool) {
        uint256 avail = IERC20(realBase).balanceOf(aToken);
        uint256 amt = avail / 4;
        if (amt < 1e12) return false;
        vm.prank(YIELD_BORROWER);
        try contracts.poolProxy.borrow(realBase, amt, 2, 0, YIELD_BORROWER) {} catch { return false; }
        vm.warp(block.timestamp + bound(seed, 1 hours, 30 days));
        address vdt = contracts.poolProxy.getReserveVariableDebtToken(realBase);
        uint256 debt = IERC20(vdt).balanceOf(YIELD_BORROWER);
        uint256 held = IERC20(realBase).balanceOf(YIELD_BORROWER);
        if (debt > held) _mintU(YIELD_BORROWER, debt - held);
        vm.startPrank(YIELD_BORROWER);
        IERC20(realBase).approve(address(contracts.poolProxy), type(uint256).max);
        contracts.poolProxy.repay(realBase, type(uint256).max, 2, YIELD_BORROWER);
        vm.stopPrank();
        return true;
    }

    // ---------------------------------------------------------------- family invariants
    function invariant_navConsistency() public view {
        assertApproxEqAbs(reportedNav(), fairNav(), 1e9, "IERC4626.totalAssets == held stata + booked local");
    }

    function invariant_convertToAssetsConsistency() public view {
        uint256 s = IERC20(realVault).totalSupply();
        if (s == 0) return;
        uint256 probe = s / 7 + 1;
        uint256 c = IERC4626(realVault).convertToAssets(probe);
        uint256 fair = probe * IERC4626(realVault).totalAssets() / s;
        assertApproxEqAbs(c, fair, 2, "convertToAssets == shares * backing / supply");
        assertLe(IERC4626(realVault).previewRedeem(probe), c + 1, "previewRedeem <= convertToAssets");
    }

    /// replay of the shrunk counterexample from the 2026-10-21 run (syDeposit "free shares", 12 shares on a 2e20 deposit)
    function test_replay_syDepositFreeShares() public {
        handler.advRateMove(17337);
        handler.advDonate(223988126479, 2164515238630, false);
        handler.redeemToLiquid(10000, 15);
        handler.erc4626Redeem(100, 8600, false);
        console2.log("pre syDeposit: stata rate (assets per 1e18)", stataTokenV2.convertToAssets(1e18));
        console2.log("  previewDeposit(stata,1e15)", IStdExSY(realVault).previewDeposit(realStata, 1e15));
        console2.log("  previewDeposit(base,convertToAssets(1e15))", IStdExSY(realVault).previewDeposit(realBase, stataTokenV2.convertToAssets(1e15)));
        console2.log("  reported / fair nav", reportedNav(), fairNav());
        console2.log("  supply", IERC20(realVault).totalSupply());
        console2.log("  booked base / bal base", IBasicVault(realVault).reserveOfToken(realBase), IERC20(realBase).balanceOf(realVault));
        console2.log("  booked stata / bal stata", IBasicVault(realVault).reserveOfToken(realStata), IERC20(realStata).balanceOf(realVault));
        console2.log("  totalAssets", IERC4626(realVault).totalAssets());
        handler.syDeposit(4372, 60000, 19);
        handler.report();
        // 12-share excess on a 50x-NAV deposit is oracle rounding amplification, now inside _sharesForMax
        assertEq(handler.violations(), 0, "rounding-aware bound absorbs the wei-level amplification");
    }

    function afterInvariant() public {
        handler.report();
        handler.persist("p4_counts_stata.log");
        (uint256 ok, uint256 fail) = handler.totals();
        assertGt(ok, 0, "non-vacuous");
        assertGe(ok * 100, (ok + fail) * 60, "non-vacuous: >=60% of attempted money calls succeed");
    }
}

interface IStdExSY {
    function previewDeposit(address tokenIn, uint256 amount) external view returns (uint256);
}
