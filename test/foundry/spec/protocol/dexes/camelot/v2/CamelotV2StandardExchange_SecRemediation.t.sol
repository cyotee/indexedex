// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {FeeOnTransferERC20} from "contracts/test/stubs/FeeOnTransferERC20.sol";
import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

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


    /// @dev REQ-C06 fixtures use distinct callers and recipients, a live share book, and zero short credit.
    struct C06Route {
        IStandardExchangeProxy target;
        IERC20 input;
        IERC20 output;
        uint256 requested;
        uint256 quoted;
        uint256 maximum;
        uint256 deadline;
        uint256 poolOutputBefore;
    }

    /// @dev Snapshot every fixture token/share balance and reserve for caller, recipient, payer and vault.
    function _c06State(C06Route memory r, address caller, address recipient) internal view returns (bytes32 state) {
        IERC20[] memory tokens = _c06Tokens();
        address[4] memory accounts = [caller, recipient, address(this), address(r.target)];
        state = keccak256(abi.encode(r.target.totalSupply(), _c06Book()));
        for (uint256 i; i < tokens.length; ++i) {
            state = keccak256(abi.encode(state, r.target.reserveOfToken(address(tokens[i]))));
            for (uint256 j; j < accounts.length; ++j) {
                state = keccak256(abi.encode(state, tokens[i].balanceOf(accounts[j])));
            }
        }
    }

    function _c06Data(C06Route memory r, address recipient, bool prepaid) internal pure returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (r.input, r.maximum, r.output, r.requested, recipient, prepaid, r.deadline));
    }

    function _c06Reject(uint8 branch, bool contractCaller) internal {
        C06Route memory r = _c06Route(branch);
        address recipient = makeAddr("C06 recipient");
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        address caller = contractCaller ? address(wallet) : makeAddr("C06 EOA");
        assertEq(caller.code.length == 0, !contractCaller, "caller kind");
        bytes memory data = _c06Data(r, recipient, true);
        bytes32 beforeState = _c06State(r, caller, recipient);
        if (contractCaller) {
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, r.quoted, 0));
            wallet.execute(address(r.target), data);
        } else {
            vm.prank(caller);
            vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
            r.target.exchangeOut(r.input, r.maximum, r.output, r.requested, recipient, true, r.deadline);
        }
        assertEq(_c06State(r, caller, recipient), beforeState, "all balances, supply and books unchanged");
    }

    function _c06Pull(C06Route memory r) internal returns (uint256 paid) {
        address caller = makeAddr("C06 pull EOA");
        address recipient = makeAddr("C06 recipient");
        assertEq(caller.code.length, 0);
        r.input.transfer(caller, r.maximum);
        uint256 beforeInput = r.input.balanceOf(caller);
        uint256 beforeOutput = r.output.balanceOf(recipient);
        uint256 beforeSupply = r.target.totalSupply();
        vm.startPrank(caller);
        r.input.approve(address(r.target), r.maximum);
        uint256 used = r.target.exchangeOut(r.input, r.maximum, r.output, r.requested, recipient, false, r.deadline);
        vm.stopPrank();
        assertEq(used, r.quoted, "input equals fixture quote");
        assertLe(used, r.maximum, "maximum respected");
        assertEq(beforeInput - r.input.balanceOf(caller), used, "pull debits only used");
        paid = r.output.balanceOf(recipient) - beforeOutput;
        _c06Payout(r, paid);
        _c06Supply(r, beforeSupply, used);
    }

    function _c06Success(uint8 branch, bool prepaid) internal {
        C06Route memory r = _c06Route(branch);
        if (!prepaid) { _c06Pull(r); return; }
        // Compare the same unchanged route on the same initial state, including zap rounding.
        uint256 snap = vm.snapshotState();
        uint256 expectedPayout = _c06Pull(r);
        assertTrue(vm.revertToState(snap));
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        address recipient = makeAddr("C06 recipient");
        uint256 beforeInput = r.input.balanceOf(address(this));
        uint256 beforeOutput = r.output.balanceOf(recipient);
        uint256 beforeSupply = r.target.totalSupply();
        r.input.approve(address(wallet), r.maximum);
        uint256 used = abi.decode(wallet.consumePretransfer(r.input, address(this), address(r.target), r.maximum,
            _c06Data(r, recipient, true)), (uint256));
        assertEq(used, r.quoted, "prepaid input equals quote");
        assertLe(used, r.maximum);
        assertEq(beforeInput - r.input.balanceOf(address(this)), r.maximum, "payer supplies credited maximum");
        assertEq(r.input.balanceOf(address(wallet)), r.maximum - used, "refund is credit minus used");
        assertEq(beforeInput - r.input.balanceOf(address(this)) - r.input.balanceOf(address(wallet)), used,
            "net input reconciles");
        assertEq(r.output.balanceOf(recipient) - beforeOutput, expectedPayout, "unchanged route payout");
        _c06Supply(r, beforeSupply, used);
    }

    function _c06Supply(C06Route memory r, uint256 beforeSupply, uint256 used) internal view {
        if (address(r.output) == address(r.target)) {
            assertEq(r.target.totalSupply(), beforeSupply + r.requested, "exact share issue");
        } else if (address(r.input) == address(r.target)) {
            assertEq(r.target.totalSupply(), beforeSupply - used, "shares burned equal input");
        } else {
            assertEq(r.target.totalSupply(), beforeSupply, "no share issue or burn");
        }
    }

    function _c06Tokens() internal view returns (IERC20[] memory tokens) {
        tokens = new IERC20[](4);
        tokens[0] = IERC20(address(tokenA)); tokens[1] = IERC20(address(tokenB));
        tokens[2] = IERC20(address(pair)); tokens[3] = IERC20(address(vault));
    }

    function _c06Book() internal view returns (uint256) { return vault.totalAssets(); }

    function _c06Payout(C06Route memory r, uint256 paid) internal view {
        if (address(r.output) == address(r.target) || (address(r.input) == address(r.target)
            && address(r.output) == address(_c06Tokens()[2])) || (address(r.input) == address(_c06Tokens()[0])
            && address(r.output) == address(_c06Tokens()[1]))) {
            assertEq(paid, r.requested, "exact requested output");
        } else {
            IERC20 lp = _c06Tokens()[2];
            if (address(r.output) == address(lp)) {
                assertGe(paid, r.requested, "zap-in pays all LP produced, at least requested");
            } else {
                // Zap-out pays every output token released by the pool, retaining its existing rounding.
                assertGt(paid, 0, "nonzero zap payout");
                assertEq(paid, r.poolOutputBefore - r.output.balanceOf(address(lp)), "all pool proceeds paid");
            }
        }
    }

    function _c06Route(uint8 branch) internal returns (C06Route memory r) {
        r.target = vault;
        IERC20 lp = IERC20(address(pair));
        uint256 seed = lp.balanceOf(address(this)) / 10;
        assertGt(seed, 0, "LP seed available");
        lp.approve(address(r.target), seed);
        r.target.exchangeIn(lp, seed, IERC20(address(r.target)), 1, address(this), false, block.timestamp + 1 hours);
        IERC20 a = IERC20(address(tokenA));
        IERC20 b = IERC20(address(tokenB));
        IERC20 share = IERC20(address(r.target));
        if (branch == 0) { r.input = a; r.output = b; }
        else if (branch == 1) { r.input = lp; r.output = a; }
        else if (branch == 2) { r.input = lp; r.output = share; }
        else if (branch == 3) { r.input = share; r.output = lp; }
        else if (branch == 4) { r.input = share; r.output = a; }
        r.requested = address(r.output) == address(r.target) ? r.target.totalSupply() / 1000 : 1 ether;
        assertGt(r.target.totalSupply(), 0, "nonempty share book");
        assertGt(r.requested, 0, "positive output");
        r.poolOutputBefore = r.output.balanceOf(address(lp));
        r.deadline = block.timestamp + 1 hours;
        r.quoted = r.target.previewExchangeOut(r.input, r.output, r.requested);
        assertGt(r.quoted, 0, "supported positive quote");
        r.maximum = r.quoted + r.quoted / 10 + 1;
        assertGe(r.maximum, r.quoted, "ceiling admits quote");
        assertGe(r.deadline, block.timestamp, "valid deadline");
        assertEq(r.input.balanceOf(address(r.target)), r.target.reserveOfToken(address(r.input)), "no unbooked input");
        assertGe(r.input.balanceOf(address(this)), r.maximum, "funded control available");
    }

    /// @notice REQ-C06 tokenSwap: Code-less short-credit caller is rejected before credit.
    function test_C06_tokenSwap_eoaShort() public { _c06Reject(0, false); }

    /// @notice REQ-C06 tokenSwap: Allowed contract caller retains the exact short-credit error.
    function test_C06_tokenSwap_contractShort() public { _c06Reject(0, true); }

    /// @notice REQ-C06 tokenSwap: Code-less false-flag caller pays the quoted input.
    function test_C06_tokenSwap_eoaPull() public { _c06Success(0, false); }

    /// @notice REQ-C06 tokenSwap: Funded contract prepayment reconciles output and refund.
    function test_C06_tokenSwap_contractFunded() public { _c06Success(0, true); }

    /// @notice REQ-C06 lpToToken: Code-less short-credit caller is rejected before credit.
    function test_C06_lpToToken_eoaShort() public { _c06Reject(1, false); }

    /// @notice REQ-C06 lpToToken: Allowed contract caller retains the exact short-credit error.
    function test_C06_lpToToken_contractShort() public { _c06Reject(1, true); }

    /// @notice REQ-C06 lpToToken: Code-less false-flag caller pays the quoted input.
    function test_C06_lpToToken_eoaPull() public { _c06Success(1, false); }

    /// @notice REQ-C06 lpToToken: Funded contract prepayment reconciles output and refund.
    function test_C06_lpToToken_contractFunded() public { _c06Success(1, true); }

    /// @notice REQ-C06 lpToShare: Code-less short-credit caller is rejected before credit.
    function test_C06_lpToShare_eoaShort() public { _c06Reject(2, false); }

    /// @notice REQ-C06 lpToShare: Allowed contract caller retains the exact short-credit error.
    function test_C06_lpToShare_contractShort() public { _c06Reject(2, true); }

    /// @notice REQ-C06 lpToShare: Code-less false-flag caller pays the quoted input.
    function test_C06_lpToShare_eoaPull() public { _c06Success(2, false); }

    /// @notice REQ-C06 lpToShare: Funded contract prepayment reconciles output and refund.
    function test_C06_lpToShare_contractFunded() public { _c06Success(2, true); }

    /// @notice REQ-C06 shareToLp: Code-less short-credit caller is rejected before credit.
    function test_C06_shareToLp_eoaShort() public { _c06Reject(3, false); }

    /// @notice REQ-C06 shareToLp: Allowed contract caller retains the exact short-credit error.
    function test_C06_shareToLp_contractShort() public { _c06Reject(3, true); }

    /// @notice REQ-C06 shareToLp: Code-less false-flag caller pays the quoted input.
    function test_C06_shareToLp_eoaPull() public { _c06Success(3, false); }

    /// @notice REQ-C06 shareToLp: Funded contract prepayment reconciles output and refund.
    function test_C06_shareToLp_contractFunded() public { _c06Success(3, true); }

    /// @notice REQ-C06 shareToToken: Code-less short-credit caller is rejected before credit.
    function test_C06_shareToToken_eoaShort() public { _c06Reject(4, false); }

    /// @notice REQ-C06 shareToToken: Allowed contract caller retains the exact short-credit error.
    function test_C06_shareToToken_contractShort() public { _c06Reject(4, true); }

    /// @notice REQ-C06 shareToToken: Code-less false-flag caller pays the quoted input.
    function test_C06_shareToToken_eoaPull() public { _c06Success(4, false); }

    /// @notice REQ-C06 shareToToken: Funded contract prepayment reconciles output and refund.
    function test_C06_shareToToken_contractFunded() public { _c06Success(4, true); }

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

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(
            IERC20(address(tokenA)), fatMax_, IERC20(address(tokenB)), amountOut_, attacker, true, _deadline()
        );
    }

    function test_E6_exchangeOut_swap_inflatedMax_contractCaller_noInventorySkim() public {
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 inventory_ = 20 ether;
        uint256 syncPull_ = TEST_AMT / 10;
        tokenA.mint(address(vault), inventory_);
        tokenA.mint(address(this), syncPull_);
        tokenA.approve(address(vault), syncPull_);
        vault.exchangeIn(IERC20(address(tokenA)), syncPull_, IERC20(address(tokenB)), 0, address(this), false, _deadline());

        uint256 bookedR_ = vault.reserveOfToken(address(tokenA));
        assertEq(bookedR_, tokenA.balanceOf(address(vault)), "E6: pairToken booked after sync");

        uint256 amountOut_ = 1 ether;
        uint256 used_ = vault.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(used_ > 0, "preview");
        uint256 fatMax_ = used_ + bookedR_;

        tokenA.mint(address(caller), used_);
        vm.prank(address(caller));
        tokenA.transfer(address(vault), used_);

        uint256 callerABefore_ = tokenA.balanceOf(address(caller));
        uint256 rBefore_ = vault.reserveOfToken(address(tokenA));

        vm.prank(address(caller));
        vault.exchangeOut(
            IERC20(address(tokenA)), fatMax_, IERC20(address(tokenB)), amountOut_, address(caller), true, _deadline()
        );

        uint256 callerAGain_ = tokenA.balanceOf(address(caller)) - callerABefore_;
        assertEq(callerAGain_, 0, "E6: no pairToken refund from booked R");
        assertGe(tokenA.balanceOf(address(vault)), rBefore_, "E6: booked pairToken R intact");
        assertLt(callerAGain_, bookedR_, "E6: attacker must not receive booked R");
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
        vm.expectRevert(abi.encodeWithSignature("AllowanceExpired(uint256)", 0));
        vault.exchangeIn(lp_, gap_, IERC20(address(vault)), 0, attacker, false, _deadline());

        assertEq(vault.totalSupply(), supplyBefore_, "I1 lpDeposit: no free share mint");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "I1 lpDeposit: attacker shares unchanged");
        assertEq(lp_.balanceOf(address(vault)), vaultLpBefore_, "I1 lpDeposit: LP inventory unmoved");
        _assertFundedLpGapControl(vault, lp_, gap_);
    }

    function _assertFundedLpGapControl(IStandardExchangeProxy vault_, IERC20 lp_, uint256 gap_) internal {
        uint256[4] memory before_ = [lp_.balanceOf(address(this)), vault_.balanceOf(attacker),
            vault_.totalSupply(), lp_.balanceOf(address(vault_))];
        AtomicPretransferCaller caller_ = new AtomicPretransferCaller();
        lp_.approve(address(caller_), gap_);
        bytes memory data_ = abi.encodeWithSignature(
            "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
            lp_, gap_, IERC20(address(vault_)), 1, attacker, false, _deadline());
        uint256 minted_ = abi.decode(caller_.consumePull(lp_, address(this), address(vault_), gap_, data_), (uint256));
        assertGt(minted_, 0, "funded control issues shares");
        assertEq(lp_.balanceOf(address(this)), before_[0] - gap_, "payer supplies the full input");
        assertEq(vault_.balanceOf(attacker), before_[1] + minted_);
        assertEq(vault_.totalSupply(), before_[2] + minted_);
        assertEq(lp_.balanceOf(address(vault_)), before_[3] + gap_, "old inventory stays in custody");
        assertEq(lp_.balanceOf(address(caller_)), 0, "exact-in pull refunds nothing");
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
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        fotVault.exchangeIn(
            IERC20(address(fot)), claimed_, IERC20(address(other)), 0, attacker, true, _deadline()
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  APEX-2026-004B / D35: exact-out refund is `min(availableBefore, max) - used`   */
    /* ---------------------------------------------------------------------- */

    function test_APEX004B_exactOut_refundTriples_contractCaller() public {
        uint256 used_ = vault.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), 1 ether);
        require(used_ > 0, "preview used");
        uint256 hundred_ = (used_ * 100) / 60;
        uint256 eighty_ = (used_ * 80) / 60;
        _refundTripleCase(hundred_, hundred_, used_); // 100/100/60 -> 40
        _refundTripleCase(hundred_, eighty_, used_); // 100/80/60 -> 20, 20 uncredited
        _refundTripleCase(used_, hundred_, used_); // 60/100/60 -> 0
    }

    function _refundTripleCase(uint256 available_, uint256 maximum_, uint256 used_) internal {
        uint256 snap = vm.snapshotState();
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        tokenA.mint(address(this), available_);
        tokenA.approve(address(caller), available_);
        uint256 bookedBefore_ = vault.reserveOfToken(address(tokenA));
        uint256 vaultBefore_ = tokenA.balanceOf(address(vault));
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (IERC20(address(tokenA)), maximum_, IERC20(address(tokenB)), 1 ether, address(caller), true, _deadline())
        );
        uint256 spent_ = abi.decode(caller.consumePretransfer(IERC20(address(tokenA)), address(this), address(vault), available_, data), (uint256));
        assertEq(spent_, used_, "used equals quote");
        uint256 credit_ = available_ < maximum_ ? available_ : maximum_;
        assertEq(tokenA.balanceOf(address(caller)), credit_ - used_, "refund = min(available, max) - used");
        assertEq(tokenB.balanceOf(address(caller)), 1 ether, "exact output");
        assertGe(vault.reserveOfToken(address(tokenA)), bookedBefore_, "booked backing never paid out");
        assertEq(tokenA.balanceOf(address(vault)), vaultBefore_ + available_ - (credit_ - used_) - used_, "vault keeps used + uncredited excess");
        assertTrue(vm.revertToState(snap));
    }
}
