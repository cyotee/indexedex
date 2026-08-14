// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";

/// @notice Aero SE security remediations: E6 Out refund, A0 first-mint, I1 LP-deposit.
/// @dev Production proxy only. Volatile pools. No SUT mocks.
contract AerodromeStandardExchange_E6_A0_I1_Test is TestBase_AerodromeStandardExchange_MultiPool {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("seAttacker");
    }

    function _vault() internal view returns (IStandardExchangeProxy) {
        return _getVault(PoolConfig.Balanced);
    }

    /* ---------------------------------------------------------------------- */
    /*  E6: fat max + transfer-only-used must not skim booked R               */
    /* ---------------------------------------------------------------------- */

    /// @notice E6: inflated maxAmountIn + transfer of only `used` cannot skim booked pairToken.
    /// @dev Anti-theater: do not transfer fatMax. Call the production proxy.
    function test_E6_exchangeOut_swap_inflatedMax_pretransferred_noExtraTransfer_noInventorySkim() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        uint256 residual_ = TEST_AMOUNT / 4;
        uint256 pull_ = TEST_AMOUNT / 16;
        tokenA.mint(address(vault_), residual_);
        tokenA.mint(attacker, pull_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), pull_);
        vault_.exchangeIn(IERC20(address(tokenA)), pull_, IERC20(address(tokenB)), 0, attacker, false, _deadline());
        vm.stopPrank();

        // After honest money-route sync, live pairToken is booked (U = 0). Public
        // reserveOfToken on this diamond reports only reserve LP lastTotal.
        uint256 bookedR_ = tokenA.balanceOf(address(vault_));
        assertGt(bookedR_, 0, "E6 seed: booked inventory");

        uint256 amountOut_ = 1 ether;
        uint256 usedIn_ =
            vault_.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(usedIn_ > 0, "E6 preview used");

        tokenA.mint(attacker, usedIn_);
        vm.prank(attacker);
        tokenA.transfer(address(vault_), usedIn_);

        uint256 fatMax_ = usedIn_ + bookedR_;
        uint256 attackerBefore_ = tokenA.balanceOf(attacker);
        uint256 liveAfterPush_ = tokenA.balanceOf(address(vault_));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, fatMax_, usedIn_)
        );
        vault_.exchangeOut(
            IERC20(address(tokenA)),
            fatMax_,
            IERC20(address(tokenB)),
            amountOut_,
            attacker,
            true,
            _deadline()
        );

        assertEq(tokenA.balanceOf(address(vault_)), liveAfterPush_, "E6: live inventory unmoved");
        assertGe(tokenA.balanceOf(address(vault_)), bookedR_, "E6: booked R intact");
        assertEq(tokenA.balanceOf(attacker), attackerBefore_, "E6: attacker did not skim pairToken");
    }

    /* ---------------------------------------------------------------------- */
    /*  A0: donate before first mint; first mover cannot drain residual LP    */
    /* ---------------------------------------------------------------------- */

    /// @notice A0: donated reserve LP blocks zap-in deposit; attacker mints nothing.
    /// @dev Donator != attacker. Must redeem-path prove (here: mint never happens).
    function test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation() public {
        IStandardExchangeProxy vault_ = _vault();
        IPool pool_ = _getPool(PoolConfig.Balanced);
        IERC20 lp_ = IERC20(address(pool_));
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        address donator_ = makeAddr("lpDonator");
        uint256 donate_ = TEST_AMOUNT / 50;
        require(lp_.balanceOf(address(this)) >= donate_, "A0 LP inventory");
        lp_.transfer(donator_, donate_);
        vm.prank(donator_);
        lp_.transfer(address(vault_), donate_);

        assertEq(lp_.balanceOf(address(vault_)), donate_, "A0 donation sits unbooked");
        assertEq(vault_.totalSupply(), 0, "A0 empty vaultShare supply");

        uint256 zapIn_ = TEST_AMOUNT / 4;
        tokenA.mint(attacker, zapIn_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), zapIn_);
        vm.expectRevert();
        vault_.exchangeIn(
            IERC20(address(tokenA)), zapIn_, IERC20(address(vault_)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(vault_.balanceOf(attacker), 0, "A0: no vaultShare mint");
        assertEq(lp_.balanceOf(address(vault_)), donate_, "A0: donated LP unmoved");
    }

    /// @notice A0: donate residual LP then first Route4 mint/redeem cannot drain donation.
    function test_A0_emptyVault_residualLp_firstMinter_noDrain() public {
        IStandardExchangeProxy vault_ = _vault();
        IPool pool_ = _getPool(PoolConfig.Balanced);
        IERC20 lp_ = IERC20(address(pool_));

        address donator_ = makeAddr("lpDonator");
        uint256 donate_ = TEST_AMOUNT / 40;
        // Offset 0: equal deposit/donation floors to 0 shares. Honest in must be >> leftover.
        uint256 attackerLp_ = TEST_AMOUNT / 2;
        require(lp_.balanceOf(address(this)) >= donate_ + attackerLp_, "A0 LP inventory");

        lp_.transfer(donator_, donate_);
        vm.prank(donator_);
        lp_.transfer(address(vault_), donate_);
        lp_.transfer(attacker, attackerLp_);

        uint256 attackerLpBefore_ = lp_.balanceOf(attacker);
        assertEq(vault_.totalSupply(), 0, "A0 first mint");

        vm.startPrank(attacker);
        lp_.approve(address(vault_), attackerLp_);
        uint256 shares_ =
            vault_.exchangeIn(lp_, attackerLp_, IERC20(address(vault_)), 0, attacker, false, _deadline());
        assertGt(shares_, 0, "A0 first mint minted");

        uint256 lpOut_ = vault_.exchangeIn(
            IERC20(address(vault_)), shares_, lp_, 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertLe(lpOut_, attackerLp_, "A0: redeem <= deposit");
        assertLe(lp_.balanceOf(attacker), attackerLpBefore_, "A0: attacker LP not increased");
        assertGe(lp_.balanceOf(address(vault_)), donate_, "A0: donated residual remains");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1 LP-deposit: lastTotal exact-gap must not free-mint                 */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: existing lastTotal gap + pretransferred=false + no transfer does not mint.
    function test_I1_lpDeposit_pretransferredFalse_existingLpGap_doesNotMint() public {
        IStandardExchangeProxy vault_ = _vault();
        IPool pool_ = _getPool(PoolConfig.Balanced);
        IERC20 lp_ = IERC20(address(pool_));

        uint256 gap_ = TEST_AMOUNT / 50;
        require(lp_.balanceOf(address(this)) >= gap_, "I1 LP inventory");
        lp_.transfer(address(vault_), gap_);

        uint256 supplyBefore_ = vault_.totalSupply();
        uint256 attackerShares_ = vault_.balanceOf(attacker);
        uint256 lpHeld_ = lp_.balanceOf(address(vault_));

        vm.prank(attacker);
        vm.expectRevert();
        vault_.exchangeIn(lp_, gap_, IERC20(address(vault_)), 0, attacker, false, _deadline());

        assertEq(vault_.totalSupply(), supplyBefore_, "I1: no free vaultShare mint");
        assertEq(vault_.balanceOf(attacker), attackerShares_, "I1: attacker shares unchanged");
        assertEq(lp_.balanceOf(address(vault_)), lpHeld_, "I1: LP inventory unmoved");
    }

    /// @notice I1: booked LP inventory + pretransferred=true + no in-call transfer reverts.
    function test_I1_lpDeposit_pretransferredTrue_bookedInventory_noTransfer_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        IPool pool_ = _getPool(PoolConfig.Balanced);
        IERC20 lp_ = IERC20(address(pool_));

        uint256 seed_ = TEST_AMOUNT / 50;
        require(lp_.balanceOf(address(this)) >= seed_, "I1 LP seed");
        lp_.approve(address(vault_), seed_);
        vault_.exchangeIn(lp_, seed_, IERC20(address(vault_)), 0, address(this), false, _deadline());

        uint256 booked_ = lp_.balanceOf(address(vault_));
        assertGt(booked_, 0, "I1 booked LP");
        uint256 supplyBefore_ = vault_.totalSupply();
        uint256 claimed_ = booked_ / 2;
        if (claimed_ == 0) claimed_ = booked_;

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault_.exchangeIn(lp_, claimed_, IERC20(address(vault_)), 0, attacker, true, _deadline());

        assertEq(vault_.totalSupply(), supplyBefore_, "I1: no free mint against booked LP");
        assertEq(lp_.balanceOf(address(vault_)), booked_, "I1: booked LP unmoved");
    }
}
