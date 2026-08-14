// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

contract OrbitalPretransferHelper {
    function mintPretransfer(
        address detf_,
        IERC20 pairToken_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        address recipient_
    ) external returns (uint256 out_) {
        if (transferAmt_ > 0) pairToken_.transferFrom(msg.sender, detf_, transferAmt_);
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            pairToken_, claimAmt_, IERC20(detf_), 0, recipient_, true, block.timestamp + 1 hours
        );
    }

    function burnPretransfer(
        address detf_,
        IERC20 pairOut_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        address recipient_
    ) external returns (uint256 out_) {
        if (transferAmt_ > 0) IERC20(detf_).transferFrom(msg.sender, detf_, transferAmt_);
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            IERC20(detf_), claimAmt_, pairOut_, 0, recipient_, true, block.timestamp + 1 hours
        );
    }
}

/// @notice Catalog I1–I3 on the production orbital DETF proxy.
contract Adversarial_Orbital_TrustFlags is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    OrbitalPretransferHelper internal preHelper;
    address internal attacker;
    address internal victim;

    function setUp() public override {
        super.setUp();
        preHelper = new OrbitalPretransferHelper();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
    }

    function _openLive() internal returns (address instance_, address p0_) {
        instance_ = _deployDetfInstance(_openArgsUnique("iFlags"));
        IUniswapV4StandardExchangeOrbitalDETF info_ = IUniswapV4StandardExchangeOrbitalDETF(instance_);
        p0_ = info_.pairToken0();
        _firstBondOn(instance_, 200 ether, 200 ether);
    }

    function _bookPairResidual(address instance_, address p0_, uint256 residual_) internal {
        SimpleMintableERC20(p0_).mint(victim, residual_);
        vm.prank(victim);
        IERC20(p0_).transfer(instance_, residual_);
        SimpleMintableERC20(p0_).mint(detfUser, residual_);
        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, residual_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), residual_ / 2 == 0 ? residual_ : residual_ / 2, IERC20(instance_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "book residual: honest mint");
    }

    function test_I1_pretransferred_mint_inventoryNoInCallTransfer_revertsDelta0() public {
        (address instance_, address p0_) = _openLive();
        uint256 residual_ = 50 ether;
        _bookPairResidual(instance_, p0_, residual_);
        uint256 balBefore_ = IERC20(p0_).balanceOf(instance_);
        uint256 attackerDetfBefore_ = IERC20(instance_).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0))
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), residual_, IERC20(instance_), 0, attacker, true, _dl()
        );

        assertEq(IERC20(p0_).balanceOf(instance_), balBefore_);
        assertEq(IERC20(instance_).balanceOf(attacker), attackerDetfBefore_);
    }

    function test_I1_pretransferred_burn_bookedDetfInventory_revertsDelta0() public {
        (address instance_, address p0_) = _openLive();
        SimpleMintableERC20(p0_).mint(victim, 80 ether);
        vm.startPrank(victim);
        IERC20(p0_).approve(instance_, type(uint256).max);
        uint256 minted_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), 80 ether, IERC20(instance_), 0, victim, false, _dl()
        );
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;
        uint256 burnHonest_ = minted_ - donateAmt_;
        if (burnHonest_ == 0) burnHonest_ = 1;
        IERC20(instance_).transfer(instance_, donateAmt_);
        IERC20(instance_).approve(instance_, burnHonest_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnHonest_, IERC20(p0_), 0, victim, false, _dl()
        );
        vm.stopPrank();

        uint256 residualDetf_ = IERC20(instance_).balanceOf(instance_);
        assertGt(residualDetf_, 0);
        uint256 invBefore_ = residualDetf_;
        uint256 attackerPairBefore_ = IERC20(p0_).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualDetf_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), residualDetf_, IERC20(p0_), 0, attacker, true, _dl()
        );

        assertEq(IERC20(instance_).balanceOf(instance_), invBefore_);
        assertEq(IERC20(p0_).balanceOf(attacker), attackerPairBefore_);
    }

    function test_I1_pretransferred_bond_inventoryNoInCallTransfer_revertsDelta0() public {
        (address instance_, address p0_) = _openLive();
        uint256 residual_ = 40 ether;
        _bookPairResidual(instance_, p0_, residual_);
        uint256 balBefore_ = IERC20(p0_).balanceOf(instance_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0))
        );
        IUniswapV4StandardExchangeOrbitalDETF(instance_).bond(
            IERC20(p0_), residual_, DEFAULT_MIN_LOCK, attacker, true, _dl()
        );

        assertEq(IERC20(p0_).balanceOf(instance_), balBefore_);
    }

    function test_I1_pretransferred_depositClaim_inventoryNoInCallTransfer_revertsDelta0() public {
        (address instance_, address p0_) = _openLive();
        uint256 residual_ = 30 ether;
        _bookPairResidual(instance_, p0_, residual_);
        uint256 balBefore_ = IERC20(p0_).balanceOf(instance_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0))
        );
        IUniswapV4StandardExchangeOrbitalDETF(instance_).depositClaim(
            IERC20(p0_), residual_, 0, attacker, true, _dl()
        );

        assertEq(IERC20(p0_).balanceOf(instance_), balBefore_);
    }

    function test_I2_pretransferred_mint_shortDelta_reverts() public {
        (address instance_, address p0_) = _openLive();
        _bookPairResidual(instance_, p0_, 40 ether);
        uint256 bookedBal_ = IERC20(p0_).balanceOf(instance_);
        uint256 claimed_ = 60 ether;
        uint256 shortDelta_ = 30 ether;
        SimpleMintableERC20(p0_).mint(attacker, shortDelta_);
        vm.startPrank(attacker);
        IERC20(p0_).approve(address(preHelper), shortDelta_);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, shortDelta_)
        );
        preHelper.mintPretransfer(instance_, IERC20(p0_), shortDelta_, claimed_, attacker);
        vm.stopPrank();
        assertEq(IERC20(instance_).balanceOf(attacker), 0);
        assertEq(IERC20(p0_).balanceOf(instance_), bookedBal_);
    }

    function test_I3_residualInventory_cannotFundSecondFreePretransfer_mint() public {
        (address instance_, address p0_) = _openLive();
        uint256 residualSeed_ = 30 ether;
        SimpleMintableERC20(p0_).mint(victim, residualSeed_);
        vm.prank(victim);
        IERC20(p0_).transfer(instance_, residualSeed_);
        SimpleMintableERC20(p0_).mint(detfUser, 40 ether);
        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, 40 ether);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), 40 ether, IERC20(instance_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
        uint256 residual_ = IERC20(p0_).balanceOf(instance_);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residualSeed_, uint256(0))
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), residualSeed_, IERC20(instance_), 0, attacker, true, _dl()
        );
        assertEq(IERC20(p0_).balanceOf(instance_), residual_);
    }

    function test_I3_residualInventory_cannotFundSecondFreePretransfer_burn() public {
        (address instance_, address p0_) = _openLive();
        SimpleMintableERC20(p0_).mint(victim, 80 ether);
        vm.startPrank(victim);
        IERC20(p0_).approve(instance_, type(uint256).max);
        uint256 minted_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), 80 ether, IERC20(instance_), 0, victim, false, _dl()
        );
        uint256 residualSeed_ = minted_ / 3;
        if (residualSeed_ == 0) residualSeed_ = 1;
        uint256 burnAmt_ = minted_ / 3;
        if (burnAmt_ == 0) burnAmt_ = 1;
        IERC20(instance_).transfer(instance_, residualSeed_);
        IERC20(instance_).approve(instance_, burnAmt_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, IERC20(p0_), 0, victim, false, _dl()
        );
        vm.stopPrank();
        uint256 residual_ = IERC20(instance_).balanceOf(instance_);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residualSeed_, uint256(0))
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), residualSeed_, IERC20(p0_), 0, attacker, true, _dl()
        );
        assertEq(IERC20(instance_).balanceOf(instance_), residual_);
    }
}
