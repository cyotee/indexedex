// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC2612} from "@crane/contracts/interfaces/IERC2612.sol";
import {ECDSA as SoladyECDSA} from "@crane/contracts/external/solady/utils/ECDSA.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBlueService} from
    "@crane/contracts/protocols/lending/morpho/blue/services/MorphoBlueService.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {FeeOnTransferERC20} from "contracts/test/stubs/FeeOnTransferERC20.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    MorphoBlueStandardExchangeCommon
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol";
import {
    TestBase_MorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

/**
 * @title Adversarial_MorphoBlueStandardExchange_P0
 * @notice Production-proxy P0: A0, A1, I1–I3, E1, E5, E6, H3, C*, L2, CROPS, O1–O2, J smoke.
 * @dev Deferred: M* (no user calldata forwarder); N* (no external callback besides Morpho `data=""`);
 *      sleeve/rebalance; Vault V2; Uni V4 hook.
 */
contract Adversarial_MorphoBlueStandardExchange_P0 is TestBase_MorphoBlueStandardExchange {
    function test_A0_donateBeforeFirstMint_noFreeShares() public {
        uint256 donation = 5 ether;
        loanToken.setBalance(attacker, donation);
        vm.prank(attacker);
        loanToken.transfer(se, donation);

        uint256 depositAmt = 100 ether;
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), depositAmt, IERC20(se));
        assertLt(preview, depositAmt, "A0 shares < 1:1 against donated NAV");
        assertGt(preview, 0, "A0 non-zero mint");
        uint256 shares = _wrapExactIn(user, depositAmt);
        assertEq(shares, preview, "A0 mint vs NAV including donation");
        assertLt(shares, depositAmt, "A0 first depositor does not mint donation as free shares");
    }

    function test_A0_morphoSupplyOnBehalf_beforeFirstMint_noFreeShares() public {
        uint256 donation = 5 ether;
        loanToken.setBalance(attacker, donation);
        vm.startPrank(attacker);
        loanToken.approve(address(morpho), donation);
        MorphoBlueService._supply(morpho, marketParams, donation, se);
        vm.stopPrank();

        uint256 depositAmt = 100 ether;
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), depositAmt, IERC20(se));
        assertLt(preview, depositAmt, "A0 onBehalf donation inflates NAV");
        uint256 shares = _wrapExactIn(user, depositAmt);
        assertEq(shares, preview);
    }

    function test_A1_donateAfterLive_noFreeMint_victimNavRises() public {
        uint256 shares = _wrapExactIn(user, 100 ether);
        uint256 convBefore = se4626.convertToAssets(shares);
        loanToken.setBalance(attacker, 60 ether);
        vm.prank(attacker);
        loanToken.transfer(se, 50 ether);
        uint256 convAfter = se4626.convertToAssets(shares);
        assertGt(convAfter, convBefore, "A1 victim NAV rises (K1)");

        uint256 supplyBefore = IERC20(se).totalSupply();
        uint256 attackerShares = _wrapExactIn(attacker, 10 ether);
        assertLt(attackerShares, 10 ether + 50 ether, "A1 no free mint of donation");
        assertEq(IERC20(se).totalSupply(), supplyBefore + attackerShares, "A1 only delta minted");
    }

    function test_I1_pretransferred_noTransfer_bookedInventory_reverts() public {
        _wrapExactIn(user, 50 ether);
        uint256 claimed = 1 ether;
        uint256 supplyBefore = IERC20(se).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0))
        );
        seIn.exchangeIn(
            IERC20(address(loanToken)), claimed, IERC20(se), 0, attacker, true, _deadline()
        );
        assertEq(IERC20(se).totalSupply(), supplyBefore, "I1 no mint");
        assertEq(IERC20(se).balanceOf(attacker), 0, "I1 attacker unchanged");
    }

    function test_I2_shortPretransfer_revertsExactArgs() public {
        _wrapExactIn(user, 50 ether);
        uint256 short_ = 1 ether;
        uint256 claimed_ = 5 ether;
        vm.prank(user);
        loanToken.transfer(se, short_);
        uint256 booked = IBasicVaultReserve(se);
        uint256 U = loanToken.balanceOf(se) - booked;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, U)
        );
        seIn.exchangeIn(
            IERC20(address(loanToken)), claimed_, IERC20(se), 0, attacker, true, _deadline()
        );
    }

    function test_I3_residualCannotFundSecondFreeMint() public {
        _wrapExactIn(user, 50 ether);
        vm.prank(user);
        loanToken.transfer(se, 2 ether);
        vm.prank(attacker);
        seIn.exchangeIn(IERC20(address(loanToken)), 2 ether, IERC20(se), 0, attacker, true, _deadline());
        uint256 supplyAfter = IERC20(se).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0))
        );
        seIn.exchangeIn(
            IERC20(address(loanToken)), 1 ether, IERC20(se), 0, attacker, true, _deadline()
        );
        assertEq(IERC20(se).totalSupply(), supplyAfter, "I3 no second mint");
    }

    function test_E1_roundTrip_conservation() public {
        uint256 inAmt = 100 ether;
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

    function test_E5_zeroAmount_deadlineExpired() public {
        vm.expectRevert(MorphoBlueStandardExchangeCommon.ZeroAmount.selector);
        seIn.previewExchangeIn(IERC20(address(loanToken)), 0, IERC20(se));

        vm.prank(user);
        vm.expectRevert(MorphoBlueStandardExchangeCommon.DeadlineExpired.selector);
        seIn.exchangeIn(
            IERC20(address(loanToken)), 1 ether, IERC20(se), 0, user, false, block.timestamp - 1
        );
    }

    function test_E6_fatMaxIn_pretransferOnlyUsed_bookedIntact() public {
        uint256 attackerShares = _wrapExactIn(attacker, 40 ether);
        uint256 morphoBefore = _expectedSupplyOf(se);
        uint256 assetsOut = 5 ether;
        uint256 used = seOut.previewExchangeOut(IERC20(se), IERC20(address(loanToken)), assetsOut);
        vm.prank(attacker);
        IERC20(se).transfer(se, attackerShares);
        vm.prank(attacker);
        uint256 amountIn = seOut.exchangeOut(
            IERC20(se),
            attackerShares,
            IERC20(address(loanToken)),
            assetsOut,
            attacker,
            true,
            _deadline()
        );
        assertEq(amountIn, used, "E6 burned preview shares only");
        assertLe(amountIn, attackerShares, "E6 fat maxIn not fully burned");
        assertApproxEqAbs(_expectedSupplyOf(se) + assetsOut, morphoBefore, 1, "E6 Morpho decreased by payout");
        assertEq(IERC20(se).balanceOf(attacker), attackerShares - used, "E6 leftover shares refunded");
    }

    function test_H3_minOutFail_fullRevert_morphoUnchanged() public {
        uint256 morphoBefore = _expectedSupplyOf(se);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), 10 ether, IERC20(se));
        vm.prank(user);
        vm.expectRevert(MorphoBlueStandardExchangeCommon.Slippage.selector);
        seIn.exchangeIn(
            IERC20(address(loanToken)), 10 ether, IERC20(se), preview + 1, user, false, _deadline()
        );
        assertEq(_expectedSupplyOf(se), morphoBefore, "H3 Morpho unchanged");
        assertEq(IERC20(se).totalSupply(), 0, "H3 no shares");
    }

    function test_C_reentrancy_nestedIsLocked() public {
        ReentrantLoan re = new ReentrantLoan();
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

    function test_L2_FoT_forbidden() public {
        FeeOnTransferERC20 fot = new FeeOnTransferERC20("FOT", "FOT", 1000);
        ERC20Mock coll = new ERC20Mock();
        MarketParams memory p = MarketParams({
            loanToken: address(fot),
            collateralToken: address(coll),
            oracle: address(oracle),
            irm: address(irm),
            lltv: DEFAULT_LLTV
        });
        morpho.createMarket(p);
        address fotSe = _deployVault(morpho, p);
        uint256 claimed_ = 10 ether;
        fot.mint(user, claimed_);
        vm.startPrank(user);
        fot.transfer(fotSe, claimed_);
        uint256 observed_ = fot.balanceOf(fotSe);
        assertLt(observed_, claimed_, "L2 FoT delivered less");
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, observed_
            )
        );
        IStandardExchangeIn(fotSe).exchangeIn(
            IERC20(address(fot)), claimed_, IERC20(fotSe), 0, user, true, _deadline()
        );
        vm.stopPrank();
        assertEq(IERC20(fotSe).totalSupply(), 0, "L2 no mint on FoT face claim");
    }

    function test_CROPS_disabledVault_exchangeOutAndRedeemStillWork() public {
        uint256 shares = _wrapExactIn(user, 50 ether);
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

    function test_O1_invalidPermit_reverts() public {
        vm.expectRevert(SoladyECDSA.InvalidSignature.selector);
        IERC2612(se).permit(user, attacker, 1 ether, _deadline(), 27, bytes32(0), bytes32(0));
        assertEq(IERC20(se).allowance(user, attacker), 0, "O1 no allowance");
    }

    function test_O2_expiredPermit_reverts() public {
        vm.warp(block.timestamp + 10);
        vm.expectRevert(abi.encodeWithSelector(IERC2612.ERC2612ExpiredSignature.selector, uint256(1)));
        IERC2612(se).permit(user, attacker, 1 ether, 1, 27, bytes32(uint256(1)), bytes32(uint256(1)));
    }

    function test_J_proxySmoke() public view {
        IDiamondLoupe loupe = IDiamondLoupe(se);
        assertTrue(loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector) != address(0));
        assertTrue(loupe.facetAddress(IERC4626.redeem.selector) != address(0));
    }

    function IBasicVaultReserve(address vault) internal view returns (uint256) {
        return IBasicVault(vault).reserveOfToken(address(loanToken));
    }
}

contract ReentrantLoan is ERC20Mock {
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
