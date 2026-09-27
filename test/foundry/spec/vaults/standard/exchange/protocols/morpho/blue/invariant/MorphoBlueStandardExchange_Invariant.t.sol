// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeAccountingHandler} from "test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IStandardExchangeIn as CraneExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut as CraneExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IMorpho, MarketParams, Id} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
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

/// @dev APEX production-route campaign. The callback token is an external dependency;
/// the Morpho market, registry-deployed SE and all mapped facets remain production code.
contract MorphoAccountingLoan is ERC20Mock {
    address public target;
    bytes public payload;
    bytes public nestedResult;
    uint256 public attempts;
    bool public nestedSuccess;
    function symbol() external pure returns (string memory) { return "INVLOAN"; }
    function arm(address target_, bytes calldata payload_) external {
        target = target_; payload = payload_; nestedResult = ""; attempts = 0; nestedSuccess = false;
    }
    function transfer(address to_, uint256 amount_) public override returns (bool) {
        bool ok = super.transfer(to_, amount_); _reenter(); return ok;
    }
    function transferFrom(address from_, address to_, uint256 amount_) public override returns (bool) {
        bool ok = super.transferFrom(from_, to_, amount_); _reenter(); return ok;
    }
    function _reenter() internal {
        if (target == address(0)) return;
        address target_ = target; target = address(0); ++attempts;
        (nestedSuccess, nestedResult) = target_.call(payload);
    }
}

contract MorphoBlueStandardExchangeHandler is StandardExchangeAccountingHandler {
    using MorphoBalancesLib for IMorpho;
    enum MorphoAction { Deposit4626, Redeem4626, SupplyOnBehalf, Borrow, Accrue, Repay, ReenterDeposit, ReenterRedeem }
    mapping(MorphoAction => Counts) public morphoCounts;
    IMorpho public immutable morpho;
    MarketParams public marketParams;
    MorphoAccountingLoan public immutable loan;
    ERC20Mock public immutable collateral;
    address public constant borrower = address(0xB0220);

    constructor(address se_, IMorpho morpho_, MarketParams memory params_)
        StandardExchangeAccountingHandler(IStandardExchangeIn(se_), IERC20(params_.loanToken), IERC20(se_), true,
            address(0xCA1101), address(0xCA1102), address(0xBAD))
    { morpho = morpho_; marketParams = params_; loan = MorphoAccountingLoan(params_.loanToken); collateral = ERC20Mock(params_.collateralToken); }

    function _fund(address actor_, uint256 amount_) internal override {
        loan.setBalance(actor_, loan.balanceOf(actor_) + amount_);
    }
    function _restingQuote(uint256 amount_) internal view override returns (uint256) {
        uint256 nav = IERC4626(address(seIn)).totalAssets();
        return Math.mulDiv(amount_, share.totalSupply() + 1, nav - amount_ + 1);
    }
    function _state() internal view override returns (bytes32) {
        return keccak256(abi.encode(super._state(), IBasicVault(address(seIn)).reserveOfToken(address(base)),
            morpho.position(Id.wrap(keccak256(abi.encode(marketParams))), address(seIn)),
            morpho.expectedSupplyAssets(marketParams, address(seIn)), base.allowance(address(seIn), address(morpho))));
    }
    function _additionalActions(address actor_, uint256 seed_) internal override {
        _deposit4626(actor_, bound(seed_, 1e16, 1 ether));
        _redeem4626(actor_);
        _supplyOnBehalf();
        _borrowAccrueRepay(bound(seed_, 1e9, 1e12), bound(seed_, 1, 600));
    }
    function _deposit4626(address actor_, uint256 amount_) internal {
        ++morphoCounts[MorphoAction.Deposit4626].attempted;
        _fund(actor_, amount_);
        IERC4626 vault = IERC4626(address(seIn));
        Checkpoint memory before_ = Checkpoint(base.balanceOf(actor_), share.balanceOf(actor_), vault.previewDeposit(amount_));
        vm.prank(actor_); base.approve(address(vault), amount_);
        _arm(MorphoAction.ReenterDeposit);
        vm.prank(actor_); uint256 minted = vault.deposit(amount_, actor_);
        _assertReentry(MorphoAction.ReenterDeposit);
        assertEq(before_.assets - base.balanceOf(actor_), amount_, "4626 deposit principal");
        assertEq(share.balanceOf(actor_) - before_.shares, minted, "4626 recipient shares");
        assertEq(minted, before_.quote, "4626 deposit quote");
        assertGt(minted, 0, "4626 funded deposit succeeds");
        mintedShares += minted;
        ++morphoCounts[MorphoAction.Deposit4626].succeeded;
    }
    function _redeem4626(address actor_) internal {
        ++morphoCounts[MorphoAction.Redeem4626].attempted;
        IERC4626 vault = IERC4626(address(seIn));
        uint256 redeem = share.balanceOf(actor_) / 20;
        Checkpoint memory before_ = Checkpoint(base.balanceOf(actor_), share.balanceOf(actor_), vault.previewRedeem(redeem));
        _arm(MorphoAction.ReenterRedeem);
        vm.prank(actor_); uint256 paid = vault.redeem(redeem, actor_, actor_);
        _assertReentry(MorphoAction.ReenterRedeem);
        assertGt(paid, 0, "4626 nonzero redemption");
        assertEq(paid, before_.quote, "4626 redeem quote");
        assertEq(before_.shares - share.balanceOf(actor_), redeem, "4626 burns once");
        assertEq(base.balanceOf(actor_) - before_.assets, paid, "4626 actual payout");
        burnedShares += redeem;
        ++morphoCounts[MorphoAction.Redeem4626].succeeded;
    }
    function _arm(MorphoAction action_) internal {
        ++morphoCounts[action_].attempted;
        loan.arm(address(seIn), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (base, 1 ether, share, 0, attacker, false, block.timestamp + 1 hours)));
    }
    function _assertReentry(MorphoAction action_) internal {
        assertEq(loan.attempts(), 1, "real dependency transfer callback reached");
        assertFalse(loan.nestedSuccess(), "nested call rejected");
        assertEq(loan.nestedResult(), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "exact production guard");
        ++morphoCounts[action_].expectedRevert;
    }
    function _supplyOnBehalf() internal {
        ++morphoCounts[MorphoAction.SupplyOnBehalf].attempted;
        _fund(address(this), 1e9);
        uint256 beforeNav = IERC4626(address(seIn)).totalAssets();
        uint256 supply = share.totalSupply();
        base.approve(address(morpho), 1e9);
        (uint256 supplied,) = morpho.supply(marketParams, 1e9, 0, address(seIn), "");
        assertEq(supplied, 1e9, "actual on-behalf supply");
        assertEq(share.totalSupply(), supply, "protocol donation never issues shares");
        assertApproxEqAbs(IERC4626(address(seIn)).totalAssets(), beforeNav + supplied, 1, "protocol-position value grows only by supplied assets");
        ++morphoCounts[MorphoAction.SupplyOnBehalf].succeeded;
    }
    function _borrowAccrueRepay(uint256 debt_, uint256 seconds_) internal {
        ++morphoCounts[MorphoAction.Borrow].attempted;
        collateral.setBalance(borrower, collateral.balanceOf(borrower) + debt_ * 2 + 1 ether);
        vm.startPrank(borrower);
        collateral.approve(address(morpho), debt_ * 2 + 1 ether);
        morpho.supplyCollateral(marketParams, debt_ * 2 + 1 ether, borrower, "");
        uint256 beforeBorrow = base.balanceOf(borrower);
        (uint256 borrowed,) = morpho.borrow(marketParams, debt_, 0, borrower, borrower);
        vm.stopPrank();
        assertEq(borrowed, debt_, "funded market borrow");
        assertEq(base.balanceOf(borrower) - beforeBorrow, debt_, "borrow delivery");
        ++morphoCounts[MorphoAction.Borrow].succeeded;
        ++morphoCounts[MorphoAction.Accrue].attempted;
        vm.warp(block.timestamp + seconds_);
        morpho.accrueInterest(marketParams);
        ++morphoCounts[MorphoAction.Accrue].succeeded;
        _repay();
    }
    function _repay() internal {
        ++morphoCounts[MorphoAction.Repay].attempted;
        Id id = Id.wrap(keccak256(abi.encode(marketParams)));
        uint256 debtShares = morpho.position(id, borrower).borrowShares;
        assertGt(debtShares, 0, "borrow created liability");
        _fund(borrower, 1 ether);
        uint256 before_ = base.balanceOf(borrower);
        vm.startPrank(borrower);
        base.approve(address(morpho), before_);
        (uint256 repaid, uint256 burned) = morpho.repay(marketParams, 0, debtShares, borrower, "");
        vm.stopPrank();
        assertEq(burned, debtShares, "all debt shares repaid");
        assertEq(before_ - base.balanceOf(borrower), repaid, "repay payer delta");
        assertEq(morpho.position(id, borrower).borrowShares, 0, "no residual debt hides liquidity failures");
        ++morphoCounts[MorphoAction.Repay].succeeded;
    }
    function assertMorphoAccounting() external view {
        for (uint8 i; i < 8; ++i) {
            Counts memory c = morphoCounts[MorphoAction(i)];
            assertEq(c.attempted, cycles / 4, "every Morpho action reached");
            assertEq(c.succeeded + c.expectedRevert, cycles / 4, "no swallowed failures");
            assertEq(c.unexpectedRevert, 0, "unexpected failure aborts campaign");
        }
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract MorphoBlueStandardExchange_Invariant is TestBase_MorphoBlueStandardExchange {
    using MorphoBalancesLib for IMorpho;

    MorphoBlueStandardExchangeHandler internal handler;

    function setUp() public override {
        super.setUp();
        loanToken = new MorphoAccountingLoan();
        marketParams.loanToken = address(loanToken);
        marketId = Id.wrap(keccak256(abi.encode(marketParams)));
        morpho.createMarket(marketParams);
        se = _deployVault(morpho, marketParams);
        seIn = CraneExchangeIn(se);
        seOut = CraneExchangeOut(se);
        mbse = IMorphoBlueStandardExchange(se);
        se4626 = IERC4626(se);
        loanToken.setBalance(user, 1_000_000 ether);
        vm.prank(user); loanToken.approve(se, type(uint256).max);
        handler = new MorphoBlueStandardExchangeHandler(se, morpho, marketParams);
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        handler.assertMorphoAccounting();
        _assert_invariant_N1_liveNav_equalsIdlePlusExpectedSupply();
        _assert_invariant_N2_reserveOfToken_isIdleBookNotNav();
        _assert_invariant_N4_donationDoesNotFreeMintExtractablePrincipal();
        _assert_invariant_N5_noThirdPartyMorphoAuthorization();
        _assert_invariant_N6_vaultPositionOnBehalfIsSelf();

    }
    function afterInvariant() public view {
        assertGe(handler.cycles(), 4, "randomized lifecycle reached");
        for (uint256 i; i < 3; ++i) assertGt(handler.actorCycles(handler.actors(i)), 0, "each honest actor participated");
        invariant_APEX_accounting();
    }
    function test_APEX_deterministicLifecycle() public {
        for (uint256 i; i < 4; ++i) handler.cycle(1 ether + i, i);
        afterInvariant();
    }

    function _assert_invariant_N1_liveNav_equalsIdlePlusExpectedSupply() internal view {
        uint256 idle = loanToken.balanceOf(se);
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        assertEq(se4626.totalAssets(), idle + expected, "N1");
    }

    function _assert_invariant_N2_reserveOfToken_isIdleBookNotNav() internal view {
        uint256 reserve = IBasicVault(se).reserveOfToken(address(loanToken));
        uint256 idle = loanToken.balanceOf(se);
        assertLe(reserve, idle, "N2 reserve <= idle");
        uint256 nav = se4626.totalAssets();
        if (nav > idle) {
            assertTrue(reserve != nav, "N2 reserve is not NAV");
        }
    }

    /// @dev N4: unbooked loanToken / Morpho donation cannot mint more SE shares than that unbooked amount.
    function _assert_invariant_N4_donationDoesNotFreeMintExtractablePrincipal() internal view {
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

    function _assert_invariant_N5_noThirdPartyMorphoAuthorization() internal view {
        for (uint256 i; i < 3; ++i) assertFalse(morpho.isAuthorized(se, handler.actors(i)), "N5 honest actor");
        assertFalse(morpho.isAuthorized(se, address(handler.integrator())), "N5 integrating contract");
        assertFalse(morpho.isAuthorized(se, handler.attacker()), "N5 attacker");
        assertFalse(morpho.isAuthorized(se, handler.borrower()), "N5 borrower");
    }

    function _assert_invariant_N6_vaultPositionOnBehalfIsSelf() internal view {
        for (uint256 i; i < 3; ++i) assertEq(morpho.position(marketId, handler.actors(i)).supplyShares, 0, "N6 actor Morpho supply");
        assertEq(morpho.position(marketId, handler.attacker()).supplyShares, 0, "N6 attacker Morpho supply");
        uint256 vaultShares = morpho.position(marketId, se).supplyShares;
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        if (vaultShares == 0) {
            assertEq(expected, 0, "N6 no vault shares => no expected supply");
        }
    }
}
