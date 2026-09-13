// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBlueService} from
    "@crane/contracts/protocols/lending/morpho/blue/services/MorphoBlueService.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {MorphoBlueStandardExchangeCommon} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol";
import {TestBase_MorphoBlueStandardExchange_Decimals} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_Decimals.sol";

/// @notice A0/A1/I1–I3/E1/E6/C/CROPS (L2 and J N/A). Combo ID is the concrete suite name.
abstract contract Adversarial_MorphoBlueStandardExchange_P0_Decimals is
    TestBase_MorphoBlueStandardExchange_Decimals
{
    function test_A0_donateBeforeFirstMint_noFreeShares() public {
        uint256 donation = _u(5);
        _mintLoan(attacker, donation);
        vm.prank(attacker);
        loanToken.transfer(se, donation);
        uint256 depositAmt = _u(100);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), depositAmt, IERC20(se));
        assertLt(preview, depositAmt, "A0 shares < 1:1 against donated NAV");
        assertGt(preview, 0, "A0 non-zero mint");
        uint256 shares = _wrapExactIn(user, depositAmt);
        assertEq(shares, preview, "A0 mint vs NAV including donation");
        assertLt(shares, depositAmt, "A0 first depositor does not mint donation as free shares");
    }

    function test_A0_morphoSupplyOnBehalf_beforeFirstMint_noFreeShares() public {
        uint256 donation = _u(5);
        _mintLoan(attacker, donation);
        vm.startPrank(attacker);
        loanToken.approve(address(morpho), donation);
        MorphoBlueService._supply(morpho, marketParams, donation, se);
        vm.stopPrank();
        uint256 depositAmt = _u(100);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), depositAmt, IERC20(se));
        assertLt(preview, depositAmt, "A0 onBehalf donation inflates NAV");
        uint256 shares = _wrapExactIn(user, depositAmt);
        assertEq(shares, preview);
    }

    function test_A1_donateAfterLive_noFreeMint_victimNavRises() public {
        uint256 shares = _wrapExactIn(user, _u(100));
        uint256 convBefore = se4626.convertToAssets(shares);
        _mintLoan(attacker, _u(60));
        vm.prank(attacker);
        loanToken.transfer(se, _u(50));
        uint256 convAfter = se4626.convertToAssets(shares);
        assertGt(convAfter, convBefore, "A1 victim NAV rises (K1)");
        uint256 supplyBefore = IERC20(se).totalSupply();
        uint256 attackerShares = _wrapExactIn(attacker, _u(10));
        assertLt(attackerShares, _u(10) + _u(50), "A1 no free mint of donation");
        assertEq(IERC20(se).totalSupply(), supplyBefore + attackerShares, "A1 only delta minted");
    }

    function test_I1_pretransferred_noTransfer_bookedInventory_reverts() public {
        _wrapExactIn(user, _u(50));
        uint256 claimed = _u(1);
        uint256 supplyBefore = IERC20(se).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0))
        );
        seIn.exchangeIn(IERC20(address(loanToken)), claimed, IERC20(se), 0, attacker, true, _deadline());
        assertEq(IERC20(se).totalSupply(), supplyBefore, "I1 no mint");
        assertEq(IERC20(se).balanceOf(attacker), 0, "I1 attacker unchanged");
    }

    function test_I2_shortPretransfer_revertsExactArgs() public {
        _wrapExactIn(user, _u(50));
        uint256 short_ = _u(1);
        uint256 claimed_ = _u(5);
        vm.prank(user);
        loanToken.transfer(se, short_);
        uint256 booked = IBasicVault(se).reserveOfToken(address(loanToken));
        uint256 U = loanToken.balanceOf(se) - booked;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, U)
        );
        seIn.exchangeIn(IERC20(address(loanToken)), claimed_, IERC20(se), 0, attacker, true, _deadline());
    }

    function test_I3_residualCannotFundSecondFreeMint() public {
        _wrapExactIn(user, _u(50));
        vm.prank(user);
        loanToken.transfer(se, _u(2));
        vm.prank(attacker);
        seIn.exchangeIn(IERC20(address(loanToken)), _u(2), IERC20(se), 0, attacker, true, _deadline());
        uint256 supplyAfter = IERC20(se).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, _u(1), uint256(0))
        );
        seIn.exchangeIn(IERC20(address(loanToken)), _u(1), IERC20(se), 0, attacker, true, _deadline());
        assertEq(IERC20(se).totalSupply(), supplyAfter, "I3 no second mint");
    }

    function test_E1_roundTrip_conservation() public {
        uint256 inAmt = _u(100);
        uint256 shares = _wrapExactIn(user, inAmt);
        uint256 nav = _idleOf(se) + _expectedSupplyOf(se);
        assertApproxEqAbs(nav, inAmt, 1, "E1 wrap NAV");
        vm.prank(user);
        uint256 outAmt = seIn.exchangeIn(
            IERC20(se), shares, IERC20(address(loanToken)), 0, user, false, _deadline()
        );
        assertApproxEqAbs(outAmt, inAmt, 1, "E1 round-trip +/- Blue dust");
        assertLe(_idleOf(se) + _expectedSupplyOf(se), 1, "E1 residual ~0");
    }

    function test_E6_fatMaxIn_pretransferOnlyUsed_bookedIntact() public {
        uint256 attackerShares = _wrapExactIn(attacker, _u(40));
        uint256 morphoBefore = _expectedSupplyOf(se);
        uint256 assetsOut = _u(5);
        uint256 used = seOut.previewExchangeOut(IERC20(se), IERC20(address(loanToken)), assetsOut);
        vm.prank(attacker);
        IERC20(se).transfer(se, attackerShares);
        vm.prank(attacker);
        uint256 amountIn = seOut.exchangeOut(
            IERC20(se), attackerShares, IERC20(address(loanToken)), assetsOut, attacker, true, _deadline()
        );
        assertEq(amountIn, used, "E6 burned preview shares only");
        assertLe(amountIn, attackerShares, "E6 fat maxIn not fully burned");
        assertApproxEqAbs(_expectedSupplyOf(se) + assetsOut, morphoBefore, 1, "E6 Morpho decreased by payout");
        assertEq(IERC20(se).balanceOf(attacker), attackerShares - used, "E6 leftover shares refunded");
    }

    function test_C_reentrancy_nestedIsLocked() public {
        ReentrantLoanDecimals re = new ReentrantLoanDecimals();
        ERC20Mock coll = new ERC20Mock();
        MarketParams memory p = MarketParams({
            loanToken: address(re),
            collateralToken: address(coll),
            oracle: address(oracle),
            irm: address(irm),
            lltv: DEFAULT_LLTV
        });
        morpho.createMarket(p);
        address seR = _deployVault(morpho, p);
        re.setBalance(user, 100 ether);
        vm.prank(user);
        re.approve(seR, type(uint256).max);
        IStandardExchangeIn inR = IStandardExchangeIn(seR);
        re.setReenter(
            seR,
            abi.encodeWithSelector(
                IStandardExchangeIn.exchangeIn.selector,
                IERC20(address(re)),
                uint256(1 ether),
                IERC20(seR),
                uint256(0),
                user,
                false,
                _deadline()
            )
        );
        uint256 supplyBefore = IERC20(seR).totalSupply();
        vm.prank(user);
        inR.exchangeIn(IERC20(address(re)), 10 ether, IERC20(seR), 0, user, false, _deadline());
        bytes memory nested = re.lastRevert();
        assertEq(nested.length, 4, "C nested revert selector");
        assertEq(bytes4(nested), IReentrancyLock.IsLocked.selector, "C nested IsLocked");
        assertEq(IERC20(seR).totalSupply() - supplyBefore, IERC20(seR).balanceOf(user), "C no extra mint");
    }

    function test_CROPS_disabledVault_exchangeOutAndRedeemStillWork() public {
        uint256 shares = _wrapExactIn(user, _u(50));
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(se, true);
        vm.prank(user);
        uint256 assetsOut = seIn.exchangeIn(
            IERC20(se), shares / 2, IERC20(address(loanToken)), 0, user, false, _deadline()
        );
        assertGt(assetsOut, 0, "CROPS exchangeOut/redeem in still works");
        vm.prank(user);
        uint256 redeemed = se4626.redeem(shares / 4, user, user);
        assertGt(redeemed, 0, "CROPS redeem still works");
    }
}

contract ReentrantLoanDecimals is ERC20Mock {
    address public target;
    bytes public payload;
    bytes public lastRevert;

    function setReenter(address target_, bytes memory payload_) external {
        target = target_;
        payload = payload_;
        lastRevert = "";
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        bool ok = super.transfer(to, amount);
        _maybeReenter();
        return ok;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        bool ok = super.transferFrom(from, to, amount);
        _maybeReenter();
        return ok;
    }

    function _maybeReenter() internal {
        if (target != address(0) && payload.length > 0) {
            address t = target;
            bytes memory p = payload;
            target = address(0);
            payload = "";
            (bool called, bytes memory ret) = t.call(p);
            if (!called) {
                lastRevert = ret;
            }
        }
    }
}
