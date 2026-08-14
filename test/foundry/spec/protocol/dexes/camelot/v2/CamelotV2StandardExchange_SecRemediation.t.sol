// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {FeeOnTransferERC20} from "contracts/test/stubs/FeeOnTransferERC20.sol";
import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";

/// @notice Stage 3 cam-se proofs on the production Camelot V2 SE proxy.
/// @dev Catalog names required by WP-SEC-CAM-OUT-001, E6/R4/A0/I1 LP-deposit.
contract CamelotV2StandardExchange_SecRemediation_Test is TestBase_CamelotV2StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    ICamelotPair internal pair;
    address internal attacker;

    uint256 internal constant SEED = 1000 ether;
    uint256 internal constant TEST_AMT = 50 ether;
    uint256 internal constant LP_SEED = 500 ether;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("camelotSeAttacker");
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 10_000 ether);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 10_000 ether);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), SEED);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), SEED);
        vault = IStandardExchangeProxy(
            camelotV2StandardExchangeDFPkg.deployVault(
                IERC20(address(tokenA)), SEED, IERC20(address(tokenB)), SEED, address(this)
            )
        );
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));
        require(address(pair) != address(0), "pair");
        tokenA.approve(address(camelotV2Router), LP_SEED);
        tokenB.approve(address(camelotV2Router), LP_SEED);
        camelotV2Router.addLiquidity(
            address(tokenA), address(tokenB), LP_SEED, LP_SEED, 1, 1, address(this), _deadline()
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /// @notice CAM-OUT: exchangeOut swap on the proxy pays tokenOut to recipient.
    function test_CAM_OUT_exchangeOut_swap_recipientReceivesTokenOut() public {
        uint256 amountOut_ = 1 ether;
        uint256 used_ = vault.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(used_ > 0, "preview used");

        deal(address(tokenA), attacker, used_);
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
    function test_E6_exchangeOut_swap_inflatedMax_pretransferred_noExtraTransfer_noInventorySkim() public {
        uint256 inventory_ = 20 ether;
        uint256 syncPull_ = TEST_AMT / 10;
        tokenA.mint(address(vault), inventory_);
        tokenA.mint(attacker, syncPull_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), syncPull_);
        vault.exchangeIn(IERC20(address(tokenA)), syncPull_, IERC20(address(tokenB)), 0, attacker, false, _deadline());
        vm.stopPrank();

        uint256 bookedR_ = vault.reserveOfToken(address(tokenA));
        assertEq(bookedR_, tokenA.balanceOf(address(vault)), "E6: pairToken booked after sync");
        assertGe(bookedR_, inventory_, "E6: seeded inventory booked");

        uint256 amountOut_ = 1 ether;
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
    function test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation() public {
        IERC20 lp_ = IERC20(address(pair));
        uint256 donate_ = lp_.balanceOf(address(this)) / 10;
        require(donate_ > 1e15, "donate");
        uint256 vaultLpBefore_ = lp_.balanceOf(address(vault));
        lp_.transfer(address(vault), donate_);

        uint256 zapIn_ = TEST_AMT;
        deal(address(tokenA), attacker, zapIn_);
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
    function test_A0_emptyVault_residualLp_firstMinter_noDrain() public {
        ERC20PermitMintableStub tokenC_ =
            new ERC20PermitMintableStub("Token C", "TKNC", 18, address(this), 10_000 ether);
        ERC20PermitMintableStub tokenD_ =
            new ERC20PermitMintableStub("Token D", "TKND", 18, address(this), 10_000 ether);
        uint256 liq_ = 500 ether;
        tokenC_.approve(address(camelotV2Router), liq_);
        tokenD_.approve(address(camelotV2Router), liq_);
        camelotV2Router.addLiquidity(
            address(tokenC_), address(tokenD_), liq_, liq_, 1, 1, address(this), _deadline()
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
        require(donate_ > 1e15, "empty donate");
        emptyLp_.transfer(address(emptyVault_), donate_);
        uint256 vaultLpAfterDonate_ = emptyLp_.balanceOf(address(emptyVault_));

        uint256 zapIn_ = TEST_AMT;
        deal(address(tokenC_), attacker, zapIn_);
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
        require(gap_ > 1e15, "gap");
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

    /// @notice L2: real FoT as configured pairToken cannot credit claimed face.
    /// @dev Agent law § Token policy. Production Camelot V2 SE proxy. Not a FoT-success path.
    function test_L2_FoT_forbidden() public {
        FeeOnTransferERC20 fot = new FeeOnTransferERC20("FOT", "FOT", 1000);
        ERC20PermitMintableStub other =
            new ERC20PermitMintableStub("Other", "OTH", 18, address(this), 10_000 ether);
        uint256 seed_ = SEED;
        fot.mint(address(this), seed_);
        fot.approve(address(camelotV2StandardExchangeDFPkg), seed_);
        other.approve(address(camelotV2StandardExchangeDFPkg), seed_);
        IStandardExchangeProxy fotVault = IStandardExchangeProxy(
            camelotV2StandardExchangeDFPkg.deployVault(
                IERC20(address(fot)), seed_, IERC20(address(other)), seed_, address(this)
            )
        );

        uint256 claimed_ = 10 ether;
        fot.mint(attacker, claimed_);
        vm.startPrank(attacker);
        fot.transfer(address(fotVault), claimed_);
        uint256 observed_ = fot.balanceOf(address(fotVault));
        assertLt(observed_, claimed_, "L2: FoT delivered less than claimed");
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, observed_
            )
        );
        fotVault.exchangeIn(
            IERC20(address(fot)), claimed_, IERC20(address(other)), 0, attacker, true, _deadline()
        );
        vm.stopPrank();
    }
}
