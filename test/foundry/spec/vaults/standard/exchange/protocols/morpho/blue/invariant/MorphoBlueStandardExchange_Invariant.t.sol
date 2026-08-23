// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    TestBase_MorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

/**
 * @title MorphoBlueStandardExchangeHandler
 * @notice Fuzz actions on the production SE proxy + hermetic Morpho.
 */
contract MorphoBlueStandardExchangeHandler is Test {
    using MorphoBalancesLib for IMorpho;

    IStandardExchangeIn public seIn;
    IStandardExchangeOut public seOut;
    IERC4626 public se4626;
    IERC20 public loan;
    address public se;
    IMorpho public morpho;
    MarketParams public marketParams;
    address public user;
    address public borrower;
    address public feeTo;
    IERC20 public collateral;

    constructor(
        address se_,
        IMorpho morpho_,
        MarketParams memory marketParams_,
        address user_,
        address borrower_,
        address feeTo_,
        IERC20 loan_,
        IERC20 collateral_
    ) {
        se = se_;
        seIn = IStandardExchangeIn(se_);
        seOut = IStandardExchangeOut(se_);
        se4626 = IERC4626(se_);
        morpho = morpho_;
        marketParams = marketParams_;
        user = user_;
        borrower = borrower_;
        feeTo = feeTo_;
        loan = loan_;
        collateral = collateral_;
    }

    function wrap(uint256 amount) external {
        amount = bound(amount, 1, 100 ether);
        vm.prank(user);
        try seIn.exchangeIn(loan, amount, IERC20(se), 0, user, false, block.timestamp + 1 hours) {} catch {}
    }

    function unwrap(uint256 shares) external {
        uint256 bal = IERC20(se).balanceOf(user);
        if (bal == 0) return;
        shares = bound(shares, 1, bal);
        vm.prank(user);
        try seIn.exchangeIn(IERC20(se), shares, loan, 0, user, false, block.timestamp + 1 hours) {} catch {}
    }

    function deposit4626(uint256 amount) external {
        amount = bound(amount, 1, 50 ether);
        vm.prank(user);
        try se4626.deposit(amount, user) {} catch {}
    }

    function redeem4626(uint256 shares) external {
        uint256 bal = IERC20(se).balanceOf(user);
        if (bal == 0) return;
        shares = bound(shares, 1, bal);
        vm.prank(user);
        try se4626.redeem(shares, user, user) {} catch {}
    }

    function donate(uint256 amount) external {
        amount = bound(amount, 1, 20 ether);
        address donor = address(this);
        dealLoan(donor, amount);
        vm.prank(donor);
        loan.transfer(se, amount);
    }

    function morphoSupplyOnBehalf(uint256 amount) external {
        amount = bound(amount, 1, 20 ether);
        address donor = address(this);
        dealLoan(donor, amount);
        vm.startPrank(donor);
        loan.approve(address(morpho), amount);
        try morpho.supply(marketParams, amount, 0, se, "") {} catch {}
        vm.stopPrank();
    }

    function borrow(uint256 debt) external {
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        if (expected < 2) return;
        debt = bound(debt, 1, expected / 2);
        uint256 coll = debt * 2 + 1 ether;
        dealColl(borrower, coll);
        vm.startPrank(borrower);
        collateral.approve(address(morpho), coll);
        try morpho.supplyCollateral(marketParams, coll, borrower, "") {} catch {
            vm.stopPrank();
            return;
        }
        try morpho.borrow(marketParams, debt, 0, borrower, borrower) {} catch {}
        vm.stopPrank();
    }

    function warpTime(uint256 secs) external {
        secs = bound(secs, 1, 30 days);
        vm.warp(block.timestamp + secs);
    }

    function dealLoan(address to, uint256 amount) internal {
        (bool ok,) = address(loan).call(abi.encodeWithSignature("setBalance(address,uint256)", to, loan.balanceOf(to) + amount));
        if (!ok) {
            deal(address(loan), to, loan.balanceOf(to) + amount);
        }
    }

    function dealColl(address to, uint256 amount) internal {
        (bool ok,) = address(collateral).call(
            abi.encodeWithSignature("setBalance(address,uint256)", to, collateral.balanceOf(to) + amount)
        );
        if (!ok) {
            deal(address(collateral), to, collateral.balanceOf(to) + amount);
        }
    }
}

contract MorphoBlueStandardExchange_Invariant is TestBase_MorphoBlueStandardExchange {
    using MorphoBalancesLib for IMorpho;

    MorphoBlueStandardExchangeHandler internal handler;

    function setUp() public override {
        super.setUp();
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        handler = new MorphoBlueStandardExchangeHandler(
            se, morpho, marketParams, user, BORROWER, feeTo_, IERC20(address(loanToken)), IERC20(address(collateralToken))
        );
        targetContract(address(handler));
        bytes4[] memory sels = new bytes4[](8);
        sels[0] = handler.wrap.selector;
        sels[1] = handler.unwrap.selector;
        sels[2] = handler.deposit4626.selector;
        sels[3] = handler.redeem4626.selector;
        sels[4] = handler.donate.selector;
        sels[5] = handler.morphoSupplyOnBehalf.selector;
        sels[6] = handler.borrow.selector;
        sels[7] = handler.warpTime.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_N1_liveNav_equalsIdlePlusExpectedSupply() public view {
        uint256 idle = loanToken.balanceOf(se);
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        assertEq(se4626.totalAssets(), idle + expected, "N1");
    }

    function invariant_N2_reserveOfToken_isIdleBookNotNav() public view {
        uint256 reserve = IBasicVault(se).reserveOfToken(address(loanToken));
        uint256 idle = loanToken.balanceOf(se);
        assertLe(reserve, idle, "N2 reserve <= idle");
        uint256 nav = se4626.totalAssets();
        if (nav > idle) {
            assertTrue(reserve != nav, "N2 reserve is not NAV");
        }
    }

    function invariant_N3_totalSupply_equalsUserPlusFeeTo() public view {
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 sum = IERC20(se).balanceOf(user) + IERC20(se).balanceOf(attacker) + IERC20(se).balanceOf(feeTo_)
            + IERC20(se).balanceOf(se);
        assertEq(IERC20(se).totalSupply(), sum, "N3");
    }

    /// @dev N4: unbooked loanToken / Morpho donation cannot mint more SE shares than that unbooked amount.
    function invariant_N4_donationDoesNotFreeMintExtractablePrincipal() public view {
        uint256 idle = loanToken.balanceOf(se);
        uint256 reserve = IBasicVault(se).reserveOfToken(address(loanToken));
        uint256 unbooked = idle > reserve ? idle - reserve : 0;
        if (unbooked > 0) {
            assertLe(se4626.convertToShares(unbooked), unbooked, "N4 convertToShares(unbooked) <= unbooked");
        }
        uint256 nav = se4626.totalAssets();
        uint256 supply = IERC20(se).totalSupply();
        if (supply == 0 && nav > 1) {
            assertLt(se4626.convertToShares(nav), nav, "N4 empty vault donation is not 1:1 shares");
        }
    }

    /// @notice N4 on the production proxy: donate then wrap; donation does not mint extra SE.
    function test_N4_donationDoesNotMintShares() public {
        uint256 supplyBefore = IERC20(se).totalSupply();
        loanToken.setBalance(attacker, 10 ether);
        vm.prank(attacker);
        loanToken.transfer(se, 10 ether);
        assertEq(IERC20(se).totalSupply(), supplyBefore, "N4 donate does not mint");

        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), 5 ether, IERC20(se));
        uint256 shares = _wrapExactIn(user, 5 ether);
        assertEq(shares, preview, "N4 wrap vs live NAV including donation");
        assertLt(shares, 5 ether + 10 ether, "N4 wrap does not mint donation as extra shares");
    }

    function invariant_N5_noThirdPartyMorphoAuthorization() public view {
        assertFalse(morpho.isAuthorized(se, user), "N5 user");
        assertFalse(morpho.isAuthorized(se, attacker), "N5 attacker");
        assertFalse(morpho.isAuthorized(se, BORROWER), "N5 borrower");
    }

    function invariant_N6_vaultPositionOnBehalfIsSelf() public view {
        assertEq(morpho.position(marketId, user).supplyShares, 0, "N6 user Morpho supply");
        assertEq(morpho.position(marketId, attacker).supplyShares, 0, "N6 attacker Morpho supply");
        uint256 vaultShares = morpho.position(marketId, se).supplyShares;
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        if (vaultShares == 0) {
            assertEq(expected, 0, "N6 no vault shares => no expected supply");
        }
    }
}
