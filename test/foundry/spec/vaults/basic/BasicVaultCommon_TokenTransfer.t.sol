// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/* -------------------------------------------------------------------------- */
/*                               Mock Tokens                                  */
/* -------------------------------------------------------------------------- */

/// @notice Standard mock ERC20 for testing normal transfers.
contract MockToken is IERC20 {
    string public name = "MockToken";
    string public symbol = "MCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @notice Fee-on-transfer mock: burns 1% of every transfer as a tax.
contract FeeOnTransferMockToken is IERC20 {
    string public name = "FeeToken";
    string public symbol = "FEE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public constant FEE_BPS = 100; // 1%

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 fee = (amount * FEE_BPS) / 10_000;
        uint256 net = amount - fee;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += net;
        totalSupply -= fee; // burned
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        uint256 fee = (amount * FEE_BPS) / 10_000;
        uint256 net = amount - fee;
        balanceOf[from] -= amount;
        balanceOf[to] += net;
        totalSupply -= fee; // burned
        return true;
    }
}

/* -------------------------------------------------------------------------- */
/*                               Harness                                      */
/* -------------------------------------------------------------------------- */

/**
 * @notice Production-storage harness for BasicVaultCommon reserve-delta law.
 * @dev Uses MultiAssetBasicVaultRepo (same slot as production SE packages).
 *      Models production money route: transfer/pull → optional refund → full-set sync.
 */
contract BasicVaultCommonHarness is BasicVaultCommon {
    constructor(IPermit2 permit2_, address[] memory expectedHoldTokens_) {
        Permit2AwareRepo._initialize(permit2_);
        MultiAssetBasicVaultRepo._initialize(expectedHoldTokens_);
    }

    function secureTokenTransfer(IERC20 tokenIn_, uint256 amount_, bool pretransferred_) external returns (uint256) {
        return _secureTokenTransfer(tokenIn_, amount_, pretransferred_);
    }

    function refundExcess(
        IERC20 token_,
        uint256 maxAmount_,
        uint256 usedAmount_,
        bool pretransferred_,
        address recipient_
    ) external {
        _refundExcess(token_, maxAmount_, usedAmount_, pretransferred_, recipient_);
    }

    function syncAllExpectedHoldReserves() external {
        _syncAllExpectedHoldReserves();
    }

    function bookedReserve(IERC20 token_) external view returns (uint256) {
        return _bookedReserve(token_);
    }

    function unbookedSurplus(IERC20 token_) external view returns (uint256) {
        return _unbookedSurplus(token_);
    }

    /**
     * @notice Models a production money-in route for INV-R1 / absorb / refund law.
     * @param token_ Token to credit.
     * @param claimed_ Claimed / pull amount.
     * @param pretransferred_ Pull vs push mode.
     * @param usedAmount_ Amount "consumed" by the route (for exact-out refund when pretransferred).
     * @param doRefund_ Whether to call _refundExcess (exact-out max > used).
     * @return credit_ Amount returned from secure transfer.
     */
    function moneyIn(
        IERC20 token_,
        uint256 claimed_,
        bool pretransferred_,
        uint256 usedAmount_,
        bool doRefund_
    ) external returns (uint256 credit_) {
        credit_ = _secureTokenTransfer(token_, claimed_, pretransferred_);
        if (doRefund_) {
            _refundExcess(token_, credit_, usedAmount_, pretransferred_, msg.sender);
        }
        _syncAllExpectedHoldReserves();
    }
}

/* -------------------------------------------------------------------------- */
/*                               Test Suite                                   */
/* -------------------------------------------------------------------------- */

/**
 * @title BasicVaultCommon_TokenTransfer_Test
 * @notice Reserve-delta pretransfer law matrix (WP-RSRV-0c / plan §7).
 * @dev Production MultiAssetBasicVaultRepo storage; hermetic (no fork).
 */
contract BasicVaultCommon_TokenTransfer_Test is Test {
    BasicVaultCommonHarness internal harness;
    MockToken internal token;
    MockToken internal tokenB;
    FeeOnTransferMockToken internal feeToken;

    IPermit2 internal constant PERMIT2_PRODUCTION = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address internal alice = makeAddr("alice");

    uint256 internal constant DUST = 50e18;
    uint256 internal constant DEPOSIT = 100e18;

    function setUp() public {
        token = new MockToken();
        tokenB = new MockToken();
        feeToken = new FeeOnTransferMockToken();

        address[] memory hold = new address[](2);
        hold[0] = address(token);
        hold[1] = address(tokenB);
        harness = new BasicVaultCommonHarness(PERMIT2_PRODUCTION, hold);
    }

    /* ---------------------------------------------------------------------- */
    /*  Pull path                                                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Pull false + approve: credit = received; after moneyIn/sync: R == B.
    function test_pull_approve_creditAndSync_INV_R1() public {
        token.mint(alice, DEPOSIT);

        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        uint256 credit = harness.moneyIn(token, DEPOSIT, false, DEPOSIT, false);
        vm.stopPrank();

        assertEq(credit, DEPOSIT, "pull credits received amount");
        assertEq(token.balanceOf(address(harness)), DEPOSIT);
        assertEq(harness.bookedReserve(token), DEPOSIT, "INV-R1: R == B after moneyIn sync");
        assertEq(harness.unbookedSurplus(token), 0);
    }

    /// @notice Pull with prior unbooked U: credit = pull delta only (not U + pull).
    function test_pull_withPriorUnbookedU_creditsPullDeltaOnly() public {
        token.mint(address(harness), DUST); // unbooked (R=0 bootstrap)
        assertEq(harness.bookedReserve(token), 0);
        assertEq(harness.unbookedSurplus(token), DUST);

        token.mint(alice, DEPOSIT);
        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        uint256 credit = harness.secureTokenTransfer(token, DEPOSIT, false);
        vm.stopPrank();

        assertEq(credit, DEPOSIT, "must not add prior unbooked U to pull credit");
        assertEq(token.balanceOf(address(harness)), DUST + DEPOSIT);
    }

    /// @notice Vault with pre-existing dust: deposit returns delta only.
    function test_secureTokenTransfer_dustDoesNotInflateCredit() public {
        token.mint(address(harness), DUST);
        assertEq(token.balanceOf(address(harness)), DUST);

        token.mint(alice, DEPOSIT);
        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        uint256 actual = harness.secureTokenTransfer(token, DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, DEPOSIT, "actualIn should equal deposit, ignoring dust");
        assertEq(token.balanceOf(address(harness)), DUST + DEPOSIT);
    }

    /// @notice Standard ERC20 path returns exact transfer amount (no dust).
    function test_secureTokenTransfer_erc20Path_noDust() public {
        token.mint(alice, DEPOSIT);

        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        uint256 actual = harness.secureTokenTransfer(token, DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, DEPOSIT, "actualIn should match transferred amount");
        assertEq(token.balanceOf(address(harness)), DEPOSIT);
    }

    /* ---------------------------------------------------------------------- */
    /*  Push / pretransferred happy paths                                     */
    /* ---------------------------------------------------------------------- */

    /// @notice Push then true, claimed = push: success; credit = claimed; after sync R == B.
    function test_push_pretransferred_claimedEqPush_successAndSync() public {
        token.mint(alice, DEPOSIT);
        vm.prank(alice);
        token.transfer(address(harness), DEPOSIT);

        assertEq(harness.unbookedSurplus(token), DEPOSIT);

        vm.prank(alice);
        uint256 credit = harness.moneyIn(token, DEPOSIT, true, DEPOSIT, false);

        assertEq(credit, DEPOSIT);
        assertEq(harness.bookedReserve(token), DEPOSIT, "INV-R1 after absorb sync");
        assertEq(harness.unbookedSurplus(token), 0);
    }

    /// @notice Bootstrap R=0: push/true may claim full live balance.
    function test_bootstrap_R0_pushTrue_claimsFullLiveBalance() public {
        // Seed live balance without prior sync (R defaults to 0)
        token.mint(address(harness), DEPOSIT);
        assertEq(harness.bookedReserve(token), 0);
        assertEq(harness.unbookedSurplus(token), DEPOSIT);

        vm.prank(alice);
        uint256 credit = harness.secureTokenTransfer(token, DEPOSIT, true);
        assertEq(credit, DEPOSIT, "bootstrap U=B allows full claim");
    }

    /// @notice Push then true, claimed < push: success; no refund of surplus; after sync absorb (I3).
    function test_push_underClaim_absorbsSurplus_noRefund() public {
        uint256 pushAmt = DEPOSIT + DUST;
        token.mint(alice, pushAmt);
        vm.prank(alice);
        token.transfer(address(harness), pushAmt);

        uint256 balAliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 credit = harness.moneyIn(token, DEPOSIT, true, DEPOSIT, false);

        assertEq(credit, DEPOSIT);
        // No refund of U - claimed
        assertEq(token.balanceOf(alice), balAliceBefore, "must not refund unclaimed push surplus");
        // Absorb: full live balance booked
        assertEq(token.balanceOf(address(harness)), pushAmt);
        assertEq(harness.bookedReserve(token), pushAmt, "I3 absorb: surplus booked into R");
        assertEq(harness.unbookedSurplus(token), 0);

        // Second free claim against absorbed inventory must fail (I1)
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, uint256(0))
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /* ---------------------------------------------------------------------- */
    /*  I1 booked / I2 shortfall                                              */
    /* ---------------------------------------------------------------------- */

    /// @notice Booked inventory (R == B), true, no push → TransferDeltaInsufficient(claimed, 0).
    function test_I1_bookedInventory_pretransferred_revertsDelta0() public {
        token.mint(address(harness), DEPOSIT + DUST);
        // Book inventory so U = 0
        harness.syncAllExpectedHoldReserves();
        assertEq(harness.bookedReserve(token), token.balanceOf(address(harness)));
        assertEq(harness.unbookedSurplus(token), 0);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, uint256(0))
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /// @notice Migrated: pretransferred returnsAmount — booked case fails; push happy is separate.
    function test_secureTokenTransfer_pretransferred_returnsAmount() public {
        token.mint(address(harness), DEPOSIT);
        token.mint(address(harness), DUST);
        harness.syncAllExpectedHoldReserves(); // book so I1 applies

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, uint256(0))
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /// @notice claimed > U: TransferDeltaInsufficient(claimed, U) with exact args.
    function test_I2_claimedGtU_revertsExactArgs() public {
        uint256 U = DEPOSIT / 2;
        token.mint(alice, U);
        vm.prank(alice);
        token.transfer(address(harness), U);

        // R=0 so U_live = U; claim more than U
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, U)
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /// @notice Shortfall with partial unbooked inventory: observedDelta arg is U = B - R.
    function test_secureTokenTransfer_pretransferred_insufficientBalance_reverts() public {
        // Booked R=0, live B = DEPOSIT-1 → U = DEPOSIT-1
        token.mint(address(harness), DEPOSIT - 1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, DEPOSIT - 1
            )
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /* ---------------------------------------------------------------------- */
    /*  Exact-out refund then sync                                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Exact-out: max push, partial use, _refundExcess, sync → caller refunded unused credit; R == B.
    function test_exactOut_refundThenSync_INV_R1() public {
        uint256 maxCredit = DEPOSIT;
        uint256 used = 60e18;
        uint256 expectedRefund = maxCredit - used;

        token.mint(alice, maxCredit);
        vm.prank(alice);
        token.transfer(address(harness), maxCredit);

        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 credit = harness.moneyIn(token, maxCredit, true, used, true);

        assertEq(credit, maxCredit);
        assertEq(token.balanceOf(alice), aliceBefore + expectedRefund, "exact-out refund of unused credit");
        assertEq(token.balanceOf(address(harness)), used);
        assertEq(harness.bookedReserve(token), used, "INV-R1 after refund-then-sync");
        assertEq(harness.unbookedSurplus(token), 0);
    }

    /* ---------------------------------------------------------------------- */
    /*  Fee-on-transfer                                                       */
    /* ---------------------------------------------------------------------- */

    /// @notice Fee-on-transfer pull: credit = actual delta.
    function test_secureTokenTransfer_feeOnTransfer_returnsNetAmount() public {
        // Register fee token into hold set via a dedicated harness
        address[] memory hold = new address[](1);
        hold[0] = address(feeToken);
        BasicVaultCommonHarness feeHarness = new BasicVaultCommonHarness(PERMIT2_PRODUCTION, hold);

        uint256 expectedFee = (DEPOSIT * 100) / 10_000;
        uint256 expectedNet = DEPOSIT - expectedFee;

        feeToken.mint(alice, DEPOSIT);

        vm.startPrank(alice);
        IERC20(address(feeToken)).approve(address(feeHarness), DEPOSIT);
        uint256 actual = feeHarness.secureTokenTransfer(IERC20(address(feeToken)), DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, expectedNet, "actualIn should reflect fee-on-transfer deduction");
        assertEq(IERC20(address(feeToken)).balanceOf(address(feeHarness)), expectedNet);
    }

    /// @notice Fee-on-transfer with pre-existing dust: only pull delta is reported.
    function test_secureTokenTransfer_feeOnTransfer_withDust() public {
        address[] memory hold = new address[](1);
        hold[0] = address(feeToken);
        BasicVaultCommonHarness feeHarness = new BasicVaultCommonHarness(PERMIT2_PRODUCTION, hold);

        uint256 expectedFee = (DEPOSIT * 100) / 10_000;
        uint256 expectedNet = DEPOSIT - expectedFee;

        feeToken.mint(address(feeHarness), DUST);
        feeToken.mint(alice, DEPOSIT);

        vm.startPrank(alice);
        IERC20(address(feeToken)).approve(address(feeHarness), DEPOSIT);
        uint256 actual = feeHarness.secureTokenTransfer(IERC20(address(feeToken)), DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, expectedNet, "actualIn should be net of fee, ignoring dust");
        assertEq(IERC20(address(feeToken)).balanceOf(address(feeHarness)), DUST + expectedNet);
    }

    /* ---------------------------------------------------------------------- */
    /*  Full-set multi-token INV-R1                                           */
    /* ---------------------------------------------------------------------- */

    /// @notice Full-set sync books multi-token hold set: all expected-hold tokens satisfy INV-R1.
    function test_fullSetSync_multiToken_INV_R1() public {
        token.mint(address(harness), 10e18);
        tokenB.mint(address(harness), 20e18);

        // Also pull token into money path
        token.mint(alice, DEPOSIT);
        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        harness.moneyIn(token, DEPOSIT, false, DEPOSIT, false);
        vm.stopPrank();

        // Full-set sync in moneyIn must book both hold-set tokens
        assertEq(harness.bookedReserve(token), token.balanceOf(address(harness)), "token A INV-R1");
        assertEq(harness.bookedReserve(tokenB), tokenB.balanceOf(address(harness)), "token B INV-R1");
        assertEq(harness.bookedReserve(tokenB), 20e18, "token B residual booked even if route only touched A");
    }
}
