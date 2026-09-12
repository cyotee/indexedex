// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";

/**
 * @title CamelotV2StandardExchange_SecRemediation_Decimals
 * @notice Stage 3 cam-se proofs on combo decimals. pairToken = tokenA.
 * @dev After Camelot pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 *      vaultShare stays 18. EX-FOT-NATS: `test_L2_FoT_forbidden` is not cloned.
 */
abstract contract CamelotV2StandardExchange_SecRemediation_Decimals is TestBase_CamelotV2StandardExchange_Decimals {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    ICamelotPair internal pair;
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("camelotSeAttacker");
        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        tokenA.mint(address(this), _uA(10_000));
        tokenB.mint(address(this), _uB(10_000));

        vm.label(address(tokenA), "pairToken-tokenA");
        vm.label(address(tokenB), "otherToken-tokenB");

        uint256 seedA = _uA(1000);
        uint256 seedB = _uB(1000);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), seedA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), seedB);
        vault = IStandardExchangeProxy(
            camelotV2StandardExchangeDFPkg.deployVault(
                IERC20(address(tokenA)), seedA, IERC20(address(tokenB)), seedB, address(this)
            )
        );
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));
        require(address(pair) != address(0), "pair");
        uint256 lpSeedA = _uA(500);
        uint256 lpSeedB = _uB(500);
        tokenA.approve(address(camelotV2Router), lpSeedA);
        tokenB.approve(address(camelotV2Router), lpSeedB);
        camelotV2Router.addLiquidity(
            address(tokenA), address(tokenB), lpSeedA, lpSeedB, 1, 1, address(this), _deadline()
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /// @notice CAM-OUT: exchangeOut swap on the proxy pays tokenOut to recipient.
    /// @dev pairToken in used from preview; amountOut is `_uB(1)` of the other token.
    function test_CAM_OUT_exchangeOut_swap_recipientReceivesTokenOut() public {
        uint256 amountOut_ = _uB(1);
        uint256 used_ = vault.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(used_ > 0, "preview used");

        tokenA.mint(attacker, used_);
        uint256 recipientBBefore_ = tokenB.balanceOf(attacker);

        vm.startPrank(attacker);
        tokenA.approve(address(vault), used_);
        uint256 usedExec_ = vault.exchangeOut(
            IERC20(address(tokenA)), used_, IERC20(address(tokenB)), amountOut_, attacker, false, _deadline()
        );
        vm.stopPrank();

        uint256 recipientDelta_ = tokenB.balanceOf(attacker) - recipientBBefore_;
        assertGt(recipientDelta_, 0, "CAM-OUT: recipient tokenOut delta");
        assertEq(usedExec_, used_, "CAM-OUT: return is tokenIn used, not amountOut");
    }

    /// @notice E6: fat max + transfer-only-used + pretransferred must not skim booked pairToken R.
    /// @dev inventory/syncPull are `_uA`; amountOut is `_uB(1)` of the other token.
    function test_E6_exchangeOut_swap_inflatedMax_pretransferred_noExtraTransfer_noInventorySkim() public {
        uint256 inventory_ = _uA(20);
        uint256 syncPull_ = _uA(5);
        tokenA.mint(address(vault), inventory_);
        tokenA.mint(attacker, syncPull_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), syncPull_);
        vault.exchangeIn(IERC20(address(tokenA)), syncPull_, IERC20(address(tokenB)), 0, attacker, false, _deadline());
        vm.stopPrank();

        uint256 bookedR_ = vault.reserveOfToken(address(tokenA));
        assertEq(bookedR_, tokenA.balanceOf(address(vault)), "E6: pairToken booked after sync");
        assertGe(bookedR_, inventory_, "E6: seeded inventory booked");

        uint256 amountOut_ = _uB(1);
        uint256 used_ = vault.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(used_ > 0, "preview");
        uint256 fatMax_ = used_ + bookedR_;

        tokenA.mint(attacker, used_);
        vm.prank(attacker);
        tokenA.transfer(address(vault), used_);

        uint256 attackerABefore_ = tokenA.balanceOf(attacker);
        uint256 rBefore_ = vault.reserveOfToken(address(tokenA));

        vm.prank(attacker);
        vault.exchangeOut(
            IERC20(address(tokenA)), fatMax_, IERC20(address(tokenB)), amountOut_, attacker, true, _deadline()
        );

        uint256 attackerAGain_ = tokenA.balanceOf(attacker) - attackerABefore_;
        assertEq(attackerAGain_, 0, "E6: no pairToken refund from booked R");
        assertGe(tokenA.balanceOf(address(vault)), rBefore_, "E6: booked pairToken R intact");
        assertLt(attackerAGain_, bookedR_, "E6: attacker must not receive booked R");
    }

    /// @notice A0: donate reserve LP (donator != attacker), zap-in deposit; redeem cannot take donation.
    /// @dev zap-in is `_uA(50)` of pairToken.
    function test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation() public {
        IERC20 lp_ = IERC20(address(pair));
        uint256 donate_ = lp_.balanceOf(address(this)) / 10;
        require(donate_ > MIN_TEST_AMOUNT, "donate");
        uint256 vaultLpBefore_ = lp_.balanceOf(address(vault));
        lp_.transfer(address(vault), donate_);

        uint256 zapIn_ = _uA(50);
        tokenA.mint(attacker, zapIn_);
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);

        vm.startPrank(attacker);
        tokenA.approve(address(vault), zapIn_);
        try vault.exchangeIn(
            IERC20(address(tokenA)), zapIn_, IERC20(address(vault)), 0, attacker, false, _deadline()
        ) returns (uint256 shares_) {
            if (shares_ > 0) {
                vault.redeem(shares_, attacker, attacker);
            }
        } catch {}
        vm.stopPrank();

        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "A0: attacker holds no leftover shares");
        assertGe(lp_.balanceOf(address(vault)), vaultLpBefore_ + donate_, "A0: donated LP remains");
    }

    /// @notice A0: unsown vault + residual LP; first minter cannot drain donation.
    /// @dev Fresh pair uses the same combo decimals as pairToken/other.
    function test_A0_emptyVault_residualLp_firstMinter_noDrain() public {
        MintableERC20Decimals tokenC_ = new MintableERC20Decimals("Token C", "TKNC", _tokenADecimals());
        MintableERC20Decimals tokenD_ = new MintableERC20Decimals("Token D", "TKND", _tokenBDecimals());
        tokenC_.mint(address(this), _uA(10_000));
        tokenD_.mint(address(this), _uB(10_000));
        uint256 liqA_ = _uA(500);
        uint256 liqB_ = _uB(500);
        tokenC_.approve(address(camelotV2Router), liqA_);
        tokenD_.approve(address(camelotV2Router), liqB_);
        camelotV2Router.addLiquidity(
            address(tokenC_), address(tokenD_), liqA_, liqB_, 1, 1, address(this), _deadline()
        );

        IStandardExchangeProxy emptyVault_ = IStandardExchangeProxy(
            camelotV2StandardExchangeDFPkg.deployVault(
                IERC20(address(tokenC_)), 0, IERC20(address(tokenD_)), 0, address(0)
            )
        );
        ICamelotPair emptyPair_ = ICamelotPair(camelotV2Factory.getPair(address(tokenC_), address(tokenD_)));
        require(address(emptyPair_) != address(0), "empty pair");
        assertEq(emptyVault_.totalSupply(), 0, "A0: empty supply");

        IERC20 emptyLp_ = IERC20(address(emptyPair_));
        uint256 donate_ = emptyLp_.balanceOf(address(this)) / 5;
        require(donate_ > MIN_TEST_AMOUNT, "empty donate");
        emptyLp_.transfer(address(emptyVault_), donate_);
        uint256 vaultLpAfterDonate_ = emptyLp_.balanceOf(address(emptyVault_));

        uint256 zapIn_ = _uA(50);
        tokenC_.mint(attacker, zapIn_);
        vm.startPrank(attacker);
        tokenC_.approve(address(emptyVault_), zapIn_);
        try emptyVault_.exchangeIn(
            IERC20(address(tokenC_)), zapIn_, IERC20(address(emptyVault_)), 0, attacker, false, _deadline()
        ) returns (uint256 shares_) {
            if (shares_ > 0) {
                emptyVault_.redeem(shares_, attacker, attacker);
            }
        } catch {}
        vm.stopPrank();

        assertEq(emptyVault_.balanceOf(attacker), 0, "A0 empty: no leftover shares");
        assertGe(emptyLp_.balanceOf(address(emptyVault_)), vaultLpAfterDonate_, "A0 empty: residual LP not drained");
    }

    /// @notice I1 LP-deposit: lastTotalAssets gap, pretransferred=false, no in-call LP transfer → no mint.
    function test_I1_lpDeposit_pretransferredFalse_existingLpGap_doesNotMint() public {
        IERC20 lp_ = IERC20(address(pair));
        uint256 gap_ = lp_.balanceOf(address(this)) / 40;
        require(gap_ > MIN_TEST_AMOUNT, "gap");
        lp_.transfer(address(vault), gap_);

        uint256 supplyBefore_ = vault.totalSupply();
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 vaultLpBefore_ = lp_.balanceOf(address(vault));

        vm.prank(attacker);
        vm.expectRevert();
        vault.exchangeIn(lp_, gap_, IERC20(address(vault)), 0, attacker, false, _deadline());

        assertEq(vault.totalSupply(), supplyBefore_, "I1 lpDeposit: no free share mint");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "I1 lpDeposit: attacker shares unchanged");
        assertEq(lp_.balanceOf(address(vault)), vaultLpBefore_, "I1 lpDeposit: LP inventory unmoved");
    }
}
